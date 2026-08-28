import 'package:Ebozor/data/model/data_output.dart';
import 'package:Ebozor/data/model/location/cityModel.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_keys.dart';
import 'package:hive/hive.dart';

class CitiesRepository {
  static const String _cacheKey = 'cities_cache_v5';
  static const String _cacheUpdatedAtKey = 'cities_cache_v5_updated_at';

  List<CityModel> getCachedCities() {
    if (!Hive.isBoxOpen(HiveKeys.historyBox)) return const [];
    final cached = Hive.box(HiveKeys.historyBox).get(_cacheKey);
    if (cached is! List) return const [];
    return cached
        .whereType<Map>()
        .map((entry) => CityModel.fromJson(Map<String, dynamic>.from(entry)))
        .toList(growable: false);
  }

  DateTime? get cacheUpdatedAt {
    if (!Hive.isBoxOpen(HiveKeys.historyBox)) return null;
    final value =
        Hive.box(HiveKeys.historyBox).get(_cacheUpdatedAtKey)?.toString();
    return value == null ? null : DateTime.tryParse(value);
  }

  Future<DataOutput<CityModel>> fetchCities(
      {required int page, int? stateId, String? search}) async {
    Map<String, dynamic> parameters = {
      Api.page: page,
      if (stateId != null && stateId > 0) Api.stateId: stateId,
      if (search != null && search.trim().isNotEmpty) Api.search: search.trim()
    };

    Map<String, dynamic> response = await Api.get(
      url: Api.getCitiesApi,
      queryParameters: parameters,
      useBaseUrl: true,
    );

    List<CityModel> modelList = (response['data']['data'] as List)
        .map((e) => CityModel.fromJson(e))
        .toList();

    return DataOutput<CityModel>(
      total: response['data']['total'] ?? 0,
      modelList: modelList,
    );
  }

  Future<DataOutput<CityModel>> fetchAllCities({int? stateId}) async {
    var page = 1;
    var total = 0;
    final citiesById = <String, CityModel>{};
    while (page <= 100) {
      final result = await fetchCities(page: page, stateId: stateId);
      total = result.total;
      for (final city in result.modelList) {
        final key = city.id?.toString() ?? city.name?.trim() ?? '';
        if (key.isNotEmpty) citiesById[key] = city;
      }
      if (result.modelList.isEmpty || citiesById.length >= total) break;
      page++;
    }

    final cities = citiesById.values.toList()
      ..sort((a, b) =>
          (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()));
    if ((stateId == null || stateId <= 0) &&
        cities.isNotEmpty &&
        Hive.isBoxOpen(HiveKeys.historyBox)) {
      final box = Hive.box(HiveKeys.historyBox);
      await box.put(
        _cacheKey,
        cities.map((city) => city.toJson()).toList(growable: false),
      );
      await box.put(_cacheUpdatedAtKey, DateTime.now().toIso8601String());
    }
    return DataOutput<CityModel>(total: total, modelList: cities);
  }
}
