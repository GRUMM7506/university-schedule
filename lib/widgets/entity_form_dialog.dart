import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/entity_model.dart';
import '../services/academic_service.dart';

class EntityFormDialog extends StatefulWidget {
  const EntityFormDialog({
    super.key,
    required this.definition,
    required this.academicService,
    this.initial,
  });

  final EntityDefinition definition;
  final EntityModel? initial;
  final AcademicService academicService;

  @override
  State<EntityFormDialog> createState() => _EntityFormDialogState();
}

/// Only Cyrillic/Latin letters, spaces and hyphens — used for ФИО-style
/// fields so a name can't accidentally end up with a digit or symbol in it.
final RegExp _fioAllowed = RegExp(r'^[A-Za-zА-Яа-яЁё\s\-]*$');

/// Digits, spaces, +, - and parentheses — enough for any phone format
/// without allowing letters or stray punctuation.
final RegExp _phoneAllowed = RegExp(r'^[0-9\s\-()+]*$');

class _EntityFormDialogState extends State<EntityFormDialog> {
  final formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> controllers;
  // Selected int values for fkSelect fields
  final Map<String, int?> fkValues = {};
  // Loaded reference data for fkSelect fields
  final Map<String, List<Map<String, dynamic>>> allFkOptions = {};
  final Map<String, List<Map<String, dynamic>>> fkOptions = {};
  bool loadingRefs = false;

