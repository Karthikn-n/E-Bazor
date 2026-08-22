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

    return const [];
  }

  /// Fetches Models for a specific Make ID
  Future<List<CarModelItem>> fetchCarModels(int makeId,
      {String? makeName}) async {
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

    return const [];
  }

  /// Fetches Trims for a specific Model ID
  Future<List<CarTrim>> fetchCarModelTrims(int modelId,
      {String? modelName}) async {
    try {
      log("🚗 [CARS API] Fetching car model trims for model_id: $modelId...");
      final response =
          await Api.get(url: "${Api.getCarModelTrimsApi}/$modelId");
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

    return const [];
  }
}
