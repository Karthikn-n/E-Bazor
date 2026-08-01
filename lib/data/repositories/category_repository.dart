
import 'dart:developer';

import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/model/data_output.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:dio/dio.dart';

// class CategoryRepository {
//   Future<DataOutput<CategoryModel>> fetchCategories({
//     required int page,
//     int? categoryId,
//   }) async {
//     try {
//       Map<String, dynamic> parameters = {
//         Api.page: page,
//       };
//
//       if (categoryId != null) {
//         parameters[Api.categoryId] = categoryId;
//       }
//       Map<String, dynamic> response =
//           await Api.get(url:
//           //"http://143.110.251.34/api/front_categories",
//           Api.getCategoriesApi,
//               queryParameters: parameters);
//
//       print("FULL API RESPONSE 👉 $response");
//       print("DATA 👉 ${response['data']}");
//       print("LIST 👉 ${response['data']['data']}");
//      print("API URL 👉 ${Api.getCategoriesApi}");
//
//       // List<CategoryModel> modelList = (response['data']['data'] as List).map(
//       //   (e) {
//       //     return CategoryModel.fromJson(e);
//       //   },
//       // ).toList();
//       List<CategoryModel> modelList =
//       (response['data'] as List).map((e) {
//         return CategoryModel.fromJson(e);
//       }).toList();
//       return DataOutput(
//         total: modelList.length, // ✅ correct
//         modelList: modelList,
//       );
//       // return DataOutput(
//       //     total: response['data']['total'] ?? 0, modelList: modelList);
//       // return (total: response['total'] ?? 0, modelList: modelList);
//     } catch (e) {
//       rethrow;
//     }
//   }
// }
class CategoryRepository {
  Future<DataOutput<CategoryModel>> fetchCategories({
    required int page,
    int? categoryId,
  }) async
  {
    try {
      Map<String, dynamic> parameters = {
        Api.page: page,
      };

      if (categoryId != null) {
        parameters[Api.categoryId] = categoryId;
      }

      Map<String, dynamic> response = await Api.get(
        url: Api.getCategoriesApi,
        queryParameters: parameters,
      );

      print("FULL API RESPONSE 👉 $response");

      /// ✅ FIX: data is List
      List list = response['data'];

      print("📦 LIST LENGTH 👉 ${list.length}");

      List<CategoryModel> modelList =
      list.map((e) => CategoryModel.fromJson(e)).toList();

      return DataOutput(
        total: modelList.length,
        modelList: modelList,
      );
    } catch (e) {
      print("❌ ERROR IN REPOSITORY 👉 $e");
      rethrow;
    }
  }





}

class FilterRepository {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: Constant.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  Future<FilterCategory> getFilters(String slug) async {
    try {
      log("🌐 [FILTER API REQ] → GET ${Constant.baseUrl}get-category-filters | params: {slug: $slug}");
      final response = await _dio.get(
        "get-category-filters",
        queryParameters: {"slug": slug},
      );

      log("📦 [FILTER API RES] → Status: ${response.statusCode} | Data: ${response.data}");

      if (response.statusCode == 200) {
        final raw = response.data['data'];

        // ✅ raw = {"categories": [...]}
        // so get first item inside categories list
        final categoryData = raw['categories'][0];

        return FilterCategory.fromJson(categoryData);
      } else {
        throw Exception("Failed to load filters");
      }
    } on DioException catch (e) {
      log("❌ [FILTER API ERR] → ${e.message} | Response: ${e.response?.data}");
      throw Exception(e.message ?? "Dio error");
    }
  }
}


