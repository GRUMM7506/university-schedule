import 'package:flutter/material.dart';

import '../models/entity_model.dart';

class EntityFormDialog extends StatefulWidget {
  const EntityFormDialog({super.key, required this.definition, this.initial});

  final EntityDefinition definition;
  final EntityModel? initial;

  @override
  State<EntityFormDialog> createState() => _EntityFormDialogState();
}

class _EntityFormDialogState extends State<EntityFormDialog> {
  final formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> controllers;

  @override
  void initState() {
    super.initState();
    controllers = {
      for (final field in widget.definition.fields)
        field.key: TextEditingController(
          text: widget.initial?[field.key]?.toString() ?? '',
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Добавить' : 'Редактировать'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in widget.definition.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _field(field),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Сохранить'),
        ),
      ],
    );
  }

  Widget _field(EntityField field) {
    if (field.type == FieldType.select) {
      return DropdownButtonFormField<String>(
        initialValue: controllers[field.key]!.text.isEmpty
            ? null
            : controllers[field.key]!.text,
        decoration: InputDecoration(
          labelText: field.label,
          border: const OutlineInputBorder(),
        ),
        items: field.options!.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (value) => controllers[field.key]!.text = value ?? '',
        validator: (value) => field.required && (value == null || value.isEmpty)
            ? 'Заполните поле'
            : null,
      );
    }
    return TextFormField(
      controller: controllers[field.key],
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: switch (field.type) {
        FieldType.number => TextInputType.number,
        FieldType.email => TextInputType.emailAddress,
        _ => TextInputType.text,
      },
      validator: (value) =>
          field.required && (value == null || value.trim().isEmpty)
          ? 'Заполните поле'
          : null,
    );
  }

  void _submit() {
    if (!formKey.currentState!.validate()) {
      return;
    }
    final payload = <String, dynamic>{};
    for (final field in widget.definition.fields) {
      final value = controllers[field.key]!.text.trim();
      if (value.isEmpty && !field.required) {
        payload[field.key] = null;
      } else if (field.type == FieldType.number ||
          field.type == FieldType.select && int.tryParse(value) != null) {
        payload[field.key] = int.parse(value);
      } else {
        payload[field.key] = value;
      }
    }
    Navigator.pop(context, payload);
  }
}
