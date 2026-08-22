import 'dart:developer';
import 'package:Ebozor/data/model/user_address_model.dart';
import 'package:Ebozor/utils/ApiService/api.dart';

class UserAddressRepository {
  Future<List<UserAddressModel>> getUserAddresses({required int userId}) async {
    try {
      final response = await Api.post(
        url: Api.getUserAddressApi,
        parameter: {
          "user_id": userId,
        },
      );

      log("📍 [GET USER ADDRESSES RES] $response");

      final rawData = response['data'];
      if (rawData is List) {
        return rawData
            .map((e) => UserAddressModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return [];
    } catch (e) {
      log("❌ [GET USER ADDRESSES ERROR] $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> saveAddress({
    required int userId,
    int? addressId,
    required String neighbourhood,
    String? streetName,
    String? apartmentNumber,
    required String label,
    required bool isDefault,
    double? lat,
    double? lan,
  }) async {
    try {
      final Map<String, dynamic> parameters = {
        "user_id": userId,
        if (addressId != null) "address_id": addressId,
        "neighbourhood": neighbourhood,
        if (streetName != null && streetName.isNotEmpty) "street_name": streetName,
        if (apartmentNumber != null && apartmentNumber.isNotEmpty)
          "apartment_number": apartmentNumber,
        "label": label,
        "default": isDefault ? 1 : 0,
        if (lat != null) "lat": lat,
        if (lan != null) "lan": lan,
      };

      log("📍 [SAVE USER ADDRESS REQ] $parameters");

      final response = await Api.post(
        url: Api.userAddressChangesApi,
        parameter: parameters,
      );

      log("📍 [SAVE USER ADDRESS RES] $response");
      return response;
    } catch (e) {
      log("❌ [SAVE USER ADDRESS ERROR] $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteAddress({
    required int userId,
    required int addressId,
  }) async {
    try {
      final Map<String, dynamic> parameters = {
        "user_id": userId,
        "address_id": addressId,
        "type": "delete",
      };

      log("📍 [DELETE USER ADDRESS REQ] $parameters");

      final response = await Api.post(
        url: Api.userAddressChangesApi,
        parameter: parameters,
      );

      log("📍 [DELETE USER ADDRESS RES] $response");
      return response;
    } catch (e) {
      log("❌ [DELETE USER ADDRESS ERROR] $e");
      rethrow;
    }
  }
}
