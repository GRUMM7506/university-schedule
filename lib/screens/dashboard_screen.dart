import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppState>().loadDashboard();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final stats = state.dashboard;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Панель управления',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 18),
        if (stats == null)
          const Center(child: CircularProgressIndicator())
        else
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _card(
                context,
                'Количество студентов',
                stats['students'],
                Icons.people_alt_outlined,
              ),
              _card(
                context,
                'Количество преподавателей',
                stats['teachers'],
                Icons.badge_outlined,
              ),
              _card(
                context,
                'Количество групп',
                stats['groups'],
                Icons.groups_outlined,
              ),
              _card(
                context,
                'Количество факультетов',
                stats['faculties'],
                Icons.account_balance_outlined,
              ),
            ],
          ),
      ],
    );
  }

  Widget _card(
    BuildContext context,
    String title,
    dynamic value,
    IconData icon,
  ) {
    return SizedBox(
      width: 260,
      height: 132,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const Spacer(),
              Text('$value', style: Theme.of(context).textTheme.headlineMedium),
              Text(title, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
