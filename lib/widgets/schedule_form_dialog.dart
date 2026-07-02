import 'dart:async';

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

  // ── Slot occupancy (T4: proactive conflict warnings) ──────────────────
  Map<String, dynamic>? _slotInfo;
  bool _checkingSlot = false;
  bool _showAllBookings = false;
  Timer? _debounce;
  int? _editingId;

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
      _editingId = _readInt(initial, 'id');
      _ensureFilteredValues();
      _loading = false;
    });
    _checkSlot();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Re-queries who/what is already booked into the currently selected
  /// week/day/pair, debounced so rapid dropdown changes don't fire a
  /// request per keystroke. Drives the warning panel below the form.
  void _checkSlot() {
    _debounce?.cancel();
    if (_weekId == null || _dayNum == null || _pairNum == null) {
      setState(() => _slotInfo = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() => _checkingSlot = true);
      try {
        final info = await widget.academicService.checkScheduleSlot(
          weekId: _weekId!,
          dayNum: _dayNum!,
          pairNum: _pairNum!,
          teacherId: _teacherId,
          classroomId: _classroomId,
          groupId: _groupId,
          excludeId: _editingId,
        );
        if (mounted) setState(() => _slotInfo = info);
      } catch (_) {
        // Non-critical: the form still works without the warning panel.
        if (mounted) setState(() => _slotInfo = null);
      } finally {
        if (mounted) setState(() => _checkingSlot = false);
      }
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
                        onChanged: (v) => setState(() {
                          _weekId = v;
                          _checkSlot();
                        }),
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
                              onChanged: (v) => setState(() {
                                _dayNum = v;
                                _checkSlot();
                              }),
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
                              },
                              onChanged: (v) => setState(() {
                                _pairNum = v;
                                _checkSlot();
                              }),
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
                          _checkSlot();
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
                        onChanged: (v) => setState(() {
                          _teacherId = v;
                          _checkSlot();
                        }),
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
                              onChanged: (v) => setState(() {
                                _classroomId = v;
                                _checkSlot();
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SlotConflictPanel(
                        checking: _checkingSlot,
                        info: _slotInfo,
                        teacherId: _teacherId,
                        classroomId: _classroomId,
                        groupId: _groupId,
                        showAll: _showAllBookings,
                        onToggleShowAll: () => setState(() => _showAllBookings = !_showAllBookings),
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

/// Shows what's already booked into the currently-selected week/day/pair
/// *before* the user hits save. Highlights a conflict when it matches the
/// currently-selected teacher/classroom/group specifically, and lets the
/// user expand a full list of everything else in that slot (or collapse it
/// out of the way once they've seen it).
class _SlotConflictPanel extends StatelessWidget {
  const _SlotConflictPanel({
    required this.checking,
    required this.info,
    required this.teacherId,
    required this.classroomId,
    required this.groupId,
    required this.showAll,
    required this.onToggleShowAll,
  });

  final bool checking;
  final Map<String, dynamic>? info;
  final int? teacherId;
  final int? classroomId;
  final int? groupId;
  final bool showAll;
  final VoidCallback onToggleShowAll;

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text('Проверяем занятость на это время…', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }
    if (info == null) return const SizedBox.shrink();

    final bookings = List<Map<String, dynamic>>.from(info!['bookings'] as List? ?? []);
    final conflicts = <Map<String, dynamic>>[
      if (info!['teacher_conflict'] != null) {'kind': 'Преподаватель', ...info!['teacher_conflict'] as Map},
      if (info!['classroom_conflict'] != null) {'kind': 'Аудитория', ...info!['classroom_conflict'] as Map},
      if (info!['group_conflict'] != null) {'kind': 'Группа', ...info!['group_conflict'] as Map},
    ];

    if (bookings.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: .1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: .3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'На это время в этой неделе больше ничего не запланировано',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in conflicts)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: .35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${c['kind']} уже занят(а) в это время: '
                      '${c['subject'] ?? '—'} · ${c['teacher'] ?? ''} · ${c['group'] ?? ''} · '
                      'ауд. ${c['classroom'] ?? '—'}',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (conflicts.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: .3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'На это время уже запланировано ${bookings.length} '
                    '${_pluralLessons(bookings.length)}, но с вашим выбором пересечений нет',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: onToggleShowAll,
          icon: Icon(showAll ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16),
          label: Text(
            showAll ? 'Скрыть занятые пары' : 'Показать всё, что занято в это время (${bookings.length})',
            style: const TextStyle(fontSize: 12.5),
          ),
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
        ),
        if (showAll)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .4)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: bookings.map((b) {
                final isTeacherHit = teacherId != null && b['teacher_id'] == teacherId;
                final isRoomHit = classroomId != null && b['classroom_id'] == classroomId;
                final isGroupHit = groupId != null && b['group_id'] == groupId;
                final hit = isTeacherHit || isRoomHit || isGroupHit;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: hit ? const Color(0xFFEF4444).withValues(alpha: .06) : null,
                    border: Border(
                      top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .3)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 6,
                        color: hit ? const Color(0xFFEF4444) : Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${b['subject'] ?? '—'} · ${b['teacher'] ?? '—'} · гр. ${b['group'] ?? '—'} · ауд. ${b['classroom'] ?? '—'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: hit ? FontWeight.w700 : FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  String _pluralLessons(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'занятие';
    if ([2, 3, 4].contains(mod10) && ![12, 13, 14].contains(mod100)) return 'занятия';
    return 'занятий';
  }
}
