import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../providers/auth_provider.dart';
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
      if (mounted) context.read<AppState>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final state = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _HeaderCard(auth: auth),
        const SizedBox(height: 20),
        if (state.dashboard == null)
          const Center(child: CircularProgressIndicator())
        else
          _AdminDashboard(stats: state.dashboard!),
      ],
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.auth});
  final AuthProvider auth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (greeting, icon, color) = switch (auth.role) {
      'Admin' => (
        'Администратор системы',
        Icons.shield_rounded,
        const Color(0xFFEF4444),
      ),
      'Teacher' => (
        'Панель преподавателя',
        Icons.cast_for_education_rounded,
        const Color(0xFFF59E0B),
      ),
      'Student' => (
        'Студенческий портал',
        Icons.school_rounded,
        const Color(0xFF10B981),
      ),
      _ => ('Добро пожаловать', Icons.dashboard_rounded, scheme.primary),
    };

    return GlassPanel(
      padding: const EdgeInsets.all(26),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: color.withValues(alpha: .15),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Добро пожаловать, ${auth.username ?? 'пользователь'}!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _DateTimeWidget(),
        ],
      ),
    );
  }
}

class _DateTimeWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = [
      '',
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '${now.day} ${months[now.month]} ${now.year}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.access_time_outlined,
                size: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Admin Dashboard ──────────────────────────────────────────────────────────

class _AdminDashboard extends StatelessWidget {
  const _AdminDashboard({required this.stats});
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Общая статистика',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatCard(
              title: 'Студентов',
              value: '${stats['students']}',
              icon: Icons.person_outlined,
              color: const Color(0xFF3B82F6),
              subtitle: 'Обучается сейчас',
            ),
            _StatCard(
              title: 'Преподавателей',
              value: '${stats['teachers']}',
              icon: Icons.cast_for_education_outlined,
              color: const Color(0xFF8B5CF6),
              subtitle: 'Ведут занятия',
            ),
            _StatCard(
              title: 'Групп',
              value: '${stats['groups']}',
              icon: Icons.groups_outlined,
              color: const Color(0xFF10B981),
              subtitle: 'Учебных групп',
            ),
            _StatCard(
              title: 'Факультетов',
              value: '${stats['faculties']}',
              icon: Icons.account_balance_outlined,
              color: const Color(0xFFF59E0B),
              subtitle: 'Подразделений',
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          'Быстрые действия',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: const [
            _QuickActionCard(
              icon: Icons.person_add_outlined,
              label: 'Добавить студента',
              color: Color(0xFF3B82F6),
              route: '/students',
            ),
            _QuickActionCard(
              icon: Icons.how_to_reg_outlined,
              label: 'Отметить посещаемость',
              color: Color(0xFF10B981),
              route: '/attendance',
            ),
            _QuickActionCard(
              icon: Icons.calendar_month_outlined,
              label: 'Расписание',
              color: Color(0xFFF59E0B),
              route: '/schedule',
            ),
            _QuickActionCard(
              icon: Icons.menu_book_outlined,
              label: 'Журнал оценок',
              color: Color(0xFF8B5CF6),
              route: '/gradebook',
            ),
          ],
        ),
        const SizedBox(height: 28),
        _InfoBanners(),
      ],
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: GlassPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '↑',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              subtitle,
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

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String route;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.go(route),
      child: SizedBox(
        width: 160,
        child: GlassPanel(
          padding: const EdgeInsets.all(18),
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBanners extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _Banner(
          icon: Icons.tips_and_updates_outlined,
          title: 'Журнал оценок',
          desc:
              'Ведите журнал оценок по группам и дисциплинам с удобной фильтрацией.',
          color: const Color(0xFF8B5CF6),
        ),
        _Banner(
          icon: Icons.calendar_view_week_outlined,
          title: 'Расписание',
          desc:
              'Красивая сетка расписания по дням недели с цветовой кодировкой занятий.',
          color: const Color(0xFF3B82F6),
        ),
        _Banner(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Управление пользователями',
          desc:
              'Создавайте аккаунты для студентов и преподавателей, управляйте ролями.',
          color: const Color(0xFFEF4444),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String desc;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: GlassPanel(
        padding: const EdgeInsets.all(18),
        child: Row(
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
