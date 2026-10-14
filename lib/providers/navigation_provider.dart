import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  String _currentRoute = '/dashboard';
  bool _isSidebarExpanded = true;
  int _resetCounter = 0; // Counter to signal sidebar reset
  int _permissionsCounter = 0;
  Map<String, dynamic>? _searchFilter; // Store search filter parameters

  String get currentRoute => _currentRoute;
  bool get isSidebarExpanded => _isSidebarExpanded;
  int get resetCounter => _resetCounter;
  int get permissionsCounter => _permissionsCounter;
  Map<String, dynamic>? get searchFilter => _searchFilter;

  void setCurrentRoute(String route, {Map<String, dynamic>? searchFilter}) {
    _currentRoute = route;
    _searchFilter = searchFilter;
    notifyListeners();
  }

  void clearSearchFilter() {
    _searchFilter = null;
    notifyListeners();
  }

  void bumpPermissions() {
    _permissionsCounter++;
    notifyListeners();
  }

  void toggleSidebar() {
    _isSidebarExpanded = !_isSidebarExpanded;
    notifyListeners();
  }

  void setSidebarExpanded(bool expanded) {
    _isSidebarExpanded = expanded;
    notifyListeners();
  }

  // Reset to dashboard and signal sidebar to clear expanded items
  void resetToDashboard() {
    _currentRoute = '/dashboard';
    _resetCounter++;
    notifyListeners();
  }
}
