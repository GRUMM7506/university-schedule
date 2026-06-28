import 'api_client.dart';

class AuthService {
  AuthService(this.client);

  final ApiClient client;

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await client.dio.post(
      '/auth/login',
      data: {'username': username, 'password': password},
    );
    client.token = response.data['access_token'] as String;
    return {
      'role': response.data['role'] as String,
      'username': response.data['username'] as String? ?? username,
      'student_id': response.data['student_id'] as int?,
    };
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final response = await client.dio.post(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    client.token = response.data['access_token'] as String;
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> me() async {
    final response = await client.dio.get('/me');
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
