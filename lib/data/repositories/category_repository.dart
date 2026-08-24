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
  }) async {
    try {
      String apiUrl;
      Map<String, dynamic> parameters = {};

      if (categoryId != null) {
        apiUrl = Api.getCategoryChildrenByParentApi;
        parameters['parent_category_id'] = categoryId;
      } else {
        apiUrl = Api.getFrontCategoriesApi;
        parameters[Api.page] = page;
      }

      Map<String, dynamic> response = await Api.get(
        url: apiUrl,
        queryParameters: parameters,
      );

      print("FULL API RESPONSE ($apiUrl) 👉 $response");

      List rawList = [];
      if (response['data'] is List) {
        rawList = response['data'];
      } else if (response['data'] is Map) {
        final dataMap = response['data'] as Map;
        if (dataMap['data'] is List) {
          rawList = dataMap['data'];
        } else if (dataMap['subcategories'] is List) {
          rawList = dataMap['subcategories'];
        } else {
          rawList = [dataMap];
        }
      }

      List<CategoryModel> modelList = rawList
          .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      print(
          "📦 CATEGORIES COUNT FOR $apiUrl (parent_category_id: $categoryId) 👉 ${modelList.length}");

      return DataOutput(
        total: modelList.length,
        modelList: modelList,
      );
    } catch (e) {
      print("❌ ERROR IN REPOSITORY 👉 $e");
      rethrow;
    }
  }

  Future<List<CategoryModel>> fetchCategoryChildrenByParent({
    int? parentId,
    String? slug,
    String? title,
  }) async {
    try {
      Map<String, dynamic> parameters = {};
      if (parentId != null) {
        parameters['parent_category_id'] = parentId;
      }
      if (slug != null && slug.isNotEmpty) {
        parameters['category_slug'] = slug;
      }
      if (title != null && title.isNotEmpty) {
        parameters['title'] = title;
      }
      Map<String, dynamic> response = await Api.get(
        url: Api.getCategoryChildrenByParentApi,
        queryParameters: parameters,
      );

      if (response['data'] is List) {
        List list = response['data'];
        return list.map((e) => CategoryModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print("❌ ERROR IN fetchCategoryChildrenByParent 👉 $e");
      return [];
    }
  }

  /// GET /api/get-category-tree-by-slug
  Future<dynamic> fetchCategoryTreeBySlug(
      {required String categorySlug}) async {
    try {
      Map<String, dynamic> parameters = {
        'category_slug': categorySlug,
      };
      log("🌐 [REQ] → GET ${Api.getCategoryTreeBySlugApi} | params: $parameters");
      Map<String, dynamic> response = await Api.get(
        url: Api.getCategoryTreeBySlugApi,
        queryParameters: parameters,
      );
      log("📦 [CATEGORY TREE BY SLUG RES] 👉 $response");
      return response['data'];
    } catch (e) {
      log("❌ [CATEGORY TREE BY SLUG ERR] 👉 $e");
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
        Api.getCategoryFiltersApi,
        queryParameters: {"slug": slug},
      );

      log("📦 [FILTER API RES] → Status: ${response.statusCode} | Data: ${response.data}");

      if (response.statusCode == 200) {
        final raw = response.data['data'];

        // ✅ raw = {"categories": [...]}
        // so get first item inside categories list
        final categories = raw is Map ? raw['categories'] : null;
        if (categories is! List || categories.isEmpty) {
          throw Exception("No filters found for category '$slug'");
        }
        final categoryData = categories.first;
        if (categoryData is! Map) {
          throw Exception("Invalid filter configuration for '$slug'");
        }
        return FilterCategory.fromJson(
          Map<String, dynamic>.from(categoryData),
        );
      } else {
        throw Exception("Failed to load filters");
      }
    } on DioException catch (e) {
      log("❌ [FILTER API ERR] → ${e.message} | Response: ${e.response?.data}");
      throw Exception(e.message ?? "Dio error");
    }
  }
}
