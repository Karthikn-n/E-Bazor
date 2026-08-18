

import 'package:Ebozor/data/model/data_output.dart';
import 'package:Ebozor/data/model/location/statesModel.dart';
import 'package:Ebozor/utils/ApiService/api.dart';

class StatesRepository {
  Future<DataOutput<StatesModel>> fetchStates(
      {required int page, required int countryId,String? search}) async {
    Map<String, dynamic> parameters = {
      Api.page: page,
      Api.countryId: countryId,
      if (search != null && search.trim().isNotEmpty) Api.search: search.trim()
    };

    Map<String, dynamic> response = await Api.get(
      url: Api.getStatesApi,
      queryParameters: parameters,
      useBaseUrl: true,
    );

    List<StatesModel> modelList = (response['data']['data'] as List)
        .map((e) => StatesModel.fromJson(e))
        .toList();

    return DataOutput<StatesModel>(
      total: response['data']['total'] ?? 0,
      modelList: modelList,
    );
  }
}
