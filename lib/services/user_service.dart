import 'api_client.dart';

class UserService {
  UserService(this.client);

  final ApiClient client;

  Future<List<Map<String, dynamic>>> listUsers() async {
    final response = await client.dio.get('/users');
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> createUser(Map<String, dynamic> payload) async {
    await client.dio.post('/users', data: payload);
  }

  Future<void> updateUser(int id, Map<String, dynamic> payload) async {
    await client.dio.put('/users/$id', data: payload);
  }

  Future<void> deleteUser(int id) async {
    await client.dio.delete('/users/$id');
  }

  Future<void> setupProfile(Map<String, dynamic> payload) async {
    await client.dio.post('/profile/setup', data: payload);
  }

  Future<void> updateProfile(Map<String, dynamic> payload) async {
    await client.dio.put('/profile/update', data: payload);
  }

  Future<Map<String, dynamic>> fetchUserPermissions(int userId) async {
    final response = await client.dio.get('/permissions/user/$userId');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> updateUserPermission(int userId, Map<String, dynamic> payload) async {
    await client.dio.put('/permissions/$userId', data: payload);
  }
}
