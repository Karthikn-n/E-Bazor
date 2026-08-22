class UserAddressModel {
  final int? id;
  final int? userId;
  final String? neighbourhood;
  final String? streetName;
  final String? apartmentNumber;
  final String? label;
  final bool? isDefault;
  final double? lat;
  final double? lan;

  UserAddressModel({
    this.id,
    this.userId,
    this.neighbourhood,
    this.streetName,
    this.apartmentNumber,
    this.label,
    this.isDefault,
    this.lat,
    this.lan,
  });

  factory UserAddressModel.fromJson(Map<String, dynamic> json) {
    return UserAddressModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id']?.toString() ?? ''),
      neighbourhood: json['neighbourhood']?.toString(),
      streetName: json['street_name']?.toString(),
      apartmentNumber: json['apartment_number']?.toString(),
      label: json['label']?.toString() ?? 'Home',
      isDefault: json['default'] == 1 || json['default'] == true || json['default'] == '1',
      lat: json['lat'] != null ? double.tryParse(json['lat'].toString()) : null,
      lan: json['lan'] != null
          ? double.tryParse(json['lan'].toString())
          : (json['long'] != null ? double.tryParse(json['long'].toString()) : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      'neighbourhood': neighbourhood,
      'street_name': streetName,
      'apartment_number': apartmentNumber,
      'label': label,
      'default': (isDefault == true) ? 1 : 0,
      if (lat != null) 'lat': lat,
      if (lan != null) 'lan': lan,
    };
  }

  String get fullAddressFormatted {
    final parts = [
      apartmentNumber,
      streetName,
      neighbourhood,
    ].where((p) => p != null && p.trim().isNotEmpty).toList();
    return parts.isNotEmpty ? parts.join(", ") : "Location details not specified";
  }
}
