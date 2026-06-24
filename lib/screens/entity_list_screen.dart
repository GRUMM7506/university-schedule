import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/entity_model.dart';
import '../providers/entity_provider.dart';
import '../services/academic_service.dart';
import '../widgets/entity_form_dialog.dart';
import '../widgets/glass.dart';

class EntityListScreen extends StatefulWidget {
  const EntityListScreen({super.key, required this.definition});

  final EntityDefinition definition;

  @override
  State<EntityListScreen> createState() => _EntityListScreenState();
}

class _EntityListScreenState extends State<EntityListScreen> {
  final Map<String, Map<int, String>> fkResolutions = {};
  bool loadingResolutions = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<EntityProvider>().load();
        _loadFkResolutions();
      }
    });
  }

  @override
  void didUpdateWidget(covariant EntityListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.definition != widget.definition) {
      fkResolutions.clear();
      _loadFkResolutions();
    }
  }

  Future<void> _loadFkResolutions() async {
    final fkFields = widget.definition.fields.where(
      (f) => f.type == FieldType.fkSelect && f.refEndpoint != null,
    );
    if (fkFields.isEmpty) return;
    setState(() => loadingResolutions = true);
    final service = context.read<AcademicService>();
    for (final field in fkFields) {
      try {
        final data = await service.list(field.refEndpoint!);
        final map = <int, String>{};
        for (final item in data) {
          final id = item['id'] as int?;
          if (id != null) {
            final labelVal = item[field.refLabelKey] ?? item['displayName'] ?? item['name'] ?? '#$id';
            map[id] = '$labelVal';
          }
        }
        fkResolutions[field.key] = map;
      } catch (e) {
        debugPrint('Error loading resolution for ${field.key}: $e');
      }
    }
    if (mounted) {
      setState(() => loadingResolutions = false);
    }
  }

  EntityField? _getField(String key) {
    for (final field in widget.definition.fields) {
      if (field.key == key) {
        return field;
      }
    }
    return null;
  }

  String _renderCellValue(String key, dynamic value) {
    if (value == null) return '';
    final field = _getField(key);
    if (field == null) return value.toString();

    if (field.type == FieldType.select && field.options != null) {
      return field.options![value.toString()] ?? value.toString();
    }

    if (field.type == FieldType.fkSelect) {
      final intId = value is int ? value : int.tryParse(value.toString());
      if (intId != null) {
        final resolutionMap = fkResolutions[field.key];
        if (resolutionMap != null && resolutionMap.containsKey(intId)) {
          return resolutionMap[intId]!;
        }
      }
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EntityProvider>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassPanel(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.definition.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _openForm(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SearchBar(
                  hintText: 'Поиск',
                  leading: const Icon(Icons.search),
                  onChanged: (value) {
                    provider.search = value;
                    provider.load();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GlassPanel(
              padding: EdgeInsets.zero,
              child: provider.loading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.error != null
                  ? Center(child: Text(provider.error!))
                  : provider.items.isEmpty
                  ? const Center(child: Text('Нет данных'))
                  : DataTable2(
                      minWidth: 780,
                      columns: [
                        const DataColumn2(
                          label: Text('ID'),
                          size: ColumnSize.S,
                        ),
                        for (final column in widget.definition.columns)
                          DataColumn2(
                            label: Text(_label(column)),
                            onSort: (_, ascending) {
                              provider.sort = ascending ? column : '-$column';
                              provider.load();
                            },
                          ),
                        const DataColumn2(
                          label: Text('Действия'),
                          size: ColumnSize.S,
                        ),
                      ],
                      rows: [
                        for (final item in provider.items)
                          DataRow(
                            cells: [
                              DataCell(Text('${item.id}')),
                              for (final column in widget.definition.columns)
                                DataCell(
                                  Text(
                                    _renderCellValue(column, item[column]),
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Редактировать',
                                      onPressed: () => _openForm(context, item),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip: 'Удалить',
                                      onPressed: () => provider.remove(item.id),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Показано: ${provider.items.length}'),
        ],
      ),
    );
  }

  String _label(String key) {
    for (final field in widget.definition.fields) {
      if (field.key == key) {
        return field.label;
      }
    }
    return key;
  }

  Future<void> _openForm(BuildContext context, [EntityModel? item]) async {
    // Read AcademicService BEFORE showDialog — dialog runs in a new route
    // and cannot access the ShellRoute's provider tree.
    final service = context.read<AcademicService>();
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => EntityFormDialog(
        definition: widget.definition,
        initial: item,
        academicService: service,
      ),
    );
    if (payload != null && context.mounted) {
      await context.read<EntityProvider>().save(payload, id: item?.id);
    }
  }
}
