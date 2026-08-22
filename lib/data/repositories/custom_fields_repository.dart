
import 'package:Ebozor/data/model/custom_field/custom_field_model.dart';
import 'package:Ebozor/utils/ApiService/api.dart';


class CustomFieldRepository {
  Future<List<CustomFieldModel>> getCustomFieldsByCategoryId(
      dynamic categoryId) async {
    try {
      Map<String, dynamic> parameters = {
        Api.categoryId: categoryId,
      };

      Map<String, dynamic> response = await Api.get(
          url: Api.getCustomFieldsByCategoryIdApi,
          queryParameters: parameters);

      dynamic data = response['data'];
      List list = [];
      if (data is List) {
        list = data;
      } else if (data is Map && data['custom_fields'] is List) {
        list = data['custom_fields'];
      }

      List<CustomFieldModel> modelList =
          list.map((e) => CustomFieldModel.fromMap(e)).toList();

      return modelList;
    } catch (e) {
      throw "$e";
    }
  }

  // Future<List<CustomFieldModel>> getCustomFields(String categoryIds) async {
  //   try {
  //     Map<String, dynamic> parameters = {
  //       Api.categoryIds: categoryIds,
  //     };

  //     Map<String, dynamic> response = await Api.get(
  //         url: Api.getCustomFieldsApi, queryParameters: parameters);

  //     List<CustomFieldModel> modelList = (response['data'] as List)
  //         .map((e) => CustomFieldModel.fromMap(e))
  //         .toList();

  //     return modelList;
  //   } catch (e) {
  //     throw "$e";
  //   }
  // }
}
