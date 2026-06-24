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
  DateTime? _birthDate;
  int? _groupId;
  List<Map<String, dynamic>> _groups = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _fioController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isStudent) {
      setState(() => _loading = false);
      return;
    }
    try {
      final groups = await context.read<AcademicService>().list('/groups');
      setState(() {
        _groups = groups;
        _groupId = groups.isNotEmpty ? groups.first['id'] as int : null;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Не удалось загрузить список групп';
        _loading = false;
      });
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (selected != null) setState(() => _birthDate = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    if (auth.isStudent && _birthDate == null) {
      setState(() => _error = 'Укажите дату рождения');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AcademicService>().setupProfile({
        'fio': _fioController.text.trim(),
        if (auth.isStudent) ...{
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
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _fioController,
                            decoration: const InputDecoration(labelText: 'ФИО'),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Введите ФИО'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          if (auth.isStudent) ...[
                            DropdownButtonFormField<int>(
                              initialValue:
                                  _groups.any((g) => g['id'] == _groupId)
                                  ? _groupId
                                  : null,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Группа',
                              ),
                              items: _groups
                                  .map(
                                    (g) => DropdownMenuItem<int>(
                                      value: g['id'] as int,
                                      child: Text('${g['name']}'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _groupId = v),
                              validator: (v) =>
                                  v == null ? 'Выберите группу' : null,
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: _pickBirthDate,
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text(
                                _birthDate == null
                                    ? 'Дата рождения'
                                    : DateFormat(
                                        'dd.MM.yyyy',
                                      ).format(_birthDate!),
                              ),
                            ),
                          ],
                          if (auth.isTeacher)
                            TextFormField(
                              controller: _positionController,
                              decoration: const InputDecoration(
                                labelText: 'Должность',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Введите должность'
                                  : null,
                            ),
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
