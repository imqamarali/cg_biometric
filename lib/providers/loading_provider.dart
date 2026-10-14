import 'package:flutter/material.dart';

class LoadingProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _loadingMessage;

  bool get isLoading => _isLoading;
  String? get loadingMessage => _loadingMessage;

  void showLoading([String? message]) {
    _isLoading = true;
    _loadingMessage = message;
    notifyListeners();
  }

  void hideLoading() {
    _isLoading = false;
    _loadingMessage = null;
    notifyListeners();
  }
}
