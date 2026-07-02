import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/entities.dart';
import '../services/academic_service.dart';
import '../widgets/glass.dart';

/// "Which classroom is free" screen: for a chosen week/day, shows every
/// classroom against every pair, and can also narrow down to a single pair
/// to answer "what's free right now" directly. Reachable from the schedule
/// screen and from the sidebar.
class ClassroomOccupancyScreen extends StatefulWidget {
  const ClassroomOccupancyScreen({super.key});

  @override
  State<ClassroomOccupancyScreen> createState() => _ClassroomOccupancyScreenState();
}

enum _ViewMode { grid, singlePair }

enum _RoomFilter { all, free, occupied }

class _ClassroomOccupancyScreenState extends State<ClassroomOccupancyScreen> {
  static const _dayNames = {
    1: 'Понедельник',
    2: 'Вторник',
    3: 'Среда',
    4: 'Четверг',
    5: 'Пятница',
    6: 'Суббота',
  };
  static const _pairTimes = {
    1: '08:00–09:30',
    2: '09:45–11:15',
    3: '11:30–13:00',
    4: '14:00–15:30',
    5: '15:45–17:15',
  };

  bool _loading = true;
  List<Map<String, dynamic>> _weeks = [];
  List<Map<String, dynamic>> _occupancy = [];

  int? _weekId;
  int _dayNum = DateTime.now().weekday.clamp(1, 6);
  int _pairNum = 1;
  String _search = '';
  _ViewMode _mode = _ViewMode.grid;
  _RoomFilter _filter = _RoomFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final service = context.read<AcademicService>();
      final weeks = await service.list('/study-weeks');
      _weekId ??= _currentOrFirstWeek(weeks);
      final occupancy = _weekId == null
          ? <Map<String, dynamic>>[]
          : await service.classroomsOccupancy(weekId: _weekId!, dayNum: _dayNum);
      if (!mounted) return;
      setState(() {
        _weeks = weeks;
        _occupancy = occupancy;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
    }
  }

  int? _currentOrFirstWeek(List<Map<String, dynamic>> weeks) {
    if (weeks.isEmpty) return null;
    final today = DateTime.now();
    for (final w in weeks) {
      final start = DateTime.tryParse('${w['start_date']}');
      final end = DateTime.tryParse('${w['end_date']}');
      if (start != null && end != null && !today.isBefore(start) && !today.isAfter(end)) {
        return w['id'] as int;
      }
    }
    return weeks.first['id'] as int;
  }

  Future<void> _reload() async {
    if (_weekId == null) return;
    try {
      final service = context.read<AcademicService>();
      final occupancy = await service.classroomsOccupancy(weekId: _weekId!, dayNum: _dayNum);
      if (mounted) setState(() => _occupancy = occupancy);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
    }
  }

