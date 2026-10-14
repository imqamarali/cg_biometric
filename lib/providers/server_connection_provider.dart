import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ServerConnectionProvider extends ChangeNotifier {
  bool _isConnected = false;
  bool _isChecking = false;
  String? _errorMessage;
  DateTime? _lastCheckTime;

  Timer? _timer;
  bool _stopped = false;

  bool get isConnected => _isConnected;
  bool get isChecking => _isChecking;
  String? get errorMessage => _errorMessage;
  DateTime? get lastCheckTime => _lastCheckTime;

  // ▶️ Start periodic checking
  void start() {
    _stopped = false;
    _timer?.cancel();
    // Defer so listeners are never notified while the widget tree is building.
    Future.microtask(() => _checkConnection().then((_) => _runCheck()));
  }

  // 🛑 Stop periodic checking
  void stop() {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
  }

  // 🔁 Main loop
  void _runCheck() {
    if (_stopped) return;
    _timer?.cancel();

    _timer = Timer(
      _isConnected ? const Duration(seconds: 30) : const Duration(seconds: 5),
      () async {
        await _checkConnection();
        _runCheck();
      },
    );
  }

  // 🔍 Core check
  Future<void> _checkConnection() async {
    if (_isChecking) return;

    _isChecking = true;
    notifyListeners();

    try {
      final result = await ApiService.checkStatus();
      _isConnected = result;
      _errorMessage = result ? null : 'Status check failed';
    } catch (e) {
      _isConnected = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isChecking = false;
      _lastCheckTime = DateTime.now();
      notifyListeners();
    }
  }

  // 👆 Manual refresh
  Future<void> manualCheck() async {
    await _checkConnection();
    _runCheck(); // reset timer after manual refresh
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
