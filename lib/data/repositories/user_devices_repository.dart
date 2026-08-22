import 'package:Ebozor/data/model/user_device_model.dart';
import 'package:Ebozor/utils/ApiService/api.dart';

class UserDevicesRepository {
  Future<List<UserDeviceModel>> getDevices() async {
    try {
      final response = await Api.get(url: Api.getDevicesApi);
      if (response['data'] != null && response['data'] is List) {
        return (response['data'] as List)
            .map((e) => UserDeviceModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> logoutDevice(int deviceId) async {
    try {
      final response = await Api.delete(
        url: "${Api.logoutDeviceApi}/$deviceId",
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
