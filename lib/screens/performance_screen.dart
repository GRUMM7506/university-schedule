import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/entities.dart';
import '../services/academic_service.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  int? facultyId;
  int? specialityId;
  int? course;
  int? groupId;
  int? studentId;
  int? disciplineId;
  int? teacherId;
  int mark = 5;
  int controlType = 1;
  int tourNum = 1;
  bool loading = true;
  bool saving = false;

  List<Map<String, dynamic>> faculties = [];
  List<Map<String, dynamic>> specialities = [];
  List<Map<String, dynamic>> groups = [];
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> disciplines = [];
  List<Map<String, dynamic>> teachers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final service = context.read<AcademicService>();
    faculties = await service.list('/faculties');
    specialities = await service.list('/specialities');
    groups = await service.list('/groups');
    disciplines = await service.list('/disciplines');
    teachers = await service.list('/teachers');
    final allStudents = await service.list('/students');

    if (groups.isNotEmpty && groupId == null) {
      final firstGroup = groups.first;
      specialityId = _readInt(firstGroup['speciality_id']);
      course = _readInt(firstGroup['course']);
      facultyId = _facultyIdForSpeciality(specialityId);
      groupId = _readInt(firstGroup['id']);
    }

    students = allStudents.where((s) => s['group_id'] == groupId).toList()
      ..sort((a, b) => '${a['fio']}'.compareTo('${b['fio']}'));
    studentId = students.any((s) => s['id'] == studentId)
        ? studentId
        : (students.isEmpty ? null : students.first['id'] as int);

    if (!_groupDisciplines.any((d) => d['id'] == disciplineId)) {
      disciplineId = _groupDisciplines.isEmpty ? null : _groupDisciplines.first['id'] as int;
      _syncTeacherFromDiscipline();
    }
    teacherId ??= teachers.isEmpty ? null : teachers.first['id'] as int;
    if (mounted) setState(() => loading = false);
  }

  List<Map<String, dynamic>> get _filteredSpecialities {
    if (facultyId == null) return specialities;
    return specialities.where((s) => _readInt(s['faculty_id']) == facultyId).toList();
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
    return courses.map((value) => {'id': value, 'name': '$value курс'}).toList();
  }

  /// Disciplines (DisciplineLoad rows) taught to the selected group.
  /// Falls back to the full discipline list if a discipline has no group_id
  /// attached (e.g. shared/elective disciplines).
  List<Map<String, dynamic>> get _groupDisciplines {
    if (groupId == null) return disciplines;
    final forGroup = disciplines.where((d) => d['group_id'] == groupId).toList();
    return forGroup.isEmpty ? disciplines : forGroup;
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

  /// Disciplines already carry the assigned teacher, so picking one
  /// pre-selects that teacher instead of leaving it to chance.
  void _syncTeacherFromDiscipline() {
    final discipline = disciplines.firstWhere(
      (d) => d['id'] == disciplineId,
      orElse: () => const {},
    );
    final fromDiscipline = _readInt(discipline['teacher_id']);
    if (fromDiscipline != null) teacherId = fromDiscipline;
  }

  Future<void> _changeGroup(int? value) async {
    if (value == null) return;
    setState(() {
      groupId = value;
      studentId = null;
    });
    final allStudents = await context.read<AcademicService>().list('/students');
    students = allStudents.where((s) => s['group_id'] == groupId).toList()
      ..sort((a, b) => '${a['fio']}'.compareTo('${b['fio']}'));
    if (mounted) {
      setState(() {
        studentId = students.isEmpty ? null : students.first['id'] as int;
        if (!_groupDisciplines.any((d) => d['id'] == disciplineId)) {
          disciplineId = _groupDisciplines.isEmpty ? null : _groupDisciplines.first['id'] as int;
          _syncTeacherFromDiscipline();
        }
      });
    }
  }

  /// In a "credit" (зачёт) control, only three outcomes are used from the
  /// shared 0-5 mark scale: not attended, fail, pass.
  static const _creditMarks = [0, 2, 3];

  void _changeControlType(int? value) {
    setState(() {
      controlType = value ?? 1;
      if (controlType == 0 && !_creditMarks.contains(mark)) {
        mark = 3; // default to "зачет"
      }
    });
  }

  Future<void> _save() async {
    if (studentId == null || disciplineId == null || teacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните студента, дисциплину и преподавателя'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await context.read<AcademicService>().savePerformance({
        'student_id': studentId,
        'discipline_id': disciplineId,
        'teacher_id': teacherId,
        'control_type': controlType,
        'tour_num': tourNum,
        'mark': mark,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Оценка сохранена')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Успеваемость', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        _SectionCard(
          title: 'Кто',
          icon: Icons.person_outline,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 170,
                  child: _refDropdown(
                    'Факультет',
                    facultyId,
                    faculties,
                    (v) {
                      setState(() {
                        facultyId = v;
                        if (!_filteredSpecialities.any((s) => _readInt(s['id']) == specialityId)) {
                          specialityId = null;
                        }
                        if (!_courseOptions.any((c) => c['id'] == course)) {
                          course = null;
                        }
                      });
                      if (!_filteredGroups.any((g) => _readInt(g['id']) == groupId)) {
                        final next = _filteredGroups.isEmpty ? null : _readInt(_filteredGroups.first['id']);
                        if (next != null) _changeGroup(next);
                      }
                    },
                    allLabel: 'Все факультеты',
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: _refDropdown(
                    'Направление',
                    specialityId,
                    _filteredSpecialities,
                    (v) => setState(() {
                      specialityId = v;
                      if (!_courseOptions.any((c) => c['id'] == course)) {
                        course = null;
                      }
                      if (!_filteredGroups.any((g) => _readInt(g['id']) == groupId)) {
                        final next = _filteredGroups.isEmpty ? null : _readInt(_filteredGroups.first['id']);
                        if (next != null) _changeGroup(next);
                      }
                    }),
                    allLabel: 'Все направления',
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: _refDropdown(
                    'Курс',
                    course,
                    _courseOptions,
                    (v) => setState(() {
                      course = v;
                      if (!_filteredGroups.any((g) => _readInt(g['id']) == groupId)) {
                        final next = _filteredGroups.isEmpty ? null : _readInt(_filteredGroups.first['id']);
                        if (next != null) _changeGroup(next);
                      }
                    }),
                    allLabel: 'Все курсы',
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<int>(
                    initialValue: _filteredGroups.any((g) => _readInt(g['id']) == groupId) ? groupId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Группа', isDense: true),
                    items: _filteredGroups
                        .map((g) => DropdownMenuItem<int>(
                              value: _readInt(g['id']),
                              child: Text('${g['name']}', overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: _changeGroup,
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: _SearchableStudentField(
                    students: students,
                    value: studentId,
                    onChanged: (v) => setState(() => studentId = v),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'По какой дисциплине',
          icon: Icons.menu_book_outlined,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _dropdown(
                    'Дисциплина',
                    disciplineId,
                    _groupDisciplines,
                    'displayName',
                    (v) => setState(() {
                      disciplineId = v;
                      _syncTeacherFromDiscipline();
                    }),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _dropdown(
                    'Преподаватель',
                    teacherId,
                    teachers,
                    'fio',
                    (v) => setState(() => teacherId = v),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<int>(
                    initialValue: controlType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Контроль', isDense: true),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Зачет')),
                      DropdownMenuItem(value: 1, child: Text('Экзамен')),
                    ],
                    onChanged: _changeControlType,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Оценка',
          icon: Icons.grade_outlined,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('Тур:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 12),
                SegmentedButton<int>(
                  segments: [1, 2, 3]
                      .map((e) => ButtonSegment(value: e, label: Text('$e')))
                      .toList(),
                  selected: {tourNum},
                  onSelectionChanged: (value) => setState(() => tourNum = value.first),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (controlType == 0)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _creditMarks.map((value) {
                  final label = switch (value) {
                    0 => 'Не был',
                    2 => 'Не зачет',
                    _ => 'Зачет',
                  };
                  final selected = mark == value;
                  return ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => setState(() => mark = value),
                  );
                }).toList(),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: performanceMarks.entries.map((e) {
                  final value = int.parse(e.key);
                  final selected = mark == value;
                  return ChoiceChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: (_) => setState(() => mark = value),
                  );
                }).toList(),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Сохранить'),
          ),
        ),
      ],
    );
  }

  Widget _refDropdown(
    String label,
    int? value,
    List<Map<String, dynamic>> data,
    ValueChanged<int?> onChanged, {
    required String allLabel,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: data.any((e) => _readInt(e['id']) == value) ? value : null,
      isExpanded: true,
      menuMaxHeight: 320,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [
        DropdownMenuItem<int>(value: null, child: Text(allLabel, overflow: TextOverflow.ellipsis)),
        ...data.map(
          (e) => DropdownMenuItem<int>(
            value: _readInt(e['id']),
            child: Text('${e['name']}', overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _dropdown(
    String label,
    int? value,
    List<Map<String, dynamic>> data,
    String display,
    ValueChanged<int?> onChanged,
  ) {
    return DropdownButtonFormField<int>(
      initialValue: data.any((e) => e['id'] == value) ? value : null,
      isExpanded: true,
      menuMaxHeight: 320,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: data
          .map(
            (e) => DropdownMenuItem<int>(
              value: e['id'] as int,
              child: Text(
                display == 'id' ? 'Дисциплина #${e['id']}' : '${e[display]}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Dropdown with a search field at the top of its menu, so picking a student
/// out of a long list doesn't require scanning the whole roster.
class _SearchableStudentField extends StatelessWidget {
  const _SearchableStudentField({
    required this.students,
    required this.value,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> students;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = students.firstWhere(
      (s) => s['id'] == value,
      orElse: () => const {},
    );
    final label = selected.isEmpty ? null : '${selected['fio']}';

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: students.isEmpty ? null : () => _openPicker(context),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Студент',
          isDense: true,
          suffixIcon: Icon(Icons.search, size: 20),
        ),
        child: Text(
          label ?? 'Нет студентов',
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _StudentPickerSheet(students: students, currentValue: value),
    );
    if (result != null) onChanged(result);
  }
}

class _StudentPickerSheet extends StatefulWidget {
  const _StudentPickerSheet({required this.students, required this.currentValue});

  final List<Map<String, dynamic>> students;
  final int? currentValue;

  @override
  State<_StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<_StudentPickerSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = query.isEmpty
        ? widget.students
        : widget.students
            .where((s) => '${s['fio']}'.toLowerCase().contains(query.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Поиск по имени...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => query = v),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('Никого не найдено'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final s = filtered[i];
                          final selected = s['id'] == widget.currentValue;
                          return ListTile(
                            title: Text('${s['fio']}'),
                            subtitle: Text('${s['email']}'),
                            trailing: selected ? const Icon(Icons.check_circle) : null,
                            selected: selected,
                            onTap: () => Navigator.pop(context, s['id'] as int),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}