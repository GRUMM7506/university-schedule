import '../models/entity_model.dart';
import 'api_client.dart';

class EntityService {
  EntityService(this.client, this.definition);

  final ApiClient client;
  final EntityDefinition definition;

  Future<List<EntityModel>> list({String? search, String? sort}) async {
    final response = await client.dio.get(
      '${definition.endpoint}/list',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (sort != null) 'sort': sort,
      },
    );
    return (response.data as List)
        .map((item) => EntityModel(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<EntityModel> create(Map<String, dynamic> payload) async {
    final response = await client.dio.post(definition.endpoint, data: payload);
    return EntityModel(Map<String, dynamic>.from(response.data as Map));
  }

  Future<EntityModel> update(int id, Map<String, dynamic> payload) async {
    final response = await client.dio.put(
      '${definition.endpoint}/$id',
      data: payload,
    );
    return EntityModel(Map<String, dynamic>.from(response.data as Map));
  }

  Future<void> delete(int id) async {
    await client.dio.delete('${definition.endpoint}/$id');
  }
}
