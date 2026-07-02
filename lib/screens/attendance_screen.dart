import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/academic_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  int? groupId;
  int? facultyId;
  int? specialityId;
  int? course;
  int pairNum = 1;
  DateTime day = DateTime.now();
  List<Map<String, dynamic>> groups = [];
  List<Map<String, dynamic>> faculties = [];
  List<Map<String, dynamic>> specialities = [];
  List<Map<String, dynamic>> students = [];
  // A student with no entry in `marks` (or an explicit null) is presumed
  // present — only exceptions are tracked, so the teacher never has to tap
  // anything for the students who simply showed up on time.
  final marks = <int, int?>{};
  bool loading = true;
  bool saving = false;
  String search = '';

  static const _absent = 0;
  static const _late = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadRefs();
    });
  }

  Future<void> _loadRefs() async {
    try {
      setState(() => loading = true);
      final service = context.read<AcademicService>();
      groups = await service.list('/groups');
      faculties = await service.list('/faculties');
      specialities = await service.list('/specialities');
      if (groups.isNotEmpty) {
        final firstGroup = groups.first;
        groupId ??= firstGroup['id'] as int;
        final sId = _readInt(firstGroup['speciality_id']);
        specialityId = sId;
        course = _readInt(firstGroup['course']);
        if (sId != null) {
          for (final speciality in specialities) {
            if (_readInt(speciality['id']) == sId) {
              facultyId = _readInt(speciality['faculty_id']);
              break;
            }
          }
        }
      } else if (faculties.isNotEmpty) {
        facultyId = faculties.first['id'] as int;
      }
      await _loadStudents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => loading = false);
      }
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
    final courses = groups
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

  Future<void> _loadStudents() async {
    setState(() => loading = true);
    try {
      final service = context.read<AcademicService>();
      final allStudents = await service.list('/students');
      students = allStudents.where((s) => s['group_id'] == groupId).toList()
        ..sort((a, b) => '${a['fio']}'.compareTo('${b['fio']}'));
      marks.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки студентов: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _changeGroup(int? value) async {
    if (value == null) return;
    setState(() {
      groupId = value;
      search = '';
    });
    await _loadStudents();
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
    final grps = _filteredGroups;
    if (!grps.any((g) => _readInt(g['id']) == groupId)) {
      groupId = grps.isNotEmpty ? _readInt(grps.first['id']) : null;
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      final service = context.read<AcademicService>();
      final date = DateFormat('yyyy-MM-dd').format(day);
      await service.saveAttendance([
        for (final student in students)
          {
            'student_id': student['id'],
            'day_date': date,
            'pair_num': pairNum,
            'mark': marks[student['id']],
          },
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Посещаемость сохранена')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _setAll(int? mark) {
    setState(() {
      for (final student in _visibleStudents) {
        marks[student['id'] as int] = mark;
      }
    });
  }

  List<Map<String, dynamic>> get _visibleStudents {
    if (search.isEmpty) return students;
    final q = search.toLowerCase();
    return students.where((s) => '${s['fio']}'.toLowerCase().contains(q)).toList();
  }

  int get _absentCount => students.where((s) => marks[s['id']] == _absent).length;
  int get _lateCount => students.where((s) => marks[s['id']] == _late).length;
  int get _presentCount => students.length - _absentCount - _lateCount;

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
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
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

  @override
  Widget build(BuildContext context) {
    final visible = _visibleStudents;
    final canEdit = context.watch<AuthProvider>().hasPermission('attendance.edit');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Text('Посещаемость', style: Theme.of(context).textTheme.headlineSmall),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildDropdown(
                'Факультет',
                facultyId,
                faculties,
                (v) {
                  setState(() {
                    facultyId = v;
                    _updateCascadingFilters();
                  });
                  _changeGroup(groupId);
                },
                // allLabel: 'Все факультеты',
                width: 240,
              ),
              _buildDropdown(
                'Направление',
                specialityId,
                _filteredSpecialities,
                (v) {
                  setState(() {
                    specialityId = v;
                    _updateCascadingFilters();
                  });
                  _changeGroup(groupId);
                },
                // allLabel: 'Все направления',
                width: 260,
              ),
              _buildDropdown(
                'Курс',
                course,
                _courseOptions,
                (v) {
                  setState(() {
                    course = v;
                    _updateCascadingFilters();
                  });
                  _changeGroup(groupId);
                },
                // allLabel: 'Все курсы',
                width: 160,
              ),
              _buildDropdown(
                'Группа',
                groupId,
                _filteredGroups,
                (v) => _changeGroup(v),
                // allLabel: 'Все группы',
                width: 220,
              ),
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<int>(
                  initialValue: pairNum,
                  decoration: const InputDecoration(
                    labelText: 'Пара',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [1, 2, 3, 4, 5, 6]
                      .map((e) => DropdownMenuItem(value: e, child: Text('$e пара')))
                      .toList(),
                  onChanged: (v) => setState(() => pairNum = v ?? 1),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                    initialDate: day,
                  );
                  if (picked != null) setState(() => day = picked);
                },
                icon: const Icon(Icons.today),
                label: Text(DateFormat('dd.MM.yyyy').format(day)),
              ),
              const Spacer(),
              if (canEdit)
                FilledButton.icon(
                  onPressed: students.isEmpty || saving ? null : _save,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Сохранить'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!loading && students.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _countChip('Присутствуют', _presentCount, const Color(0xFF10B981)),
                _countChip('Опоздали', _lateCount, const Color(0xFFF59E0B)),
                _countChip('Отсутствуют', _absentCount, const Color(0xFFEF4444)),
                const SizedBox(width: 8),
                if (canEdit) ...[
                  TextButton.icon(
                    onPressed: () => _setAll(null),
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Сбросить (все присутствуют)'),
                  ),
                  TextButton.icon(
                    onPressed: () => _setAll(_late),
                    icon: const Icon(Icons.schedule, size: 18),
                    label: const Text('Все опоздали'),
                  ),
                  TextButton.icon(
                    onPressed: () => _setAll(_absent),
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Все отсутствуют'),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 8),
        if (!loading && students.length > 6)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Поиск по имени...',
                prefixIcon: Icon(Icons.search, size: 20),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => search = v),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : students.isEmpty
                  ? const Center(child: Text('Нет студентов'))
                  : visible.isEmpty
                      ? const Center(child: Text('Никого не найдено'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final student = visible[i];
                            final sid = student['id'] as int;
                            final mark = marks[sid];
                            return _StudentRow(
                              fio: '${student['fio']}',
                              email: '${student['email']}',
                              mark: mark,
                              canEdit: canEdit,
                              onChanged: (v) => setState(() => marks[sid] = v),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _countChip(String label, int count, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text(
          '$count',
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      label: Text(label),
      backgroundColor: color.withValues(alpha: .08),
      side: BorderSide(color: color.withValues(alpha: .3)),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.fio,
    required this.email,
    required this.mark,
    required this.canEdit,
    required this.onChanged,
  });

  final String fio;
  final String email;
  final int? mark;
  final bool canEdit;
  final ValueChanged<int?> onChanged;

  static const _absent = 0;
  static const _late = 1;

  Color get _rowColor => switch (mark) {
        _absent => const Color(0xFFEF4444),
        _late => const Color(0xFFF59E0B),
        _ => const Color(0xFF10B981),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: _rowColor, width: 3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: _rowColor.withValues(alpha: .12),
            child: Text(
              fio.isNotEmpty ? fio[0] : '?',
              style: TextStyle(color: _rowColor, fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fio, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          // Presence is the default and is never tapped — the teacher only
          // touches one of these two toggles for the students who weren't
          // simply there on time, which is what keeps marking a group fast.
          _ExceptionToggle(
            label: 'Опоздал',
            icon: Icons.schedule,
            color: const Color(0xFFF59E0B),
            active: mark == _late,
            onTap: canEdit ? () => onChanged(mark == _late ? null : _late) : null,
          ),
          const SizedBox(width: 8),
          _ExceptionToggle(
            label: 'Отсутствует',
            icon: Icons.cancel,
            color: const Color(0xFFEF4444),
            active: mark == _absent,
            onTap: canEdit ? () => onChanged(mark == _absent ? null : _absent) : null,
          ),
        ],
      ),
    );
  }
}

/// A small pill button for one exception state. Filled and colored when
/// active; a quiet outline when not, so an untouched (present) row stays
/// visually calm and the exceptions are what draw the eye.
class _ExceptionToggle extends StatelessWidget {
  const _ExceptionToggle({
    required this.label,
    required this.icon,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: .15) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? color.withValues(alpha: .5) : color.withValues(alpha: .25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: active ? color : color.withValues(alpha: .55)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? color : color.withValues(alpha: .55),
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
