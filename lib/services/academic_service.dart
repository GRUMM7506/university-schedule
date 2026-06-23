import 'api_client.dart';

class AcademicService {
  AcademicService(this.client);

  final ApiClient client;

  Future<List<Map<String, dynamic>>> list(String endpoint) async {
    final response = await client.dio.get('$endpoint/list');
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> groupSchedule(
    int groupId, {
    int? weekId,
  }) async {
    final response = await client.dio.get(
      '/schedule/group/$groupId',
      queryParameters: {if (weekId != null) 'week_id': weekId},
    );
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> teacherSchedule(
    int teacherId, {
    int? weekId,
  }) async {
    final response = await client.dio.get(
      '/schedule/teacher/$teacherId',
      queryParameters: {if (weekId != null) 'week_id': weekId},
    );
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> saveAttendance(List<Map<String, dynamic>> items) async {
    await client.dio.post('/attendance/bulk', data: items);
  }

  Future<void> savePerformance(Map<String, dynamic> payload, {int? id}) async {
    if (id == null) {
      await client.dio.post('/performance', data: payload);
    } else {
      await client.dio.put('/performance/$id', data: payload);
    }
  }
}
