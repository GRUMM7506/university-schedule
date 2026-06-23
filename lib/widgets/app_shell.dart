import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/entities.dart';
import '../providers/auth_provider.dart';
import 'glass.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final entries = [
      ('Панель управления', '/', Icons.dashboard_outlined),
      ...entityDefinitions.map(
        (e) => (e.title, e.route, Icons.table_chart_outlined),
      ),
      ('Расписание', '/schedule', Icons.calendar_month_outlined),
      ('Посещаемость', '/attendance', Icons.fact_check_outlined),
      ('Успеваемость', '/performance', Icons.school_outlined),
    ];
    final selectedIndex = entries.indexWhere(
      (e) => GoRouterState.of(context).uri.path == e.$2,
    );
    final compact = MediaQuery.sizeOf(context).width < 980;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Academic Flow'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Chip(
              avatar: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: const Text('ERP'),
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .12),
            ),
          ),
          IconButton(
            tooltip: 'Выйти',
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout),
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
                    width: 292,
                    child: GlassPanel(
                      padding: EdgeInsets.zero,
                      child: _NavigationContent(
                        entries: entries,
                        selectedIndex: selectedIndex,
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

class _NavigationContent extends StatelessWidget {
  const _NavigationContent({
    required this.entries,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<(String, String, IconData)> entries;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NavigationDrawer(
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onDestinationSelected: onSelected,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 26, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [scheme.primary, scheme.secondary],
                  ),
                ),
                child: const Icon(Icons.school_outlined, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'University ERP',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'Управление учебным процессом',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        for (final entry in entries)
          NavigationDrawerDestination(
            icon: Icon(entry.$3),
            selectedIcon: Icon(entry.$3),
            label: Text(entry.$1),
          ),
      ],
    );
  }
}