  List<Map<String, dynamic>> get _filteredRooms {
    final query = _search.trim().toLowerCase();
    var rooms = _occupancy;
    if (query.isNotEmpty) {
      rooms = rooms
          .where((r) =>
              '${r['number']}'.toLowerCase().contains(query) ||
              '${r['type'] ?? ''}'.toLowerCase().contains(query))
          .toList();
    }
    if (_mode == _ViewMode.singlePair && _filter != _RoomFilter.all) {
      rooms = rooms.where((r) {
        final pairs = Map<String, dynamic>.from(r['pairs'] as Map? ?? {});
        final busy = pairs.containsKey('$_pairNum');
        return _filter == _RoomFilter.free ? !busy : busy;
      }).toList();
    }
    return rooms;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Занятость аудиторий', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              IconButton.filled(
                tooltip: 'Обновить',
                onPressed: _loading ? null : _reload,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Кто и когда занимает аудитории — удобно для быстрого поиска свободного кабинета',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _buildFilters(context),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : GlassPanel(
                    padding: const EdgeInsets.all(12),
                    child: _mode == _ViewMode.grid ? _buildGrid(context) : _buildSinglePair(context),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<int>(
            initialValue: _weeks.any((w) => w['id'] == _weekId) ? _weekId : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Учебная неделя', isDense: true),
            items: _weeks
                .map((w) => DropdownMenuItem<int>(value: w['id'] as int, child: Text('${w['name']}')))
                .toList(),
            onChanged: (v) {
              setState(() => _weekId = v);
              _reload();
            },
          ),
        ),
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<int>(
            initialValue: _dayNum,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'День', isDense: true),
            items: _dayNames.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) {
              setState(() => _dayNum = v ?? _dayNum);
              _reload();
            },
          ),
        ),
        SizedBox(
          width: 220,
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Поиск аудитории',
              hintText: 'Номер или тип, напр. 305 или лаборатория',
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 18),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        SegmentedButton<_ViewMode>(
          segments: const [
            ButtonSegment(value: _ViewMode.grid, label: Text('Сетка на день'), icon: Icon(Icons.grid_view_outlined)),
            ButtonSegment(value: _ViewMode.singlePair, label: Text('По паре'), icon: Icon(Icons.filter_1_outlined)),
          ],
          selected: {_mode},
          onSelectionChanged: (v) => setState(() => _mode = v.first),
        ),
        if (_mode == _ViewMode.singlePair) ...[
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<int>(
              initialValue: _pairNum,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Пара', isDense: true),
              items: _pairTimes.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text('${e.key} пара · ${e.value}')))
                  .toList(),
              onChanged: (v) => setState(() => _pairNum = v ?? _pairNum),
            ),
          ),
          SegmentedButton<_RoomFilter>(
            segments: const [
              ButtonSegment(value: _RoomFilter.all, label: Text('Все')),
              ButtonSegment(value: _RoomFilter.free, label: Text('Свободные')),
              ButtonSegment(value: _RoomFilter.occupied, label: Text('Занятые')),
            ],
            selected: {_filter},
            onSelectionChanged: (v) => setState(() => _filter = v.first),
          ),
        ],
      ],
    );
  }

  Widget _buildGrid(BuildContext context) {
    final rooms = _filteredRooms;
    if (rooms.isEmpty) {
      return const Center(child: Text('Аудитории не найдены'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 10,
        headingRowHeight: 40,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 64,
        columns: [
          const DataColumn(label: Text('Аудитория', style: TextStyle(fontWeight: FontWeight.w700))),
          for (final p in _pairTimes.keys)
            DataColumn(
              label: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$p пара', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(_pairTimes[p]!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
        ],
        rows: rooms.map((room) {
          final pairs = Map<String, dynamic>.from(room['pairs'] as Map? ?? {});
          return DataRow(
            cells: [
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${room['number']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (room['type'] != null) ...[
                      const SizedBox(width: 6),
                      Text(classroomTypes[room['type']] ?? '${room['type']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
              for (final p in _pairTimes.keys) DataCell(_gridCell(pairs['$p'] as Map?)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _gridCell(Map? booking) {
    if (booking == null) {
      return Container(
        width: 130,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: .1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: .25)),
        ),
        child: const Text(
          'Свободна',
          style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w700, fontSize: 12),
        ),
      );
    }
    return Tooltip(
      message: '${booking['subject'] ?? ''}\n${booking['teacher'] ?? ''}\nгр. ${booking['group'] ?? ''}',
      child: Container(
        width: 130,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: .1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: .25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${booking['subject'] ?? '—'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 12),
            ),
            Text(
              'гр. ${booking['group'] ?? '—'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSinglePair(BuildContext context) {
    final rooms = _filteredRooms;
    final free = rooms.where((r) => !Map<String, dynamic>.from(r['pairs'] as Map? ?? {}).containsKey('$_pairNum')).toList();
    final occupied = rooms.where((r) => Map<String, dynamic>.from(r['pairs'] as Map? ?? {}).containsKey('$_pairNum')).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_filter != _RoomFilter.occupied) ...[
            _sectionHeader('Свободны (${free.length})', const Color(0xFF10B981)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: free.map((r) => _roomChip(r, free: true)).toList(),
            ),
            const SizedBox(height: 20),
          ],
          if (_filter != _RoomFilter.free) ...[
            _sectionHeader('Заняты (${occupied.length})', const Color(0xFFEF4444)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: occupied.map((r) => _roomChip(r, free: false)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String text, Color color) => Row(
        children: [
          Container(width: 4, height: 16, color: color),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ],
      );

  Widget _roomChip(Map<String, dynamic> room, {required bool free}) {
    final pairs = Map<String, dynamic>.from(room['pairs'] as Map? ?? {});
    final booking = pairs['$_pairNum'] as Map?;
    final color = free ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      width: 210,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(free ? Icons.meeting_room_outlined : Icons.meeting_room, size: 16, color: color),
              const SizedBox(width: 6),
              Text('${room['number']}', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
              if (room['type'] != null) ...[
                const SizedBox(width: 6),
                Text(classroomTypes[room['type']] ?? '${room['type']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ],
          ),
          if (booking != null) ...[
            const SizedBox(height: 6),
            Text('${booking['subject'] ?? '—'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text('${booking['teacher'] ?? ''} · гр. ${booking['group'] ?? ''}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ],
      ),
    );
  }
}
