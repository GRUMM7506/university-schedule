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

  Future<Map<String, dynamic>> me() async {
    final response = await client.dio.get('/me');
    return response.data as Map<String, dynamic>;
  }

  void logout() {
    client.token = null;
  }
}
