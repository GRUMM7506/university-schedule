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
  int? studentId;
  int? disciplineId;
  int? teacherId;
  int mark = 5;
  int controlType = 1;
  int tourNum = 1;
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> disciplines = [];
  List<Map<String, dynamic>> teachers = [];

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
    students = await service.list('/students');
    disciplines = await service.list('/disciplines');
    teachers = await service.list('/teachers');
    studentId ??= students.isEmpty ? null : students.first['id'] as int;
    disciplineId ??= disciplines.isEmpty
        ? null
        : disciplines.first['id'] as int;
    teacherId ??= teachers.isEmpty ? null : teachers.first['id'] as int;
    setState(() {});
  }

  Future<void> _save() async {
    await context.read<AcademicService>().savePerformance({
      'student_id': studentId,
      'discipline_id': disciplineId,
      'teacher_id': teacherId,
      'control_type': controlType,
      'tour_num': tourNum,
      'mark': mark,
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Оценка сохранена')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Успеваемость', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _dropdown(
              'Студент',
              studentId,
              students,
              'fio',
              (v) => setState(() => studentId = v),
            ),
            _dropdown(
              'Дисциплина',
              disciplineId,
              disciplines,
              'id',
              (v) => setState(() => disciplineId = v),
            ),
            _dropdown(
              'Преподаватель',
              teacherId,
              teachers,
              'fio',
              (v) => setState(() => teacherId = v),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<int>(
                initialValue: controlType,
                decoration: const InputDecoration(
                  labelText: 'Контроль',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Зачет')),
                  DropdownMenuItem(value: 1, child: Text('Экзамен')),
                ],
                onChanged: (v) => setState(() => controlType = v ?? 1),
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<int>(
                initialValue: tourNum,
                decoration: const InputDecoration(
                  labelText: 'Тур',
                  border: OutlineInputBorder(),
                ),
                items: [1, 2, 3, 4]
                    .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                    .toList(),
                onChanged: (v) => setState(() => tourNum = v ?? 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SegmentedButton<int>(
          segments: performanceMarks.entries
              .map(
                (e) => ButtonSegment(
                  value: int.parse(e.key),
                  label: Text(e.value),
                ),
              )
              .toList(),
          selected: {mark},
          onSelectionChanged: (value) => setState(() => mark = value.first),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Сохранить'),
          ),
        ),
      ],
    );
  }

  Widget _dropdown(
    String label,
    int? value,
    List<Map<String, dynamic>> data,
    String display,
    ValueChanged<int?> onChanged,
  ) {
    return SizedBox(
      width: 280,
      child: DropdownButtonFormField<int>(
        initialValue: data.any((e) => e['id'] == value) ? value : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: data
            .map(
              (e) => DropdownMenuItem<int>(
                value: e['id'] as int,
                child: Text(
                  display == 'id' ? 'Дисциплина #${e['id']}' : '${e[display]}',
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
