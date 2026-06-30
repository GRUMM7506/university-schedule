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
    final rawStudentId = response.data['student_id'];
    final studentId = rawStudentId == null
        ? null
        : (rawStudentId is int ? rawStudentId : int.tryParse(rawStudentId.toString()));
    return {
      'role': response.data['role'] as String,
      'username': response.data['username'] as String? ?? username,
      'student_id': studentId,
    };
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final response = await client.dio.post(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    client.token = response.data['access_token'] as String;
    final rawStudentId = response.data['student_id'];
    if (rawStudentId != null) {
      final studentId = rawStudentId is int
          ? rawStudentId
          : int.tryParse(rawStudentId.toString());
      response.data['student_id'] = studentId;
    }
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> me() async {
    final response = await client.dio.get('/me');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> guestLogin() async {
    final response = await client.dio.post('/auth/guest');
    client.token = response.data['access_token'] as String;
    final rawStudentId = response.data['student_id'];
    final studentId = rawStudentId == null
        ? null
        : (rawStudentId is int ? rawStudentId : int.tryParse(rawStudentId.toString()));
    return {
      'role': response.data['role'] as String,
      'username': response.data['username'] as String? ?? 'Гость',
      'student_id': studentId,
    };
  }

  Future<Map<String, dynamic>> getPermissions(String username) async {
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
