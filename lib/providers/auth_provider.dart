import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this.service);

  final AuthService service;
  String? role;
  String? username;
  int? studentId;
  int? linkedId;
  String? fio;
  bool loading = false;
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
    notifyListeners();
  }
}
