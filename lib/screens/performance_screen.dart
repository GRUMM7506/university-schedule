import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/entities.dart';
import '../providers/auth_provider.dart';
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
  int? disciplineId;
  int? teacherId;
  int controlType = 1;
  bool loading = true;

  List<Map<String, dynamic>> faculties = [];
  List<Map<String, dynamic>> specialities = [];
  List<Map<String, dynamic>> groups = [];
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> disciplines = [];
  List<Map<String, dynamic>> teachers = [];

  /// studentId -> {tourNum -> mark}
  Map<int, Map<int, int?>> marks = {};

  /// One date per tour column (tours 1..3 -> index 0..2).
  final List<DateTime?> tourDates = List<DateTime?>.filled(3, null);

  /// Keys of cells currently saving, e.g. "12_2" (studentId_tourNum).
  final Set<String> savingCells = {};

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

    if (!_groupDisciplines.any((d) => d['id'] == disciplineId)) {
      disciplineId = _groupDisciplines.isEmpty ? null : _groupDisciplines.first['id'] as int;
      _syncTeacherFromDiscipline();
    }
    teacherId ??= teachers.isEmpty ? null : teachers.first['id'] as int;

    await _loadMarks();
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

  /// Pulls all performance records and keeps only the ones matching the
  /// current group's students + selected discipline/teacher/control type,
  /// arranged as studentId -> tourNum -> mark for the table.
  Future<void> _loadMarks() async {
    if (disciplineId == null || teacherId == null || students.isEmpty) {
      if (mounted) setState(() => marks = {});
      return;
    }
    final service = context.read<AcademicService>();
    final all = await service.list('/performance');
    final studentIds = students.map((s) => _readInt(s['id'])).whereType<int>().toSet();

    final result = <int, Map<int, int?>>{};
    for (final p in all) {
      final sid = _readInt(p['student_id']);
      if (sid == null || !studentIds.contains(sid)) continue;
      if (_readInt(p['discipline_id']) != disciplineId) continue;
      if (_readInt(p['teacher_id']) != teacherId) continue;
      if (_readInt(p['control_type']) != controlType) continue;
      final tour = _readInt(p['tour_num']) ?? 1;
      result.putIfAbsent(sid, () => {})[tour] = _readInt(p['mark']);
    }
    if (mounted) setState(() => marks = result);
  }

  Future<void> _changeGroup(int? value) async {
    if (value == null) return;
    setState(() {
      groupId = value;
    });
    final allStudents = await context.read<AcademicService>().list('/students');
    students = allStudents.where((s) => s['group_id'] == groupId).toList()
      ..sort((a, b) => '${a['fio']}'.compareTo('${b['fio']}'));
    if (!_groupDisciplines.any((d) => d['id'] == disciplineId)) {
      disciplineId = _groupDisciplines.isEmpty ? null : _groupDisciplines.first['id'] as int;
      _syncTeacherFromDiscipline();
    }
    await _loadMarks();
    if (mounted) setState(() {});
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

  /// In a "credit" (зачёт) control, only three outcomes are used from the
  /// shared 0-5 mark scale: not attended, fail, pass.
  static const _creditMarks = [0, 2, 3];
  static const _creditLabels = {0: 'Не был', 2: 'Не зачет', 3: 'Зачет'};

  void _changeControlType(int? value) {
    setState(() => controlType = value ?? 1);
    _loadMarks();
  }

  Future<void> _setMark(int? studentId, int tour, int value) async {
    if (studentId == null || disciplineId == null || teacherId == null) return;
    final key = '${studentId}_$tour';
    setState(() => savingCells.add(key));
    try {
      await context.read<AcademicService>().savePerformance({
        'student_id': studentId,
        'discipline_id': disciplineId,
        'teacher_id': teacherId,
        'control_type': controlType,
        'tour_num': tour,
        'mark': value,
        if (tourDates[tour - 1] != null) 'date': tourDates[tour - 1]!.toIso8601String(),
      });
      marks.putIfAbsent(studentId, () => {})[tour] = value;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить оценку'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => savingCells.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final canEdit = context.watch<AuthProvider>().hasPermission('performance.edit');
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
                        _updateCascadingFilters();
                      });
                      if (groupId != null) _changeGroup(groupId);
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
                    (v) {
                      setState(() {
                        specialityId = v;
                        _updateCascadingFilters();
                      });
                      if (groupId != null) _changeGroup(groupId);
                    },
                    allLabel: 'Все направления',
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: _refDropdown(
                    'Курс',
                    course,
                    _courseOptions,
                    (v) {
                      setState(() {
                        course = v;
                        _updateCascadingFilters();
                      });
                      if (groupId != null) _changeGroup(groupId);
                    },
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
                    onChanged: canEdit ? _changeGroup : null,
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
                    canEdit
                        ? (v) {
                            setState(() {
                              disciplineId = v;
                              _syncTeacherFromDiscipline();
                            });
                            _loadMarks();
                          }
                        : null,
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
                    canEdit
                        ? (v) {
                            setState(() => teacherId = v);
                            _loadMarks();
                          }
                        : null,
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
                    onChanged: canEdit ? _changeControlType : null,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Ведомость',
          icon: Icons.table_chart_outlined,
          children: [
            _buildMarksTable(canEdit),
          ],
        ),
      ],
    );
  }

  Widget _buildMarksTable(bool canEdit) {
    if (disciplineId == null || teacherId == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Выберите дисциплину и преподавателя')),
      );
    }
    if (students.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('В группе нет студентов')),
      );
    }
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              flex: 3,
              child: Text('Студент', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            for (var t = 1; t <= 3; t++)
              Expanded(
                flex: 2,
                child: _TourHeader(
                  tourNum: t,
                  date: tourDates[t - 1],
                  enabled: canEdit,
                  onPickDate: (d) => setState(() => tourDates[t - 1] = d),
                ),
              ),
          ],
        ),
        const Divider(height: 20),
        for (final student in students) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: Text('${student['fio']}', overflow: TextOverflow.ellipsis),
                ),
                for (var t = 1; t <= 3; t++)
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _MarkCell(
                        mark: marks[_readInt(student['id'])]?[t],
                        controlType: controlType,
                        enabled: canEdit,
                        saving: savingCells.contains('${_readInt(student['id'])}_$t'),
                        onSelect: (value) => _setMark(_readInt(student['id']), t, value),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }

  Widget _refDropdown(
    String label,
    int? value,
    List<Map<String, dynamic>> data,
    ValueChanged<int?>? onChanged, {
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
    ValueChanged<int?>? onChanged,
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

/// Column header for a tour: the tour number plus a tappable date, so the
/// whole column's records can be tied to a specific exam/credit day.
class _TourHeader extends StatelessWidget {
  const _TourHeader({
    required this.tourNum,
    required this.date,
    required this.enabled,
    required this.onPickDate,
  });

  final int tourNum;
  final DateTime? date;
  final bool enabled;
  final ValueChanged<DateTime?> onPickDate;

  @override
  Widget build(BuildContext context) {
    final label = date == null
        ? 'Дата'
        : '${date!.day.toString().padLeft(2, '0')}.${date!.month.toString().padLeft(2, '0')}.${date!.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Тур $tourNum', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 4),
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: enabled ? () => _pick(context) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_outlined, size: 13, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) onPickDate(picked);
  }
}

