import 'dart:developer';
import 'package:Ebozor/data/model/cars/car_models.dart';
import 'package:Ebozor/utils/ApiService/api.dart';

class CarsRepository {
  /// Fetches all Car Makes from API with robust fallback
  Future<List<CarMake>> fetchCarMakes() async {
    try {
      log("🚗 [CARS API] Fetching car makes from ${Api.getCarMakesApi}...");
      final response = await Api.get(url: Api.getCarMakesApi);
      log("📦 [CARS API RES: car_makes] 👉 $response");

      dynamic rawData = response;
      if (response.containsKey('data')) {
        rawData = response['data'];
      }

      if (rawData is List && rawData.isNotEmpty) {
        List<CarMake> list = rawData.map((e) => CarMake.fromJson(e)).toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      }
    } catch (e) {
      log("⚠️ [CARS API WARN: car_makes fallback] 👉 $e");
    }

    // Fallback comprehensive list of UAE Car Makes
    return _getDefaultCarMakes();
  }

  /// Fetches Models for a specific Make ID
  Future<List<CarModelItem>> fetchCarModels(int makeId, {String? makeName}) async {
    try {
      log("🚗 [CARS API] Fetching car models for make_id: $makeId...");
      final response = await Api.get(url: "${Api.getCarModelsApi}/$makeId");
      log("📦 [CARS API RES: car_models] 👉 $response");

      dynamic rawData = response;
      if (response.containsKey('data')) {
        rawData = response['data'];
      }

      if (rawData is List && rawData.isNotEmpty) {
        List<CarModelItem> list =
            rawData.map((e) => CarModelItem.fromJson(e)).toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      }
    } catch (e) {
      log("⚠️ [CARS API WARN: car_models fallback] 👉 $e");
    }

    // Fallback models based on make name
    return _getDefaultModelsForMake(makeId, makeName);
  }

  /// Fetches Trims for a specific Model ID
  Future<List<CarTrim>> fetchCarModelTrims(int modelId, {String? modelName}) async {
    try {
      log("🚗 [CARS API] Fetching car model trims for model_id: $modelId...");
      final response = await Api.get(url: "${Api.getCarModelTrimsApi}/$modelId");
      log("📦 [CARS API RES: car_model_trims] 👉 $response");

      dynamic rawData = response;
      if (response.containsKey('data')) {
        rawData = response['data'];
      }

      if (rawData is List && rawData.isNotEmpty) {
        List<CarTrim> list = rawData.map((e) => CarTrim.fromJson(e)).toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      }
    } catch (e) {
      log("⚠️ [CARS API WARN: car_model_trims fallback] 👉 $e");
    }

    // Fallback trims
    return _getDefaultTrims(modelId);
  }

  /// Comprehensive UAE Car Makes fallback list
  List<CarMake> _getDefaultCarMakes() {
    final makes = [
      "Toyota",
      "Nissan",
      "Mercedes-Benz",
      "BMW",
      "Lexus",
      "Porsche",
      "Land Rover",
      "Audi",
      "Ford",
      "Hyundai",
      "Kia",
      "Honda",
      "Chevrolet",
      "Jeep",
      "Volkswagen",
      "Tesla",
      "Mitsubishi",
      "Ferrari",
      "Lamborghini",
      "Rolls-Royce",
      "Bentley",
      "Aston Martin",
      "Dodge",
      "GMC",
      "Infiniti",
      "Mazda",
      "Maserati",
      "McLaren",
      "Mini",
      "Subaru",
      "Suzuki",
      "Volvo",
      "Cadillac",
      "Jaguar",
      "Alfa Romeo",
      "Genesis",
      "BYD",
      "Changan",
      "Geely",
      "Haval",
      "MG",
      "Chery",
      "Jetour",
      "Tank",
      "GAC",
      "Exeed",
      "Hongqi",
      "Zeekr",
      "Other Make"
    ];

    return makes.asMap().entries.map((entry) {
      return CarMake(id: entry.key + 1, name: entry.value);
    }).toList();
  }

