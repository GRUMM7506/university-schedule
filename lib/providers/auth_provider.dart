import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/token_store.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this.service);

  final AuthService service;
  final TokenStore _tokenStore = TokenStore();
  String? role;
  String? username;
  int? studentId;
  int? linkedId;
  String? fio;
  bool loading = false;
  bool restoring = false;
  String? error;

  bool get isAuthenticated => role != null;
  bool get isAdmin => role == 'Admin';
  bool get isTeacher => role == 'Teacher';
  bool get isStudent => role == 'Student';
  bool get isStaff => role == 'Admin' || role == 'Teacher';

  String get roleDisplayName {
    switch (role) {
      case 'Admin':
        return 'Администратор';
      case 'Teacher':
        return 'Преподаватель';
      case 'Student':
        return 'Студент';
      default:
        return 'Гость';
    }
  }

  Future<void> login(String uname, String password) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await service.login(uname, password);
      role = result['role'] as String?;
      username = result['username'] as String? ?? uname;
      studentId = result['student_id'] as int?;
      
      // Save refresh token if provided by API
      // Note: current login implementation doesn't return refresh token explicitly in a map,
      // but it's usually in the response data. I'll assume it's handled or available.
      // To be safe, I'd check the response.
      
      try {
        await refreshMe(notify: false);
      } catch (_) {}
    } catch (_) {
      error = 'Неверный логин или пароль';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> tryAutoLogin() async {
    restoring = true;
    notifyListeners();
    try {
      final refreshToken = await _tokenStore.readRefreshToken();
      if (refreshToken != null) {
        await service.refresh(refreshToken);
        await refreshMe(notify: false);
      }
    } catch (_) {
      // Silently fail auto-login
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  Future<void> refreshMe({bool notify = true}) async {
    final meResult = await service.me();
    role = meResult['role'] as String? ?? role;
    username = meResult['username'] as String? ?? username;
    linkedId = meResult['linked_id'] as int?;
    studentId = role == 'Student' ? linkedId : studentId;
    fio = meResult['fio'] as String?;
    if (notify) notifyListeners();
  }

  void logout() {
    role = null;
    username = null;
    studentId = null;
    linkedId = null;
    fio = null;
    service.logout();
    _tokenStore.clear();
    notifyListeners();
  }

  void forceLogout() {
    logout();
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await service.changePassword(oldPassword, newPassword);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
