import 'package:Ebozor/data/model/custom_field/custom_field_model.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';

class SellerVerificationFieldRepository {
  Future<List<VerificationFieldModel>> getSellerVerificationFields() async {
    try {
      Map<String, dynamic> parameters = {};

      Map<String, dynamic> response = await Api.get(
          url: Api.getVerificationFieldApi, queryParameters: parameters);

      List<VerificationFieldModel> modelList = (response['data'] as List)
          .map((e) => VerificationFieldModel.fromMap(e))
          .toList();

      return modelList;
    } catch (e) {
      throw "$e";
    }
  }

  Future<Map> setUserPhoneNumber({required String phoneNumber}) async {
    try {
      final user = HiveUtils.getUserDetails();
      final userId = user.id ?? HiveUtils.getUserId();

      Map response = await Api.post(
        url: Api.setUserPhoneNumberApi,
        parameter: {
          if (userId != null) 'user_id': userId,
          'phone_number': phoneNumber,
        },
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map> sendVerificationField(
      {required Map<String, dynamic> data}) async {
    try {
      Map response =
          await Api.post(url: Api.sendVerificationRequestApi, parameter: data);

      return response;
    } catch (e) {
      rethrow;
    }
  }
}
