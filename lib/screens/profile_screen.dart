import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/academic_service.dart';
import '../widgets/glass.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profileData;
  bool _loading = true;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final service = context.read<AcademicService>();
    try {
      if (auth.isStudent && auth.linkedId != null) {
        // Use dashboard for stats + getEntity for phone/address
        final dashboard = await service.studentDashboard(auth.linkedId!);
        final entity = await service.getEntity('/students', auth.linkedId!);
        _profileData = {...dashboard, ...entity};
      } else if (auth.isTeacher && auth.linkedId != null) {
        final dashboard = await service.teacherDashboard(auth.linkedId!);
        final entity = await service.getEntity('/teachers', auth.linkedId!);
        _profileData = {...dashboard, ...entity};
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _startEditing() => setState(() => _editing = true);

  void _cancelEditing() => setState(() => _editing = false);

  Future<void> _onSaved() async {
    setState(() => _editing = false);
    await _load(); // Refresh data
    if (mounted) {
      final auth = context.read<AuthProvider>();
      await auth.refreshMe(); // Update FIO in app bar
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (_editing) {
      return _ProfileEditView(
        profileData: _profileData,
        onSaved: _onSaved,
        onCancel: _cancelEditing,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Header card
        GlassPanel(
          padding: const EdgeInsets.all(28),
          child: Row(
            children: [
              _AvatarWidget(
                username: auth.username ?? '',
                role: auth.role ?? '',
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profileData?['fio'] ??
                          auth.fio ??
                          auth.username ??
                          'Пользователь',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    _RoleChip(role: auth.role ?? ''),
                    const SizedBox(height: 12),
                    if (auth.isTeacher && _profileData?['position'] != null)
                      _InfoRow(
                        Icons.work_outline,
                        '${_profileData!['position']}',
                      ),
                    _InfoRow(Icons.person_outline, 'Логин: ${auth.username}'),
                    if (_profileData?['phone'] != null &&
                        '${_profileData!['phone']}'.isNotEmpty)
                      _InfoRow(
                        Icons.phone_outlined,
                        '${_profileData!['phone']}',
                      ),
                    if (_profileData?['address'] != null &&
                        '${_profileData!['address']}'.isNotEmpty)
                      _InfoRow(
                        Icons.location_on_outlined,
                        '${_profileData!['address']}',
                      ),
                  ],
                ),
              ),
              // Edit button (only for Student/Teacher)
              if (!auth.isAdmin && _profileData != null)
                IconButton.filledTonal(
                  onPressed: _startEditing,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Редактировать профиль',
                ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () => _showChangePasswordDialog(context),
                icon: const Icon(Icons.lock_outline),
                tooltip: 'Сменить пароль',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_profileData != null) ...[
          if (auth.isStudent) _StudentStats(data: _profileData!),
          if (auth.isTeacher) _TeacherStats(data: _profileData!),
        ] else if (auth.isAdmin)
          _AdminProfileInfo(username: auth.username ?? ''),
      ],
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    await showDialog<void>(
      context: context,
      builder: (_) => _ChangePasswordDialog(auth: auth),
    );
  }
}

// ─── Change Password Dialog ────────────────────────────────────────────────

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.auth});

  final AuthProvider auth;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _saving = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _oldPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.auth.changePassword(
        oldPassword: _oldPasswordCtrl.text,
        newPassword: _newPasswordCtrl.text,
      );
      if (!mounted) return;
      setState(() => _success = true);
    } on DioException catch (e) {
      final detail = e.response?.data is Map
          ? e.response?.data['detail']?.toString()
          : null;
      setState(
        () => _error = detail ?? 'Не удалось изменить пароль',
      );
    } catch (_) {
      setState(() => _error = 'Не удалось изменить пароль');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_success) {
      return AlertDialog(
        icon: Icon(Icons.check_circle_outline, color: scheme.primary, size: 36),
        title: const Text('Пароль изменён'),
        content: const Text(
          'Ваш пароль успешно обновлён. Используйте его при следующем входе.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Готово'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Смена пароля'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _oldPasswordCtrl,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Текущий пароль',
                  prefixIcon: Icon(Icons.lock_outline, color: scheme.primary),
                ),
                validator: (v) => v == null || v.isEmpty
                    ? 'Введите текущий пароль'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _newPasswordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Новый пароль',
                  prefixIcon:
                      Icon(Icons.lock_reset_outlined, color: scheme.primary),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Введите новый пароль';
                  if (v.length < 6) {
                    return 'Минимум 6 символов';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmPasswordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Подтвердите новый пароль',
                  prefixIcon:
                      Icon(Icons.check_circle_outline, color: scheme.primary),
                ),
                validator: (v) {
                  if (v != _newPasswordCtrl.text) {
                    return 'Пароли не совпадают';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: .3),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: scheme.error.withValues(alpha: .4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: scheme.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: scheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Сохранить'),
        ),
      ],
    );
  }
}

