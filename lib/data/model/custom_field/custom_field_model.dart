import 'dart:convert';

class CustomFieldModel {
  int? id;
  String? name;
  String? label;
  List? value;
  String? type;
  String? image;
  int? required;
  int? minLength;
  int? maxLength;
  dynamic values;
  bool? isFieldMultiselect;

  CustomFieldModel({
    this.id,
    this.name,
    this.label,
    this.type,
    this.values,
    this.image,
    this.required,
    this.maxLength,
    this.minLength,
    this.value,
    this.isFieldMultiselect,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'label': label,
      'type': type,
      'values': values,
      'image': image,
      'required': required,
      'min_length': minLength,
      'max_length': maxLength,
      'value': value,
      'is_field_multiselect': isFieldMultiselect,
    };
  }

  factory CustomFieldModel.fromMap(Map<String, dynamic> map) {
    int? parseRequired(dynamic req) {
      if (req == null) return null;
      if (req is bool) return req ? 1 : 0;
      if (req is int) return req;
      return int.tryParse(req.toString());
    }

    int? parseInt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      return int.tryParse(val.toString());
    }

    bool parseMultiselect(dynamic val) {
      if (val == null) return false;
      if (val is bool) return val;
      if (val is int) return val == 1;
      if (val is String) return val == '1' || val.toLowerCase() == 'true';
      return false;
    }

    List? parseValue(Map<String, dynamic> m) {
      dynamic val = m['value'];
      if (val == null && m['custom_field_value'] != null && m['custom_field_value'] is Map) {
        val = m['custom_field_value']['value'];
      }
      if (val == null && m['field_value'] != null) {
        val = m['field_value'];
      }
      if (val == null) return null;

      if (val is List) {
        final flatList = [];
        for (var item in val) {
          if (item is String && item.trim().startsWith('[') && item.trim().endsWith(']')) {
            try {
              final decoded = jsonDecode(item.trim());
              if (decoded is List) {
                flatList.addAll(decoded);
                continue;
              }
            } catch (_) {}
          }
          flatList.add(item);
        }
        return flatList;
      }

      if (val is String && val.trim().startsWith('[') && val.trim().endsWith(']')) {
        try {
          final decoded = jsonDecode(val.trim());
          if (decoded is List) return decoded;
        } catch (_) {}
      }

      return [val];
    }

    return CustomFieldModel(
      id: parseInt(map['id'] ?? map['custom_field_id']),
      name: (map['name'] ?? map['label_name'] ?? map['label'])?.toString(),
      label: (map['label'] ?? map['label_name'] ?? map['name'])?.toString(),
      type: (map['field_type'] ?? map['type'])?.toString(),
      values:
          (map['values'] ?? map['field_values'] ?? map['options']) as dynamic,
      image: map['image']?.toString(),
      required: parseRequired(map['required'] ?? map['is_required']),
      maxLength: parseInt(map['max_length']),
      minLength: parseInt(map['min_length']),
      value: parseValue(map),
      isFieldMultiselect: parseMultiselect(map['is_field_multiselect'] ??
          map['is_multiselect'] ??
          map['is_multiple'] ??
          map['multiselect']),
    );
  }

  @override
  String toString() {
    return 'CustomFieldModel(id: $id, name: $name, label: $label, type: $type, image: $image, required: $required, minLength: $minLength, maxLength: $maxLength, values: $values, value: $value, isFieldMultiselect: $isFieldMultiselect)';
  }
}

class VerificationFieldModel {
  int? id;
  String? name;
  String? type;
  int? required;
  int? minLength;
  int? maxLength;
  String? status;
  dynamic values;

  int? get isRequired => required;

  VerificationFieldModel({
    this.id,
    this.name,
    this.type,
    this.values,
    this.required,
    this.maxLength,
    this.minLength,
    this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'values': values,
      'required': required,
      'min_length': minLength,
      'max_length': maxLength,
      'status': status,
    };
  }

  factory VerificationFieldModel.fromMap(Map<String, dynamic> map) {
    int? parseRequired(dynamic req) {
      if (req == null) return null;
      if (req is bool) return req ? 1 : 0;
      if (req is int) return req;
      return int.tryParse(req.toString());
    }

    int? parseInt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      return int.tryParse(val.toString());
    }

    return VerificationFieldModel(
      id: parseInt(map['id']),
      name: map['name']?.toString(),
      type: map['type']?.toString(),
      values: map['values'] as dynamic,
      required: parseRequired(map['is_required'] ?? map['required']),
      maxLength: parseInt(map['max_length']),
      minLength: parseInt(map['min_length']),
      status: map['status']?.toString(),
    );
  }

  @override
  String toString() {
    return 'VerificationFieldModel(id: $id, name: $name, type: $type, required: $required, minLength: $minLength, maxLength: $maxLength, values: $values,status:$status)';
  }
}
