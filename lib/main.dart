import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'routes/app_router.dart';
import 'services/academic_service.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';

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

  @override
  void initState() {
    super.initState();
    apiClient = ApiClient();
    authProvider = AuthProvider(AuthService(apiClient));
  }

  @override
  Widget build(BuildContext context) {
    final router = buildRouter(authProvider, apiClient);
    return MultiProvider(
      providers: [
        Provider.value(value: apiClient),
        Provider(create: (_) => AcademicService(apiClient)),
        ChangeNotifierProvider.value(value: authProvider),
      ],
      child: MaterialApp.router(
        title: 'University ERP',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B87)),
          visualDensity: VisualDensity.standard,
          cardTheme: const CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),
        routerConfig: router,
      ),
    );
  }
}
