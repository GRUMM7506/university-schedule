import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/entities.dart';
import '../providers/auth_provider.dart';
import 'glass.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  List<(String, String, IconData)> _buildEntries(AuthProvider auth) {
    if (auth.isStudent) {
      return const [
        ('Мой портал', '/portal', Icons.home_outlined),
        ('Профиль', '/profile', Icons.account_circle_outlined),
      ];
    }

    if (auth.isTeacher) {
      return const [
        ('Панель управления', '/', Icons.dashboard_outlined),
        ('Журнал', '/gradebook', Icons.menu_book_outlined),
        ('Расписание', '/schedule', Icons.calendar_month_outlined),
        ('Посещаемость', '/attendance', Icons.how_to_reg_outlined),
        ('Успеваемость', '/performance', Icons.school_outlined),
        ('Профиль', '/profile', Icons.manage_accounts_outlined),
      ];
    }

    // Admin — full menu
    return [
      ('Панель управления', '/', Icons.dashboard_outlined),
      ('Журнал', '/gradebook', Icons.menu_book_outlined),
      ...entityDefinitions.map(
        (e) => (
          e.title,
          e.route,
          entityIcons[e.route] ?? Icons.table_chart_outlined,
        ),
      ),
      ('Расписание', '/schedule', Icons.calendar_month_outlined),
      ('Посещаемость', '/attendance', Icons.how_to_reg_outlined),
      ('Успеваемость', '/performance', Icons.school_outlined),
      ('Пользователи', '/users-admin', Icons.admin_panel_settings_outlined),
      ('Профиль', '/profile', Icons.manage_accounts_outlined),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final entries = _buildEntries(auth);
    final currentPath = GoRouterState.of(context).uri.path;
    final selectedIndex = entries.indexWhere((e) => e.$2 == currentPath);
    final compact = MediaQuery.sizeOf(context).width < 980;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Academic Flow'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _RoleBadge(role: auth.role ?? ''),
          ),
          if (auth.username != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  auth.username!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Выйти',
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: compact
          ? Drawer(
              backgroundColor: Colors.transparent,
              child: AppGlassBackground(
                child: SafeArea(
                  child: _NavigationContent(
                    entries: entries,
                    selectedIndex: selectedIndex,
                    auth: auth,
                    onSelected: (index) {
                      Navigator.of(context).pop();
                      context.go(entries[index].$2);
                    },
                  ),
                ),
              ),
            )
          : null,
      body: AppGlassBackground(
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              if (!compact)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 0, 18),
                  child: SizedBox(
                    width: 268,
                    child: GlassPanel(
                      padding: EdgeInsets.zero,
                      child: _NavigationContent(
                        entries: entries,
                        selectedIndex: selectedIndex,
                        auth: auth,
                        onSelected: (index) => context.go(entries[index].$2),
                      ),
                    ),
                  ),
                ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (role) {
      'Admin' => ('Админ', const Color(0xFFEF4444), Icons.shield_outlined),
      'Teacher' => (
        'Учитель',
        const Color(0xFFF59E0B),
        Icons.cast_for_education_outlined,
      ),
      'Student' => ('Студент', const Color(0xFF10B981), Icons.school_outlined),
      _ => ('?', Colors.grey, Icons.person_outlined),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationContent extends StatelessWidget {
  const _NavigationContent({
    required this.entries,
    required this.selectedIndex,
    required this.onSelected,
    required this.auth,
  });

  final List<(String, String, IconData)> entries;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final AuthProvider auth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NavigationDrawer(
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onDestinationSelected: onSelected,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    colors: [scheme.primary, scheme.secondary],
                  ),
                ),
                child: const Icon(
                  Icons.school_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'University ERP',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              _RoleBadge(role: auth.role ?? ''),
            ],
          ),
        ),
        const Divider(height: 1, indent: 20, endIndent: 20),
        const SizedBox(height: 4),
        for (final entry in entries)
          NavigationDrawerDestination(
            icon: Icon(entry.$3),
            selectedIcon: Icon(entry.$3),
            label: Text(entry.$1),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
