import 'package:flutter/material.dart';

import '../models/entities.dart';
import '../services/academic_service.dart';

class ScheduleFormDialog extends StatefulWidget {
  const ScheduleFormDialog({
    super.key,
    required this.academicService,
    this.initial,
  });

  final AcademicService academicService;
  final Map<String, dynamic>? initial;

  @override
  State<ScheduleFormDialog> createState() => _ScheduleFormDialogState();
}

class _ScheduleFormDialogState extends State<ScheduleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  List<Map<String, dynamic>> _weeks = [];
  List<Map<String, dynamic>> _faculties = [];
  List<Map<String, dynamic>> _specialities = [];
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _classrooms = [];
  List<Map<String, dynamic>> _disciplines = [];

  int? _weekId;
  int? _dayNum;
  int? _pairNum;
  int? _facultyId;
  int? _specialityId;
  int? _course;
  int? _groupId;
  int? _subjectId;
  int? _teacherId;
  int? _lessonType;
  int? _classroomId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final initial = widget.initial;
    final results = await Future.wait([
      widget.academicService.list('/study-weeks'),
      widget.academicService.list('/faculties'),
      widget.academicService.list('/specialities'),
      widget.academicService.list('/groups'),
      widget.academicService.list('/subjects'),
      widget.academicService.list('/teachers'),
      widget.academicService.list('/classrooms'),
      widget.academicService.list('/disciplines'),
    ]);
    if (!mounted) return;
    setState(() {
      _weeks = results[0];
      _faculties = results[1];
      _specialities = results[2];
      _groups = results[3];
      _subjects = results[4];
      _teachers = results[5];
      _classrooms = results[6];
      _disciplines = results[7];
      _weekId = _readInt(initial, 'study_week_id') ?? _firstId(_weeks);
      _dayNum = _readInt(initial, 'day_num') ?? 1;
      _pairNum = _readInt(initial, 'pair_num') ?? 1;
      _facultyId = _readInt(initial, 'faculty_id') ?? _firstId(_faculties);
      _specialityId = _readInt(initial, 'speciality_id');
      _course = _readInt(initial, 'course');
      _groupId = _readInt(initial, 'group_id');
      _subjectId = _readInt(initial, 'subject_id');
      _teacherId = _readInt(initial, 'teacher_id');
      _lessonType = _readInt(initial, 'lesson_type') ?? 0;
      _classroomId = _readInt(initial, 'classroom_id') ?? _firstId(_classrooms);
      _ensureFilteredValues();
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredSpecialities {
    if (_facultyId == null) return _specialities;
    return _specialities
        .where((s) => _readInt(s, 'faculty_id') == _facultyId)
        .toList();
  }

  List<Map<String, dynamic>> get _filteredGroups {
    return _groups.where((g) {
      final groupSpecialityId = _readInt(g, 'speciality_id');
      final matchesSpeciality = _specialityId == null || groupSpecialityId == _specialityId;
      final matchesCourse = _course == null || _readInt(g, 'course') == _course;
      return matchesSpeciality && matchesCourse;
    }).toList();
  }

  List<Map<String, dynamic>> get _groupDisciplines =>
      _disciplines.where((d) => d['group_id'] == _groupId).toList();

  List<Map<String, dynamic>> get _filteredSubjects {
    final ids = _groupDisciplines.map((d) => d['subject_id']).toSet();
    return _subjects.where((s) => ids.contains(s['id'])).toList();
  }

  List<Map<String, dynamic>> get _filteredTeachers {
    final ids = _groupDisciplines
        .where((d) => d['subject_id'] == _subjectId)
        .map((d) => d['teacher_id'])
        .toSet();
    return _teachers.where((t) => ids.contains(t['id'])).toList();
  }

  void _ensureFilteredValues() {
    final specialities = _filteredSpecialities;
    if (!specialities.any((s) => s['id'] == _specialityId)) {
      _specialityId = _firstId(specialities);
    }
    final groups = _filteredGroups;
    if (!groups.any((g) => g['id'] == _groupId)) {
      _groupId = _firstId(groups);
    }
    final subjects = _filteredSubjects;
    if (!subjects.any((s) => s['id'] == _subjectId)) {
      _subjectId = _firstId(subjects);
    }
    final teachers = _filteredTeachers;
    if (!teachers.any((t) => t['id'] == _teacherId)) {
      _teacherId = _firstId(teachers);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'study_week_id': _weekId,
      'day_num': _dayNum,
      'pair_num': _pairNum,
      'faculty_id': _facultyId,
      'speciality_id': _specialityId,
      'course': _course,
      'group_id': _groupId,
      'subject_id': _subjectId,
      'teacher_id': _teacherId,
      'lesson_type': _lessonType,
      'classroom_id': _classroomId,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Добавить занятие' : 'Изменить занятие',
      ),
      content: SizedBox(
        width: 560,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _select(
                        label: 'Учебная неделя',
                        value: _weekId,
                        items: _weeks,
                        onChanged: (v) => setState(() => _weekId = v),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _selectFromMap(
                              label: 'День',
                              value: _dayNum,
                              items: const {
                                1: 'Понедельник',
                                2: 'Вторник',
                                3: 'Среда',
                                4: 'Четверг',
                                5: 'Пятница',
                                6: 'Суббота',
                              },
                              onChanged: (v) => setState(() => _dayNum = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _selectFromMap(
                              label: 'Пара',
                              value: _pairNum,
                              items: const {
                                1: '1 пара',
                                2: '2 пара',
                                3: '3 пара',
                                4: '4 пара',
                                5: '5 пара',
                                6: '6 пара',
                              },
                              onChanged: (v) => setState(() => _pairNum = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _select(
                        label: 'Факультет',
                        value: _facultyId,
                        items: _faculties,
                        onChanged: (v) => setState(() {
                          _facultyId = v;
                          _ensureFilteredValues();
                        }),
                      ),
                      const SizedBox(height: 12),
                      _select(
                        label: 'Направление',
                        value: _specialityId,
                        items: _filteredSpecialities,
                        emptyText: 'Для факультета нет направлений',
                        onChanged: (v) => setState(() {
                          _specialityId = v;
                          _ensureFilteredValues();
                        }),
                      ),
                      const SizedBox(height: 12),
                      _selectFromStringMap(
                        label: 'Курс',
                        value: _course,
                        items: const {
                          '1': '1 курс',
                          '2': '2 курс',
                          '3': '3 курс',
                          '4': '4 курс'
                        },
                        onChanged: (v) => setState(() {
                          _course = v;
                          _ensureFilteredValues();
                        }),
                      ),
                      const SizedBox(height: 12),
                      _select(
                        label: 'Группа',
                        value: _groupId,
                        items: _filteredGroups,
                        emptyText: 'Нет групп для фильтра',
                        onChanged: (v) => setState(() {
                          _groupId = v;
                          _ensureFilteredValues();
                        }),
                      ),
                      const SizedBox(height: 12),
                      _select(
                        label: 'Предмет',
                        value: _subjectId,
                        items: _filteredSubjects,
                        emptyText: 'Для группы нет дисциплин',
                        onChanged: (v) => setState(() {
                          _subjectId = v;
                          _ensureFilteredValues();
                        }),
                      ),
                      const SizedBox(height: 12),
                      _select(
                        label: 'Преподаватель',
                        value: _teacherId,
                        items: _filteredTeachers,
                        labelKey: 'fio',
                        emptyText: 'Нет преподавателей для предмета',
                        allowEmpty: true,
                        emptyItemLabel: 'Не выбран',
                        onChanged: (v) => setState(() => _teacherId = v),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _selectFromStringMap(
                              label: 'Тип занятия',
                              value: _lessonType,
                              items: lessonTypes,
                              onChanged: (v) => setState(() => _lessonType = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _select(
                              label: 'Аудитория',
                              value: _classroomId,
                              items: _classrooms,
                              labelKey: 'number',
                              onChanged: (v) =>
                                  setState(() => _classroomId = v),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton.icon(
          onPressed: _loading ? null : _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Сохранить'),
        ),
      ],
    );
  }

  Widget _select({
    required String label,
    required int? value,
    required List<Map<String, dynamic>> items,
    required ValueChanged<int?> onChanged,
    String labelKey = 'name',
    String emptyText = 'Нет данных',
    bool allowEmpty = false,
    String emptyItemLabel = 'Выберите...',
  }) {
    final normalizedValue = items.any((e) => e['id'] == value) ? value : null;
    final dropdownItems = <DropdownMenuItem<int?>>[];
    if (allowEmpty) {
      dropdownItems.add(
        DropdownMenuItem<int?>(
          value: null,
          child: Text(emptyItemLabel),
        ),
      );
    }
    dropdownItems.addAll(
      items.map(
        (e) => DropdownMenuItem<int?>(
          value: e['id'] as int,
          child: Text(
            '${e[labelKey] ?? e['name']}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
    return DropdownButtonFormField<int?>(
      initialValue: normalizedValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: dropdownItems,
      hint: Text(emptyText),
      validator: allowEmpty ? null : (v) => v == null ? 'Заполните поле' : null,
      onChanged: items.isEmpty ? null : onChanged,
    );
  }

  Widget _selectFromMap({
    required String label,
    required int? value,
    required Map<int, String> items,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      validator: (v) => v == null ? 'Заполните поле' : null,
      onChanged: onChanged,
    );
  }

  Widget _selectFromStringMap({
    required String label,
    required int? value,
    required Map<String, String> items,
    required ValueChanged<int?> onChanged,
  }) {
    return _selectFromMap(
      label: label,
      value: value,
      items: items.map((k, v) => MapEntry(int.parse(k), v)),
      onChanged: onChanged,
    );
  }
}

int? _firstId(List<Map<String, dynamic>> items) =>
    items.isEmpty ? null : items.first['id'] as int;

int? _readInt(Map<String, dynamic>? data, String key) {
  final value = data?[key];
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
