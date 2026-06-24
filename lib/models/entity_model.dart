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
    this.refEndpoint,
    this.refLabelKey = 'name',
  });

  final String key;
  final String label;
  final FieldType type;
  final bool required;
  final Map<String, String>? options;

  /// For fkSelect: endpoint to load reference records (e.g. '/groups')
  final String? refEndpoint;

  /// For fkSelect: which key from reference records to display as label
  final String refLabelKey;
}

enum FieldType { text, number, date, email, select, fkSelect }

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