// ─── Edit View ────────────────────────────────────────────────────────────────

class _ProfileEditView extends StatefulWidget {
  const _ProfileEditView({
    required this.profileData,
    required this.onSaved,
    required this.onCancel,
  });

  final Map<String, dynamic>? profileData;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  @override
  State<_ProfileEditView> createState() => _ProfileEditViewState();
}

class _ProfileEditViewState extends State<_ProfileEditView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fioCtrl;
  late final TextEditingController _positionCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  DateTime? _birthDate;
  int? _groupId;
  List<Map<String, dynamic>> _groups = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = widget.profileData;
    _fioCtrl = TextEditingController(text: d?['fio'] as String? ?? '');
    _positionCtrl =
        TextEditingController(text: d?['position'] as String? ?? '');
    _phoneCtrl = TextEditingController(text: d?['phone'] as String? ?? '');
    _addressCtrl = TextEditingController(text: d?['address'] as String? ?? '');
    if (d?['birth_date'] != null) {
      try {
        _birthDate = DateTime.parse('${d!['birth_date']}');
      } catch (_) {}
    }
    _groupId = d?['group_id'] as int?;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGroups());
  }

  @override
  void dispose() {
    _fioCtrl.dispose();
    _positionCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isStudent) return;
    try {
      final groups = await context.read<AcademicService>().list('/groups');
      setState(() {
        _groups = groups;
        // Set groupId from profileData if not already set
        if (_groupId == null && groups.isNotEmpty) {
          _groupId = groups.first['id'] as int;
        }
      });
    } catch (_) {}
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20, now.month, now.day),
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
      final payload = <String, dynamic>{
        'fio': _fioCtrl.text.trim(),
        if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
        if (_addressCtrl.text.trim().isNotEmpty)
          'address': _addressCtrl.text.trim(),
        if (auth.isTeacher && _positionCtrl.text.trim().isNotEmpty)
          'position': _positionCtrl.text.trim(),
        if (auth.isStudent && _groupId != null) 'group_id': _groupId,
        if (auth.isStudent && _birthDate != null)
          'birth_date': DateFormat('yyyy-MM-dd').format(_birthDate!),
      };
      await context.read<AcademicService>().updateProfile(payload);
      widget.onSaved();
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

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Header
        Row(
          children: [
            IconButton(
              onPressed: _saving ? null : widget.onCancel,
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              tooltip: 'Отмена',
            ),
            const SizedBox(width: 8),
            Text(
              'Редактирование профиля',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 20),

        GlassPanel(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─ FIO ─────────────────────────────────────────
                TextFormField(
                  controller: _fioCtrl,
                  decoration: InputDecoration(
                    labelText: 'ФИО',
                    prefixIcon: Icon(
                      Icons.badge_outlined,
                      color: scheme.primary,
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Введите ФИО' : null,
                ),
                const SizedBox(height: 16),

                // ─ Position (teacher only) ───────────────────
                if (auth.isTeacher) ...[
                  TextFormField(
                    controller: _positionCtrl,
                    decoration: InputDecoration(
                      labelText: 'Должность',
                      prefixIcon:
                          Icon(Icons.work_outline, color: scheme.primary),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Введите должность'
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],

                // ─ Group (student only) ─────────────────────
                if (auth.isStudent && _groups.isNotEmpty) ...[
                  DropdownButtonFormField<int>(
                    initialValue: _groups.any((g) => g['id'] == _groupId)
                        ? _groupId
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Группа',
                      prefixIcon:
                          Icon(Icons.group_outlined, color: scheme.primary),
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
                    validator: (v) => v == null ? 'Выберите группу' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                // ─ Birth date (student only) ─────────────────
                if (auth.isStudent) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                    ),
                    onPressed: _pickBirthDate,
                    icon: Icon(
                      Icons.calendar_today_outlined,
                      color: scheme.primary,
                      size: 20,
                    ),
                    label: Text(
                      _birthDate == null
                          ? 'Дата рождения'
                          : DateFormat('dd.MM.yyyy').format(_birthDate!),
                      style: TextStyle(
                        color: _birthDate == null
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ─ Phone ────────────────────────────────────
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Телефон',
                    hintText: '+7 (999) 000-00-00',
                    prefixIcon:
                        Icon(Icons.phone_outlined, color: scheme.primary),
                  ),
                ),
                const SizedBox(height: 16),

                // ─ Address ──────────────────────────────────
                TextFormField(
                  controller: _addressCtrl,
                  decoration: InputDecoration(
                    labelText: 'Адрес',
                    prefixIcon: Icon(
                      Icons.location_on_outlined,
                      color: scheme.primary,
                    ),
                  ),
                  maxLines: 2,
                ),

                // ─ Error ────────────────────────────────────
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer.withValues(alpha: .3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: scheme.error.withValues(alpha: .4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: scheme.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(color: scheme.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ─ Actions ──────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : widget.onCancel,
                        icon: const Icon(Icons.close),
                        label: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('Сохранить изменения'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

class _AvatarWidget extends StatelessWidget {
  const _AvatarWidget({required this.username, required this.role});
  final String username;
  final String role;

  Color get color => switch (role) {
        'Admin' => const Color(0xFFEF4444),
        'Teacher' => const Color(0xFFF59E0B),
        'Student' => const Color(0xFF10B981),
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: .6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 36,
          ),
        ),
      ),
    );
  }
}

// ─── Role chip ────────────────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (role) {
      'Admin' => (
          'Администратор',
          const Color(0xFFEF4444),
          Icons.shield_outlined,
        ),
      'Teacher' => (
          'Преподаватель',
          const Color(0xFFF59E0B),
          Icons.cast_for_education_outlined,
        ),
      'Student' => (
          'Студент',
          const Color(0xFF10B981),
          Icons.school_outlined,
        ),
      _ => ('Гость', Colors.grey, Icons.person_outlined),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

// ─── Student Stats ────────────────────────────────────────────────────────────

class _StudentStats extends StatelessWidget {
  const _StudentStats({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final attendanceRate = (data['attendance_rate'] as num?)?.toDouble() ?? 0.0;
    final avgMark = (data['avg_mark'] as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Моя статистика',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatWidget(
              label: 'Посещаемость',
              value: '${attendanceRate.toStringAsFixed(0)}%',
              icon: Icons.how_to_reg_outlined,
              color: attendanceRate >= 80
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              progress: attendanceRate / 100,
            ),
            _StatWidget(
              label: 'Средний балл',
              value: avgMark.toStringAsFixed(1),
              icon: Icons.grade_outlined,
              color: avgMark >= 4
                  ? const Color(0xFF10B981)
                  : avgMark >= 3
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFEF4444),
              progress: avgMark / 5,
            ),
            _StatWidget(
              label: 'Занятий посещено',
              value:
                  '${data['attendance_present']}/${data['attendance_total']}',
              icon: Icons.event_available_outlined,
              color: const Color(0xFF3B82F6),
              progress: data['attendance_total'] == 0
                  ? 0
                  : (data['attendance_present'] as num) /
                      (data['attendance_total'] as num),
            ),
            _StatWidget(
              label: 'Оценок получено',
              value: '${data['grades_count']}',
              icon: Icons.assignment_turned_in_outlined,
              color: const Color(0xFF8B5CF6),
              progress: 1.0,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatWidget extends StatelessWidget {
  const _StatWidget({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.progress,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: GlassPanel(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: color.withValues(alpha: .12),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Teacher Stats ────────────────────────────────────────────────────────────

class _TeacherStats extends StatelessWidget {
  const _TeacherStats({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Моя нагрузка',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _TeacherStatCard(
              'Дисциплин',
              '${data['disciplines_count']}',
              Icons.science_outlined,
              const Color(0xFF8B5CF6),
            ),
            _TeacherStatCard(
              'Групп',
              '${data['groups_count']}',
              Icons.groups_outlined,
              const Color(0xFF3B82F6),
            ),
            _TeacherStatCard(
              'Студентов',
              '${data['students_count']}',
              Icons.person_outlined,
              const Color(0xFF10B981),
            ),
            _TeacherStatCard(
              'Занятий в расписании',
              '${data['schedule_count']}',
              Icons.calendar_today_outlined,
              const Color(0xFFF59E0B),
            ),
          ],
        ),
      ],
    );
  }
}

class _TeacherStatCard extends StatelessWidget {
  const _TeacherStatCard(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: GlassPanel(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 28,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Admin Profile ────────────────────────────────────────────────────────────

class _AdminProfileInfo extends StatelessWidget {
  const _AdminProfileInfo({required this.username});
  final String username;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        GlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.shield_outlined,
                color: Color(0xFFEF4444),
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(
                'Права администратора',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ...[
                'Управление пользователями',
                'Редактирование всех данных',
                'Просмотр журнала и статистики',
                'Управление расписанием',
              ].map(
                (perm) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 14,
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(width: 6),
                      Text(perm, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}