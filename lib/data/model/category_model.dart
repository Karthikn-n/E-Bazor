// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:Ebozor/utils/ApiService/api.dart';

class Type {
  String? id;
  String? type;

  Type({this.id, this.type});

  Type.fromJson(Map<String, dynamic> json) {
    id = json[Api.id].toString();
    type = json[Api.type];
  }
}

class CategoryModel {
  final int? id;
  final String? name;
  final String? url;
  final String? slug;
  final List<CategoryModel>? children;
  final String? description;
  final int? subcategoriesCount;
  final bool? frontList;
  final int? parentCategoryId;

  CategoryModel({
    this.id,
    this.name,
    this.url,
    this.description,
    this.children,
    this.subcategoriesCount,
    this.slug,
    this.frontList,
    this.parentCategoryId,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    try {
      List<dynamic> childData = json['subcategories'] ?? json['children'] ?? [];
      List<CategoryModel> children = childData
          .map((child) =>
              CategoryModel.fromJson(Map<String, dynamic>.from(child)))
          .toList();

      int? catId = json['id'] != null
          ? int.tryParse(json['id'].toString())
          : (json['category_id'] != null
              ? int.tryParse(json['category_id'].toString())
              : null);

      bool? isFront = json['front_list'] == true ||
          json['front_list'] == 1 ||
          json['front_list'] == '1' ||
          json['front_list'] == 'true';

      int? parentCatId = json['parent_category_id'] != null
          ? int.tryParse(json['parent_category_id'].toString())
          : null;

      return CategoryModel(
        id: catId,
        name: (json['translated_name'] != null &&
                json['translated_name'].toString().isNotEmpty)
            ? json['translated_name']
            : json['name'],
        url: (json['image'] != null && json['image'].toString().isNotEmpty)
            ? json['image']
            : null,
        slug: json['slug'],
        subcategoriesCount: json['subcategories_count'] ?? children.length,
        children: children,
        description: json['description'] ?? "",
        frontList: isFront,
        parentCategoryId: parentCatId,
      );
    } catch (e) {
      rethrow;
    }
  }

  CategoryModel copyWith({
    int? id,
    String? name,
    String? url,
    String? slug,
    List<CategoryModel>? children,
    String? description,
    int? subcategoriesCount,
    bool? frontList,
    int? parentCategoryId,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      slug: slug ?? this.slug,
      children: children ?? this.children,
      description: description ?? this.description,
      subcategoriesCount: subcategoriesCount ?? this.subcategoriesCount,
      frontList: frontList ?? this.frontList,
      parentCategoryId: parentCategoryId ?? this.parentCategoryId,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'translated_name': name,
      'image': url,
      'slug': slug,
      'subcategories_count': subcategoriesCount,
      "description": description,
      'subcategories': children?.map((child) => child.toJson()).toList() ?? [],
    };
    return data;
  }

  @override
  String toString() {
    return 'CategoryModel( id: $id, translated_name:$name, url: $url, slug: $slug, descrtiption:$description, children: $children, subcategories_count:$subcategoriesCount)';
  }
}
// class FilterCategory {
//   final int id;
//   final String name;
//   final String slug;
//   final List<FilterSubCategory> children;
//   final List<FilterItem> filters;
//
//   FilterCategory({
//     required this.id,
//     required this.name,
//     required this.slug,
//     required this.children,
//     required this.filters,
//   });
//
//   factory FilterCategory.fromJson(Map<String, dynamic> json) {
//     return FilterCategory(
//       id: json['category_id'],
//       name: json['name'],
//       slug: json['slug'],
//       children: (json['children'] as List)
//           .map((e) => FilterSubCategory.fromJson(e))
//           .toList(),
//       filters: (json['filters'] as List)
//           .map((e) => FilterItem.fromJson(e))
//           .toList(),
//     );
//   }
// }
//
// class FilterItem {
//   final String name;
//   final String type;
//   final List<String> values;
//   final bool multiSelect;
//
//   FilterItem({
//     required this.name,
//     required this.type,
//     required this.values,
//     required this.multiSelect,
//   });
//
//   factory FilterItem.fromJson(Map<String, dynamic> json) {
//     return FilterItem(
//       name: json['name'],
//       type: json['type'],
//       values: List<String>.from(json['values'] ?? []),
//       multiSelect: json['multiselect'] == true,
//     );
//   }
// }
//
// class FilterSubCategory {
//   final int id;
//   final String name;
//   final String slug;
//
//   FilterSubCategory({
//     required this.id,
//     required this.name,
//     required this.slug,
//   });
//
//   factory FilterSubCategory.fromJson(Map<String, dynamic> json) {
//     return FilterSubCategory(
//       id: json['category_id'],
//       name: json['name'],
//       slug: json['slug'],
//     );
//   }
// }

class FilterCategory {
  final int? id; // ✅ nullable
  final String? name; // ✅ nullable
  final String? slug; // ✅ nullable
  final List<FilterSubCategory> children;
  final List<FilterItem> filters;

