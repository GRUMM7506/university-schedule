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
import '../screens/gradebook_screen.dart';
import '../screens/login_screen.dart';
import '../screens/performance_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/profile_setup_screen.dart';
import '../screens/schedule_screen.dart';
import '../screens/student_portal_screen.dart';
import '../screens/user_management_screen.dart';
import '../services/academic_service.dart';
import '../services/api_client.dart';
import '../services/entity_service.dart';
import '../widgets/app_shell.dart';

GoRouter buildRouter(
  AuthProvider auth,
  ApiClient client,
  AcademicService academicService,
) {
  return GoRouter(
    refreshListenable: auth,
    initialLocation: '/',
    redirect: (context, state) {
      // While we're attempting to silently restore a session from the
      // stored refresh token, don't redirect anywhere yet — show a splash.
      if (auth.restoring) return null;

      final loggingIn = state.uri.path == '/login';
      final setupProfile = state.uri.path == '/profile-setup';

      if (!auth.isAuthenticated) return loggingIn ? null : '/login';

      if (auth.linkedId == null && !auth.isAdmin) {
        return setupProfile ? null : '/profile-setup';
      }

      if (loggingIn || setupProfile) {
        if (auth.isStudent) return '/portal';
        return '/';
      }

      if (!auth.isStudent && state.uri.path == '/portal') return '/';
      if (auth.isStudent && _isAdminRoute(state.uri.path)) return '/portal';
      if (!auth.isAdmin && state.uri.path == '/users-admin') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => Provider.value(
          value: academicService,
          child: const ProfileSetupScreen(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => MultiProvider(
          providers: [Provider.value(value: academicService)],
          child: AppShell(child: child),
        ),
        routes: [
          // Dashboard (admin/teacher)
          GoRoute(
            path: '/',
            builder: (context, state) => ChangeNotifierProvider(
              create: (_) => AppState(client),
              child: const DashboardScreen(),
            ),
          ),

          // Student portal
          GoRoute(
            path: '/portal',
            builder: (context, state) => const StudentPortalScreen(),
          ),

          // Gradebook
          GoRoute(
            path: '/gradebook',
            builder: (context, state) => const GradebookScreen(),
          ),

          // Schedule
          GoRoute(
            path: '/schedule',
            builder: (context, state) => const ScheduleScreen(),
          ),

          // Attendance
          GoRoute(
            path: '/attendance',
            builder: (context, state) => const AttendanceScreen(),
          ),

          // Performance (grading)
          GoRoute(
            path: '/performance',
            builder: (context, state) => const PerformanceScreen(),
          ),

          // Profile
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),

          // User management (admin only)
          GoRoute(
            path: '/users-admin',
            builder: (context, state) => const UserManagementScreen(),
          ),

          // Student aliases (same screens but for student nav)
          GoRoute(
            path: '/my-grades',
            builder: (context, state) => const StudentPortalScreen(),
          ),
          GoRoute(
            path: '/my-attendance',
            builder: (context, state) => const StudentPortalScreen(),
          ),

          // CRUD entity routes (admin only)
          for (final definition in entityDefinitions)
            GoRoute(
              path: definition.route,
              builder: (context, state) => ChangeNotifierProvider(
                key: ValueKey(definition.route),
                create: (_) => EntityProvider(
                  EntityService(client, definition),
                  academicService,
                ),
                child: EntityListScreen(definition: definition),
              ),
            ),
        ],
      ),
    ],
  );
}

bool _isAdminRoute(String path) {
  const adminRoutes = [
    '/faculties',
    '/specialities',
    '/groups',
    '/students',
    '/teachers',
    '/subjects',
    '/disciplines',
    '/classrooms',
    '/study-weeks',
    '/execution',
    '/attendance',
    '/performance',
    '/users-admin',
    '/gradebook',
  ];
  return adminRoutes.contains(path);
}