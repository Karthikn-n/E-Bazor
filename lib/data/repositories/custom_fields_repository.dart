import 'package:Ebozor/data/model/custom_field/custom_field_model.dart';
import 'package:Ebozor/utils/ApiService/api.dart';

class CustomFieldRepository {
  Future<List<CustomFieldModel>> getCustomFieldsByCategoryId(
      dynamic categoryId) async {
    try {
      Map<String, dynamic> parameters = {
        Api.categoryId: categoryId,
        'id': categoryId,
      };

      Map<String, dynamic> response = await Api.get(
          url: Api.getCustomFieldsByCategoryIdApi, queryParameters: parameters);

      dynamic data = response['data'];
      List list = [];
      if (data is List) {
        list = data;
      } else if (data is Map && data['custom_fields'] is List) {
        list = data['custom_fields'];
      }

      final modelList = list
          .whereType<Map>()
          .map((e) => CustomFieldModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      await Future.wait(modelList.map(_resolveKnownApiDropdown));

      return modelList;
    } catch (e) {
      throw "$e";
    }
  }

  Future<void> _resolveKnownApiDropdown(CustomFieldModel field) async {
    if ((field.type ?? '').toLowerCase() != 'dropdown_api') return;
    final sources = field.values is List
        ? field.values as List
        : field.values == null
            ? const []
            : [field.values];
    if (!sources
        .map((source) => source.toString().trim().toLowerCase())
        .contains('job-roles')) {
      field.values = const [];
      return;
    }
    try {
      final response = await Api.get(url: 'job-roles');
      dynamic data = response['data'];
      if (data is Map) {
        data = data['job_roles'] ?? data['roles'] ?? data['data'];
      }
      if (data is! List) {
        field.values = const [];
        return;
      }
      field.values = data
          .map((entry) {
            if (entry is String || entry is num) return entry.toString().trim();
            if (entry is Map) {
              return (entry['title'] ?? entry['name'] ?? entry['label'])
                  ?.toString()
                  .trim();
            }
            return null;
          })
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false);
    } catch (_) {
      field.values = const [];
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
