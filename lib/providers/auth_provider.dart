import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this.service);

  final AuthService service;
  String? role;
  bool loading = false;
  String? error;

  bool get isAuthenticated => role != null;

  Future<void> login(String username, String password) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      role = await service.login(username, password);
    } catch (_) {
      error = 'Неверный логин или пароль';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void logout() {
    role = null;
    service.logout();
    notifyListeners();
  }
}
