import 'dart:convert';
import 'dart:io';

import 'package:Ebozor/data/model/custom_field/custom_field_model.dart';
import 'package:Ebozor/ui/screens/item/add_item_screen/widgets/posting_form_shared.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class DynamicCustomFieldsController extends ChangeNotifier {
  List<CustomFieldModel> _fields = const [];
  final Map<int, TextEditingController> _text = {};
  final Map<int, List<String>> _selected = {};
  final Map<int, File> _files = {};
  final Set<int> _expandedMultiselects = {};
  bool _showErrors = false;

  List<CustomFieldModel> get fields => List.unmodifiable(_fields);

  void replaceFields(List<CustomFieldModel> fields) {
    final unique = <int, CustomFieldModel>{};
    for (final field in fields) {
      if (field.id != null) unique[field.id!] = field;
    }
    _fields = unique.values.toList(growable: false);
    final ids = unique.keys.toSet();
    for (final id in _text.keys.toList()) {
      if (!ids.contains(id)) _text.remove(id)?.dispose();
    }
    _selected.removeWhere((id, _) => !ids.contains(id));
    _files.removeWhere((id, _) => !ids.contains(id));
    _expandedMultiselects.removeWhere((id) => !ids.contains(id));
    for (final field in _fields) {
      final initial = _values(field.value);
      if (_isFile(field)) {
        continue;
      } else if (_isText(field)) {
        final controller = textController(field);
        if (initial.isNotEmpty) {
          controller.text = initial.first;
        }
      } else {
        if (initial.isNotEmpty || !_selected.containsKey(field.id!)) {
          _selected[field.id!] = initial;
        }
      }
    }
    notifyListeners();
  }

  TextEditingController textController(CustomFieldModel field) =>
      _text.putIfAbsent(
        field.id!,
        () => TextEditingController()..addListener(notifyListeners),
      );

  List<String> selected(CustomFieldModel field) =>
      List.unmodifiable(_selected[field.id!] ?? const <String>[]);

  void selectOne(CustomFieldModel field, String? value) {
    _selected[field.id!] = value == null ? [] : [value];
    notifyListeners();
  }

  void selectMany(CustomFieldModel field, Iterable<String> values) {
    _selected[field.id!] = values.toSet().toList(growable: false);
    notifyListeners();
  }

  bool isMultiselectExpanded(CustomFieldModel field) =>
      field.id != null && _expandedMultiselects.contains(field.id);

  void toggleMultiselect(CustomFieldModel field) {
    final id = field.id;
    if (id == null) return;
    _expandedMultiselects.contains(id)
        ? _expandedMultiselects.remove(id)
        : _expandedMultiselects.add(id);
    notifyListeners();
  }

  void toggleOption(CustomFieldModel field, String option) {
    final values = {...selected(field)};
    values.contains(option) ? values.remove(option) : values.add(option);
    selectMany(field, values);
  }

  File? selectedFile(CustomFieldModel field) =>
      field.id == null ? null : _files[field.id!];

  Future<void> pickFile(CustomFieldModel field) async {
    final id = field.id;
    if (id == null) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'svg'],
    );
    final filePath = (result.isNotEmpty) ? result.first.path : null;
    if (filePath == null || filePath.isEmpty) return;
    _files[id] = File(filePath);
    notifyListeners();
  }

  void removeFile(CustomFieldModel field) {
    if (field.id != null) {
      _files.remove(field.id);
      notifyListeners();
    }
  }

  List<String> valueOf(CustomFieldModel field) {
    if (field.id == null) return const [];
    if (_isFile(field)) {
      final file = _files[field.id!];
      return file == null ? const [] : [path.basename(file.path)];
    }
    if (_isText(field)) {
      final value = _text[field.id!]?.text.trim() ?? '';
      return value.isEmpty ? const [] : [value];
    }
    return (_selected[field.id!] ?? const <String>[])
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);
  }

  String? validate() {
    _showErrors = true;
    String? first;
    for (final field in _fields) {
      first ??= errorFor(field);
    }
    notifyListeners();
    return first;
  }

  String? errorFor(CustomFieldModel field) {
    if (!_showErrors) return null;
    final value = valueOf(field);
    final label = _label(field);
    if (field.required == 1 && value.isEmpty) return '$label is required';
    if (_isText(field) && value.isNotEmpty) {
      if (field.minLength != null && value.first.length < field.minLength!) {
        return '$label must be at least ${field.minLength} characters';
      }
      if (field.maxLength != null && value.first.length > field.maxLength!) {
        return '$label must be at most ${field.maxLength} characters';
      }
    }
    return null;
  }

  Map<String, List<String>> toSubmissionMap() {
    final result = <String, List<String>>{};
    for (final field in _fields) {
      final value = valueOf(field);
      if (field.id != null && !_isFile(field) && value.isNotEmpty) {
        result[field.id!.toString()] = value;
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> toFileSubmissionMap() async {
    final result = <String, dynamic>{};
    for (final entry in _files.entries) {
      result['custom_field_files[${entry.key}]'] = await MultipartFile.fromFile(
        entry.value.path,
        filename: path.basename(entry.value.path),
      );
    }
    return result;
  }

  @override
  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

class DynamicCustomFieldsForm extends StatelessWidget {
  final DynamicCustomFieldsController controller;
  final bool isLoading;

  const DynamicCustomFieldsForm({
    super.key,
    required this.controller,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && controller.fields.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final field in controller.fields) ...[
            PostingFieldLabel(
              '${_label(field)}${field.required == 1 ? ' *' : ''}',
            ),
            _field(context, field),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }

  Widget _field(BuildContext context, CustomFieldModel field) {
    final type = (field.type ?? '').trim().toLowerCase();
    final options = customFieldOptions(field.values);
    final error = controller.errorFor(field);
    if (_isFile(field)) {
      final selectedFile = controller.selectedFile(field);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: () => controller.pickFile(field),
            icon: const Icon(Icons.attach_file_rounded),
            label: Text(
              selectedFile == null
                  ? 'Choose file'
                  : path.basename(selectedFile.path),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (selectedFile != null)
            InputChip(
              avatar: const Icon(Icons.insert_drive_file_rounded, size: 18),
              label: Text(
                path.basename(selectedFile.path),
                overflow: TextOverflow.ellipsis,
              ),
              deleteIcon: const Icon(Icons.close_rounded, size: 17),
              onDeleted: () => controller.removeFile(field),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                error,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      );
    }
    if (_isText(field)) {
      final number = type == 'number' || type == 'numeric';
      return TextFormField(
        controller: controller.textController(field),
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        maxLines: type == 'textarea' ? 4 : 1,
        maxLength: field.maxLength,
        decoration: _decoration(context, 'Enter ${_label(field)}', error),
      );
    }

    final multi = field.isFieldMultiselect == true || type == 'checkbox';
    if (multi) {
      final selected = controller.selected(field);
      final expanded = controller.isMultiselectExpanded(field);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: options.isEmpty
                ? null
                : () => controller.toggleMultiselect(field),
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration:
                  _decoration(context, 'Select ${_label(field)}', error),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selected.isEmpty
                          ? 'Select ${_label(field)}'
                          : '${selected.length} selected',
                      style: TextStyle(
                        color: selected.isEmpty
                            ? context.color.textLightColor
                            : context.color.textDefaultColor,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                ],
              ),
            ),
          ),
          if (expanded && options.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.color.borderColor),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  return Material(
                    color: Colors.transparent,
                    child: CheckboxListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      value: selected.contains(option),
                      title: Text(option),
                      onChanged: (_) => controller.toggleOption(field, option),
                    ),
                  );
                },
              ),
            ),
          ],
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selected
                  .map(
                    (option) => InputChip(
                      label: Text(option),
                      deleteIcon: const Icon(Icons.close_rounded, size: 17),
                      onDeleted: () => controller.toggleOption(field, option),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      );
    }

    if ((type == 'button' || type == 'radio') && options.isNotEmpty) {
      final selected = controller.selected(field).firstOrNull?.trim().toLowerCase();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map((option) => ChoiceChip(
                      label: Text(option),
                      selected: selected == option.trim().toLowerCase(),
                      onSelected: (_) => controller.selectOne(field, option),
                    ))
                .toList(growable: false),
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(error,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      );
    }

    final selected = controller.selected(field).firstOrNull?.trim().toLowerCase();
    final matchingOption = options.firstWhere(
      (opt) => opt.trim().toLowerCase() == selected,
      orElse: () => '',
    );

    return DropdownButtonFormField<String>(
      initialValue: matchingOption.isNotEmpty ? matchingOption : null,
      isExpanded: true,
      dropdownColor: context.color.secondaryColor,
      borderRadius: BorderRadius.circular(12),
      menuMaxHeight: 320,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      decoration: _decoration(context, 'Select ${_label(field)}', error),
      hint: Text('Select ${_label(field)}'),
      items: options
          .map((option) => DropdownMenuItem(
                value: option,
                child: Text(option, overflow: TextOverflow.ellipsis),
              ))
          .toList(growable: false),
      onChanged: options.isEmpty
          ? null
          : (value) => controller.selectOne(field, value),
    );
  }

  InputDecoration _decoration(
    BuildContext context,
    String hint,
    String? error,
  ) {
    return InputDecoration(
      hintText: hint,
      errorText: error,
      filled: true,
      fillColor: context.color.secondaryColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: context.color.borderColor.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

bool _isText(CustomFieldModel field) {
  final type = (field.type ?? '').trim().toLowerCase();
  if (const {'number', 'numeric', 'text', 'textbox', 'textarea'}
      .contains(type)) {
    return true;
  }
  return customFieldOptions(field.values).isEmpty &&
      !const {'dropdown', 'radio', 'button', 'checkbox', 'select'}
          .contains(type);
}

bool _isFile(CustomFieldModel field) {
  final type = (field.type ?? '').trim().toLowerCase();
  return const {'file', 'fileinput', 'file_input', 'upload'}.contains(type);
}

String _label(CustomFieldModel field) {
  final label = field.label?.trim();
  if (label != null && label.isNotEmpty) return label;
  final name = field.name?.trim();
  return name == null || name.isEmpty ? 'Field' : name;
}

List<String> customFieldOptions(dynamic raw) {
  if (raw == null) return const [];
  if (raw is List) {
    final result = <String>[];
    for (final item in raw) {
      if (item == null) continue;
      final itemStr = item.toString().trim();
      if (itemStr.isEmpty) continue;
      if (itemStr.startsWith('[') && itemStr.endsWith(']')) {
        try {
          final decoded = jsonDecode(itemStr);
          if (decoded is List) {
            result.addAll(customFieldOptions(decoded));
            continue;
          }
        } catch (_) {}
      }
      result.add(itemStr);
    }
    return result.toSet().toList(growable: false);
  }
  if (raw is String) {
    final value = raw.trim();
    if (value.isEmpty) return const [];
    if (value.startsWith('[') && value.endsWith(']')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return customFieldOptions(decoded);
      } catch (_) {}
    }
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
  final str = raw.toString().trim();
  return str.isEmpty ? const [] : [str];
}

List<String> _values(dynamic raw) => customFieldOptions(raw);

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
