class SavedSearchParentCategory {
  final int? id;
  final String? name;
  final int count;
  final String? image;

  SavedSearchParentCategory({
    this.id,
    this.name,
    this.count = 0,
    this.image,
  });

  factory SavedSearchParentCategory.fromJson(Map<String, dynamic> json) {
    return SavedSearchParentCategory(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      name: json['name']?.toString(),
      count: json['count'] is int
          ? json['count']
          : int.tryParse(json['count']?.toString() ?? '0') ?? 0,
      image: json['image']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'count': count,
      'image': image,
    };
  }
}

class SavedSearchModel {
  final int? id;
  final int? userId;
  final String? title;
  final int? categoryId;
  final int? parentCategoryId;
  final String? categorySlug;
  final String? searchUrl;
  final String? apiSearchUrl;
  final String? location;
  final bool? subscribeEmail;
  final bool? notification;
  final int newListingCount;
  final int totalListingCount;
  final List<String> photos;
  final List<String> categoryHierarchy;
  final String? createdAt;
  final String? updatedAt;

  SavedSearchModel({
    this.id,
    this.userId,
    this.title,
    this.categoryId,
    this.parentCategoryId,
    this.categorySlug,
    this.searchUrl,
    this.apiSearchUrl,
    this.location,
    this.subscribeEmail,
    this.notification,
    this.newListingCount = 0,
    this.totalListingCount = 0,
    this.photos = const [],
    this.categoryHierarchy = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory SavedSearchModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedPhotos = [];
    if (json['photos'] is List) {
      parsedPhotos = (json['photos'] as List)
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    List<String> parsedHierarchy = [];
    if (json['category_hierarchy'] is List) {
      parsedHierarchy = (json['category_hierarchy'] as List)
          .map((e) => e is Map ? (e['name'] ?? '').toString() : e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return SavedSearchModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      userId: json['user_id'] is int
          ? json['user_id']
          : int.tryParse(json['user_id']?.toString() ?? ''),
      title: json['title']?.toString(),
      categoryId: json['category_id'] is int
          ? json['category_id']
          : int.tryParse(json['category_id']?.toString() ?? ''),
      parentCategoryId: json['parent_category_id'] is int
          ? json['parent_category_id']
          : int.tryParse(json['parent_category_id']?.toString() ?? ''),
      categorySlug: json['category_slug']?.toString(),
      searchUrl: json['search_url']?.toString(),
      apiSearchUrl: json['api_search_url']?.toString() ?? json['search_url']?.toString(),
      location: json['location']?.toString(),
      subscribeEmail: json['subscribe_email'] == 1 ||
          json['subscribe_email'] == true ||
          json['subscribe_email'] == '1',
      notification: json['notification'] == 1 ||
          json['notification'] == true ||
          json['notification'] == '1',
      newListingCount: json['new_listing_count'] is int
          ? json['new_listing_count']
          : int.tryParse(json['new_listing_count']?.toString() ?? '0') ?? 0,
      totalListingCount: json['total_listing_count'] is int
          ? json['total_listing_count']
          : int.tryParse(json['total_listing_count']?.toString() ?? '0') ?? 0,
      photos: parsedPhotos,
      categoryHierarchy: parsedHierarchy,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'category_id': categoryId,
      'parent_category_id': parentCategoryId,
      'category_slug': categorySlug,
      'search_url': searchUrl,
      'api_search_url': apiSearchUrl,
      'location': location,
      'subscribe_email': subscribeEmail == true ? 1 : 0,
      'notification': notification == true ? 1 : 0,
      'new_listing_count': newListingCount,
      'total_listing_count': totalListingCount,
      'photos': photos,
      'category_hierarchy': categoryHierarchy,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  SavedSearchModel copyWith({
    int? id,
    int? userId,
    String? title,
    int? categoryId,
    int? parentCategoryId,
    String? categorySlug,
    String? searchUrl,
    String? apiSearchUrl,
    String? location,
    bool? subscribeEmail,
    bool? notification,
    int? newListingCount,
    int? totalListingCount,
    List<String>? photos,
    List<String>? categoryHierarchy,
    String? createdAt,
    String? updatedAt,
  }) {
    return SavedSearchModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      parentCategoryId: parentCategoryId ?? this.parentCategoryId,
      categorySlug: categorySlug ?? this.categorySlug,
      searchUrl: searchUrl ?? this.searchUrl,
      apiSearchUrl: apiSearchUrl ?? this.apiSearchUrl,
      location: location ?? this.location,
      subscribeEmail: subscribeEmail ?? this.subscribeEmail,
      notification: notification ?? this.notification,
      newListingCount: newListingCount ?? this.newListingCount,
      totalListingCount: totalListingCount ?? this.totalListingCount,
      photos: photos ?? this.photos,
      categoryHierarchy: categoryHierarchy ?? this.categoryHierarchy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
