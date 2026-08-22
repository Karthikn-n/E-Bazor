import 'package:Ebozor/data/model/blog_model.dart';
import 'package:Ebozor/data/model/data_output.dart';
import 'package:Ebozor/utils/ApiService/api.dart';

class BlogsRepository {
  Future<DataOutput<BlogModel>> fetchBlogs({
    required int page,
    String? tag,
    String? categoryId,
    String? sortBy,
  }) async {
    Map<String, dynamic> parameters = {
      Api.page: page,
      if (tag != null && tag.isNotEmpty && tag != "All") "tag": tag,
      if (categoryId != null && categoryId.isNotEmpty) "category_id": categoryId,
      if (sortBy != null && sortBy.isNotEmpty) "sort_by": sortBy,
    };

    Map<String, dynamic> result =
        await Api.get(url: Api.getBlogApi, queryParameters: parameters);

    List<BlogModel> modelList = (result['data']['data'] as List)
        .map((element) => BlogModel.fromJson(element))
        .toList();

    return DataOutput<BlogModel>(
        total: result['data']['total'] ?? 0, modelList: modelList);
  }

  Future<List<String>> fetchBlogTags({int? blogId}) async {
    try {
      Map<String, dynamic> parameters = {
        if (blogId != null) "blog_id": blogId,
      };
      Map<String, dynamic> result = await Api.get(
        url: Api.getBlogTagsApi,
        queryParameters: parameters,
      );
      final rawData = result['data'];
      if (rawData != null) {
        if (rawData is List) {
          return rawData
              .map((e) => e is Map
                  ? (e['tag'] ?? e['name'] ?? e['title'] ?? e.toString()).toString()
                  : e.toString())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
