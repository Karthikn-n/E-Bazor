class VerificationRequestModel {
  int? id;
  int? userId;
  String? status;
  String? createdAt;
  String? updatedAt;
  String? rejectionReason;
  List<VerificationFieldValues>? verificationFieldValues;

  VerificationRequestModel({
    this.id,
    this.userId,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.rejectionReason,
    this.verificationFieldValues,
  });

  VerificationRequestModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    userId = json['user_id'];
    status = json['status'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    rejectionReason = json['rejection_reason'];
    if (json['verification_field_values'] != null) {
      verificationFieldValues = <VerificationFieldValues>[];
      json['verification_field_values'].forEach((v) {
        verificationFieldValues!.add(VerificationFieldValues.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['user_id'] = userId;
    data['status'] = status;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['rejection_reason'] = rejectionReason;
    if (verificationFieldValues != null) {
      data['verification_field_values'] =
          verificationFieldValues!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class VerificationFieldValues {
  int? id;
  int? verificationFieldId;
  String? value;
  int? userId;
  int? verificationRequestId;
  String? createdAt;
  String? updatedAt;

  VerificationFieldValues({
    this.id,
    this.verificationFieldId,
    this.value,
    this.userId,
    this.verificationRequestId,
    this.createdAt,
    this.updatedAt,
  });

  VerificationFieldValues.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    verificationFieldId = json['verification_field_id'];
    value = json['value'];
    userId = json['user_id'];
    verificationRequestId = json['verification_request_id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['verification_field_id'] = verificationFieldId;
    data['value'] = value;
    data['user_id'] = userId;
    data['verification_request_id'] = verificationRequestId;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    return data;
  }
}
