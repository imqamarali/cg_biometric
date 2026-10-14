// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../services/api_service.dart';
import '../services/elevation.dart';
import '../services/wbf_capture.dart';
import '../theme/ace_theme.dart';
import '../widgets/custom_dialog.dart';

/// The three operations of the device:
///  * `registration` - Member Registration: scan once and save by CNIC.
///  * `allotment`    - Allotment Verification: CNIC + file number.
///  * `transfer`     - Transfer Verification: CNIC + transfer ID.
/// A verification always scans a finger and sends it to the server, which
/// matches it against the registered fingerprint (and records the result).
class BiometricRegistrationScreen extends StatefulWidget {
  final String operation;

  const BiometricRegistrationScreen({super.key, required this.operation});

  @override
  State<BiometricRegistrationScreen> createState() =>
      _BiometricRegistrationScreenState();
}

class _BiometricRegistrationScreenState
    extends State<BiometricRegistrationScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _cnicController = TextEditingController();
  final TextEditingController _refController = TextEditingController();

  bool get _isRegistration => widget.operation == 'registration';
  bool get _isTransfer => widget.operation == 'transfer';
  bool get _isVerification => !_isRegistration;

  // Banner under the form.
  String? _notice;
  Color _noticeColor = Ace.info;

  // State of the current CNIC.
  bool _checked = false; // lookup finished
  bool _registered = false; // a fingerprint is already registered
  bool _alreadyVerified = false; // transfer already verified ("continue")
  List<dynamic>? _memberships;

  // Fingerprint / result.
  bool _loading = false;
  bool _scanning = false;
  bool _authenticated = false;
  String _consoleMessage = '';
  Uint8List? _fingerprintImage;
  bool? _verifyOk;
  String _verifyMessage = '';

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _cnicController.dispose();
    _refController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- helpers
  String get _ref => _refController.text.trim();
  String get _cnic => _cnicController.text.trim();
  String get _type => widget.operation; // registration | allotment | transfer

  void _resetResult() {
    _checked = false;
    _registered = false;
    _alreadyVerified = false;
    _memberships = null;
    _authenticated = false;
    _consoleMessage = '';
    _fingerprintImage = null;
    _notice = null;
    _verifyOk = null;
    _verifyMessage = '';
  }

  Future<void> _error(String title, String message) => ErrorDialog.show(
    context: context,
    title: title,
    message: message,
    width: 520,
    height: 260,
  );

  // ------------------------------------------------------------------ check
  Future<void> _check() async {
    if (_loading) return;
    if (!RegExp(r'^\d{13}$').hasMatch(_cnic)) {
      await _error('Invalid CNIC', 'The CNIC must be exactly 13 digits.');
      return;
    }
    if (!_isRegistration && _ref.isEmpty) {
      await _error(
        _isTransfer ? 'Transfer ID required' : 'File number required',
        _isTransfer
            ? 'Enter the transfer request ID.'
            : 'Enter the file number the CNIC belongs to.',
      );
      return;
    }

    setState(() {
      _resetResult();
      _loading = true;
    });

    try {
      // 1. Who is this CNIC (and does it belong to the file / transfer)?
      final response = await ApiService.getData(
        cnic: _cnic,
        fileNo: (!_isRegistration && !_isTransfer) ? _ref : null,
        transferId: _isTransfer ? _ref : null,
      );
      final ok =
          response['success'] == true &&
          response['data'] is Map &&
          response['data']['status'] == true &&
          response['data']['data'] is List;
      if (!ok) {
        setState(() => _loading = false);
        await _error(
          'Member not found',
          (response['data'] is Map ? response['data']['message'] : null)
                  ?.toString() ??
              response['message']?.toString() ??
              'No member found for this CNIC.',
        );
        return;
      }
      final list = List.from(response['data']['data'] as List);

      // 2. Is a fingerprint already registered? What comes next?
      final check = await ApiService.checkCnic(
        cnic: _cnic,
        transferId: _isTransfer ? _ref : null,
      );
      if (!mounted) return;
      final next = check['success'] == true ? check['next'] as String? : null;

      setState(() {
        _memberships = list;
        _checked = true;
        _registered = next == 'verify' || next == 'continue';
        _alreadyVerified = next == 'continue' && _isTransfer;
        _loading = false;
      });

      if (_isRegistration) {
        if (_registered) {
          setState(() {
            _notice =
                'This member is already registered. Registration is normally done once; saving a new scan will replace the registered fingerprint.';
            _noticeColor = Ace.warning;
          });
        } else {
          await _scan(); // first registration: capture straight away
        }
      } else {
        if (next == 'register') {
          setState(() {
            _notice =
                check['message']?.toString() ??
                'Not registered: biometric registration is required first. Use Member Registration for this CNIC.';
            _noticeColor = Ace.danger;
          });
        } else {
          setState(() {
            _notice = _alreadyVerified
                ? 'Already verified on this transfer. You can scan again to re-check.'
                : 'Registered fingerprint found. Place the finger on the scanner to verify.';
            _noticeColor = _alreadyVerified ? Ace.successDark : Ace.info;
          });
          await _verify(); // scan and match against the saved fingerprint
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      await _error('Error', e.toString());
    }
  }

  // ------------------------------------------------------------------- scan
  /// Captures one fingerprint into [_fingerprintImage]. Returns true on success.
  Future<bool> _scan() async {
    // No pre-check of the reader: just try to capture and report the real
    // reason if it fails.
    setState(() {
      _consoleMessage = 'Waiting for fingerprint...';
      _fingerprintImage = null;
      _verifyOk = null;
      _verifyMessage = '';
      _notice = null;
      _scanning = true;
    });

    try {
      // 1. Windows' own fingerprint service, in-process (any Windows Hello reader).
      setState(() => _consoleMessage = 'Place your finger on scanner...');
      final result = await captureWithWindowsBiometric().timeout(
        const Duration(seconds: 60),
        onTimeout: () => const WbfCaptureResult.fail(
          'No finger was detected within 60 seconds.',
        ),
      );
      if (!mounted) return false;
      if (result.isOk) {
        setState(() {
          _fingerprintImage = result.png;
          _authenticated = true;
          _consoleMessage = 'Fingerprint captured successfully!';
        });
        return true;
      }

      // 2. Administrator permission needed: ask for it now.
      if (result.needsAdmin && !await Elevation.isElevated()) {
        final ask = await ConfirmationDialog.show(
          context: context,
          title: 'Administrator permission needed',
          message:
              'Windows only gives the fingerprint image to administrators. Restart CG Biometric as administrator now?',
          confirmText: 'Restart as administrator',
          cancelText: 'Not now',
          icon: Icons.admin_panel_settings_outlined,
          width: 540,
          height: 250,
        );
        if (ask == true && await Elevation.relaunchAsAdmin()) {
          exit(0);
        }
        setState(() => _consoleMessage = result.error ?? 'Scan failed');
        return false;
      }

      // 3. DigitalPersona helper, only when it is installed next to the app.
      final hasDp = await _findHelperPath(
        'FingerprintReaderApp.exe',
      ).then((_) => true, onError: (_) => false);
      if (!hasDp) {
        setState(() => _consoleMessage = result.error ?? 'Scan failed');
        await _error('Fingerprint scan failed', result.error ?? 'Scan failed');
        return false;
      }

      // DigitalPersona SDK helper (fallback).
      final exe = await _findHelperPath('FingerprintReaderApp.exe');
      final process = await Process.start(exe, []);
      final out = StringBuffer();
      process.stdout.transform(utf8.decoder).listen((data) {
        out.write(data);
        if (data.contains('Place your finger') && mounted) {
          setState(() => _consoleMessage = 'Place your finger on scanner...');
        }
      });
      process.stderr.transform(utf8.decoder).listen((e) {
        debugPrint('reader error: $e');
      });
      final procExit = await process.exitCode.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          process.kill();
          return -1;
        },
      );
      final text = out.toString();
      final err = RegExp(r'ERROR\|([^\r\n]*)').firstMatch(text);
      if (err != null || (procExit == -1 && !text.contains('IMAGE_BASE64|'))) {
        final msg = (err?.group(1)?.trim().isNotEmpty ?? false)
            ? err!.group(1)!.trim()
            : 'No finger was detected within 60 seconds.';
        setState(() => _consoleMessage = msg);
        await _error('Fingerprint scan failed', msg);
        return false;
      }
      if (!text.contains('IMAGE_BASE64|')) {
        setState(() => _consoleMessage = 'No fingerprint data received.');
        await _error('Error', 'No fingerprint image received from scanner.');
        return false;
      }
      final b64 = text.split('IMAGE_BASE64|')[1].replaceAll('\n', '').trim();
      setState(() {
        _fingerprintImage = base64Decode(b64);
        _authenticated = true;
        _consoleMessage = 'Fingerprint captured successfully!';
      });
      return true;
    } on FileSystemException catch (e) {
      setState(() => _consoleMessage = 'Fingerprint helper missing');
      await _error(
        'Missing component',
        'The fingerprint helper was not found. ${e.message}\nReinstall CG Biometric.',
      );
      return false;
    } catch (e) {
      setState(() => _consoleMessage = 'Error scanning fingerprint: $e');
      await _error('Error', e.toString());
      return false;
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<String> _findHelperPath(String exeName) async {
    final dir = File(Platform.resolvedExecutable).parent;
    final candidates = [
      path.join(dir.path, exeName),
      path.join(dir.path, 'resources', exeName),
      path.join(
        Directory.current.path,
        'windows',
        'runner',
        'resources',
        exeName,
      ),
    ];
    for (final c in candidates) {
      if (await File(c).exists()) return c;
    }
    throw FileSystemException('$exeName not found', candidates.first);
  }

  // --------------------------------------------------------- register (post)
  Future<void> _register() async {
    final image = _fingerprintImage;
    if (image == null) return;

    if (_registered) {
      final replace = await ConfirmationDialog.show(
        context: context,
        title: 'Replace fingerprint?',
        message:
            'This member already has a registered fingerprint. Replace it with the new scan?',
        confirmText: 'Replace',
        cancelText: 'Cancel',
        icon: Icons.warning_amber_rounded,
        width: 520,
        height: 240,
      );
      if (replace != true) return;
    }

    setState(() => _loading = true);
    final result = await ApiService.registerMember(
      cnic: _cnic,
      fingerprintImage: image,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] != true) {
      await _error(
        'Registration failed',
        (result['message'] ?? 'Failed to register biometric data').toString(),
      );
      return;
    }
    await SuccessDialog.show(
      context: context,
      title: 'Registered',
      message:
          'Member registered. Verifications will now use this fingerprint.',
      width: 520,
      height: 230,
    );
    if (mounted) Navigator.of(context).pop();
  }

  // ------------------------------------------------------------------ verify
  /// Scans a finger and sends it to the server, which matches it against the
  /// fingerprint saved at registration and records the result.
  Future<void> _verify() async {
    final ok = await _scan();
    if (!ok || !mounted) return;
    final image = _fingerprintImage;
    if (image == null) return;

    setState(() {
      _loading = true;
      _verifyOk = null;
    });
    final result = await ApiService.verifyData(
      type: _type,
      cnic: _cnic,
      fileNo: _isTransfer ? null : _ref,
      transferId: _isTransfer ? _ref : null,
      fingerprintImage: image,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _verifyOk = result['success'] == true;
      var msg = result['message']?.toString() ?? '';
      if (_verifyOk!) {
        _verifyMessage = msg.isEmpty
            ? 'Fingerprint matched and saved'
            : '$msg - saved';
        if (_isTransfer) _alreadyVerified = true;
      } else {
        // "Fingerprint not found" from the server means no match.
        final lower = msg.toLowerCase();
        _verifyMessage = (msg.isEmpty || lower.contains('not found'))
            ? 'Fingerprint not matching. Please try again.'
            : msg;
      }
    });
  }

  // ------------------------------------------------------------ one record
  Map<String, dynamic>? get _record {
    final list = _memberships;
    if (list == null) return null;
    final maps = list
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    if (maps.isEmpty) return null;
    if (_isRegistration) return maps.first;

    final ref = _ref.toLowerCase();
    final keys = _isTransfer
        ? const ['transfer_id', 'transfer_request_id', 'transfer_no']
        : const ['file_no', 'file_number', 'fileno'];
    String norm(Object? v) => v?.toString().trim().toLowerCase() ?? '';
    for (final m in maps) {
      for (final k in keys) {
        if (ref.isNotEmpty && norm(m[k]) == ref) return m;
      }
    }
    return maps.first;
  }

  // ------------------------------------------------------------ details grid
  Widget _detailCell(String label, Widget value, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Ace.borderLight),
          bottom: BorderSide(color: Ace.borderLight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.6,
              color: Ace.muted,
            ),
          ),
          const SizedBox(height: 4),
          value,
        ],
      ),
    );
  }

  Widget _buildLeftColumn() {
    final rec = _record;
    final title = rec == null
        ? 'Member details'
        : _isRegistration
        ? 'Member'
        : (_isTransfer ? 'Transfer #$_ref' : 'File $_ref');

    Widget body;
    if (_loading && !_checked) {
      body = const _LoadingPane(text: 'Fetching record...');
    } else if (_memberships == null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.manage_search, size: 46, color: Color(0xFFCCCCCC)),
            const SizedBox(height: 8),
            Text(
              _isRegistration
                  ? 'Enter the CNIC, then press Check'
                  : 'Enter the ${_isTransfer ? 'transfer ID' : 'file number'} and CNIC, then press Check',
              style: const TextStyle(color: Ace.muted),
            ),
          ],
        ),
      );
    } else if (rec == null) {
      body = const Center(
        child: Text(
          'No matching record found',
          style: TextStyle(color: Ace.muted),
        ),
      );
    } else {
      String f(String k) {
        final v = rec[k]?.toString().trim();
        return (v == null || v.isEmpty) ? '-' : v;
      }

      Widget text(String v) => SelectableText(
        v,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      );

      final status = f('comment');
      final cells = <(String, Widget)>[
        ('Member name', text(f('member_name'))),
        ('Relation', text('${f('relation')}  ${f('sodowo')}'.trim())),
        ('CNIC', text(_cnic)),
        ('Consumer no', text(f('consumer_no'))),
        ('Plot no', text(f('plot_no'))),
        ('Size', text(f('size'))),
        ('Sector', text(f('sector_name'))),
        if (_isRegistration)
          ('Memberships', text('${_memberships!.length}'))
        else
          (_isTransfer ? 'Transfer ID' : 'File no', text(_ref)),
        (
          'Status',
          Align(
            alignment: Alignment.centerLeft,
            child: AceLabel(status == '-' ? 'Unknown' : status),
          ),
        ),
      ];

      body = LayoutBuilder(
        builder: (context, c) {
          const photoW = 132.0;
          final gridW = c.maxWidth - photoW;
          final cols = gridW >= 440 ? 3 : 2;
          final cellW = (gridW - 1) / cols;
          return SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: photoW,
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Ace.headerBg,
                    border: Border(
                      right: BorderSide(color: Ace.borderLight),
                      bottom: BorderSide(color: Ace.borderLight),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Ace.border),
                          color: Colors.white,
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Image.network(
                          rec['image']?.toString() ?? '',
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 88,
                            height: 88,
                            color: Ace.borderLight,
                            child: const Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        f('member_name'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Ace.link,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Wrap(
                    children: [
                      for (final cell in cells)
                        _detailCell(
                          cell.$1,
                          cell.$2,
                          cell.$1 == 'Status'
                              ? cellW * cols
                              : (cell.$1 == 'File no' ||
                                        cell.$1 == 'Transfer ID' ||
                                        cell.$1 == 'Memberships') &&
                                    cols == 3
                              ? cellW * 2
                              : cellW,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return AceWidgetBox(
      title: title,
      icon: Icons.badge_outlined,
      padding: EdgeInsets.zero,
      child: body,
    );
  }

  // ------------------------------------------------------- right-hand panel
  Widget _resultBar() => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(10),
    color: _verifyOk! ? Ace.successDark : Ace.danger,
    child: Row(
      children: [
        Icon(
          _verifyOk! ? Icons.check_circle : Icons.cancel,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _verifyMessage,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _spinnerIcon(IconData icon) => _loading
      ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
      : Icon(icon, size: 18);

  Widget _fingerprintVisual({double size = 96}) {
    if (_fingerprintImage != null) {
      return Container(
        decoration: BoxDecoration(border: Border.all(color: Ace.border)),
        child: Image.memory(_fingerprintImage!, width: 150, height: 150),
      );
    }
    if (_scanning) {
      return ScaleTransition(
        scale: Tween(
          begin: 0.9,
          end: 1.08,
        ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
        child: FadeTransition(
          opacity: Tween(begin: 0.45, end: 1.0).animate(_pulse),
          child: Icon(Icons.fingerprint, size: size, color: Ace.info),
        ),
      );
    }
    return Icon(
      Icons.fingerprint,
      size: size,
      color: _authenticated
          ? Ace.successDark
          : (_isVerification && _registered
                ? Ace.successDark.withValues(alpha: 0.7)
                : const Color(0xFFCCCCCC)),
    );
  }

  Widget _buildRightColumn() {
    final hasRecord = _record != null;
    return AceWidgetBox(
      title: _isRegistration ? 'Fingerprint' : 'Verification',
      icon: Icons.fingerprint,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _fingerprintVisual(),
              const SizedBox(height: 8),
              if (_scanning)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  child: LinearProgressIndicator(minHeight: 3, color: Ace.info),
                ),
              const SizedBox(height: 8),
              Text(
                _consoleMessage.isNotEmpty
                    ? _consoleMessage
                    : (_isVerification && hasRecord && _registered
                          ? 'Registered fingerprint on file'
                          : 'Ready'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Ace.muted),
              ),
              const SizedBox(height: 12),
              if (_verifyOk != null) _resultBar(),

              // ---- Member Registration ----
              if (_isRegistration && _fingerprintImage != null)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _registered
                        ? Ace.warning
                        : Ace.successDark,
                  ),
                  onPressed: _loading ? null : _register,
                  icon: _spinnerIcon(Icons.cloud_upload_outlined),
                  label: Text(
                    _registered ? 'Replace Fingerprint' : 'Save Fingerprint',
                  ),
                ),
              if (_isRegistration && hasRecord && !_scanning) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _scan,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(
                    _fingerprintImage == null
                        ? 'Scan fingerprint'
                        : 'Scan again',
                  ),
                ),
              ],

              // ---- Allotment / Transfer Verification ----
              if (_isVerification && hasRecord && _registered && !_scanning)
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Ace.primary),
                  onPressed: _loading ? null : _verify,
                  icon: _spinnerIcon(Icons.fingerprint),
                  label: Text(
                    _verifyOk == null ? 'Scan & Verify' : 'Scan again',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------- form
  Widget _labelled(String label, Widget field) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12.5, color: Ace.muted)),
      const SizedBox(height: 4),
      field,
    ],
  );

  static const _fieldPadding = EdgeInsets.symmetric(horizontal: 10);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!_isRegistration) ...[
              Expanded(
                child: _labelled(
                  _isTransfer ? 'Transfer ID' : 'File No',
                  SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _refController,
                      enabled: !_loading,
                      keyboardType: _isTransfer
                          ? TextInputType.number
                          : TextInputType.text,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        contentPadding: _fieldPadding,
                        hintText: _isTransfer ? 'e.g. 51' : 'e.g. NAV-ACH-1',
                        prefixIcon: Icon(
                          _isTransfer ? Icons.swap_horiz : Icons.folder_open,
                          size: 18,
                        ),
                      ),
                      onSubmitted: (_) => _check(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: _labelled(
                'CNIC (13 digits)',
                SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _cnicController,
                    enabled: !_loading,
                    keyboardType: TextInputType.number,
                    maxLength: 13,
                    textAlignVertical: TextAlignVertical.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      contentPadding: _fieldPadding,
                      counterText: '',
                      hintText: '3520112345671',
                      prefixIcon: Icon(Icons.badge_outlined, size: 18),
                    ),
                    onSubmitted: (_) => _check(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              height: 40,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Ace.info,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onPressed: _loading ? null : _check,
                icon: _spinnerIcon(Icons.search),
                label: Text(_loading ? 'Checking...' : 'Check'),
              ),
            ),
          ],
        ),
        if (_notice != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _noticeColor.withValues(alpha: 0.12),
              border: Border.all(color: _noticeColor),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: _noticeColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_notice!, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildLeftColumn()),
              const SizedBox(width: 14),
              SizedBox(width: 280, child: _buildRightColumn()),
            ],
          ),
        ),
      ],
    );
  }
}

/// Centered spinner with a caption, used while a request is running.
class _LoadingPane extends StatelessWidget {
  final String text;
  const _LoadingPane({required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const LinearProgressIndicator(minHeight: 3, color: Ace.info),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 46,
                  height: 46,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: Ace.info,
                  ),
                ),
                const SizedBox(height: 14),
                Text(text, style: const TextStyle(color: Ace.muted)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
