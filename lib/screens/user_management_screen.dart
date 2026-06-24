import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/academic_service.dart';
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
      users = await context.read<AcademicService>().listUsers();
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
        await context.read<AcademicService>().createUser(result);
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
      await context.read<AcademicService>().updateUser(
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
      await context.read<AcademicService>().deleteUser(user['id'] as int);
      _load();
    }
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
            tooltip: 'Удалить',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
        ],
      ),
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
              value: _role,
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
            if (_passwordCtrl.text.isNotEmpty)
              payload['password'] = _passwordCtrl.text;
            Navigator.pop(context, payload);
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('Сохранить'),
        ),
      ],
    );
  }
}
