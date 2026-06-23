import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../widgets/glass.dart';

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
        GlassPanel(
          padding: const EdgeInsets.all(28),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Панель управления',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Обзор ключевых показателей учебного процесса.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.query_stats_outlined,
                size: 42,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
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
      height: 146,
      child: GlassPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .12),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const Spacer(),
            Text(
              '$value',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
