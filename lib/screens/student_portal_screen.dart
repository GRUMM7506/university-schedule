import 'package:flutter/material.dart';
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
  List<Map<String, dynamic>> disciplines = [];
  Map<int, String> disciplineNames = {};
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
      disciplines = await service.list('/disciplines');
      // Создаём маппинг ID -> имя дисциплины
      for (final d in disciplines) {
        final id = d['id'] as int?;
        final name = d['name'] ?? d['displayName'] ?? '#${id}';
        if (id != null) {
          disciplineNames[id] = name.toString();
        }
      }
      // Выбирать текущую неделю, а не первую
      if (weeks.isNotEmpty) {
        // Пытаемся найти текущую неделю (where week_id = current)
        final today = DateTime.now();
        int? currentWeekId;
        for (final week in weeks) {
          final startDate = DateTime.tryParse(week['start_date'].toString());
          final endDate = DateTime.tryParse(week['end_date'].toString());
          if (startDate != null && endDate != null && today.isAfter(startDate) && today.isBefore(endDate.add(const Duration(days: 1)))) {
            currentWeekId = week['id'] as int;
            break;
          }
        }
        weekId = currentWeekId ?? (weeks.first['id'] as int);
      }
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
                      attendance: attendance,
                      onWeekChanged: (v) {
                        weekId = v;
                        _load();
                      },
                    ),
                    _GradesTab(grades: grades, disciplineNames: disciplineNames),
                    _AttendanceTab(attendance: attendance, disciplineNames: disciplineNames),
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

class _ScheduleTab extends StatefulWidget {
  const _ScheduleTab({
    required this.items,
    required this.weeks,
    required this.weekId,
    required this.attendance,
    required this.onWeekChanged,
  });

  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> weeks;
  final List<Map<String, dynamic>> attendance;
  final int? weekId;
  final ValueChanged<int?> onWeekChanged;

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  bool gridMode = true;

  static const _dayNames = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
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

  /// Получить статус посещаемости для конкретной пары (по дате и номеру пары)
  /// Возвращает: (метка, иконка, цвет) или null если нет данных
  ({String label, IconData icon, Color color})? _getAttendanceStatus(String date, int pairNum) {
    for (final a in widget.attendance) {
      if (a['day_date'].toString() == date && a['pair_num'] == pairNum) {
        final mark = a['mark'] as int? ?? 2;
        return switch (mark) {
          2 => (
            label: 'Присутствовал',
            icon: Icons.check_circle,
            color: const Color(0xFF10B981),
          ),
          1 => (
            label: 'Опоздал',
            icon: Icons.schedule,
            color: const Color(0xFFF59E0B),
          ),
          _ => (
            label: 'Отсутствовал',
            icon: Icons.cancel,
            color: const Color(0xFFEF4444),
          ),
        };
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.weeks.isNotEmpty)
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int>(
                    initialValue: widget.weekId,
                    decoration: const InputDecoration(
                      labelText: 'Неделя',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: widget.weeks
                        .map(
                          (w) => DropdownMenuItem<int>(
                            value: w['id'] as int,
                            child: Text('${w['name']}'),
                          ),
                        )
                        .toList(),
                    onChanged: widget.onWeekChanged,
                  ),
                ),
              // Legend
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: lessonTypes.entries.map((e) {
                  final color =
                      lessonTypeColors[int.parse(e.key)] ?? Colors.grey;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        e.value,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  );
                }).toList(),
              ),
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _ViewButton(
                      icon: Icons.grid_view_outlined,
                      active: gridMode,
                      onTap: () => setState(() => gridMode = true),
                    ),
                    _ViewButton(
                      icon: Icons.view_list_outlined,
                      active: !gridMode,
                      onTap: () => setState(() => gridMode = false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: widget.items.isEmpty
              ? const Center(child: Text('Нет занятий на выбранную неделю'))
              : gridMode
              ? _buildGridView()
              : _buildListView(),
        ),
      ],
    );
  }

  Widget _buildGridView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        if (isMobile) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                _buildDayRow([1, 2, 3]),
                const SizedBox(height: 12),
                _buildDayRow([4, 5, 6]),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: _buildDayRow(List.generate(6, (i) => i + 1)),
        );
      },
    );
  }

  Widget _buildDayRow(List<int> days) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in days)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: day != days.last ? 10 : 0),
              child: _DayColumn(
                dayName: _dayNames[day],
                items: widget.items.where((e) => e['day_num'] == day).toList(),
                pairTimes: _pairTimes,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildListView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        for (int day = 1; day <= 6; day++)
          _DayListBlock(
            dayName: _dayNamesFull[day],
            items: widget.items.where((e) => e['day_num'] == day).toList(),
            pairTimes: _pairTimes,
          ),
      ],
    );
  }
}

