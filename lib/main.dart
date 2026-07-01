import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'routes/app_router.dart';
import 'services/academic_service.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/token_store.dart';
import 'services/user_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';


final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showGlobalErrorSnackBar(String message) {
  rootScaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void main() {
  runApp(const UniversityApp());
}

class UniversityApp extends StatefulWidget {
  const UniversityApp({super.key});

  @override
  State<UniversityApp> createState() => _UniversityAppState();
}

class _UniversityAppState extends State<UniversityApp> {
  late final ApiClient apiClient;
  late final AuthProvider authProvider;
  late final ThemeController themeController;
  late final AcademicService academicService;
  late final UserService userService;
  late final GoRouter router;

  @override
  void initState() {
    super.initState();
    apiClient = ApiClient();
    authProvider = AuthProvider(AuthService(apiClient));
    themeController = ThemeController()..load();
    // Created once for the whole app lifetime (not per-route) so its
    // reference-data cache actually survives navigation between screens.
    academicService = AcademicService(apiClient);
    userService = UserService(apiClient);
    router = buildRouter(authProvider, apiClient, academicService);

    apiClient.onError = showGlobalErrorSnackBar;
    apiClient.onSessionExpired = authProvider.forceLogout;

    // Attempt to silently resume a session from the persisted refresh
    // token before the router makes its first redirect decision.
    authProvider.tryAutoLogin();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: apiClient),
        Provider.value(value: academicService),
        Provider.value(value: userService),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: themeController),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) {
          return MaterialApp.router(
            scaffoldMessengerKey: rootScaffoldMessengerKey,
            title: 'University ERP',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: theme.themeMode,
            routerConfig: router,
            builder: (context, child) {
              return AnimatedBuilder(
                animation: authProvider,
                builder: (context, _) {
                  if (authProvider.restoring) {
                    return const _SplashScreen();
                  }
                  return child ?? const SizedBox.shrink();
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}