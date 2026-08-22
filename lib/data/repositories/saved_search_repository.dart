import 'package:Ebozor/data/model/data_output.dart';
import 'package:Ebozor/data/model/saved_search_model.dart';
import 'package:Ebozor/utils/ApiService/api.dart';

class SavedSearchResult {
  final DataOutput<SavedSearchModel> output;
  final List<SavedSearchParentCategory> parentCategories;

  SavedSearchResult({
    required this.output,
    this.parentCategories = const [],
  });
}

class SavedSearchRepository {
  Future<SavedSearchModel> createSavedSearch({
    required String title,
    int? categoryId,
    int? parentCategoryId,
    String? categorySlug,
    String? searchUrl,
    String? apiSearchUrl,
    String? location,
    bool? subscribeEmail,
    bool? notification,
  }) async {
    Map<String, dynamic> parameters = {
      Api.title: title,
    };

    if (categoryId != null && categoryId > 0) {
      parameters[Api.categoryId] = categoryId;
    }
    if (parentCategoryId != null && parentCategoryId > 0) {
      parameters[Api.parentCategoryId] = parentCategoryId;
    }
    if (categorySlug != null && categorySlug.isNotEmpty) {
      parameters[Api.categorySlug] = categorySlug;
    }
    if (searchUrl != null && searchUrl.isNotEmpty) {
      parameters[Api.searchUrl] = searchUrl;
    }
    if (apiSearchUrl != null && apiSearchUrl.isNotEmpty) {
      parameters[Api.apiSearchUrl] = apiSearchUrl;
    }
    if (location != null && location.isNotEmpty) {
      parameters[Api.location] = location;
    }
    if (subscribeEmail != null) {
      parameters[Api.subscribeEmail] = subscribeEmail ? 1 : 0;
    }
    if (notification != null) {
      parameters[Api.notification] = notification ? 1 : 0;
    }

    final response = await Api.post(
      url: Api.savedSearchApi,
      parameter: parameters,
    );

    if (response['data'] is Map<String, dynamic>) {
      return SavedSearchModel.fromJson(response['data']);
    } else if (response['data'] is List && (response['data'] as List).isNotEmpty) {
      return SavedSearchModel.fromJson((response['data'] as List).first);
    }

    return SavedSearchModel(title: title);
  }

  Future<SavedSearchResult> fetchSavedSearches({required int page}) async {
    Map<String, dynamic> parameters = {
      Api.page: page,
    };

    final response = await Api.get(
      url: Api.savedSearchApi,
      queryParameters: parameters,
    );

    List<SavedSearchModel> modelList = [];
    int total = 0;

    if (response['data'] is Map<String, dynamic>) {
      final dataMap = response['data'] as Map<String, dynamic>;
      if (dataMap['data'] is List) {
        modelList = (dataMap['data'] as List)
            .map((e) => SavedSearchModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      total = dataMap['total'] is int
          ? dataMap['total']
          : int.tryParse(dataMap['total']?.toString() ?? '0') ?? modelList.length;
    } else if (response['data'] is List) {
      modelList = (response['data'] as List)
          .map((e) => SavedSearchModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      total = modelList.length;
    }

    List<SavedSearchParentCategory> parentCategories = [];
    if (response['parent_category'] is List) {
      parentCategories = (response['parent_category'] as List)
          .map((e) => SavedSearchParentCategory.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return SavedSearchResult(
      output: DataOutput(total: total, modelList: modelList),
      parentCategories: parentCategories,
    );
  }

  Future<Map<String, dynamic>> editSavedSearch({
    required int id,
    required String title,
  }) async {
    Map<String, dynamic> parameters = {
      Api.id: id,
      Api.title: title,
    };

    final response = await Api.post(
      url: Api.editSavedSearchApi,
      parameter: parameters,
    );

    return response;
  }

  Future<Map<String, dynamic>> deleteSavedSearch({required int id}) async {
    Map<String, dynamic> parameters = {
      Api.id: id,
    };

    final response = await Api.post(
      url: Api.deleteSavedSearchApi,
      parameter: parameters,
    );

    return response;
  }
}
