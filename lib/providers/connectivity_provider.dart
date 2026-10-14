import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityProvider extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  bool _isConnected = true;
  String _connectionType = 'Unknown';
  double _connectionSpeed = 0.0; // in Mbps

  bool get isConnected => _isConnected;
  String get connectionType => _connectionType;
  double get connectionSpeed => _connectionSpeed;

  ConnectivityProvider() {
    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
      onError: (error) {
        debugPrint('Connectivity error: $error');
      },
    );
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      _isConnected = false;
      _connectionType = 'Error';
      notifyListeners();
    }
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    if (result == ConnectivityResult.none) {
      _isConnected = false;
      _connectionType = 'No Internet';
      _connectionSpeed = 0.0;
    } else {
      _isConnected = true;
      if (result == ConnectivityResult.mobile) {
        _connectionType = 'Mobile Data';
        _connectionSpeed = await _testConnectionSpeed();
      } else if (result == ConnectivityResult.wifi) {
        _connectionType = 'WiFi';
        _connectionSpeed = await _testConnectionSpeed();
      } else if (result == ConnectivityResult.ethernet) {
        _connectionType = 'Ethernet';
        _connectionSpeed = await _testConnectionSpeed();
      } else {
        _connectionType = 'Connected';
        _connectionSpeed = await _testConnectionSpeed();
      }
    }
    notifyListeners();
  }

  Future<double> _testConnectionSpeed() async {
    try {
      // Simulate speed test (in real app, you'd ping a server)
      // For now, we'll return a mock speed based on connection type
      await Future.delayed(const Duration(milliseconds: 100));
      return 25.5; // Mock speed in Mbps
    } catch (e) {
      return 0.0;
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
