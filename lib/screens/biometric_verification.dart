// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../services/api_service.dart';
import '../widgets/custom_dialog.dart';
import '../widgets/defaults.dart';

class BiometricVerificationScreen extends StatefulWidget {
  const BiometricVerificationScreen({super.key});

  @override
  State<BiometricVerificationScreen> createState() =>
      _BiometricVerificationScreenState();
}

class _BiometricVerificationScreenState
    extends State<BiometricVerificationScreen> {
  final TextEditingController _cnicController = TextEditingController();

  final LocalAuthentication _auth = LocalAuthentication();

  bool _deviceConnected = false;
  bool _scanning = false;
  bool _verified = false;

  String _consoleMessage = '';
  List<dynamic>? _memberships;

  @override
  void initState() {
    super.initState();
    _checkDevice();
  }

  // ---------------- DEVICE CHECK ----------------
  Future<void> _checkDevice() async {
    final supported = await _auth.isDeviceSupported();
    if (!mounted) return;
    setState(() => _deviceConnected = supported);
  }

  // ---------------- AUTO VERIFY ----------------
  Future<void> _startVerification() async {
    final cnic = _cnicController.text.trim();
    if (cnic.isEmpty || _scanning) return;

    setState(() {
      _scanning = true;
      _verified = false;
      _memberships = null;
      _consoleMessage = 'Waiting for fingerprint...';
    });
    var progressOpen = false;
    void closeProgress() {
      if (progressOpen && mounted) {
        progressOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    progressOpen = true;

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Verify fingerprint',
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
      if (!mounted) return;

      if (!authenticated) {
        setState(() => _consoleMessage = 'Fingerprint not recognized');
        return;
      }

      final response = await ApiService.getData(cnic: cnic);
      if (!mounted) return;
      closeProgress();
      if (response['success'] == true &&
          response['data'] != null &&
          response['data']['status'] == true) {
        final dataList = response['data']['data'];
        setState(() {
          _verified = true;
          _consoleMessage = response['message'] ?? 'Fingerprint verified';
          _memberships = dataList is List ? List.from(dataList) : [];
        });
      } else {
        ErrorDialog.show(
          context: context,
          title: 'Verification Failed',
          message:
              response['message'] ??
              response['data']?['message'] ??
              'Fingerprint does not match',
        );
      }
    } catch (e) {
      closeProgress();
      if (mounted) {
        ErrorDialog.show(
          context: context,
          title: 'Error',
          message: e.toString(),
        );
      }
    } finally {
      closeProgress();
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        /// 🔹 INFO PANEL (NEW)
        buildInfoPanel(theme, _deviceConnected),
        TextField(
          controller: _cnicController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'CNIC',
            prefixIcon: const Icon(Icons.verified_user),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onSubmitted: (_) {
            if (_deviceConnected) {
              _startVerification();
            }
          },
        ),
        if (_consoleMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _consoleMessage,
              style: TextStyle(
                color: _verified ? Colors.green.shade700 : Colors.blueGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        const SizedBox(height: 24),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: buildLeftColumn(_memberships)),
            Expanded(
              flex: 1,
              child: Icon(
                Icons.fingerprint,
                size: 120,
                color: _verified ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
