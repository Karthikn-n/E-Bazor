class FavoriteListingModel {
  final int? favouritelistingId;
  final String title;
  final int count;
  final LatestFavoriteItem? latestItem;

  FavoriteListingModel({
    this.favouritelistingId,
    required this.title,
    required this.count,
    this.latestItem,
  });

  bool get isDefault => favouritelistingId == null;

  factory FavoriteListingModel.fromJson(Map<String, dynamic> json) {
    int? parseId(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      return int.tryParse(val.toString());
    }

    int parseCount(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      return int.tryParse(val.toString()) ?? 0;
    }

    return FavoriteListingModel(
      favouritelistingId: parseId(json['favouritelisting_id'] ?? json['id']),
      title: json['title']?.toString() ?? json['listing_name']?.toString() ?? "All Favorites",
      count: parseCount(json['count']),
      latestItem: json['latest_item'] != null && json['latest_item'] is Map<String, dynamic>
          ? LatestFavoriteItem.fromJson(json['latest_item'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'favouritelisting_id': favouritelistingId,
      'title': title,
      'count': count,
      'latest_item': latestItem?.toJson(),
    };
  }

  FavoriteListingModel copyWith({
    int? favouritelistingId,
    String? title,
    int? count,
    LatestFavoriteItem? latestItem,
  }) {
    return FavoriteListingModel(
      favouritelistingId: favouritelistingId ?? this.favouritelistingId,
      title: title ?? this.title,
      count: count ?? this.count,
      latestItem: latestItem ?? this.latestItem,
    );
  }
}

class LatestFavoriteItem {
  final int? id;
  final String? image;

  LatestFavoriteItem({
    this.id,
    this.image,
  });

  factory LatestFavoriteItem.fromJson(Map<String, dynamic> json) {
    int? parseId(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      return int.tryParse(val.toString());
    }

    return LatestFavoriteItem(
      id: parseId(json['id']),
      image: json['image']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image': image,
    };
  }
}
