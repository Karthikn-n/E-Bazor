class CustomFieldModel {
  int? id;
  String? name;
  List? value;
  String? type;
  String? image;
  int? required;
  int? minLength;
  int? maxLength;
  dynamic values;

  CustomFieldModel(
      {this.id,
      this.name,
      this.type,
      this.values,
      this.image,
      this.required,
      this.maxLength,
      this.minLength,
      this.value});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'values': values,
      'image': image,
      'required': required,
      'min_length': minLength,
      'max_length': maxLength,
      'value': value,
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

    return CustomFieldModel(
      id: parseInt(map['id']),
      name: map['name']?.toString(),
      type: map['type']?.toString(),
      values: map['values'] as dynamic,
      image: map['image']?.toString(),
      required: parseRequired(map['required'] ?? map['is_required']),
      maxLength: parseInt(map['max_length']),
      minLength: parseInt(map['min_length']),
      value: map['value'] is List ? map['value'] : (map['value'] != null ? [map['value']] : null),
    );
  }

  @override
  String toString() {
    return 'CustomFieldModel(id: $id, name: $name, type: $type, image: $image, required: $required, minLength: $minLength, maxLength: $maxLength, values: $values,value:$value)';
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
