import 'package:Ebozor/data/model/motors_service_models.dart';
import 'package:Ebozor/utils/ApiService/api.dart';

class MotorsServiceRepository {
  static const _standardFeatures = [
    'Doorstep Inspection',
    'Exterior & Body',
    'Engine & Transmission',
    'Brakes & Suspension',
    'Electrical Systems & Controls',
    'Rims & Tyres Condition',
    'Road Test',
  ];

  static const fallbackPackages = [
    InspectionPackageModel(
      id: 8,
      name: 'Advanced',
      price: 569,
      points: '240-point inspection',
      features: [
        ..._standardFeatures,
        'Chassis Condition',
        'Under Body Examination',
        'Computerized Diagnostic Scan',
        'Accident History Check',
      ],
    ),
    InspectionPackageModel(
      id: 9,
      name: 'Standard',
      price: 369,
      points: '120-point inspection',
      features: _standardFeatures,
    ),
  ];

  Future<List<InspectionPackageModel>> fetchInspectionPackages() async {
    try {
      // The current backend stores inspection packages with the legacy type
      // "inception", but its request validator rejects that type. Fall back to
      // the unfiltered endpoint and isolate those plans locally. This also keeps
      // newly added/removed dashboard packages dynamic.
      Map<String, dynamic> response;
      var filterInspectionTypes = false;
      try {
        response = await Api.get(
          url: Api.getPackageApi,
          queryParameters: const {'type': 'inspection'},
        );
      } catch (_) {
        response = await Api.get(url: Api.getPackageApi);
        filterInspectionTypes = true;
      }

      if (response['error'] == true || response['data'] is! List) {
        return fallbackPackages;
      }

      final packages = (response['data'] as List)
          .whereType<Map>()
          .where((json) {
            if (!filterInspectionTypes) return true;
            final type = json['type']?.toString().trim().toLowerCase();
            return type == 'inspection' || type == 'inception';
          })
          .map((json) => InspectionPackageModel.fromJson(
                Map<String, dynamic>.from(json),
              ))
          .map(_withFallbackFeatures)
          .toList(growable: false);
      return packages.isEmpty ? fallbackPackages : packages;
    } catch (_) {
      return fallbackPackages;
    }
  }

  static InspectionPackageModel _withFallbackFeatures(
    InspectionPackageModel package,
  ) {
    if (package.features.isNotEmpty) return package;
    for (final fallback in fallbackPackages) {
      final matchesId = package.id != null && package.id == fallback.id;
      final matchesName =
          package.name.trim().toLowerCase() == fallback.name.toLowerCase();
      if (matchesId || matchesName) {
        return InspectionPackageModel(
          id: package.id ?? fallback.id,
          name: package.name,
          price: package.price,
          points: package.points.isEmpty ? fallback.points : package.points,
          features: fallback.features,
        );
      }
    }
    return package;
  }

  Future<Map<String, dynamic>> bookInspection(
    Map<String, dynamic> payload,
  ) =>
      Api.post(url: Api.carInspectionApi, parameter: payload);

  Future<Map<String, dynamic>> submitEvaluation(
    Map<String, dynamic> payload,
  ) =>
      Api.post(url: Api.carEvaluationsApi, parameter: payload);

  Future<Map<String, dynamic>> submitFinance(
    Map<String, dynamic> payload,
  ) =>
      Api.post(url: Api.carFinanceApi, parameter: payload);

  Future<List<CarInspectionRecord>> fetchInspections(
    dynamic userId, {
    String filter = 'latest_first',
  }) async {
    final response = await Api.post(
      url: Api.getCarInspectionApi,
      parameter: {'user_id': userId, 'filter': filter},
    );
    dynamic data = response['data'];
    if (data is Map) {
      data = data['data'] ?? data['inspections'] ?? data['appointments'];
    }
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((json) => CarInspectionRecord.fromJson(
              Map<String, dynamic>.from(json),
            ))
        .toList(growable: false);
  }
}
