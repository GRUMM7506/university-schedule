import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../models/entities.dart';
import '../providers/auth_provider.dart';
import '../providers/entity_provider.dart';
import '../screens/attendance_screen.dart';
import '../screens/classroom_occupancy_screen.dart';
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

      final path = state.uri.path;
      final loggingIn = path == '/login';
      final setupProfile = path == '/profile-setup';

      if (auth.isGuest) {
        final canAccess = path == '/schedule' ||
            (path == '/' && auth.hasPermission('dashboard.view'));
        return canAccess ? null : '/schedule';
      }

      if (!auth.isAuthenticated) return loggingIn ? null : '/login';

      if (auth.linkedId == null && !auth.isAdmin && !auth.isGuest) {
        return setupProfile ? null : '/profile-setup';
      }

      // Each role's "home" once logged in.
      final home = auth.isStudent ? '/portal' : '/';

      if (loggingIn || setupProfile) return home;

      if (!auth.isStudent && path == '/portal') return '/';
      if (auth.isStudent && path == '/') return '/portal';
      if (auth.isStudent && path == '/schedule') return '/my-schedule';
      if (auth.isStudent && path == '/attendance') return '/my-attendance';
      if (auth.isStudent && (path == '/performance' || path == '/gradebook')) {
        return '/my-grades';
      }

      // Permission-gated routes: blocks direct URL entry to a screen the
      // user's menu wouldn't show them (e.g. an admin revoked
      // 'attendance.view' for a teacher who still types /attendance).
      if (!auth.canAccessRoute(path)) return home;

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

          // Classroom occupancy / free-room finder
          GoRoute(
            path: '/classrooms-map',
            builder: (context, state) => const ClassroomOccupancyScreen(),
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

          // User management (gated by users.manage permission)
          GoRoute(
            path: '/users-admin',
            builder: (context, state) => const UserManagementScreen(),
          ),

          // Student aliases (same screens but for student nav)
          GoRoute(
            path: '/my-schedule',
            builder: (context, state) => const StudentPortalScreen(),
          ),
          GoRoute(
            path: '/my-grades',
            builder: (context, state) => const StudentPortalScreen(),
          ),
          GoRoute(
            path: '/my-attendance',
            builder: (context, state) => const StudentPortalScreen(),
          ),

          // Reference-data CRUD routes — access is gated per-route by
          // permission via auth.canAccessRoute in the redirect above.
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