  @override
  void initState() {
    super.initState();
    controllers = {
      for (final field in widget.definition.fields)
        field.key: TextEditingController(
          text: widget.initial?[field.key]?.toString() ?? '',
        ),
    };
    // Pre-populate fkValues from initial data
    for (final field in widget.definition.fields) {
      if (field.type == FieldType.fkSelect) {
        final v = widget.initial?[field.key];
        fkValues[field.key] = v is int ? v : int.tryParse(v?.toString() ?? '');
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFkRefs());
  }

  Future<void> _loadFkRefs() async {
    final fkFields = widget.definition.fields.where(
      (f) => f.type == FieldType.fkSelect && f.refEndpoint != null,
    );
    if (fkFields.isEmpty) return;
    setState(() => loadingRefs = true);
    // Use the service passed in — avoids Provider lookup across route boundaries
    for (final field in fkFields) {
      try {
        final data = await widget.academicService.list(field.refEndpoint!);
        allFkOptions[field.key] = data;
        fkOptions[field.key] = data;
      } catch (_) {
        allFkOptions[field.key] = [];
        fkOptions[field.key] = [];
      }
    }
    if (mounted) {
      for (final field in widget.definition.fields) {
        _applyFilter(field);
      }
    }

    setState(() {
      loadingRefs = false;
    });
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _applyFilter(EntityField field) {
  if (field.dependsOn.isEmpty) {
    fkOptions[field.key] = allFkOptions[field.key] ?? [];
    return;
  }

  final source = allFkOptions[field.key] ?? [];

  fkOptions[field.key] = source.where((item) {
    for (final parent in field.dependsOn) {
      final selected = fkValues[parent];

      if (selected != null && item[parent] != selected) {
        return false;
      }
    }

    return true;
  }).toList();
}

  void _updateChildren(String parentKey) {
    for (final field in widget.definition.fields) {
      if (!field.dependsOn.contains(parentKey)) continue;

      _applyFilter(field);

      final list = fkOptions[field.key]!;

      if (list.isEmpty) {
        fkValues[field.key] = null;
      } else {
        if (!list.any((e) => e['id'] == fkValues[field.key])) {
  fkValues[field.key] = list.isEmpty ? null : list.first['id'];
}
      }

      _updateChildren(field.key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.initial == null ? 'Добавить' : 'Редактировать'),
      content: SizedBox(
        width: 560,
        child: loadingRefs
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final field in widget.definition.fields)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _field(field, scheme),
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

  Future<void> _pickDate(EntityField field) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (selected != null) {
      setState(() {
        controllers[field.key]!.text = DateFormat('dd.MM.yyyy').format(selected);
      });
    }
  }

  Widget _field(EntityField field, ColorScheme scheme) {
    if (field.type == FieldType.fkSelect) {
      final options = fkOptions[field.key] ?? [];
      final currentVal = fkValues[field.key];
      // Ensure current value exists in options; if not, reset to null
      final validVal = options.any((e) => e['id'] == currentVal)
          ? currentVal
          : null;

      return DropdownButtonFormField<int>(
        initialValue: validVal,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: field.label,
          prefixIcon: Icon(
            Icons.link_outlined,
            size: 18,
            color: scheme.primary,
          ),
        ),
        menuMaxHeight: 320,
        items: options.map((e) {
          final id = e['id'] as int;
          final labelVal = e[field.refLabelKey] ?? e['name'] ?? '#$id';
          return DropdownMenuItem<int>(
            value: id,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#$id',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$labelVal',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (v) {
          setState(() {
            fkValues[field.key] = v;
            _updateChildren(field.key);
          });
        },
        validator: (v) =>
            field.required && v == null ? 'Выберите значение' : null,
      );
    }

    if (field.type == FieldType.select) {
      return DropdownButtonFormField<String>(
        initialValue: controllers[field.key]!.text.isEmpty
            ? null
            : controllers[field.key]!.text,
        isExpanded: true,
        decoration: InputDecoration(labelText: field.label),
        menuMaxHeight: 320,
        items: field.options!.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (value) => controllers[field.key]!.text = value ?? '',
        validator: (value) => field.required && (value == null || value.isEmpty)
            ? 'Заполните поле'
            : null,
      );
    }

    if (field.type == FieldType.date) {
      return Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controllers[field.key],
              decoration: InputDecoration(
                labelText: field.label,
                hintText: 'дд.мм.гггг',
              ),
              keyboardType: TextInputType.datetime,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (field.required && text.isEmpty) return 'Заполните поле';
                if (text.isNotEmpty) {
                  try {
                    if (field.type == FieldType.date) {
                      DateFormat('dd.MM.yyyy').parseStrict(text);
                    }
                    return null;
                  } catch (_) {
                    return 'Формат даты: дд.мм.гггг';
                  }
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => _pickDate(field),
            child: const Icon(Icons.calendar_today_outlined),
          ),
        ],
      );
    }

    return TextFormField(
      controller: controllers[field.key],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: field.label,
      ),
      keyboardType: switch (field.type) {
        FieldType.number => TextInputType.number,
        FieldType.email => TextInputType.emailAddress,
        FieldType.phone => TextInputType.phone,
        _ => TextInputType.text,
      },
      validator: (value) => _validateTextField(field, value),
    );
  }

  String? _validateTextField(EntityField field, String? value) {
    final text = value?.trim() ?? '';
    if (field.required && text.isEmpty) return 'Заполните поле';
    if (text.isEmpty) return null;
    
    if (field.type == FieldType.number) {
      if (int.tryParse(text) == null) {
        return 'Здесь можно использовать только цифры';
      }
    }
    
    if (field.type == FieldType.email) {
      final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      if (!emailPattern.hasMatch(text)) {
        return 'Введите корректный email';
      }
    }
    if (field.type == FieldType.fio) {
      if (!_fioAllowed.hasMatch(text)) {
        return 'Здесь можно использовать только буквы, пробел и дефис';
      }
      if (text.trim().split(RegExp(r'\s+')).length < 2 && field.key == 'fio') {
        return 'Укажите фамилию и имя';
      }
    }
    if (field.type == FieldType.phone) {
      final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
      if (!_phoneAllowed.hasMatch(text) || digitsOnly.length < 7) {
        return 'Здесь можно использовать только цифры и символы + - ( )';
      }
    }
    if (field.type == FieldType.date) {
      try {
        DateFormat('dd.MM.yyyy').parseStrict(text);
        return null;
      } catch (_) {
        return 'Формат даты: дд.мм.гггг';
      }
    }
    return null;
  }

  void _submit() {
    if (!formKey.currentState!.validate()) return;
    final payload = <String, dynamic>{};
    for (final field in widget.definition.fields) {
      if (field.type == FieldType.fkSelect) {
        payload[field.key] = fkValues[field.key];
      } else {
        final value = controllers[field.key]!.text.trim();
        if (value.isEmpty && !field.required) {
          payload[field.key] = null;
        } else if (field.type == FieldType.number) {
          payload[field.key] = int.parse(value);
        } else if (field.type == FieldType.select && int.tryParse(value) != null) {
          payload[field.key] = int.parse(value);
        } else {
          // date and other string types
          if (field.type == FieldType.date) {
            final date = DateFormat('dd.MM.yyyy').parseStrict(value);
            payload[field.key] = DateFormat('yyyy-MM-dd').format(date);
          }
          else if (field.type == FieldType.number) {
            payload[field.key] = int.parse(value);
          }
          else {
            payload[field.key] = value;
          }
        }
      }
    }
    Navigator.pop(context, payload);
  }
}
