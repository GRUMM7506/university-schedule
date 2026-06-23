import 'package:flutter/foundation.dart';

import '../models/entity_model.dart';
import '../services/entity_service.dart';

class EntityProvider extends ChangeNotifier {
  EntityProvider(this.service);

  final EntityService service;
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
    await load();
  }

  Future<void> remove(int id) async {
    await service.delete(id);
    await load();
  }
}
