import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class SessionProvider extends ChangeNotifier {
  SharedPreferences? _prefs;
  SessionProvider() {
    loadSession();
  }

  loadSession() async {
    _prefs = await SharedPreferences.getInstance();
    _hasSession = _prefs?.getString('api_token') != null;
    _isChecking = true;
    notifyListeners();
  }

  bool _hasSession = false;
  bool _isChecking = true;

  bool get hasSession => _hasSession;
  bool get isChecking => _isChecking;

  Future<void> checkApiSession() async {
    _isChecking = true;
    notifyListeners();

    final hasSession = await ApiService.checkStatus();
    if (hasSession) {
      _hasSession = true;
    }
    _isChecking = false;
    notifyListeners();
  }

  Future<void> checkLocalSession() async {
    _isChecking = true;
    notifyListeners();

    final hasSession = _prefs?.getString('api_token') != null;
    if (hasSession) {
      _hasSession = true;
    }
    _isChecking = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getLastLogin() async {
    final info = await SharedPreferences.getInstance();
    final userData = info.getString('user_data');
    if (userData == null) {
      return null;
    }

    return json.decode(userData) as Map<String, dynamic>;
  }
}