// ─── Grid Day Column ──────────────────────────────────────────────────────────

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.dayName,
    required this.items,
    required this.pairTimes,
  });

  final String dayName;
  final List<Map<String, dynamic>> items;
  final Map<int, String> pairTimes;

  bool _isCurrentDayOfWeek(String short) {
    final now = DateTime.now();
    const map = {'Пн': 1, 'Вт': 2, 'Ср': 3, 'Чт': 4, 'Пт': 5, 'Сб': 6};
    return map[short] == now.weekday;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isToday = _isCurrentDayOfWeek(dayName);
    final itemByPair = {
      for (final item in items) item['pair_num'] as int: item,
    };

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isToday
                ? scheme.primary.withValues(alpha: .15)
                : scheme.surfaceContainerHighest.withValues(alpha: .3),
            borderRadius: BorderRadius.circular(12),
            border: isToday
                ? Border.all(color: scheme.primary.withValues(alpha: .4))
                : null,
          ),
          child: Column(
            children: [
              Text(
                dayName,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: isToday ? scheme.primary : scheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              if (isToday)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (int pair = 1; pair <= 6; pair++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: itemByPair.containsKey(pair)
                ? _LessonCard(item: itemByPair[pair]!, pairTimes: pairTimes)
                : _EmptySlot(pairNum: pair, pairTimes: pairTimes),
          ),
      ],
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.pairNum, required this.pairTimes});

  final int pairNum;
  final Map<int, String> pairTimes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = pairTimes[pairNum] ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: .2),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            '$pairNum',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant.withValues(alpha: .35),
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 9,
              color: scheme.onSurfaceVariant.withValues(alpha: .25),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '—',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant.withValues(alpha: .25),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.item, required this.pairTimes});

  final Map<String, dynamic> item;
  final Map<int, String> pairTimes;

  @override
  Widget build(BuildContext context) {
    final lessonType = item['lesson_type'] as int? ?? 0;
    final color = lessonTypeColors[lessonType] ?? Colors.grey;
    final pairNum = item['pair_num'] as int? ?? 1;
    final time = pairTimes[pairNum] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassPanel(
        padding: const EdgeInsets.all(10),
        borderRadius: 12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['subject']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${lessonTypes['$lessonType']}',
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _InfoRow(Icons.access_time_outlined, time),
            _InfoRow(Icons.person_outline, '${item['teacher']}'),
            _InfoRow(Icons.meeting_room_outlined, 'ауд. ${item['classroom']}'),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(
            icon,
            size: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── List Day Block ───────────────────────────────────────────────────────────

class _DayListBlock extends StatelessWidget {
  const _DayListBlock({
    required this.dayName,
    required this.items,
    required this.pairTimes,
  });

  final String dayName;
  final List<Map<String, dynamic>> items;
  final Map<int, String> pairTimes;

  @override
  Widget build(BuildContext context) {
    final maxPair = items.fold<int>(0, (max, item) {
      final pairNum = item['pair_num'] as int? ?? 0;
      return pairNum > max ? pairNum : max;
    });

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  dayName,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    items.isEmpty ? 'нет пар' : '${items.length} занят.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            const _ListEmptyDayCard()
          else
            for (int pair = 1; pair <= maxPair; pair++) ..._buildPairRows(pair),
        ],
      ),
    );
  }

  List<Widget> _buildPairRows(int pair) {
    final pairItems = items.where((e) => e['pair_num'] == pair).toList();
    if (pairItems.isEmpty) {
      return [_ListEmptyPairCard(pairNum: pair, pairTimes: pairTimes)];
    }
    return pairItems
        .map((item) => _ListLessonCard(item: item, pairTimes: pairTimes))
        .toList();
  }
}

class _ListEmptyDayCard extends StatelessWidget {
  const _ListEmptyDayCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .45)),
      ),
      child: Text(
        'В этот день пар нет',
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ListEmptyPairCard extends StatelessWidget {
  const _ListEmptyPairCard({required this.pairNum, required this.pairTimes});

  final int pairNum;
  final Map<int, String> pairTimes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: .45),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$pairNum',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    'пара',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Пусто',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pairTimes[pairNum] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant.withValues(alpha: .75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListLessonCard extends StatelessWidget {
  const _ListLessonCard({required this.item, required this.pairTimes});

  final Map<String, dynamic> item;
  final Map<int, String> pairTimes;

  @override
  Widget build(BuildContext context) {
    final lessonType = item['lesson_type'] as int? ?? 0;
    final color = lessonTypeColors[lessonType] ?? Colors.grey;
    final pairNum = item['pair_num'] as int? ?? 1;
    final time = pairTimes[pairNum] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$pairNum',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  Text('пара', style: TextStyle(color: color, fontSize: 9)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['subject']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    children: [
                      _Chip(Icons.access_time_outlined, time, color),
                      _Chip(
                        Icons.person_outline,
                        '${item['teacher']}',
                        Colors.grey,
                      ),
                      _Chip(
                        Icons.meeting_room_outlined,
                        'ауд. ${item['classroom']}',
                        Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(20),
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
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color.withValues(alpha: .7)),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ViewButton extends StatelessWidget {
  const _ViewButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: active
              ? scheme.primary.withValues(alpha: .15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: active ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ─── Grades Tab ───────────────────────────────────────────────────────────────

class _GradesTab extends StatelessWidget {
  const _GradesTab({required this.grades, required this.disciplineNames});
  final List<Map<String, dynamic>> grades;
  final Map<int, String> disciplineNames;

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
        // Использовать имя дисциплины из API, если доступно
        final disciplineName = g['discipline_name'] as String? ?? 
            (g['discipline_id'] != null ? 'Дисциплина #${g['discipline_id']}' : 'Неизвестная дисциплина');
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
                      disciplineName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
  const _AttendanceTab({required this.attendance, required this.disciplineNames});
  final List<Map<String, dynamic>> attendance;
  final Map<int, String> disciplineNames;

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
        
        // Получить информацию о посещаемости - нам нужно попытаться получить информацию о дисциплине
        // Сейчас у нас есть day_date, pair_num, но нет информации о дисциплине
        // Это требует изменения API, но пока мы можем улучшить отображение даты и времени
        final pairTimes = {
          1: '08:00–09:30',
          2: '09:45–11:15',
          3: '11:30–13:00',
          4: '13:45–15:15',
          5: '15:30–17:00',
          6: '17:15–18:45',
        };
        final pairNum = a['pair_num'] as int? ?? 1;
        final time = pairTimes[pairNum] ?? '';
        
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
                      '$pairNum пара ($time)',
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