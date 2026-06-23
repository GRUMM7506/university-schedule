import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../models/entities.dart';
import '../providers/auth_provider.dart';
import '../providers/entity_provider.dart';
import '../screens/attendance_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/entity_list_screen.dart';
import '../screens/login_screen.dart';
import '../screens/performance_screen.dart';
import '../screens/schedule_screen.dart';
import '../services/api_client.dart';
import '../services/entity_service.dart';
import '../widgets/app_shell.dart';

GoRouter buildRouter(AuthProvider auth, ApiClient client) {
  return GoRouter(
    refreshListenable: auth,
    initialLocation: '/',
    redirect: (context, state) {
      final loggingIn = state.uri.path == '/login';
      if (!auth.isAuthenticated) return loggingIn ? null : '/login';
      if (loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => ChangeNotifierProvider(
              create: (_) => AppState(client),
              child: const DashboardScreen(),
            ),
          ),
          for (final definition in entityDefinitions)
            GoRoute(
              path: definition.route,
              builder: (context, state) => ChangeNotifierProvider(
                key: ValueKey(definition.route),
                create: (_) =>
                    EntityProvider(EntityService(client, definition)),
                child: EntityListScreen(definition: definition),
              ),
            ),
          GoRoute(
            path: '/schedule',
            builder: (context, state) => const ScheduleScreen(),
          ),
          GoRoute(
            path: '/attendance',
            builder: (context, state) => const AttendanceScreen(),
          ),
          GoRoute(
            path: '/performance',
            builder: (context, state) => const PerformanceScreen(),
          ),
        ],
      ),
    ],
  );
}
