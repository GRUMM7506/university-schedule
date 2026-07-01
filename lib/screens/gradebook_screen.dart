import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/entities.dart';
import '../services/academic_service.dart';
import '../widgets/glass.dart';

class GradebookScreen extends StatefulWidget {
  const GradebookScreen({super.key});

  @override
  State<GradebookScreen> createState() => _GradebookScreenState();
}

class _GradebookScreenState extends State<GradebookScreen> {
  int? groupId;
  int? facultyId;
  int? specialityId;
  int? course;
  List<Map<String, dynamic>> groups = [];
  List<Map<String, dynamic>> faculties = [];
  List<Map<String, dynamic>> specialities = [];
  List<Map<String, dynamic>> rawData = [];
  bool loading = true;
  String searchQuery = '';

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
      groupId = firstGroup['id'] as int;
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
    await _loadData();
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

  Future<void> _loadData() async {
    setState(() => loading = true);
    final service = context.read<AcademicService>();
    rawData = await service.gradebook(groupId: groupId);
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
    final grps = _filteredGroups;
    if (!grps.any((g) => _readInt(g['id']) == groupId)) {
      groupId = grps.isNotEmpty ? _readInt(grps.first['id']) : null;
    }
  }

  // Build a pivot: student -> {discipline -> {mark, subject_name}}
  Map<String, Map<String, dynamic>> _buildPivot() {
    final Map<String, Map<String, dynamic>> pivot = {};
    for (final row in rawData) {
      final studentId = '${row['student_id']}';
      final fio = '${row['student_fio']}';
      if (!pivot.containsKey(studentId)) {
        pivot[studentId] = {'_fio': fio, '_group': '${row['group_name']}'};
      }
      if (row['perf_id'] != null) {
        final discId = '${row['discipline_id']}';
        pivot[studentId]![discId] = {
          'mark': row['mark'],
          'subject': row['subject_name'],
          'control_type': row['control_type'],
        };
      }
    }
    return pivot;
  }

  Set<String> _getSubjects(Map<String, Map<String, dynamic>> pivot) {
    final subjects = <String>{};
    for (final student in pivot.values) {
      for (final key in student.keys) {
        if (!key.startsWith('_')) subjects.add(key);
      }
    }
    return subjects;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.menu_book_outlined,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Журнал успеваемости',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Оценки студентов по дисциплинам',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
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
                      (v) {
                        setState(() {
                          facultyId = v;
                          _updateCascadingFilters();
                        });
                        _loadData();
                      },
                      allLabel: 'Все факультеты',
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
                        _loadData();
                      },
                      allLabel: 'Все направления',
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
                        _loadData();
                      },
                      allLabel: 'Все курсы',
                      width: 160,
                    ),
                    _buildDropdown(
                      'Группа',
                      groupId,
                      _filteredGroups,
                      (v) {
                        setState(() => groupId = v);
                        _loadData();
                      },
                      allLabel: 'Все группы',
                      width: 220,
                    ),
                    const SizedBox(width: 12),
                    IconButton.filled(
                      tooltip: 'Обновить',
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Wrap(
            spacing: 10,
            children: performanceMarks.entries.map((e) {
              final mark = int.parse(e.key);
              return _MarkBadge(mark: mark, label: e.value);
            }).toList(),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GlassPanel(
              padding: EdgeInsets.zero,
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : rawData.isEmpty
                  ? _EmptyState()
                  : _buildTable(MediaQuery.of(context).size.width),
            ),
          ),
        ],
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

  Widget _buildTable(double width) {
    final pivot = _buildPivot();
    final subjects = _getSubjects(pivot).toList()..sort();
    final students = pivot.entries
        .where(
          (e) =>
              searchQuery.isEmpty ||
              e.value['_fio'].toString().toLowerCase().contains(
                searchQuery.toLowerCase(),
              ),
        )
        .toList();

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: width),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: .15),
            ),
            columns: [
              const DataColumn(
                label: Text('№', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              const DataColumn(
                label: Text(
                  'Студент',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const DataColumn(
                label: Text(
                  'Группа',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              for (final discId in subjects)
                DataColumn(
                  label: SizedBox(
                    width: 90,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _subjectShortName(pivot, discId),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              const DataColumn(
                label: Text(
                  'Ср. балл',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
            rows: students.asMap().entries.map((entry) {
              final idx = entry.key;
              final studentData = entry.value.value;
              final marks = <int>[];
              for (final discId in subjects) {
                if (studentData.containsKey(discId)) {
                  marks.add(studentData[discId]['mark'] as int);
                }
              }
              final avg = marks.isEmpty
                  ? 0.0
                  : marks.reduce((a, b) => a + b) / marks.length;

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      '${idx + 1}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: .12),
                          child: Text(
                            studentData['_fio'].toString()[0],
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${studentData['_fio']}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${studentData['_group']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  for (final discId in subjects)
                    DataCell(
                      Center(
                        child: studentData.containsKey(discId)
                            ? _MarkBadge(
                                mark: studentData[discId]['mark'] as int,
                                compact: true,
                              )
                            : const Text(
                                '—',
                                style: TextStyle(color: Colors.grey),
                              ),
                      ),
                    ),
                  DataCell(_AvgBadge(avg: avg)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _subjectShortName(
    Map<String, Map<String, dynamic>> pivot,
    String discId,
  ) {
    for (final s in pivot.values) {
      if (s.containsKey(discId)) {
        return '${s[discId]['subject'] ?? 'Дисц. #$discId'}';
      }
    }
    return 'Дисц. #$discId';
  }
}

class _MarkBadge extends StatelessWidget {
  const _MarkBadge({required this.mark, this.label, this.compact = false});

  final int mark;
  final String? label;
  final bool compact;

  Color get color => switch (mark) {
    5 => const Color(0xFF10B981),
    4 => const Color(0xFF3B82F6),
    3 => const Color(0xFFF59E0B),
    2 => const Color(0xFFEF4444),
    1 => const Color(0xFF6B7280),
    0 => const Color(0xFF374151),
    _ => Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: .3)),
        ),
        child: Center(
          child: Text(
            '$mark',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(
              child: Text(
                '$mark',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(
              label!,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AvgBadge extends StatelessWidget {
  const _AvgBadge({required this.avg});
  final double avg;

  @override
  Widget build(BuildContext context) {
    if (avg == 0) return const Text('—', style: TextStyle(color: Colors.grey));
    final color = avg >= 4.5
        ? const Color(0xFF10B981)
        : avg >= 3.5
        ? const Color(0xFF3B82F6)
        : avg >= 2.5
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Text(
        avg.toStringAsFixed(1),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: .3),
          ),
          const SizedBox(height: 16),
          Text(
            'Нет данных для отображения',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Выберите группу или добавьте оценки через раздел «Успеваемость»',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: .7),
            ),
          ),
        ],
      ),
    );
  }
}