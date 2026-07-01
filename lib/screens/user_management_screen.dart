import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/user_service.dart';
import '../widgets/glass.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<Map<String, dynamic>> users = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      users = await context.read<UserService>().listUsers();
    } catch (_) {}
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassPanel(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Управление пользователями',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Только для администраторов',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _openCreateDialog(context),
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Добавить'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(child: _buildUserList()),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    if (users.isEmpty) {
      return const Center(child: Text('Пользователи не найдены'));
    }
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: users.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: .3),
        ),
        itemBuilder: (context, i) {
          final user = users[i];
          return _UserTile(
            user: user,
            onEdit: () => _openEditDialog(context, user),
            onDelete: () => _confirmDelete(context, user),
            onPermissions: () => _openPermissionsDialog(context, user),
          );
        },
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext ctx) async {
    final result = await showDialog<Map<String, String>>(
      context: ctx,
      builder: (_) => const _UserDialog(),
    );
    if (result != null && mounted) {
      try {
        await context.read<UserService>().createUser(result);
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Пользователь создан'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _openEditDialog(
    BuildContext ctx,
    Map<String, dynamic> user,
  ) async {
    final result = await showDialog<Map<String, String>>(
      context: ctx,
      builder: (_) => _UserDialog(user: user),
    );
    if (result != null && mounted) {
      await context.read<UserService>().updateUser(
        user['id'] as int,
        result,
      );
      _load();
    }
  }

  Future<void> _confirmDelete(
    BuildContext ctx,
    Map<String, dynamic> user,
  ) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Удалить пользователя?'),
        content: Text('Вы уверены, что хотите удалить «${user['username']}»?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<UserService>().deleteUser(user['id'] as int);
      _load();
    }
  }

  Future<void> _openPermissionsDialog(
    BuildContext ctx,
    Map<String, dynamic> user,
  ) async {
    await showDialog(
      context: ctx,
      builder: (_) => _PermissionsDialog(
        userId: user['id'] as int,
        username: '${user['username']}',
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.onEdit,
    required this.onDelete,
    required this.onPermissions,
  });

  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPermissions;

  @override
  Widget build(BuildContext context) {
    final role = '${user['role']}';
    final (color, icon) = switch (role) {
      'Admin' => (const Color(0xFFEF4444), Icons.shield_outlined),
      'Teacher' => (const Color(0xFFF59E0B), Icons.cast_for_education_outlined),
      'Student' => (const Color(0xFF10B981), Icons.school_outlined),
      _ => (Colors.grey, Icons.person_outlined),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${user['username']}'[0].toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user['username']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Row(
                  children: [
                    Icon(icon, size: 12, color: color),
                    const SizedBox(width: 4),
                    Text(
                      role,
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Редактировать',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Права доступа',
            onPressed: onPermissions,
            icon: const Icon(Icons.admin_panel_settings_outlined),
          ),
          IconButton(
            tooltip: 'Удалить',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}

class _PermissionsDialog extends StatefulWidget {
  const _PermissionsDialog({required this.userId, required this.username});

  final int userId;
  final String username;

  @override
  State<_PermissionsDialog> createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends State<_PermissionsDialog> {
  bool _loading = true;
  List<Map<String, dynamic>> _permissions = [];
  final Set<String> _pending = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = context.read<UserService>();
    final data = await service.fetchUserPermissions(widget.userId);
    final perms = (data['permissions'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (!mounted) return;
    setState(() {
      _permissions = perms;
      _loading = false;
    });
  }

  Future<void> _toggle(Map<String, dynamic> perm, bool? newValue) async {
    final permKey = perm['permission'] as String;
    if (_pending.contains(permKey)) return;
    setState(() => _pending.add(permKey));
    final service = context.read<UserService>();
    try {
      await service.updateUserPermission(widget.userId, {
        'permission': permKey,
        'is_granted': newValue,
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _pending.remove(permKey));
    }
  }

  static const _entityNames = {
    'dashboard': 'Дашборд',
    'users': 'Пользователи',
    'permissions': 'Права доступа',
    'faculties': 'Факультеты',
    'specialities': 'Специальности',
    'groups': 'Группы',
    'students': 'Студенты',
    'teachers': 'Преподаватели',
    'subjects': 'Предметы',
    'classrooms': 'Аудитории',
    'study-weeks': 'Учебные недели',
    'disciplines': 'Дисциплины',
    'execution': 'Исполнение',
    'schedule': 'Расписание',
    'attendance': 'Посещаемость',
    'performance': 'Успеваемость',
    'gradebook': 'Журнал',
  };

  bool _effective(Map<String, dynamic> perm) {
    final override = perm['override'];
    if (override == null) return perm['default_granted'] as bool? ?? false;
    return override as bool;
  }

  Widget _permCheckbox(Map<String, dynamic> perm, String label) {
    final permKey = perm['permission'] as String;
    final isPending = _pending.contains(permKey);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: isPending
              ? const Padding(
                  padding: EdgeInsets.all(2),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Checkbox(
                  value: _effective(perm),
                  onChanged: (v) => _toggle(perm, v),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, Map<String, Map<String, dynamic>>>{};
    for (final p in _permissions) {
      final permKey = p['permission'] as String;
      final entity = permKey.split('.').first;
      final action = permKey.split('.').last;
      groups.putIfAbsent(entity, () => {});
      groups[entity]![action] = p;
    }
    final entries = groups.entries.toList();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.admin_panel_settings_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Права доступа: ${widget.username}'),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                shrinkWrap: true,
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final entity = entries[i].key;
                  final perms = entries[i].value;
                  final label = _entityNames[entity] ?? entity;
                  final view = perms['view'];
                  final edit = perms['edit'];
                  final manage = perms['manage'];
                  final anyOverridden = [
                    view,
                    edit,
                    manage,
                  ].any((p) => p != null && p['override'] != null);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      children: [
                        if (anyOverridden)
                          Icon(Icons.tune, size: 14, color: Theme.of(context).colorScheme.primary),
                        if (anyOverridden) const SizedBox(width: 4),
                        SizedBox(
                          width: 130,
                          child: Text(
                            label,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Spacer(),
                        if (view != null) _permCheckbox(view, 'Чтение'),
                        if (edit != null) _permCheckbox(edit, 'Редактирование'),
                        if (manage != null) _permCheckbox(manage, 'Управление'),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}

class _UserDialog extends StatefulWidget {
  const _UserDialog({this.user});
  final Map<String, dynamic>? user;

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _role = 'Student';
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _usernameCtrl.text = widget.user!['username'] as String? ?? '';
      _role = widget.user!['role'] as String? ?? 'Student';
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.user != null;
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEdit ? Icons.edit_outlined : Icons.person_add_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Text(isEdit ? 'Редактировать пользователя' : 'Новый пользователь'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _usernameCtrl,
              readOnly: isEdit,
              decoration: InputDecoration(
                labelText: 'Логин',
                prefixIcon: const Icon(Icons.person_outline),
                border: const OutlineInputBorder(),
                filled: isEdit,
                fillColor: isEdit
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                          .withValues(alpha: .4)
                    : null,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: isEdit ? 'Новый пароль (оставьте пустым)' : 'Пароль',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: 'Роль',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Admin', child: Text('Администратор')),
                DropdownMenuItem(
                  value: 'Teacher',
                  child: Text('Преподаватель'),
                ),
                DropdownMenuItem(value: 'Student', child: Text('Студент')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'Student'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton.icon(
          onPressed: () {
            final payload = <String, String>{'role': _role};
            if (!isEdit) payload['username'] = _usernameCtrl.text.trim();
            if (_passwordCtrl.text.isNotEmpty) {
              payload['password'] = _passwordCtrl.text;
            }
            Navigator.pop(context, payload);
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('Сохранить'),
        ),
      ],
    );
  }
}