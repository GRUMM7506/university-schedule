import 'api_client.dart';

class AuthService {
  AuthService(this.client);

  final ApiClient client;

  /// Parses a dynamic value to int, handling both int and string representations.
  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await client.dio.post(
      '/auth/login',
      data: {'username': username, 'password': password},
    );
    client.token = response.data['access_token'] as String;
    return {
      'role': response.data['role'] as String,
      'username': response.data['username'] as String? ?? username,
      'student_id': _toInt(response.data['student_id']),
      'refresh_token': response.data['refresh_token'] as String?,
    };
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final response = await client.dio.post(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    client.token = response.data['access_token'] as String;
    return {
      ...Map<String, dynamic>.from(response.data as Map),
      'student_id': _toInt(response.data['student_id']),
    };
  }

  Future<Map<String, dynamic>> me() async {
    final response = await client.dio.get('/me');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> guestLogin() async {
    final response = await client.dio.post('/auth/guest');
    client.token = response.data['access_token'] as String;
    return {
      'role': response.data['role'] as String,
      'username': response.data['username'] as String? ?? 'Гость',
      'student_id': _toInt(response.data['student_id']),
      'refresh_token': response.data['refresh_token'] as String?,
    };
  }

  /// Fetches the effective permissions for the current authenticated user.
  Future<Map<String, dynamic>> getPermissions() async {
    final response = await client.dio.get('/permissions/me');
    return response.data as Map<String, dynamic>;
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    await client.dio.post(
      '/auth/change-password',
      data: {'old_password': oldPassword, 'new_password': newPassword},
    );
  }

  void logout() {
    client.token = null;
  }
}
