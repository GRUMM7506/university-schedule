import 'package:flutter/foundation.dart';

import '../models/entity_model.dart';
import '../services/academic_service.dart';
import '../services/entity_service.dart';

class EntityProvider extends ChangeNotifier {
  EntityProvider(this.service, [this.academicService]);

  final EntityService service;

  /// Optional: when provided, mutations clear its reference-data cache so
  /// dropdowns elsewhere in the app (which read through AcademicService.list)
  /// don't keep showing stale data after a create/update/delete here.
  final AcademicService? academicService;

  List<EntityModel> items = [];
  bool loading = false;
  String? error;
  String search = '';
  String? sort;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await service.list(search: search, sort: sort);
    } catch (err) {
      error = 'Не удалось загрузить данные';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> save(Map<String, dynamic> payload, {int? id}) async {
    if (id == null) {
      await service.create(payload);
    } else {
      await service.update(id, payload);
    }
    academicService?.clearListCache();
    await load();
  }

  Future<void> remove(int id) async {
    await service.delete(id);
    academicService?.clearListCache();
    await load();
  }
}