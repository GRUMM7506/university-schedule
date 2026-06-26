import 'package:flutter/material.dart';
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
  Map<String, dynamic>? profileData;
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
    final auth = context.read<AuthProvider>();
    final service = context.read<AcademicService>();
    try {
      if (auth.isStudent && auth.studentId != null) {
        profileData = await service.studentDashboard(auth.studentId!);
      } else if (auth.isTeacher) {
        // Try to find teacher id by listing
        final teachers = await service.list('/teachers');
        final match = teachers
            .where((t) => '${t['email']}'.startsWith('${auth.username}@'))
            .toList();
        if (match.isNotEmpty) {
          profileData = await service.teacherDashboard(
            match.first['id'] as int,
          );
          profileData!['_teacherId'] = match.first['id'];
        }
      }
    } catch (_) {}
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Avatar card
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
                      profileData?['fio'] ?? auth.username ?? 'Пользователь',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    _RoleChip(role: auth.role ?? ''),
                    const SizedBox(height: 12),
                    if (auth.isTeacher && profileData?['position'] != null)
                      _InfoRow(
                        Icons.work_outline,
                        '${profileData!['position']}',
                      ),
                    _InfoRow(Icons.person_outline, 'Логин: ${auth.username}'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (profileData != null) ...[
          if (auth.isStudent) _StudentStats(data: profileData!),
          if (auth.isTeacher) _TeacherStats(data: profileData!),
        ] else if (auth.isAdmin)
          _AdminProfileInfo(username: auth.username ?? ''),
      ],
    );
  }
}

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
      'Student' => ('Студент', const Color(0xFF10B981), Icons.school_outlined),
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
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
