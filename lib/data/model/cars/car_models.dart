import 'dart:io';
import 'package:Ebozor/data/model/category_model.dart';

class CarMake {
  final int id;
  final String name;
  final String? image;
  final int? activeStatus;
  final int? sortOrder;

  CarMake({
    required this.id,
    required this.name,
    this.image,
    this.activeStatus,
    this.sortOrder,
  });

  factory CarMake.fromJson(Map<String, dynamic> json) {
    return CarMake(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      image: json['image']?.toString(),
      activeStatus: json['active_status'] is int
          ? json['active_status']
          : int.tryParse(json['active_status']?.toString() ?? ''),
      sortOrder: json['sort_order'] is int
          ? json['sort_order']
          : int.tryParse(json['sort_order']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'active_status': activeStatus,
      'sort_order': sortOrder,
    };
  }

  @override
  String toString() => name;
}

class CarModelItem {
  final int id;
  final String name;
  final int? carMakeId;
  final String? makeName;

  CarModelItem({
    required this.id,
    required this.name,
    this.carMakeId,
    this.makeName,
  });

  factory CarModelItem.fromJson(Map<String, dynamic> json) {
    return CarModelItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      carMakeId: json['car_make_id'] is int
          ? json['car_make_id']
          : int.tryParse(json['car_make_id']?.toString() ?? ''),
      makeName: json['make_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'car_make_id': carMakeId,
      'make_name': makeName,
    };
  }

  @override
  String toString() => name;
}

class CarTrim {
  final int id;
  final String name;
  final int? carModelId;

  CarTrim({
    required this.id,
    required this.name,
    this.carModelId,
  });

  factory CarTrim.fromJson(Map<String, dynamic> json) {
    return CarTrim(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      carModelId: json['car_model_id'] is int
          ? json['car_model_id']
          : int.tryParse(json['car_model_id']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'car_model_id': carModelId,
    };
  }

  @override
  String toString() => name;
}

/// Holds all vehicle specs collected in Screen 1 ("Tell us about your car")
class CarSpecsData {
  final CategoryModel? category;
  final List<CategoryModel>? breadcrumbs;
  final String emirate;
  final CarMake? make;
  final CarModelItem? model;
  final CarTrim? trim;
  final String? customTrim;
  final String regionalSpecs;
  final int year;
  final int kilometers;
  final String bodyType;
  final double price;
  final String phoneNumber;

  CarSpecsData({
    this.category,
    this.breadcrumbs,
    required this.emirate,
    required this.make,
    required this.model,
    this.trim,
    this.customTrim,
    required this.regionalSpecs,
    required this.year,
    required this.kilometers,
    required this.bodyType,
    required this.price,
    required this.phoneNumber,
  });

  String get displayName {
    final makeStr = make?.name ?? '';
    final modelStr = model?.name ?? '';
    final trimStr = trim?.name ?? customTrim ?? '';
    return '$year $makeStr $modelStr ${trimStr.isNotEmpty ? trimStr : ''}'.trim();
  }

  String get effectiveTrim => trim?.name ?? customTrim ?? 'Base';
}

/// Holds complete data from Screen 2 ("You're almost there!")
class CarPostingData {
  final CarSpecsData specs;
  final List<File> imageFiles;
  final String title;
  final String description;
  final String interiorColor;
  final String exteriorColor;
  final String warranty;
  final String fuelType;
  final String doors;
  final String cylinders;
  final String transmission;
  final String seatingCapacity;
  final String horsepower;
  final String steeringSide;
  final String engineCapacity;
  final List<String> driverAssistance;
  final List<String> entertainmentTech;
  final List<String> comfortConvenience;
  final List<String> exteriorFeatures;
  final String locationNeighbourhood;
  final String? locationBuildingStreet;
  final String? locationApartmentVilla;
  final String locationLabel;
  final String locationAddress;

  CarPostingData({
    required this.specs,
    required this.imageFiles,
    required this.title,
    required this.description,
    required this.interiorColor,
    required this.exteriorColor,
    required this.warranty,
    required this.fuelType,
    required this.doors,
    required this.cylinders,
    required this.transmission,
    required this.seatingCapacity,
    required this.horsepower,
    required this.steeringSide,
    required this.engineCapacity,
    required this.driverAssistance,
    required this.entertainmentTech,
    required this.comfortConvenience,
    required this.exteriorFeatures,
    required this.locationNeighbourhood,
    this.locationBuildingStreet,
    this.locationApartmentVilla,
    required this.locationLabel,
    required this.locationAddress,
  });

  double get price => specs.price;
}

/// Model representing an Add-on or Package option
class CarPackageOption {
  final String id;
  final String title;
  final String badge;
  final String subtitle;
  final double price;
  final int durationDays;
  final bool isAddon;
  final String type; // 'standard', 'premium', 'featured'

  CarPackageOption({
    required this.id,
    required this.title,
    required this.badge,
    required this.subtitle,
    required this.price,
    required this.durationDays,
    required this.isAddon,
    required this.type,
  });
}
