import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/entities.dart';
import '../providers/auth_provider.dart';
import 'glass.dart';

/// A single, flat navigation destination (route the drawer can go to).
typedef _NavEntry = ({String title, String route, IconData icon});

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _dbEditorExpanded = true;

  List<_NavEntry> _flatEntries(AuthProvider auth) {
    if (auth.isStudent) {
      final entries = <_NavEntry>[
        (title: 'Мой портал', route: '/portal', icon: Icons.home_outlined),
      ];
      if (auth.hasPermission('gradebook.view')) {
        entries.add((title: 'Журнал', route: '/gradebook', icon: Icons.menu_book_outlined));
      }
      if (auth.hasPermission('schedule.view')) {
        entries.add((title: 'Расписание', route: '/my-schedule', icon: Icons.calendar_month_outlined));
      }
      if (auth.hasPermission('attendance.view')) {
        entries.add((title: 'Посещаемость', route: '/my-attendance', icon: Icons.how_to_reg_outlined));
      }
      if (auth.hasPermission('performance.view')) {
        entries.add((title: 'Успеваемость', route: '/my-grades', icon: Icons.school_outlined));
      }
      entries.add((title: 'Профиль', route: '/profile', icon: Icons.account_circle_outlined));
      return entries;
    }

    if (auth.isGuest) {
      final entries = <_NavEntry>[
        (title: 'Панель управления', route: '/', icon: Icons.dashboard_outlined),
      ];
      if (auth.hasPermission('schedule.view')) {
        entries.add((title: 'Расписание', route: '/schedule', icon: Icons.calendar_month_outlined));
      }
      return entries;
    }

    // Teacher and Admin share the same permission-driven menu shape;
    // Admin simply has every permission granted, so nothing is hidden.
    final entries = <_NavEntry>[
      (title: 'Панель управления', route: '/', icon: Icons.dashboard_outlined),
    ];
    if (auth.hasPermission('gradebook.view')) {
      entries.add((title: 'Журнал', route: '/gradebook', icon: Icons.menu_book_outlined));
    }
    if (auth.hasPermission('schedule.view')) {
      entries.add((title: 'Расписание', route: '/schedule', icon: Icons.calendar_month_outlined));
    }
    if (auth.hasPermission('classrooms.view')) {
      entries.add((title: 'Занятость аудиторий', route: '/classrooms-map', icon: Icons.meeting_room_outlined));
    }
    if (auth.hasPermission('attendance.view')) {
      entries.add((title: 'Посещаемость', route: '/attendance', icon: Icons.how_to_reg_outlined));
    }
    if (auth.hasPermission('performance.view')) {
      entries.add((title: 'Успеваемость', route: '/performance', icon: Icons.school_outlined));
    }
    if (auth.hasPermission('users.manage')) {
      entries.add((title: 'Пользователи', route: '/users-admin', icon: Icons.admin_panel_settings_outlined));
    }
    entries.add((title: 'Профиль', route: '/profile', icon: Icons.manage_accounts_outlined));
    return entries;
  }

  /// Reference-data entries (faculties..execution) the user can see,
  /// grouped under one collapsible "Редактор БД" item.
  List<_NavEntry> _dbEditorEntries(AuthProvider auth) {
    if (auth.isStudent || auth.isGuest) return const [];
    return [
      for (final e in entityDefinitions)
        if (auth.hasPermission(auth.permissionForRoute(e.route) ?? '${e.route.replaceFirst('/', '')}.view'))
          (
            title: e.title,
            route: e.route,
            icon: entityIcons[e.route] ?? Icons.table_chart_outlined,
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final flatEntries = _flatEntries(auth);
    final dbEntries = _dbEditorEntries(auth);
    final currentPath = GoRouterState.of(context).uri.path;
    final compact = MediaQuery.sizeOf(context).width < 980;

    void navigate(String route) {
      if (compact) Navigator.of(context).maybePop();
      context.go(route);
    }

    Widget navContent() => _NavigationContent(
          flatEntries: flatEntries,
          dbEntries: dbEntries,
          currentPath: currentPath,
          auth: auth,
          dbEditorExpanded: _dbEditorExpanded,
          onToggleDbEditor: () => setState(() => _dbEditorExpanded = !_dbEditorExpanded),
          onSelected: navigate,
        );

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
                child: SafeArea(child: navContent()),
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
                      child: navContent(),
                    ),
                  ),
                ),
              Expanded(child: widget.child),
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
      _ => ('Гость', Colors.grey, Icons.person_outlined),
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
    required this.flatEntries,
    required this.dbEntries,
    required this.currentPath,
    required this.onSelected,
    required this.auth,
    required this.dbEditorExpanded,
    required this.onToggleDbEditor,
  });

  final List<_NavEntry> flatEntries;
  final List<_NavEntry> dbEntries;
  final String currentPath;
  final ValueChanged<String> onSelected;
  final AuthProvider auth;
  final bool dbEditorExpanded;
  final VoidCallback onToggleDbEditor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dbEditorActive = dbEntries.any((e) => e.route == currentPath);

    return ListView(
      padding: EdgeInsets.zero,
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
        for (final entry in flatEntries)
          _NavTile(
            icon: entry.icon,
            label: entry.title,
            selected: entry.route == currentPath,
            onTap: () => onSelected(entry.route),
          ),
        if (dbEntries.isNotEmpty) ...[
          _NavTile(
            icon: Icons.storage_outlined,
            label: 'Редактор БД',
            selected: dbEditorActive && !dbEditorExpanded,
            trailing: Icon(
              dbEditorExpanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            onTap: onToggleDbEditor,
          ),
          if (dbEditorExpanded)
            for (final entry in dbEntries)
              _NavTile(
                icon: entry.icon,
                label: entry.title,
                selected: entry.route == currentPath,
                indent: true,
                onTap: () => onSelected(entry.route),
              ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

/// A single drawer row. Built manually (instead of
/// NavigationDrawerDestination) so it can render at an indent level and
/// carry a trailing expand/collapse chevron for the "Редактор БД" group.
class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.indent = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(indent ? 32 : 12, 2, 12, 2),
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? scheme.onSecondaryContainer : scheme.onSurface,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
