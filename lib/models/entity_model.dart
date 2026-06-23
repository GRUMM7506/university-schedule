class EntityModel {
  EntityModel(this.data);

  final Map<String, dynamic> data;

  int get id => data['id'] as int? ?? 0;

  dynamic operator [](String key) => data[key];

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(data);
}

class EntityField {
  const EntityField({
    required this.key,
    required this.label,
    this.type = FieldType.text,
    this.required = true,
    this.options,
  });

  final String key;
  final String label;
  final FieldType type;
  final bool required;
  final Map<String, String>? options;
}

enum FieldType { text, number, date, email, select }

class EntityDefinition {
  const EntityDefinition({
    required this.title,
    required this.route,
    required this.endpoint,
    required this.fields,
    required this.columns,
    this.sortKey = 'id',
  });

  final String title;
  final String route;
  final String endpoint;
  final List<EntityField> fields;
  final List<String> columns;
  final String sortKey;
}
