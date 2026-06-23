import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/entity_model.dart';
import '../providers/entity_provider.dart';
import '../widgets/entity_form_dialog.dart';
import '../widgets/glass.dart';

class EntityListScreen extends StatefulWidget {
  const EntityListScreen({super.key, required this.definition});

  final EntityDefinition definition;

  @override
  State<EntityListScreen> createState() => _EntityListScreenState();
}

class _EntityListScreenState extends State<EntityListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<EntityProvider>().load();
      }
    });
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
                                DataCell(Text('${item[column] ?? ''}')),
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
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          EntityFormDialog(definition: widget.definition, initial: item),
    );
    if (payload != null && context.mounted) {
      await context.read<EntityProvider>().save(payload, id: item?.id);
    }
  }
}
