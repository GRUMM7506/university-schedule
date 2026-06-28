import 'package:flutter/material.dart';
import '../services/academic_service.dart';

class GroupPicker extends StatefulWidget {
  const GroupPicker({
    super.key,
    required this.academicService,
    required this.onChanged,
    this.initialGroupId,
    this.required = false,
  });

  final AcademicService academicService;
  final ValueChanged<int?> onChanged;
  final int? initialGroupId;
  final bool required;

  @override
  State<GroupPicker> createState() => _GroupPickerState();
}

class _GroupPickerState extends State<GroupPicker> {
  List<Map<String, dynamic>> _faculties = [];
  List<Map<String, dynamic>> _specialities = [];
  List<Map<String, dynamic>> _groups = [];
  int? _facultyId;
  int? _specialityId;
  int? _groupId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        widget.academicService.list('/faculties'),
        widget.academicService.list('/specialities'),
        widget.academicService.list('/groups'),
      ]);
      if (!mounted) return;
      setState(() {
        _faculties = results[0];
        _specialities = results[1];
        _groups = results[2];
        _resolveInitial();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _resolveInitial() {
    if (widget.initialGroupId != null) {
      final group = _groups.firstWhere(
        (g) => g['id'] == widget.initialGroupId,
        orElse: () => const {},
      );
      if (group.isNotEmpty) {
        final specId = group['speciality_id'] as int?;
        if (specId != null) {
          _specialityId = specId;
          final spec = _specialities.firstWhere(
            (s) => s['id'] == specId,
            orElse: () => const {},
          );
          if (spec.isNotEmpty) {
            _facultyId = spec['faculty_id'] as int?;
          }
        }
        _groupId = widget.initialGroupId;
        widget.onChanged(_groupId);
        return;
      }
    }

    if (_groups.isNotEmpty) {
      _groupId = _groups.first['id'] as int;
      final specId = _groups.first['speciality_id'] as int?;
      if (specId != null) {
        _specialityId = specId;
        final spec = _specialities.firstWhere(
          (s) => s['id'] == specId,
          orElse: () => const {},
        );
        if (spec.isNotEmpty) {
          _facultyId = spec['faculty_id'] as int?;
        }
      }
      widget.onChanged(_groupId);
    } else {
      widget.onChanged(null);
    }
  }

  List<Map<String, dynamic>> get _filteredSpecialities {
    if (_facultyId == null) return _specialities;
    return _specialities.where((s) => s['faculty_id'] == _facultyId).toList();
  }

  List<Map<String, dynamic>> get _filteredGroups {
    if (_specialityId == null) return _groups;
    return _groups.where((g) => g['speciality_id'] == _specialityId).toList();
  }

  void _onFacultyChanged(int? value) {
    setState(() {
      _facultyId = value;
      _specialityId = null;
      _groupId = null;
    });

    final filteredSpecs = _filteredSpecialities;
    if (filteredSpecs.isNotEmpty) {
      setState(() => _specialityId = filteredSpecs.first['id'] as int);
      final filteredGroups = _filteredGroups;
      if (filteredGroups.isNotEmpty) {
        setState(() => _groupId = filteredGroups.first['id'] as int);
        widget.onChanged(_groupId);
      } else {
        widget.onChanged(null);
      }
    } else {
      widget.onChanged(null);
    }
  }

  void _onSpecialityChanged(int? value) {
    setState(() {
      _specialityId = value;
      _groupId = null;
    });

    final filteredGroups = _filteredGroups;
    if (filteredGroups.isNotEmpty) {
      setState(() => _groupId = filteredGroups.first['id'] as int);
      widget.onChanged(_groupId);
    } else {
      widget.onChanged(null);
    }
  }

  void _onGroupChanged(int? value) {
    setState(() => _groupId = value);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Row(
        children: [
          Expanded(child: _DropdownSkeleton(label: 'Факультет')),
          const SizedBox(width: 8),
          Expanded(child: _DropdownSkeleton(label: 'Направление')),
          const SizedBox(width: 8),
          Expanded(child: _DropdownSkeleton(label: 'Группа')),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _Dropdown(
            label: 'Факультет',
            value: _facultyId,
            items: _faculties,
            onChanged: _onFacultyChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Dropdown(
            label: 'Направление',
            value: _specialityId,
            items: _filteredSpecialities,
            onChanged: _onSpecialityChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Dropdown(
            label: 'Группа',
            value: _groupId,
            items: _filteredGroups,
            onChanged: _onGroupChanged,
            validator: widget.required
                ? (v) => v == null ? 'Выберите группу' : null
                : null,
          ),
        ),
      ],
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final int? value;
  final List<Map<String, dynamic>> items;
  final ValueChanged<int?> onChanged;
  final FormFieldValidator<int?>? validator;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        border: const OutlineInputBorder(),
      ),
      // ignore: deprecated_member_use
      value: items.any((e) => e['id'] == value) ? value : null,
      items: items
          .map(
            (e) => DropdownMenuItem<int>(
              value: e['id'] as int,
              child: Text(
                '${e['name']}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (v) => onChanged(v),
      validator: validator,
    );
  }
}

class _DropdownSkeleton extends StatelessWidget {
  const _DropdownSkeleton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
