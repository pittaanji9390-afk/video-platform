import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _token;
  String? _userRole;

  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;
  String? get userRole => _userRole;

  Future<bool> login(String email, String password) async {
    _isAuthenticated = true;
    _token = 'demo_token';
    _userRole = 'vendor';
    notifyListeners();
    return true;
  }

  void logout() {
    _isAuthenticated = false;
    _token = null;
    _userRole = null;
    notifyListeners();
  }
}
