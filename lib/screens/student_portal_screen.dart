import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/entities.dart';
import '../providers/auth_provider.dart';
import '../services/academic_service.dart';
import '../widgets/glass.dart';

/// Student portal — shows the student's own schedule, grades, and attendance.
class StudentPortalScreen extends StatefulWidget {
  const StudentPortalScreen({super.key});

  @override
  State<StudentPortalScreen> createState() => _StudentPortalScreenState();
}

class _StudentPortalScreenState extends State<StudentPortalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? dashData;
  List<Map<String, dynamic>> scheduleItems = [];
  List<Map<String, dynamic>> grades = [];
  List<Map<String, dynamic>> attendance = [];
  List<Map<String, dynamic>> weeks = [];
  int? weekId;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final auth = context.read<AuthProvider>();
    final service = context.read<AcademicService>();
    final studentId = auth.studentId;
    if (studentId == null) {
      setState(() => loading = false);
      return;
    }
    try {
      weeks = await service.list('/study-weeks');
      weekId ??= weeks.isEmpty ? null : weeks.first['id'] as int;
      dashData = await service.studentDashboard(studentId);
      grades = await service.studentPerformance(studentId);
      attendance = await service.studentAttendance(studentId);
      scheduleItems = await service.studentSchedule(studentId, weekId: weekId);
    } catch (_) {}
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: GlassPanel(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981),
                            const Color(0xFF10B981).withValues(alpha: .6),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          auth.username?.isNotEmpty == true
                              ? auth.username![0].toUpperCase()
                              : 'С',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dashData?['fio'] ?? auth.username ?? 'Студент',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          if (!loading && dashData != null)
                            Wrap(
                              spacing: 10,
                              children: [
                                _QuickStat(
                                  'Посещ.',
                                  '${dashData!['attendance_rate']}%',
                                  const Color(0xFF10B981),
                                ),
                                _QuickStat(
                                  'Ср. балл',
                                  '${dashData!['avg_mark']}',
                                  const Color(0xFF3B82F6),
                                ),
                                _QuickStat(
                                  'Оценок',
                                  '${dashData!['grades_count']}',
                                  const Color(0xFF8B5CF6),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TabBar(
                  controller: _tabs,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.calendar_today_outlined),
                      text: 'Расписание',
                    ),
                    Tab(icon: Icon(Icons.grade_outlined), text: 'Оценки'),
                    Tab(
                      icon: Icon(Icons.how_to_reg_outlined),
                      text: 'Посещаемость',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _ScheduleTab(
                      items: scheduleItems,
                      weeks: weeks,
                      weekId: weekId,
                      onWeekChanged: (v) {
                        weekId = v;
                        _load();
                      },
                    ),
                    _GradesTab(grades: grades),
                    _AttendanceTab(attendance: attendance),
                  ],
                ),
        ),
      ],
    );
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color.withValues(alpha: .8)),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Schedule Tab ─────────────────────────────────────────────────────────────

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab({
    required this.items,
    required this.weeks,
    required this.weekId,
    required this.onWeekChanged,
  });

  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> weeks;
  final int? weekId;
  final ValueChanged<int?> onWeekChanged;

  static const _dayNamesFull = [
    '',
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
  ];
  static const _pairTimes = {
    1: '08:00–09:30',
    2: '09:45–11:15',
    3: '11:30–13:00',
    4: '13:45–15:15',
    5: '15:30–17:00',
    6: '17:15–18:45',
  };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (weeks.isNotEmpty)
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<int>(
              value: weekId,
              decoration: const InputDecoration(
                labelText: 'Неделя',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: weeks
                  .map(
                    (w) => DropdownMenuItem<int>(
                      value: w['id'] as int,
                      child: Text('${w['name']}'),
                    ),
                  )
                  .toList(),
              onChanged: onWeekChanged,
            ),
          ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          const Center(child: Text('Нет занятий на выбранную неделю'))
        else
          for (int day = 1; day <= 6; day++) _buildDay(context, day),
      ],
    );
  }

  Widget _buildDay(BuildContext context, int day) {
    final dayItems = items.where((e) => e['day_num'] == day).toList();
    if (dayItems.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            _dayNamesFull[day],
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        ...dayItems.map((item) {
          final lessonType = item['lesson_type'] as int? ?? 0;
          final color = lessonTypeColors[lessonType] ?? Colors.grey;
          final pairNum = item['pair_num'] as int? ?? 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassPanel(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '$pairNum',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['subject']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_pairTimes[pairNum]} · ${item['teacher']} · ауд. ${item['classroom']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      lessonTypes['$lessonType'] ?? '',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Grades Tab ───────────────────────────────────────────────────────────────

class _GradesTab extends StatelessWidget {
  const _GradesTab({required this.grades});
  final List<Map<String, dynamic>> grades;

  @override
  Widget build(BuildContext context) {
    if (grades.isEmpty) {
      return const Center(child: Text('Оценок пока нет'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: grades.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final g = grades[i];
        final mark = g['mark'] as int? ?? 0;
        final color = _markColor(mark);
        return GlassPanel(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: .3)),
                ),
                child: Center(
                  child: Text(
                    '$mark',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Дисциплина #${g['discipline_id']}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Контроль: ${g['control_type'] == 1 ? 'Экзамен' : 'Зачет'} · Тур ${g['tour_num']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _markLabel(mark),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _markColor(int mark) => switch (mark) {
    5 => const Color(0xFF10B981),
    4 => const Color(0xFF3B82F6),
    3 => const Color(0xFFF59E0B),
    2 => const Color(0xFFEF4444),
    _ => Colors.grey,
  };

  String _markLabel(int mark) => switch (mark) {
    5 => 'Отлично',
    4 => 'Хорошо',
    3 => 'Удовл.',
    2 => 'Неудовл.',
    1 => 'Неявка',
    0 => 'Недопуск',
    _ => '$mark',
  };
}

// ─── Attendance Tab ───────────────────────────────────────────────────────────

class _AttendanceTab extends StatelessWidget {
  const _AttendanceTab({required this.attendance});
  final List<Map<String, dynamic>> attendance;

  @override
  Widget build(BuildContext context) {
    if (attendance.isEmpty) {
      return const Center(child: Text('Данных о посещаемости нет'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: attendance.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final a = attendance[i];
        final mark = a['mark'] as int? ?? 2;
        final (label, icon, color) = switch (mark) {
          2 => (
            'Присутствовал',
            Icons.check_circle_outline,
            const Color(0xFF10B981),
          ),
          1 => ('Опоздал', Icons.schedule_outlined, const Color(0xFFF59E0B)),
          _ => ('Отсутствовал', Icons.cancel_outlined, const Color(0xFFEF4444)),
        };
        return GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Text(
                      'Пара ${a['pair_num']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${a['day_date']}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
