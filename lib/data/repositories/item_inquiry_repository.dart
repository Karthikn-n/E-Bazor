import 'package:Ebozor/utils/ApiService/api.dart';

class ItemInquiryRepository {
  Future<Map<String, dynamic>> sendItemInquiry({
    required int itemId,
    required String name,
    required String email,
    required String message,
    String? phone,
    String? listingUrl,
    String? referenceCode,
  }) async {
    try {
      Map<String, dynamic> params = {
        "item_id": itemId,
        "name": name,
        "email": email,
        "message": message,
      };
      if (phone != null && phone.trim().isNotEmpty) {
        params["phone"] = phone.trim();
      }
      if (listingUrl != null && listingUrl.trim().isNotEmpty) {
        params["listing_url"] = listingUrl.trim();
      }
      if (referenceCode != null && referenceCode.trim().isNotEmpty) {
        params["reference_code"] = referenceCode.trim();
      }

      final response = await Api.post(
        url: Api.sendItemInquiryApi,
        parameter: params,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
