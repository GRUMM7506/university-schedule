import 'package:flutter/foundation.dart';

import '../services/api_client.dart';

class AppState extends ChangeNotifier {
  AppState(this.client);

  final ApiClient client;
  Map<String, dynamic>? dashboard;

  Future<void> loadDashboard() async {
    final response = await client.dio.get('/dashboard');
    dashboard = Map<String, dynamic>.from(response.data as Map);
    notifyListeners();
  }
}
