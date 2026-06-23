import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/entities.dart';
import '../providers/auth_provider.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление учебным процессом'),
        actions: [
          IconButton(
            tooltip: 'Выйти',
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: NavigationDrawer(
        selectedIndex: entries.indexWhere(
          (e) => GoRouterState.of(context).uri.path == e.$2,
        ),
        onDestinationSelected: (index) {
          Navigator.of(context).pop();
          context.go(entries[index].$2);
        },
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 24, 16, 12),
            child: Text(
              'University ERP',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          for (final entry in entries)
            NavigationDrawerDestination(
              icon: Icon(entry.$3),
              label: Text(entry.$1),
            ),
        ],
      ),
      body: child,
    );
  }
}
