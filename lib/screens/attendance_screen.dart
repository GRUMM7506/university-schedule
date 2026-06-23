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
  int pairNum = 1;
  DateTime day = DateTime.now();
  List<Map<String, dynamic>> groups = [];
  List<Map<String, dynamic>> students = [];
  final marks = <int, int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _load();
      }
    });
  }

  Future<void> _load() async {
    final service = context.read<AcademicService>();
    groups = await service.list('/groups');
    final allStudents = await service.list('/students');
    groupId ??= groups.isEmpty ? null : groups.first['id'] as int;
    students = allStudents.where((s) => s['group_id'] == groupId).toList();
    for (final student in students) {
      marks.putIfAbsent(student['id'] as int, () => 2);
    }
    setState(() {});
  }

  Future<void> _save() async {
    final service = context.read<AcademicService>();
    final date = DateFormat('yyyy-MM-dd').format(day);
    await service.saveAttendance([
      for (final student in students)
        {
          'student_id': student['id'],
          'day_date': date,
          'pair_num': pairNum,
          'mark': marks[student['id']] ?? 2,
        },
    ]);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Посещаемость сохранена')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Посещаемость', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<int>(
                initialValue: groupId,
                decoration: const InputDecoration(
                  labelText: 'Группа',
                  border: OutlineInputBorder(),
                ),
                items: groups
                    .map(
                      (g) => DropdownMenuItem<int>(
                        value: g['id'] as int,
                        child: Text('${g['name']}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  groupId = value;
                  _load();
                },
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<int>(
                initialValue: pairNum,
                decoration: const InputDecoration(
                  labelText: 'Пара',
                  border: OutlineInputBorder(),
                ),
                items: [1, 2, 3, 4, 5, 6]
                    .map(
                      (e) => DropdownMenuItem(value: e, child: Text('$e пара')),
                    )
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
                if (picked != null) {
                  setState(() => day = picked);
                }
              },
              icon: const Icon(Icons.today),
              label: Text(DateFormat('dd.MM.yyyy').format(day)),
            ),
            FilledButton.icon(
              onPressed: students.isEmpty ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Сохранить'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (students.isEmpty)
          const Center(child: Text('Нет студентов'))
        else
          for (final student in students)
            ListTile(
              title: Text('${student['fio']}'),
              subtitle: Text('${student['email']}'),
              trailing: SegmentedButton<int>(
                segments: attendanceMarks.entries
                    .map(
                      (e) => ButtonSegment(
                        value: int.parse(e.key),
                        label: Text(e.value),
                      ),
                    )
                    .toList(),
                selected: {marks[student['id']] ?? 2},
                onSelectionChanged: (value) =>
                    setState(() => marks[student['id'] as int] = value.first),
              ),
            ),
      ],
    );
  }
}
