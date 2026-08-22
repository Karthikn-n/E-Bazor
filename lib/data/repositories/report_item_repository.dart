import 'package:Ebozor/data/model/data_output.dart';
import 'package:Ebozor/data/model/report_item/reason_model.dart';
import 'package:Ebozor/utils/ApiService/api.dart';

class ReportItemRepository {
  Future<DataOutput<ReportReason>> fetchReportReasonsList() async {
    try {
      Map<String, dynamic> response = await Api.get(
        url: Api.getReportReasonsApi,
        queryParameters: {},
      );

      List<ReportReason> list = (response['data']['data'] as List).map((e) {
        return ReportReason(id: e["id"], reason: e['reason']);
      }).toList();

      return DataOutput(total: response['total'], modelList: list);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map> reportAd({
    required int userId,
    required int itemId,
    required String reportType,
    required String reportText,
    String? spamType,
  }) async {
    try {
      Map response = await Api.post(
        url: Api.adReportApi,
        parameter: {
          "user_id": userId,
          "item_id": itemId,
          "report_type": reportType,
          "report_text": reportText,
          if (spamType != null && spamType.isNotEmpty) "spam_type": spamType,
        },
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map> reportItem({
    required int reasonId,
    required int itemId,
    String? message,
  }) async {
    try {
      Map response = await Api.post(
        url: Api.addReportsApi,
        parameter: {
          "report_reason_id": (reasonId == -10) ? "" : reasonId,
          "item_id": itemId,
          if (message != null) "other_message": message
        },
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }
}
