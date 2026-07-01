import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/entities.dart';
import '../providers/auth_provider.dart';
import '../services/academic_service.dart';
import '../widgets/glass.dart';
import '../widgets/permission_gate.dart';
import '../widgets/schedule_form_dialog.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  int? facultyId;
  int? specialityId;
  int? course;
  int? teacherId;
  int? weekId;
  List<Map<String, dynamic>> groups = [];
  List<Map<String, dynamic>> faculties = [];
  List<Map<String, dynamic>> specialities = [];
  List<Map<String, dynamic>> teachers = [];
  List<Map<String, dynamic>> weeks = [];
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  bool gridMode = true;
  late TabController _tabController;

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
    4: '14:00–15:30',
    5: '15:45–17:15',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadRefs();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRefs() async {
    final service = context.read<AcademicService>();
    groups = await service.list('/groups');
    faculties = await service.list('/faculties');
    specialities = await service.list('/specialities');
    teachers = await service.list('/teachers');
    weeks = await service.list('/study-weeks');
    if (groups.isNotEmpty) {
      final firstGroup = groups.first;
      specialityId = _readInt(firstGroup['speciality_id']);
      course = _readInt(firstGroup['course']);
      facultyId = _facultyIdForSpeciality(specialityId);
    } else if (faculties.isNotEmpty) {
      facultyId = _readInt(faculties.first['id']);
    }

    // Auto-detect current week based on today's date
    if (weeks.isNotEmpty) {
      final today = DateTime.now();
      weekId = _findCurrentWeek(today, weeks) ?? weeks.first['id'] as int;
    }
    await _load();
  }

  /// Returns the first [StudyWeek] whose start_date ≤ today ≤ end_date,
  /// or null if none matches.
  int? _findCurrentWeek(DateTime today, List<Map<String, dynamic>> weeks) {
    final normalized = DateTime(today.year, today.month, today.day);
    for (final w in weeks) {
      final start = DateTime.tryParse('${w['start_date']}');
      final end = DateTime.tryParse('${w['end_date']}');
      if (start != null &&
          end != null &&
          !normalized.isBefore(start) &&
          !normalized.isAfter(end)) {
        return w['id'] as int;
      }
    }
    return null;
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final service = context.read<AcademicService>();
    if (teacherId != null) {
      items = await service.teacherSchedule(teacherId!, weekId: weekId);
    } else {
      final selectedGroups = _filteredGroups;
      if (selectedGroups.isEmpty) {
        items = [];
      } else {
        final schedules = await Future.wait(
          selectedGroups.map((group) async {
            final result = await service.groupSchedule(
              _readInt(group['id']) ?? 0,
              weekId: weekId,
            );
            final groupItems =
                result['items'] as List<Map<String, dynamic>>? ?? [];
            return groupItems
                .map(
                  (item) => {
                    ...item,
                    'group_name': item['group_name'] ?? group['name'],
                  },
                )
                .toList();
          }),
        );
        items = schedules.expand((groupItems) => groupItems).toList();
      }
    }
    setState(() => loading = false);
  }

  void _updateCascadingFilters() {
    final specs = _filteredSpecialities;
    if (!specs.any((s) => _readInt(s['id']) == specialityId)) {
      specialityId = specs.isNotEmpty ? _readInt(specs.first['id']) : null;
    }
    final courses = _courseOptions;
    if (!courses.any((c) => c['id'] == course)) {
      course = courses.isNotEmpty ? _readInt(courses.first['id']) : null;
    }
  }

  List<Map<String, dynamic>> get _filteredSpecialities {
    if (facultyId == null) return specialities;
    return specialities
        .where((s) => _readInt(s['faculty_id']) == facultyId)
        .toList();
  }

  List<Map<String, dynamic>> get _filteredGroups {
    return groups.where((group) {
      final groupSpecialityId = _readInt(group['speciality_id']);
      final groupFacultyId = _facultyIdForSpeciality(groupSpecialityId);
      final groupCourse = _readInt(group['course']);
      return (facultyId == null || groupFacultyId == facultyId) &&
          (specialityId == null || groupSpecialityId == specialityId) &&
          (course == null || groupCourse == course);
    }).toList();
  }

  List<Map<String, dynamic>> get _courseOptions {
    final courses =
        groups
            .where((group) {
              final groupSpecialityId = _readInt(group['speciality_id']);
              final groupFacultyId = _facultyIdForSpeciality(groupSpecialityId);
              return (facultyId == null || groupFacultyId == facultyId) &&
                  (specialityId == null || groupSpecialityId == specialityId);
            })
            .map((group) => _readInt(group['course']))
            .whereType<int>()
            .toSet()
            .toList()
          ..sort();
    return courses
        .map((value) => {'id': value, 'name': '$value курс'})
        .toList();
  }

  int? _facultyIdForSpeciality(int? specialityId) {
    if (specialityId == null) return null;
    for (final speciality in specialities) {
      if (_readInt(speciality['id']) == specialityId) {
        return _readInt(speciality['faculty_id']);
      }
    }
    return null;
  }

  int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final service = context.read<AcademicService>();
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          ScheduleFormDialog(academicService: service, initial: item),
    );
    if (payload != null && mounted) {
      try {
        await service.saveSchedule(payload, id: item?['id'] as int?);
        _load();
      } on DioException catch (e) {
        final detail = e.response?.data is Map
            ? e.response?.data['detail']?.toString()
            : null;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(detail ?? 'Не удалось сохранить занятие')),
        );
      }
    }
  }

  Future<void> _delete(int id) async {
    await context.read<AcademicService>().deleteSchedule(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : gridMode
              ? _buildGridView()
              : _buildListView(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      child: GlassPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.calendar_month_outlined,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Расписание занятий',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                PermissionGate(
                  permission: 'schedule.edit',
                  child: FilledButton.icon(
                    onPressed: _openForm,
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить'),
                  ),
                ),
                const SizedBox(width: 12),
                // View toggle
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
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildDropdown(
                  'Факультет',
                  facultyId,
                  faculties,
                  (v) => setState(() {
                    facultyId = v;
                    _updateCascadingFilters();
                    teacherId = null;
                  }),
                  allLabel: 'Все факультеты',
                  width: 240,
                ),
                _buildDropdown(
                  'Направление',
                  specialityId,
                  _filteredSpecialities,
                  (v) => setState(() {
                    specialityId = v;
                    _updateCascadingFilters();
                    teacherId = null;
                  }),
                  allLabel: 'Все направления',
                  width: 260,
                ),
                _buildDropdown(
                  'Курс',
                  course,
                  _courseOptions,
                  (v) => setState(() {
                    course = v;
                    _updateCascadingFilters();
                    teacherId = null;
                  }),
                  allLabel: 'Все курсы',
                  width: 160,
                ),
                _buildDropdown(
                  'Преподаватель',
                  teacherId,
                  teachers,
                  (v) => setState(() {
                    teacherId = v;
                  }),
                  allLabel: 'Все преподаватели',
                  labelKey: 'fio',
                  width: 260,
                ),
                _buildDropdown(
                  'Неделя',
                  weekId,
                  weeks,
                  (v) => setState(() => weekId = v),
                ),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('Показать'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Legend
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: lessonTypes.entries.map((e) {
                final color = lessonTypeColors[int.parse(e.key)] ?? Colors.grey;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(e.value, style: Theme.of(context).textTheme.bodySmall),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    int? value,
    List<Map<String, dynamic>> data,
    ValueChanged<int?> onChanged, {
    String labelKey = 'name',
    double width = 200,
    String? allLabel,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<int>(
        initialValue: data.any((e) => e['id'] == value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          isDense: true,
        ),
        menuMaxHeight: 320,
        items: [
          if (allLabel != null)
            DropdownMenuItem<int>(value: null, child: Text(allLabel)),
          ...data.map(
            (e) => DropdownMenuItem<int>(
              value: _readInt(e['id']),
              child: Text(
                '${e[labelKey] ?? e['name']}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        selectedItemBuilder: allLabel == null
            ? null
            : (_) => [
                Text(allLabel, overflow: TextOverflow.ellipsis),
                ...data.map(
                  (e) => Text(
                    '${e[labelKey] ?? e['name']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildGridView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        if (isMobile) {
          // Split into two 3-day rows for mobile
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
        // Desktop — single row with all 6 days
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
                dayFull: _dayNamesFull[day],
                items: items.where((e) => e['day_num'] == day).toList(),
                pairTimes: _pairTimes,
                onEdit: context.read<AuthProvider>().hasPermission('schedule.edit') ? _openForm : null,
                onDelete: context.read<AuthProvider>().hasPermission('schedule.edit') ? _delete : null,
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
            items: items.where((e) => e['day_num'] == day).toList(),
            pairTimes: _pairTimes,
            onEdit: context.read<AuthProvider>().hasPermission('schedule.edit') ? _openForm : null,
            onDelete: context.read<AuthProvider>().hasPermission('schedule.edit') ? _delete : null,
          ),
      ],
    );
  }
}

// ─── Grid Day Column ──────────────────────────────────────────────────────────

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.dayName,
    required this.dayFull,
    required this.items,
    required this.pairTimes,
    this.onEdit,
    this.onDelete,
  });

  final String dayName;
  final String dayFull;
  final List<Map<String, dynamic>> items;
  final Map<int, String> pairTimes;
  final void Function(Map<String, dynamic> item)? onEdit;
  final void Function(int id)? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isToday = _isCurrentDayOfWeek(dayName);
    final maxPair = items.fold<int>(0, (max, item) {
      final pairNum = item['pair_num'] as int? ?? 0;
      return pairNum > max ? pairNum : max;
    });

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
        ...() {
  final itemByPair = {
    for (final item in items) item['pair_num'] as int: item,
  };

  return [
    for (int pair = 1; pair <= 5; pair++)
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: itemByPair.containsKey(pair)
            ? _LessonCard(
                item: itemByPair[pair]!,
                pairTimes: pairTimes,
                onEdit: onEdit != null
                    ? () => onEdit!(itemByPair[pair]!)
                    : null,
                onDelete: onDelete != null
                    ? () => onDelete!(itemByPair[pair]!['id'] as int)
                    : null,
              )
            : _EmptySlot(
                pairNum: pair,
                pairTimes: pairTimes,
              ),
      ),
  ];
}()]);
  }

  List<Widget> _buildPairSlots(int pair) {
    final pairItems = items.where((e) => e['pair_num'] == pair).toList();
    if (pairItems.isEmpty) {
      return [_EmptyPairSlot(pairNum: pair, pairTimes: pairTimes)];
    }

    return pairItems
        .map(
          (item) => _LessonCard(
            item: item,
            pairTimes: pairTimes,
            onEdit: onEdit != null ? () => onEdit!(item) : null,
            onDelete: onDelete != null
                ? () => onDelete!(item['id'] as int)
                : null,
          ),
        )
        .toList();
  }

  bool _isCurrentDayOfWeek(String short) {
    final now = DateTime.now();
    final dayOfWeek = now.weekday; // 1=Mon..6=Sat
    const map = {'Пн': 1, 'Вт': 2, 'Ср': 3, 'Чт': 4, 'Пт': 5, 'Сб': 6};
    return map[short] == dayOfWeek;
  }
}

class _EmptyPairSlot extends StatelessWidget {
  const _EmptyPairSlot({required this.pairNum, required this.pairTimes});

  final int pairNum;
  final Map<int, String> pairTimes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: .45),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$pairNum пара',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${pairTimes[pairNum] ?? ''} · пусто',
              style: TextStyle(
                fontSize: 10,
                color: scheme.onSurfaceVariant.withValues(alpha: .65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.item,
    required this.pairTimes,
    this.onEdit,
    this.onDelete,
  });

  final Map<String, dynamic> item;
  final Map<int, String> pairTimes;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final lessonType = item['lesson_type'] as int? ?? 0;
    final color = lessonTypeColors[lessonType] ?? Colors.grey;
    final pairNum = item['pair_num'] as int? ?? 1;
    final time = pairTimes[pairNum] ?? '';
    final groupName = item['group_name'] ?? item['group'];

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
                if (onEdit != null)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    padding: EdgeInsets.zero,
                    onSelected: (v) {
                      if (v == 'edit') onEdit!();
                      if (v == 'delete') onDelete!();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Изменить'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Удалить',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _InfoRow(Icons.access_time_outlined, time),
            if (groupName != null)
              _InfoRow(Icons.groups_outlined, '$groupName'),
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

// ─── Empty Pair Slot (grid) ───────────────────────────────────────────────────

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({
    required this.pairNum,
    required this.pairTimes,
  });

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
          style: BorderStyle.solid,
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

// ─── List Day Block ───────────────────────────────────────────────────────────

class _DayListBlock extends StatelessWidget {
  const _DayListBlock({
    required this.dayName,
    required this.items,
    required this.pairTimes,
    this.onEdit,
    this.onDelete,
  });

  final String dayName;
  final List<Map<String, dynamic>> items;
  final Map<int, String> pairTimes;
  final void Function(Map<String, dynamic> item)? onEdit;
  final void Function(int id)? onDelete;

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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
        .map(
          (item) => _ListLessonCard(
            item: item,
            pairTimes: pairTimes,
            onEdit: onEdit != null ? () => onEdit!(item) : null,
            onDelete: onDelete != null
                ? () => onDelete!(item['id'] as int)
                : null,
          ),
        )
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
  const _ListLessonCard({
    required this.item,
    required this.pairTimes,
    this.onEdit,
    this.onDelete,
  });

  final Map<String, dynamic> item;
  final Map<int, String> pairTimes;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final lessonType = item['lesson_type'] as int? ?? 0;
    final color = lessonTypeColors[lessonType] ?? Colors.grey;
    final pairNum = item['pair_num'] as int? ?? 1;
    final time = pairTimes[pairNum] ?? '';
    final groupName = item['group_name'] ?? item['group'];

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
                      if (groupName != null)
                        _Chip(Icons.groups_outlined, '$groupName', Colors.grey),
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
            if (onEdit != null)
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onSelected: (v) {
                  if (v == 'edit') onEdit!();
                  if (v == 'delete') onDelete!();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Изменить')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Удалить', style: TextStyle(color: Colors.red)),
                  ),
                ],
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
