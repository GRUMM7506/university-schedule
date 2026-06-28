import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/academic_service.dart';
import '../widgets/glass.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fioController = TextEditingController();
  final _positionController = TextEditingController(text: 'Преподаватель');
  final _birthDateController = TextEditingController();
  DateTime? _birthDate;

  int? _facultyId;
  int? _specialityId;
  int? _course;
  int? _groupId;

  List<Map<String, dynamic>> _faculties = [];
  List<Map<String, dynamic>> _specialities = [];

  /// Все группы выбранной специальности (загружаются при смене специальности)
  List<Map<String, dynamic>> _allGroups = [];

  static const List<int> _courses = [1, 2, 3, 4];

  bool _loading = true;
  bool _saving = false;
  String? _error;

  // ── Computed ───────────────────────────────────────────────────────────────

  /// Группы, отфильтрованные по выбранному курсу.
  /// Если курс не выбран — все группы специальности.
  List<Map<String, dynamic>> get _filteredGroups {
    if (_course == null) return _allGroups;
    return _allGroups
        .where((g) => g['course'] == _course)
        .toList();
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _fioController.dispose();
    _positionController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isStudent) {
      setState(() => _loading = false);
      return;
    }
    try {
      final faculties =
          await context.read<AcademicService>().list('/faculties');
      setState(() {
        _faculties = faculties;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Не удалось загрузить список факультетов';
        _loading = false;
      });
    }
  }

  // ── Cascade handlers ───────────────────────────────────────────────────────

  Future<void> _onFacultyChanged(int? facultyId) async {
    setState(() {
      _facultyId = facultyId;
      _specialityId = null;
      _specialities = [];
      _course = null;
      _groupId = null;
      _allGroups = [];
    });
    if (facultyId == null) return;
    try {
      final all = await context.read<AcademicService>().list('/specialities');
      setState(() {
        _specialities =
            all.where((s) => s['faculty_id'] == facultyId).toList();
      });
    } catch (_) {
      setState(() => _error = 'Не удалось загрузить направления');
    }
  }

  Future<void> _onSpecialityChanged(int? specialityId) async {
    setState(() {
      _specialityId = specialityId;
      _course = null;
      _groupId = null;
      _allGroups = [];
    });
    if (specialityId == null) return;
    try {
      final all = await context.read<AcademicService>().list('/groups');
      setState(() {
        _allGroups =
            all.where((g) => g['speciality_id'] == specialityId).toList();
        // Курс ещё не выбран — автовыбор невозможен, но сбрасываем на всякий
        _groupId = null;
      });
    } catch (_) {
      setState(() => _error = 'Не удалось загрузить группы');
    }
  }

  void _onCourseChanged(int? course) {
    setState(() {
      _course = course;
      _groupId = null;
    });
    if (course == null) return;
    // Автовыбор группы, если после фильтра осталась ровно одна
    final available = _filteredGroups;
    if (available.length == 1) {
      setState(() => _groupId = available.first['id'] as int);
    }
  }

  // ── Date picker ────────────────────────────────────────────────────────────

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (selected != null) {
      setState(() {
        _birthDate = selected;
        _birthDateController.text = DateFormat('dd.MM.yyyy').format(selected);
      });
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    if (auth.isStudent) {
      if (_birthDate == null && _birthDateController.text.trim().isNotEmpty) {
        try {
          _birthDate = DateFormat('dd.MM.yyyy')
              .parseStrict(_birthDateController.text.trim());
        } catch (_) {}
      }
      if (_birthDate == null) {
        setState(() => _error = 'Укажите дату рождения');
        return;
      }
      if (_facultyId == null ||
          _specialityId == null ||
          _course == null ||
          _groupId == null) {
        setState(
          () => _error = 'Выберите факультет, направление, курс и группу',
        );
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AcademicService>().setupProfile({
        'fio': _fioController.text.trim(),
        if (auth.isStudent) ...{
          'faculty_id': _facultyId,
          'speciality_id': _specialityId,
          'course': _course,
          'group_id': _groupId,
          'birth_date': DateFormat('yyyy-MM-dd').format(_birthDate!),
        },
        if (auth.isTeacher) 'position': _positionController.text.trim(),
      });
      await auth.refreshMe();
      if (!mounted) return;
      context.go(auth.isStudent ? '/portal' : '/');
    } on DioException catch (e) {
      final detail = e.response?.data is Map
          ? e.response?.data['detail']?.toString()
          : null;
      setState(() => _error = detail ?? 'Не удалось сохранить профиль');
    } catch (_) {
      setState(() => _error = 'Не удалось сохранить профиль');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: GlassPanel(
              padding: const EdgeInsets.all(24),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.account_circle_outlined,
                            size: 52,
                            color: scheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Настройка профиля',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 24),

                          // ── ФИО ──────────────────────────────────────────
                          TextFormField(
                            controller: _fioController,
                            decoration:
                                const InputDecoration(labelText: 'ФИО'),
                            validator: (v) =>
                                v == null || v.trim().isEmpty
                                    ? 'Введите ФИО'
                                    : null,
                          ),
                          const SizedBox(height: 14),

                          // ── Студент: каскадный выбор ──────────────────────
                          if (auth.isStudent) ...[
                            // Факультет
                            DropdownButtonFormField<int>(
                              initialValue:
                                  _faculties.any((f) => f['id'] == _facultyId)
                                  ? _facultyId
                                  : null,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Факультет',
                              ),
                              items: _faculties
                                  .map(
                                    (f) => DropdownMenuItem<int>(
                                      value: f['id'] as int,
                                      child: Text('${f['name']}'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _onFacultyChanged,
                              validator: (v) =>
                                  v == null ? 'Выберите факультет' : null,
                            ),
                            const SizedBox(height: 14),

                            // Направление — пересоздаём при смене факультета
                            DropdownButtonFormField<int>(
                              key: ValueKey(_facultyId),
                              initialValue:
                                  _specialities.any(
                                    (s) => s['id'] == _specialityId,
                                  )
                                  ? _specialityId
                                  : null,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Направление',
                              ),
                              items: _specialities
                                  .map(
                                    (s) => DropdownMenuItem<int>(
                                      value: s['id'] as int,
                                      child: Text('${s['name']}'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _onSpecialityChanged,
                              validator: (v) =>
                                  v == null ? 'Выберите направление' : null,
                            ),
                            const SizedBox(height: 14),

                            // Курс — пересоздаём при смене специальности.
                            // Выбирается до группы, чтобы сузить список групп.
                            DropdownButtonFormField<int>(
                              key: ValueKey(_specialityId),
                              initialValue: _course,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Курс',
                              ),
                              items: _courses
                                  .map(
                                    (c) => DropdownMenuItem<int>(
                                      value: c,
                                      child: Text('$c курс'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _onCourseChanged,
                              validator: (v) =>
                                  v == null ? 'Выберите курс' : null,
                            ),
                            const SizedBox(height: 14),

                            // Группа — фильтруется по специальности + курсу.
                            // Пересоздаём при каждом изменении любого из них.
                            DropdownButtonFormField<int>(
                              key: ValueKey('${_specialityId}_$_course'),
                              initialValue:
                                  _filteredGroups.any(
                                    (g) => g['id'] == _groupId,
                                  )
                                  ? _groupId
                                  : null,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Группа',
                                // Подсказка: сколько групп доступно
                                helperText: _specialityId != null &&
                                        _course != null &&
                                        _filteredGroups.isEmpty
                                    ? 'Нет групп для выбранного курса'
                                    : null,
                                helperStyle: TextStyle(color: scheme.error),
                              ),
                              items: _filteredGroups
                                  .map(
                                    (g) => DropdownMenuItem<int>(
                                      value: g['id'] as int,
                                      child: Text('${g['name']}'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _groupId = v),
                              validator: (v) =>
                                  v == null ? 'Выберите группу' : null,
                            ),
                            const SizedBox(height: 14),

                            // Дата рождения
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _birthDateController,
                                    decoration: const InputDecoration(
                                      labelText: 'Дата рождения',
                                      hintText: 'дд.мм.гггг',
                                    ),
                                    keyboardType: TextInputType.datetime,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Укажите дату рождения';
                                      }
                                      try {
                                        DateFormat('dd.MM.yyyy')
                                            .parseStrict(v.trim());
                                        return null;
                                      } catch (_) {
                                        return 'Формат даты: дд.мм.гггг';
                                      }
                                    },
                                    onChanged: (value) {
                                      final trimmed = value.trim();
                                      if (trimmed.isEmpty) {
                                        setState(() => _birthDate = null);
                                        return;
                                      }
                                      try {
                                        setState(
                                          () => _birthDate = DateFormat(
                                            'dd.MM.yyyy',
                                          ).parseStrict(trimmed),
                                        );
                                      } catch (_) {
                                        setState(() => _birthDate = null);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: _pickBirthDate,
                                  child: const Icon(
                                    Icons.calendar_today_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // ── Преподаватель ─────────────────────────────────
                          if (auth.isTeacher)
                            TextFormField(
                              controller: _positionController,
                              decoration: const InputDecoration(
                                labelText: 'Должность',
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? 'Введите должность'
                                      : null,
                            ),

                          // ── Ошибка ────────────────────────────────────────
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              _error!,
                              style: TextStyle(color: scheme.error),
                              textAlign: TextAlign.center,
                            ),
                          ],

                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: const Text('Сохранить'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _saving ? null : auth.logout,
                            child: const Text('Выйти'),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}