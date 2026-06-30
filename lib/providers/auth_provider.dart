import 'package:dio/dio.dart';
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
  Set<String> permissions = {};

  bool get isAuthenticated => role != null;
  bool get isAdmin => role == 'Admin';
  bool get isTeacher => role == 'Teacher';
  bool get isStudent => role == 'Student';
  bool get isGuest => role == 'Guest';
  bool get isStaff => role == 'Admin' || role == 'Teacher';

  bool hasPermission(String permission) =>
      isAdmin || permissions.contains(permission);

  /// Routes that don't require a specific permission — every authenticated
  /// user (of any role allowed to reach the shell at all) can open them.
  static const _routesWithoutPermissionCheck = {
    '/', '/portal', '/profile', '/profile-setup', '/login',
  };

  /// Maps a shell route to the permission key that gates it, following the
  /// "<entity>.view" / "<entity>.manage" convention from
  /// app/core/permissions.py. Falls back to deriving "<segment>.view" for
  /// CRUD reference-data routes (e.g. '/study-weeks' -> 'study-weeks.view'),
  /// which covers every entry in entityDefinitions automatically.
  String? permissionForRoute(String route) {
    const explicit = {
      '/gradebook': 'gradebook.view',
      '/schedule': 'schedule.view',
      '/attendance': 'attendance.view',
      '/performance': 'performance.view',
      '/users-admin': 'users.manage',
      '/my-schedule': 'schedule.view',
      '/my-grades': 'performance.view',
      '/my-attendance': 'attendance.view',
    };
    if (explicit.containsKey(route)) return explicit[route];
    if (_routesWithoutPermissionCheck.contains(route)) return null;
    // Any other route is treated as a reference-data (CRUD) route.
    final segment = route.startsWith('/') ? route.substring(1) : route;
    return segment.isEmpty ? null : '$segment.view';
  }

  /// Whether the current user is allowed to open [route] at all — used by
  /// the router's redirect guard so direct URL entry can't bypass what the
  /// drawer already hides.
  bool canAccessRoute(String route) {
    if (isAdmin) return true;
    final permission = permissionForRoute(route);
    if (permission == null) return true;
    return hasPermission(permission);
  }

  String get roleDisplayName {
    switch (role) {
      case 'Admin':
        return 'Администратор';
      case 'Teacher':
        return 'Преподаватель';
      case 'Student':
        return 'Студент';
      case 'Guest':
        return 'Гость';
      default:
        return 'Гость';
    }
  }

  Future<void> _loadPermissions() async {
    try {
      final result = await service.getPermissions(username ?? '');
      final list = (result['permissions'] as List?) ?? const [];
      permissions = list.map((e) => e.toString()).toSet();
    } catch (_) {
      permissions = {};
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
      studentId = _toInt(result['student_id']);

      try {
        await refreshMe(notify: false);
      } catch (_) {}
      await _loadPermissions();
    } on DioException {
      error = 'Неверный логин или пароль';
    } catch (e) {
      error = 'Ошибка после входа: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loginAsGuest() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await service.guestLogin();
      role = result['role'] as String?;
      username = result['username'] as String?;
      studentId = _toInt(result['student_id']);
      await _loadPermissions();
    } on DioException {
      error = 'Не удалось войти как гость';
    } catch (e) {
      error = 'Ошибка после входа: $e';
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
        await _loadPermissions();
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
    linkedId = _toInt(meResult['linked_id']);
    studentId = role == 'Student' ? linkedId : studentId;
    fio = meResult['fio'] as String?;
    if (notify) notifyListeners();
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  void logout() {
    role = null;
    username = null;
    studentId = null;
    linkedId = null;
    fio = null;
    permissions = {};
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