/// Short Russian abbreviations shown in the grid instead of raw digits.
const Map<int, String> _examShortLabels = {5: 'отл', 4: 'хор', 3: 'удовл', 2: 'неуд'};

/// Full label for a given mark value, used in dialogs and confirmations.
String _markLabel(int controlType, int value) {
  if (controlType == 0) return _PerformanceScreenState._creditLabels[value] ?? '$value';
  return performanceMarks['$value'] ?? '$value';
}

/// A single mark cell in the grid. Shows a short abbreviation (or a dash) and,
/// once a mark is set, is locked — marks can only be entered once, never
/// edited afterwards, so tapping does nothing after that point.
class _MarkCell extends StatelessWidget {
  const _MarkCell({
    required this.mark,
    required this.controlType,
    required this.enabled,
    required this.saving,
    required this.onSelect,
  });

  final int? mark;
  final int controlType;
  final bool enabled;
  final bool saving;
  final ValueChanged<int> onSelect;

  bool get _locked => mark != null;

  String get _label {
    if (mark == null) return '—';
    if (controlType == 0) return _PerformanceScreenState._creditLabels[mark] ?? '$mark';
    return _examShortLabels[mark] ?? '$mark';
  }

  Color? _bgColor(BuildContext context) {
    if (mark == null) return null;
    final scheme = Theme.of(context).colorScheme;
    if (controlType == 0) {
      if (mark == 2) return Colors.red.withValues(alpha: .12);
      if (mark == 3) return Colors.green.withValues(alpha: .12);
      return scheme.surfaceContainerHighest.withValues(alpha: .3);
    }
    if (mark! <= 2) return Colors.red.withValues(alpha: .12);
    if (mark == 3) return Colors.orange.withValues(alpha: .12);
    return Colors.green.withValues(alpha: .12);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled && !_locked ? () => _openDialog(context) : null,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _bgColor(context) ?? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .4)),
        ),
        child: saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (_locked) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.lock_outline, size: 11, color: Theme.of(context).colorScheme.outline),
                  ],
                ],
              ),
      ),
    );
  }

  Future<void> _openDialog(BuildContext context) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => _MarkSelectDialog(controlType: controlType),
    );
    if (selected == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтвердите оценку'),
        content: Text(
          'Поставить оценку «${_markLabel(controlType, selected)}»?\n\n'
          'После сохранения изменить её будет нельзя — проверьте значение перед подтверждением.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Подтвердить')),
        ],
      ),
    );
    if (confirmed == true) onSelect(selected);
  }
}

/// Dialog listing the valid mark options for the current control type
/// (зачёт vs экзамен). Exam marks are shown with their short abbreviation.
class _MarkSelectDialog extends StatelessWidget {
  const _MarkSelectDialog({required this.controlType});

  final int controlType;

  @override
  Widget build(BuildContext context) {
    final values = controlType == 0
        ? _PerformanceScreenState._creditMarks
        : (performanceMarks.keys.map(int.parse).toList()..sort());

    return AlertDialog(
      title: const Text('Выберите оценку'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: values.map((value) {
            final short = controlType == 1 ? _examShortLabels[value] : null;
            return ListTile(
              leading: short == null
                  ? null
                  : Container(
                      width: 52,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        short,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
              title: Text(_markLabel(controlType, value)),
              onTap: () => Navigator.pop(context, value),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
      ],
    );
  }
}