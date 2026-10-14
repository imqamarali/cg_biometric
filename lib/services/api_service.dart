import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/static_env.dart';

/// Client for the biometric device gateway (see docs/biometric-api.md).
///
/// The server is configured by a base URL (`HOST`, e.g.
/// `https://erp.example.com/admin/web`). Every call is a `POST` to
/// `HOST/biometric_gateway/index.php` with an `action` field, and every
/// answer is `{status, message, data}`.
class ApiService {
  static const _baseUrlKey = 'base_url';
  static const _gatewayPath = '/biometric_gateway/index.php';
  static const _timeout = Duration(seconds: 15);

  // ---------------- SESSION EXPIRY ----------------

  /// Set by the app shell: clears the session and shows the login screen.
  static void Function(String message)? onSessionExpired;
  static bool _expiring = false;

  static bool _isUnauthorized(Map<String, dynamic> data) {
    if (data['status'] == true) return false;
    final msg = '${data['message']}'.toLowerCase();
    return msg.contains('unauthorized') ||
        msg.contains('invalid token') ||
        msg.contains('token expired') ||
        msg.contains('session expired') ||
        msg.contains('invalid api token');
  }

  /// Wipes the local session and sends the user back to the login screen.
  static Future<void> expireSession([
    String message = 'Session out. Please sign in again.',
  ]) async {
    if (_expiring) return;
    _expiring = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().toList()) {
        if (key != _baseUrlKey) await prefs.remove(key);
      }
      onSessionExpired?.call(message);
    } finally {
      // Allow the next login to be guarded again.
      Future.delayed(const Duration(seconds: 2), () => _expiring = false);
    }
  }

  // ---------------- BASE URL ----------------

  /// The configured base URL, or an empty string when none was set.
  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey) ?? '';
  }

  /// Saves the base URL used for every API call. An empty value restores the
  /// built-in default. Returns false when the value is not a valid http(s) URL.
  static Future<bool> setBaseUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = value.trim().replaceAll(RegExp(r'/+$'), '');
    if (cleaned.isEmpty) {
      await prefs.remove(_baseUrlKey);
      return true;
    }
    final uri = Uri.tryParse(cleaned);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      return false;
    }
    await prefs.setString(_baseUrlKey, cleaned);
    return true;
  }

  /// Gateway URL: `HOST/biometric_gateway/index.php`. A value that already
  /// points at a `.php` file is used as given.
  static Future<Uri> _gateway() async {
    final base = await getBaseUrl();
    if (base.isEmpty) return Uri.parse(StaticEnv.apiBaseUrl);
    if (base.toLowerCase().endsWith('.php')) return Uri.parse(base);
    return Uri.parse('$base$_gatewayPath');
  }

  // ---------------- HELPERS ----------------

  static Future<bool> hasSession() async =>
      (await SharedPreferences.getInstance()).getString('api_token') != null;

  static Future<String> _token() async =>
      (await SharedPreferences.getInstance()).getString('api_token') ?? '';

  /// POSTs [fields] as JSON to the gateway and returns the decoded envelope.
  static Future<Map<String, dynamic>> _call(Map<String, dynamic> fields) async {
    final response = await http
        .post(
          await _gateway(),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(fields),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw 'Server returned HTTP ${response.statusCode}';
    }
    final decoded = json.decode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw 'Unexpected response from server';
    }
    // A rejected token on any call means the session is over.
    if (fields['action'] != 'login' &&
        fields['api_token'] != null &&
        _isUnauthorized(decoded)) {
      await expireSession();
      throw 'Session out. Please sign in again.';
    }
    return decoded;
  }

  // ---------------- CHECK STATUS ----------------
  static Future<bool> checkStatus() async {
    try {
      final token = await _token();
      if (token.isEmpty) {
        await expireSession();
        return false;
      }
      final data = await _call({'action': 'check_status', 'api_token': token});
      return data['status'] == true;
    } catch (_) {
      return false;
    }
  }

  // ---------------- LOGIN ----------------
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final data = await _call({
        'action': 'login',
        'username': username,
        'password': password,
      });

      if (data['status'] == true && data['data'] is Map) {
        final userData = Map<String, dynamic>.from(data['data'] as Map);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', username);
        await prefs.setString('api_token', '${userData['api_token']}');
        await prefs.setString(
          'get_data_endpoint',
          '${userData['get_data_endpoint'] ?? ''}',
        );
        await prefs.setString(
          'post_data_endpoint',
          '${userData['post_data_endpoint'] ?? ''}',
        );
        await prefs.setString('user_data', json.encode(userData));
        return {'success': true, 'user': userData};
      }
      return {
        'success': false,
        'message': data['message']?.toString() ?? 'Login failed',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ---------------- CHECK CNIC ----------------
  /// Is this CNIC registered, and what comes next?
  /// `next` is `register`, `verify` or `continue` (already verified on the
  /// given transfer).
  static Future<Map<String, dynamic>> checkCnic({
    required String cnic,
    String? transferId,
  }) async {
    try {
      final token = await _token();
      if (token.isEmpty) {
        return {'success': false, 'message': 'User not logged in'};
      }
      final data = await _call({
        'action': 'check_cnic',
        'api_token': token,
        'cnic': cnic,
        if (transferId != null && transferId.isNotEmpty)
          'transfer_id': int.tryParse(transferId) ?? transferId,
      });
      final inner = data['data'];
      return {
        'success': data['status'] == true && inner is Map,
        'message': data['message']?.toString(),
        'next': inner is Map ? inner['next']?.toString() : null,
        'registered': inner is Map ? inner['registered'] == true : null,
        'verified': inner is Map ? inner['verified'] : null,
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ---------------- GET DATA ----------------
  /// Memberships of a CNIC. With [fileNo] the CNIC must belong to that file;
  /// with [transferId] it must be a member of that transfer request.
  static Future<Map<String, dynamic>> getData({
    required String cnic,
    String? fileNo,
    String? transferId,
  }) async {
    try {
      final token = await _token();
      if (token.isEmpty) {
        return {'success': false, 'message': 'User not logged in'};
      }
      final data = await _call({
        'action': 'get_data',
        'api_token': token,
        'cnic': cnic,
        if (fileNo != null && fileNo.isNotEmpty) 'file_no': fileNo,
        if (transferId != null && transferId.isNotEmpty)
          'transfer_id': int.tryParse(transferId) ?? transferId,
      });
      return {'success': true, 'data': data, 'message': data['message']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ---------------- POST / VERIFY ----------------

  /// Member Registration: saves (or replaces) the fingerprint of a CNIC.
  /// Sent once per member; later verifications use the registered fingerprint.
  static Future<Map<String, dynamic>> registerMember({
    required String cnic,
    required Uint8List fingerprintImage,
  }) => _fingerprintCall(
    'post_data',
    type: 'registration',
    cnic: cnic,
    fingerprintImage: fingerprintImage,
  );

  /// Allotment / Transfer verification. With no [fingerprintImage] the server
  /// verifies from the registered fingerprint; with one it compares a live scan.
  /// [type] is `allotment` (needs [fileNo]) or `transfer` (needs [transferId]).
  static Future<Map<String, dynamic>> verifyData({
    required String type,
    required String cnic,
    Uint8List? fingerprintImage,
    String? fileNo,
    String? transferId,
  }) => _fingerprintCall(
    'verify_data',
    type: type,
    cnic: cnic,
    fingerprintImage: fingerprintImage,
    fileNo: fileNo,
    transferId: transferId,
  );

  /// Result: `{success, message, data, method}` where `data` is the project's
  /// own answer; `method` is `registry` or `scan` for verifications.
  static Future<Map<String, dynamic>> _fingerprintCall(
    String action, {
    required String type,
    required String cnic,
    Uint8List? fingerprintImage,
    String? fileNo,
    String? transferId,
  }) async {
    try {
      final token = await _token();
      if (token.isEmpty) {
        return {'success': false, 'message': 'User not logged in'};
      }
      final data = await _call({
        'action': action,
        'api_token': token,
        'type': type,
        'cnic': cnic,
        if (type == 'allotment') 'file_no': fileNo,
        if (type == 'transfer')
          'transfer_id': int.tryParse(transferId ?? '') ?? transferId,
        if (fingerprintImage != null)
          'fingerprint_snapshots': [base64Encode(fingerprintImage)],
      });

      if (data['status'] != true) {
        return {
          'success': false,
          'message': data['message']?.toString() ?? 'Request refused',
        };
      }
      final inner = data['data'];
      String? method;
      if (inner is Map) {
        method =
            (inner['method'] ??
                    (inner['data'] is Map ? inner['data']['method'] : null))
                ?.toString();
      }
      if (inner is Map && inner['status'] == false) {
        return {
          'success': false,
          'message': inner['message']?.toString() ?? 'Request failed',
          'data': inner,
        };
      }
      return {
        'success': true,
        'message': (inner is Map ? inner['message'] : null) ?? data['message'],
        'data': inner,
        'method': method,
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ---------------- VERIFY BIOMETRIC IMAGE ----------------
  static Future<Map<String, dynamic>> captureBiometricImage({
    required String cnic,
    required String base64Image,
  }) async {
    try {
      final token = await _token();
      if (token.isEmpty) {
        return {'success': false, 'message': 'User not logged in'};
      }
      final data = await _call({
        'action': 'verify_biometric_image',
        'api_token': token,
        'cnic': cnic,
        'base64_image': base64Image,
      });
      return {'success': true, 'data': data['data']?['data']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // ---------------- LOGOUT ----------------
  /// Drops the token on the server (best effort) and clears local session
  /// data, keeping the configured base URL.
  static Future<void> logout() async {
    try {
      final token = await _token();
      if (token.isNotEmpty) {
        await _call({'action': 'logout', 'api_token': token});
      }
    } catch (_) {
      // Offline: the token still expires on its own after 5 hours.
    }
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (key != _baseUrlKey) await prefs.remove(key);
    }
  }

  static List<String> buildFingerprintArray(Uint8List fingerprintImage) {
    return [base64Encode(fingerprintImage)];
  }
}
