import '../core/ttl_cache.dart';
import 'api_client.dart';

class AcademicService {
  AcademicService(this.client);

  final ApiClient client;

  /// Caches the *unparameterized* `list(endpoint)` calls used by dropdowns
  /// and forms throughout the app (faculties, groups, teachers, subjects,
  /// etc.). Screens that search/sort go through EntityService instead and
  /// are intentionally not cached here, since they need live results.
  final TtlCache<String, List<Map<String, dynamic>>> _listCache = TtlCache(
    ttl: const Duration(minutes: 2),
  );

  Future<List<Map<String, dynamic>>> list(
    String endpoint, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _listCache.get(endpoint);
      if (cached != null) return cached;
    }

    final response = await client.dio.get('$endpoint/list');
    var data = (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (endpoint == '/disciplines') {
      try {
        final subjects = await list('/subjects');
        final teachers = await list('/teachers');
        final groups = await list('/groups');

        final subjectMap = {for (final s in subjects) s['id']: s['name']};
        final teacherMap = {for (final t in teachers) t['id']: t['fio']};
        final groupMap = {for (final g in groups) g['id']: g['name']};

        data = data.map((d) {
          final sName = subjectMap[d['subject_id']] ?? '#${d['subject_id']}';
          final tName = teacherMap[d['teacher_id']] ?? '#${d['teacher_id']}';
          final gName = groupMap[d['group_id']] ?? '#${d['group_id']}';
          return {
            ...d,
            'displayName': '$sName — $tName ($gName)',
          };
        }).toList();
      } catch (_) {}
    }

    _listCache.set(endpoint, data);
    return data;
  }

  /// Drops all cached reference-data lists. Call this after creating,
  /// editing, or deleting a record anywhere in the app so the next read
  /// (a dropdown, a form, another screen) reflects the change instead of
  /// showing up to [TtlCache]'s TTL of stale data.
  void clearListCache() => _listCache.clear();

  Future<Map<String, dynamic>> groupSchedule(int groupId, {int? weekId}) async {
    final response = await client.dio.get(
      '/schedule/group/$groupId',
      queryParameters: {if (weekId != null) 'week_id': weekId},
    );
    return {
      'items': (response.data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    };
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

  Future<List<Map<String, dynamic>>> studentSchedule(
    int studentId, {
    int? weekId,
  }) async {
    final response = await client.dio.get(
      '/schedule/student/$studentId',
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

  Future<List<Map<String, dynamic>>> gradebook({
    int? groupId,
    int? disciplineId,
  }) async {
    final response = await client.dio.get(
      '/gradebook',
      queryParameters: {
        if (groupId != null) 'group_id': groupId,
        if (disciplineId != null) 'discipline_id': disciplineId,
      },
    );
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> studentDashboard(int studentId) async {
    final response = await client.dio.get('/dashboard/student/$studentId');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> teacherDashboard(int teacherId) async {
    final response = await client.dio.get('/dashboard/teacher/$teacherId');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> studentAttendance(int studentId) async {
    final response = await client.dio.get('/students/$studentId/attendance');
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> studentPerformance(int studentId) async {
    final response = await client.dio.get('/students/$studentId/performance');
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

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

  Future<void> saveSchedule(Map<String, dynamic> payload, {int? id}) async {
    if (id == null) {
      await client.dio.post('/schedule', data: payload);
    } else {
      await client.dio.put('/schedule/$id', data: payload);
    }
  }

  Future<void> deleteSchedule(int id) async {
    await client.dio.delete('/schedule/$id');
  }

  Future<void> setupProfile(Map<String, dynamic> payload) async {
    await client.dio.post('/profile/setup', data: payload);
    clearListCache();
  }

  Future<void> updateProfile(Map<String, dynamic> payload) async {
    await client.dio.put('/profile/update', data: payload);
    clearListCache();
  }

  /// Fetch a single entity record (e.g. /students/5 or /teachers/3)
  Future<Map<String, dynamic>> getEntity(String endpoint, int id) async {
    final response = await client.dio.get('$endpoint/$id');
    return Map<String, dynamic>.from(response.data as Map);
  }
  Future<Map<String, dynamic>> fetchUserPermissions(int userId) async {
    final response = await client.dio.get('/permissions/user/$userId');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> updateUserPermission(int userId, Map<String, dynamic> payload) async {
    await client.dio.put('/permissions/$userId', data: payload);
  }
}