  /// Default popular models for common makes
  List<CarModelItem> _getDefaultModelsForMake(int makeId, String? makeName) {
    final normalized = (makeName ?? "").toLowerCase().trim();
    List<String> models = [];

    if (normalized.contains("toyota")) {
      models = [
        "Land Cruiser",
        "Prado",
        "Camry",
        "Corolla",
        "RAV4",
        "Fortuner",
        "Hilux",
        "Yaris",
        "Highlander",
        "FJ Cruiser",
        "Supra",
        "Innova",
        "Crown",
        "Veloz",
        "Avalon"
      ];
    } else if (normalized.contains("nissan")) {
      models = [
        "Patrol",
        "Altima",
        "Sunny",
        "X-Trail",
        "Pathfinder",
        "Kicks",
        "Maxima",
        "GT-R",
        "Navara",
        "Urvan",
        "Magnite",
        "Z"
      ];
    } else if (normalized.contains("mercedes")) {
      models = [
        "G-Class",
        "S-Class",
        "E-Class",
        "C-Class",
        "GLE-Class",
        "GLC-Class",
        "GLS-Class",
        "A-Class",
        "CLA-Class",
        "CLS-Class",
        "AMG GT",
        "SL-Class",
        "EQS",
        "EQE"
      ];
    } else if (normalized.contains("bmw")) {
      models = [
        "X5",
        "X6",
        "X7",
        "7 Series",
        "5 Series",
        "3 Series",
        "4 Series",
        "X3",
        "X1",
        "M3",
        "M4",
        "M5",
        "8 Series",
        "i7",
        "iX"
      ];
    } else if (normalized.contains("lexus")) {
      models = [
        "LX 600",
        "LX 570",
        "GX 460",
        "RX 350",
        "ES 350",
        "IS 300",
        "LS 500",
        "NX 300",
        "UX 200",
        "LC 500",
        "RC F"
      ];
    } else if (normalized.contains("porsche")) {
      models = [
        "Cayenne",
        "911",
        "Panamera",
        "Macan",
        "Taycan",
        "718 Boxster",
        "718 Cayman"
      ];
    } else if (normalized.contains("land rover") || normalized.contains("range rover")) {
      models = [
        "Range Rover",
        "Range Rover Sport",
        "Defender",
        "Range Rover Velar",
        "Range Rover Evoque",
        "Discovery",
        "Discovery Sport"
      ];
    } else if (normalized.contains("audi")) {
      models = [
        "Q7",
        "Q8",
        "A6",
        "A8",
        "A4",
        "Q5",
        "Q3",
        "RS6",
        "RS7",
        "R8",
        "e-tron GT"
      ];
    } else if (normalized.contains("ford")) {
      models = [
        "Mustang",
        "F-150",
        "Explorer",
        "Expedition",
        "Ranger",
        "Bronco",
        "Edge",
        "Territory",
        "Taurus"
      ];
    } else if (normalized.contains("hyundai")) {
      models = [
        "Tucson",
        "Santa Fe",
        "Elantra",
        "Sonata",
        "Creta",
        "Accent",
        "Palisade",
        "Kona",
        "Staria"
      ];
    } else if (normalized.contains("kia")) {
      models = [
        "Sportage",
        "Sorento",
        "Telluride",
        "K5",
        "Cerato",
        "Pegas",
        "Carnival",
        "Seltos",
        "Sonet"
      ];
    } else if (normalized.contains("honda")) {
      models = [
        "Accord",
        "Civic",
        "CR-V",
        "Pilot",
        "City",
        "HR-V",
        "ZR-V",
        "Odyssey"
      ];
    } else if (normalized.contains("tesla")) {
      models = [
        "Model Y",
        "Model 3",
        "Model X",
        "Model S",
        "Cybertruck"
      ];
    } else {
      models = [
        "Standard Model",
        "Base Model",
        "Sport Model",
        "Limited Model",
        "Executive Model",
        "Custom Model"
      ];
    }

    return models.asMap().entries.map((entry) {
      return CarModelItem(
        id: entry.key + 1,
        name: entry.value,
        carMakeId: makeId,
        makeName: makeName,
      );
    }).toList();
  }

  /// Default trims
  List<CarTrim> _getDefaultTrims(int modelId) {
    final trims = [
      "Standard / Base",
      "Full Option / Limited",
      "Sport",
      "Executive",
      "Platinum / Highline",
      "Mid Option",
      "Performance / Dynamic",
      "Other Trim"
    ];

    return trims.asMap().entries.map((entry) {
      return CarTrim(
        id: entry.key + 1,
        name: entry.value,
        carModelId: modelId,
      );
    }).toList();
  }
}
