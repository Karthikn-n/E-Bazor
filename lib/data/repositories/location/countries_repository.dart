import 'package:Ebozor/data/model/data_output.dart';
import 'package:Ebozor/data/model/location/countriesModel.dart';
import 'package:Ebozor/utils/ApiService/api.dart';

class CountriesRepository {
  Future<DataOutput<CountriesModel>> fetchCountries({required int page,String? search}) async {
    Map<String, dynamic> parameters = {
      Api.page: page,
      if (search != null && search.trim().isNotEmpty) Api.search: search.trim()
    };

    Map<String, dynamic> response = await Api.get(
      url: Api.getCountriesApi,
      queryParameters: parameters,
      useBaseUrl: true,
    );

    List<CountriesModel> modelList = (response['data']['data'] as List)
        .map((e) => CountriesModel.fromJson(e))
        .toList();

    return DataOutput<CountriesModel>(
      total: response['data']['total'] ?? 0,
      modelList: modelList,
    );
  }
}
