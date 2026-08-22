class UserDeviceModel {
  final int? id;
  final String? deviceName;
  final String? platform;
  final String? lastUsedAt;
  final bool? isCurrent;
  final String? location;

  UserDeviceModel({
    this.id,
    this.deviceName,
    this.platform,
    this.lastUsedAt,
    this.isCurrent,
    this.location,
  });

  factory UserDeviceModel.fromJson(Map<String, dynamic> json) {
    return UserDeviceModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      deviceName: json['device_name']?.toString(),
      platform: json['platform']?.toString(),
      lastUsedAt: json['last_used_at']?.toString(),
      isCurrent: json['is_current'] == true || json['is_current'] == 1 || json['is_current'] == '1',
      location: json['location']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_name': deviceName,
      'platform': platform,
      'last_used_at': lastUsedAt,
      'is_current': isCurrent,
      'location': location,
    };
  }
}