  FilterCategory({
    this.id,
    this.name,
    this.slug,
    required this.children,
    required this.filters,
  });

  factory FilterCategory.fromJson(Map<String, dynamic> json) {
    return FilterCategory(
      id: int.tryParse(json['category_id']?.toString() ?? ''),
      name: json['name']?.toString(),
      slug: json['slug']?.toString(),
      children: (json['children'] as List? ?? [])
          .map((e) => FilterSubCategory.fromJson(e))
          .toList(),
      filters: (json['filters'] as List? ?? [])
          .map((e) => FilterItem.fromJson(e))
          .toList(),
    );
  }
}

class FilterSubCategory {
  final int? id; // ✅ nullable
  final String? name; // ✅ nullable
  final String? slug; // ✅ nullable

  FilterSubCategory({
    this.id,
    this.name,
    this.slug,
  });

  factory FilterSubCategory.fromJson(Map<String, dynamic> json) {
    return FilterSubCategory(
      id: int.tryParse(json['category_id']?.toString() ?? ''),
      name: json['name']?.toString(),
      slug: json['slug']?.toString(),
    );
  }
}

// class FilterItem {
//   final String? name;        // ✅ nullable
//   final String? type;        // ✅ nullable
//   final List<String> values;
//   final bool multiSelect;
//
//   FilterItem({
//     this.name,
//     this.type,
//     required this.values,
//     required this.multiSelect,
//   });
//
//   factory FilterItem.fromJson(Map<String, dynamic> json) {
//     return FilterItem(
//       name: json['name'] as String?,
//       type: json['type'] as String?,
//       values: List<String>.from(json['values'] ?? []),
//       multiSelect: json['multiselect'] == true,
//     );
//   }
// }

class FilterItem {
  final String? name;
  final String? type;
  final List<String> values;
  final List<Map<String, dynamic>> valuesObject;
  final bool multiSelect;
  final int sortOrder;
  final bool isActive;
  final String? placeholder; // ✅ add this

  FilterItem({
    this.name,
    this.type,
    required this.values,
    this.valuesObject = const [],
    required this.multiSelect,
    this.sortOrder = 0,
    this.isActive = true,
    this.placeholder,
  });

  factory FilterItem.fromJson(Map<String, dynamic> json) {
    final rawValues = json['values'];
    final rawObjects = json['values_obj'];
    final valuesObject = rawObjects is List
        ? rawObjects
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList()
        : <Map<String, dynamic>>[];
    final values = rawValues is List
        ? rawValues
            .where((value) => value != null)
            .map((value) => value.toString())
            .toList()
        : <String>[];
    if (values.isEmpty && valuesObject.isNotEmpty) {
      values.addAll(valuesObject.map((value) =>
          (value['label'] ?? value['name'] ?? value['value']).toString()));
    }
    final rawType = json['type']?.toString().trim().toLowerCase() ?? '';
    final type = switch (rawType) {
      'textbox' || 'input' => 'text',
      'numeric' => 'number',
      'select' => 'dropdown',
      'radio' || 'checkbox' => 'button',
      _ => rawType,
    };
    return FilterItem(
      name: json['name']?.toString(),
      type: type,
      values: values,
      valuesObject: valuesObject,
      multiSelect: json['multiselect'] == true ||
          json['multiselect'] == 1 ||
          json['multiselect'] == '1',
      sortOrder: int.tryParse(json['sort_order']?.toString() ?? '') ?? 0,
      isActive: json['is_active'] == true ||
          json['is_active'] == 1 ||
          json['is_active'] == '1',
      placeholder: json['placeholder'] as String?, // ✅ add this
    );
  }
}
