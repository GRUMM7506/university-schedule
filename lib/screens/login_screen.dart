import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/glass.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Prefill demo credentials only in debug builds to avoid leaking them in prod
  final username = TextEditingController(text: kDebugMode ? 'admin' : '');
  final password = TextEditingController(text: kDebugMode ? 'admin123' : '');

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGlassBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;
                  final loginCard = GlassPanel(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Вход в систему',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Демо-доступ:\n• Админ: admin / admin123\n• Преподаватель: teacher / teacher123\n• Студент: student / student123',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: username,
                          decoration: const InputDecoration(
                            labelText: 'Логин',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: password,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Пароль',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        if (auth.error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Text(
                              auth.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: auth.loading
                              ? null
                              : () => auth.login(username.text, password.text),
                          icon: auth.loading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: const Text('Войти'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: auth.loading ? null : auth.loginAsGuest,
                          icon: const Icon(Icons.public),
                          label: const Text('Войти как гость'),
                        ),
                      ],
                    ),
                  );

                  // IntrinsicHeight решает проблему infinite height для CrossAxisAlignment.stretch
                  return IntrinsicHeight(
                    child: Flex(
                      direction: wide ? Axis.horizontal : Axis.vertical,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (wide)
                          Expanded(flex: 5, child: _IntroPanel(wide: wide))
                        else
                          _IntroPanel(wide: wide),
                        SizedBox(width: wide ? 24 : 0, height: wide ? 0 : 18),
                        if (wide)
                          Expanded(flex: 4, child: loginCard)
                        else
                          loginCard,
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroPanel extends StatelessWidget {
  const _IntroPanel({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      padding: EdgeInsets.all(wide ? 34 : 26),
      opacity: Theme.of(context).brightness == Brightness.dark ? .14 : .46,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.secondary],
              ),
            ),
            child: const Icon(Icons.auto_stories_outlined, color: Colors.white),
          ),
          const SizedBox(height: 26),
          Text(
            'Academic Flow',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.02,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Современная панель для расписания, посещаемости, успеваемости и справочников университета.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _FeatureChip(
                icon: Icons.calendar_month_outlined,
                label: 'Расписание',
              ),
              _FeatureChip(icon: Icons.fact_check_outlined, label: 'Контроль'),
              _FeatureChip(icon: Icons.table_chart_outlined, label: 'Данные'),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
