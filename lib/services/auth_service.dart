import 'api_client.dart';

class AuthService {
  AuthService(this.client);

  final ApiClient client;

  Future<String> login(String username, String password) async {
    final response = await client.dio.post(
      '/auth/login',
      data: {'username': username, 'password': password},
    );
    client.token = response.data['access_token'] as String;
    return response.data['role'] as String;
  }

  void logout() {
    client.token = null;
  }
}
