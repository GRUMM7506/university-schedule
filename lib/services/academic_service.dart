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

  /// For every classroom: what's booked into each pair of the given
  /// week/day. Powers the "which room is free" screen.
  Future<List<Map<String, dynamic>>> classroomsOccupancy({
    required int weekId,
    required int dayNum,
  }) async {
    final response = await client.dio.get(
      '/classrooms/occupancy',
      queryParameters: {'week_id': weekId, 'day_num': dayNum},
    );
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Everything already booked into an exact week/day/pair, plus whether
  /// the given teacher/classroom/group specifically clash with one of
  /// those bookings. Used to warn *before* saving a schedule entry.
  Future<Map<String, dynamic>> checkScheduleSlot({
    required int weekId,
    required int dayNum,
    required int pairNum,
    int? teacherId,
    int? classroomId,
    int? groupId,
    int? excludeId,
  }) async {
    final response = await client.dio.get(
      '/schedule/check-slot',
      queryParameters: {
        'week_id': weekId,
        'day_num': dayNum,
        'pair_num': pairNum,
        if (teacherId != null) 'teacher_id': teacherId,
        if (classroomId != null) 'classroom_id': classroomId,
        if (groupId != null) 'group_id': groupId,
        if (excludeId != null) 'exclude_id': excludeId,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Fetch a single entity record (e.g. /students/5 or /teachers/3)
  Future<Map<String, dynamic>> getEntity(String endpoint, int id) async {
    final response = await client.dio.get('$endpoint/$id');
    return response.data as Map<String, dynamic>;
  }
}
