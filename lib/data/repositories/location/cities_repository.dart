import 'package:Ebozor/data/model/data_output.dart';
import 'package:Ebozor/data/model/location/cityModel.dart';
import 'package:Ebozor/utils/ApiService/api.dart';

class CitiesRepository {
  Future<DataOutput<CityModel>> fetchCities(
      {required int page, required int stateId,String? search}) async {
    Map<String, dynamic> parameters = {
      Api.page: page,
      Api.stateId: stateId,
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
}
