import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/entities.dart';
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
  final marks = <int, int>{};
  bool loading = true;
  bool saving = false;
  String search = '';

  static const _present = 2;
  static const _late = 1;
  static const _absent = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadRefs();
    });
  }

  Future<void> _loadRefs() async {
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
    final service = context.read<AcademicService>();
    final allStudents = await service.list('/students');
    students = allStudents.where((s) => s['group_id'] == groupId).toList()
      ..sort((a, b) => '${a['fio']}'.compareTo('${b['fio']}'));
    marks.clear();
    for (final student in students) {
      marks.putIfAbsent(student['id'] as int, () => _present);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _changeGroup(int? value) async {
    if (value == null) return;
    setState(() {
      groupId = value;
      search = '';
    });
    await _loadStudents();
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
            'mark': marks[student['id']] ?? _present,
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

  void _setAll(int mark) {
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

  Map<int, int> get _counts {
    final result = {_present: 0, _late: 0, _absent: 0};
    for (final student in students) {
      final m = marks[student['id']] ?? _present;
      result[m] = (result[m] ?? 0) + 1;
    }
    return result;
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
    final counts = _counts;
    final visible = _visibleStudents;

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
                (v) => setState(() {
                  facultyId = v;
                  if (!_filteredSpecialities.any(
                    (s) => _readInt(s['id']) == specialityId,
                  )) {
                    specialityId = null;
                  }
                  if (!_courseOptions.any((c) => c['id'] == course)) {
                    course = null;
                  }
                  groupId = null;
                }),
                // allLabel: 'Все факультеты',
                width: 240,
              ),
              _buildDropdown(
                'Направление',
                specialityId,
                _filteredSpecialities,
                (v) => setState(() {
                  specialityId = v;
                  if (!_courseOptions.any((c) => c['id'] == course)) {
                    course = null;
                  }
                  groupId = null;
                }),
                // allLabel: 'Все направления',
                width: 260,
              ),
              // _buildDropdown(
              //   'Курс',
              //   course,
              //   _courseOptions,
              //   (v) => setState(() {
              //     course = v;
              //     groupId = null;
              //   }),
              //   // allLabel: 'Все курсы',
              //   width: 160,
              // ),
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
                _countChip('Присутствуют', counts[_present] ?? 0, const Color(0xFF10B981)),
                _countChip('Опоздали', counts[_late] ?? 0, const Color(0xFFF59E0B)),
                _countChip('Отсутствуют', counts[_absent] ?? 0, const Color(0xFFEF4444)),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _setAll(_present),
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Все присутствуют'),
                ),
                TextButton.icon(
                  onPressed: () => _setAll(_absent),
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Все отсутствуют'),
                ),
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
                            final mark = marks[sid] ?? _present;
                            return _StudentRow(
                              fio: '${student['fio']}',
                              email: '${student['email']}',
                              mark: mark,
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
    required this.onChanged,
  });

  final String fio;
  final String email;
  final int mark;
  final ValueChanged<int> onChanged;

  Color get _markColor => switch (mark) {
        2 => const Color(0xFF10B981),
        1 => const Color(0xFFF59E0B),
        _ => const Color(0xFFEF4444),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: _markColor, width: 3)),
      ),
      child: ListTile(
        title: Text(fio, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(email, style: const TextStyle(fontSize: 12)),
        trailing: SegmentedButton<int>(
          segments: attendanceMarks.entries
              .map((e) => ButtonSegment(value: int.parse(e.key), label: Text(e.value)))
              .toList(),
          selected: {mark},
          onSelectionChanged: (value) => onChanged(value.first),
        ),
      ),
    );
  }
}