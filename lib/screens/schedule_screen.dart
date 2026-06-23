import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/entities.dart';
import '../services/academic_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int? groupId;
  int? teacherId;
  int? weekId;
  List<Map<String, dynamic>> groups = [];
  List<Map<String, dynamic>> teachers = [];
  List<Map<String, dynamic>> weeks = [];
  List<Map<String, dynamic>> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadRefs();
      }
    });
  }

  Future<void> _loadRefs() async {
    final service = context.read<AcademicService>();
    groups = await service.list('/groups');
    teachers = await service.list('/teachers');
    weeks = await service.list('/study-weeks');
    if (groups.isNotEmpty) {
      groupId = groups.first['id'] as int;
    }
    if (weeks.isNotEmpty) {
      weekId = weeks.first['id'] as int;
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final service = context.read<AcademicService>();
    items = teacherId != null
        ? await service.teacherSchedule(teacherId!, weekId: weekId)
        : await service.groupSchedule(groupId ?? 0, weekId: weekId);
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Расписание', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _dropdown(
              'Группа',
              groupId,
              groups,
              (value) => setState(() {
                groupId = value;
                teacherId = null;
              }),
            ),
            _dropdown(
              'Преподаватель',
              teacherId,
              teachers,
              (value) => setState(() {
                teacherId = value;
                groupId = null;
              }),
            ),
            _dropdown(
              'Неделя',
              weekId,
              weeks,
              (value) => setState(() => weekId = value),
            ),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.filter_alt_outlined),
              label: const Text('Показать'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else
          for (final day in const [1, 2, 3, 4, 5, 6]) _dayBlock(day),
      ],
    );
  }

  Widget _dropdown(
    String label,
    int? value,
    List<Map<String, dynamic>> data,
    ValueChanged<int?> onChanged,
  ) {
    return SizedBox(
      width: 260,
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
                child: Text('${e['name'] ?? e['fio']}'),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _dayBlock(int day) {
    final names = [
      '',
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота',
    ];
    final dayItems = items.where((e) => e['day_num'] == day).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(names[day], style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (dayItems.isEmpty)
            const Text('Нет занятий')
          else
            for (final item in dayItems)
              ListTile(
                leading: CircleAvatar(child: Text('${item['pair_num']}')),
                title: Text('${item['subject']}'),
                subtitle: Text(
                  '${item['teacher']} | ауд. ${item['classroom']} | ${lessonTypes['${item['lesson_type']}']}',
                ),
              ),
        ],
      ),
    );
  }
}
