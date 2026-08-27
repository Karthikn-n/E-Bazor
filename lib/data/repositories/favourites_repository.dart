import 'package:Ebozor/data/model/data_output.dart';
import 'package:Ebozor/data/model/favorite_listing_model.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';

class FavoriteRepository {
  Future<Map<String, dynamic>> manageFavorites(int id,
      {int? favouritelistingId}) async {
    Map<String, dynamic> parameters = {
      Api.itemId: id,
      if (favouritelistingId != null) 'favouritelisting_id': favouritelistingId,
    };

    Map<String, dynamic> response = await Api.post(
      url: Api.manageFavouriteApi,
      parameter: parameters,
      useBaseUrl: true,
    );
    return response;
  }

  Future<Set<int?>> fetchFavoriteMembershipIdsForItem({
    required int itemId,
  }) async {
    final currentUserId = HiveUtils.getUserId()?.toString();
    var page = 1;

    while (true) {
      final response = await Api.get(
        url: Api.getFavoriteItemApi,
        queryParameters: {Api.page: page},
        useBaseUrl: true,
      );
      final pagination = response['data'];
      final rawItems = pagination is Map && pagination['data'] is List
          ? pagination['data'] as List
          : const <dynamic>[];

      for (final rawItem in rawItems) {
        if (rawItem is! Map || rawItem['id']?.toString() != itemId.toString()) {
          continue;
        }

        final memberships = <int?>{};
        final rawFavorites = rawItem['favourites'];
        if (rawFavorites is List) {
          for (final rawFavorite in rawFavorites) {
            if (rawFavorite is! Map ||
                !rawFavorite.containsKey('favouritelisting_id')) {
              continue;
            }
            final membershipUserId = rawFavorite['user_id']?.toString();
            if (currentUserId != null &&
                membershipUserId != null &&
                membershipUserId != currentUserId) {
              continue;
            }

            final rawListingId = rawFavorite['favouritelisting_id'];
            if (rawListingId == null) {
              memberships.add(null);
            } else {
              final listingId = int.tryParse(rawListingId.toString());
              if (listingId != null) memberships.add(listingId);
            }
          }
        }
        return memberships;
      }

      final currentPage = pagination is Map
          ? int.tryParse(pagination['current_page'].toString())
          : 1;
      final lastPage = pagination is Map
          ? int.tryParse(pagination['last_page'].toString())
          : 1;
      if (rawItems.isEmpty ||
          (currentPage ?? page) >= (lastPage ?? currentPage ?? page)) {
        return <int?>{};
      }
      page++;
    }
  }

  Future<Map<String, dynamic>> removeFavoriteEverywhere(int itemId) async {
    final memberships = await fetchFavoriteMembershipIdsForItem(itemId: itemId);
    if (memberships.isEmpty) {
      throw StateError('No favorite-list membership was found for this item.');
    }

    Map<String, dynamic> lastResponse = <String, dynamic>{};
    for (final listingId in memberships) {
      lastResponse = await manageFavorites(
        itemId,
        favouritelistingId: listingId,
      );
    }

    final remaining = await fetchFavoriteMembershipIdsForItem(itemId: itemId);
    if (remaining.isNotEmpty) {
      throw StateError(
          'The item could not be removed from every favorite list.');
    }

    return {
      ...lastResponse,
      'message': 'Removed from all Favorites',
      'removed_membership_count': memberships.length,
    };
  }

  Future<DataOutput<ItemModel>> fetchFavorites({
    required int page,
    int? favouritelistingId,
    String? search,
    int? categoryId,
  }) async {
    Map<String, dynamic> parameters = {
      Api.page: page,
      if (favouritelistingId != null) 'favouritelisting_id': favouritelistingId,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (categoryId != null && categoryId > 0) 'category_id': categoryId,
    };

    Map<String, dynamic> response = await Api.get(
      url: Api.getFavoriteItemApi,
      queryParameters: parameters,
      useBaseUrl: true,
    );

    List<ItemModel> modelList = [];
    if (response['data'] != null &&
        response['data']['data'] != null &&
        response['data']['data'] is List) {
      modelList = (response['data']['data'] as List)
          .map((e) => ItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return DataOutput<ItemModel>(
      total: response['data']?['total'] ?? modelList.length,
      modelList: modelList,
    );
  }

  Future<Set<int>> fetchFavoriteListingIdsForItem({
    required int itemId,
    required Iterable<int> listingIds,
  }) async {
    final containingListingIds = <int>{};

    await Future.wait(listingIds.map((listingId) async {
      var page = 1;
      var fetchedCount = 0;

      while (true) {
        final result = await fetchFavorites(
          page: page,
          favouritelistingId: listingId,
        );
        if (result.modelList.any((item) => item.id == itemId)) {
          containingListingIds.add(listingId);
          return;
        }

        fetchedCount += result.modelList.length;
        if (result.modelList.isEmpty || fetchedCount >= result.total) return;
        page++;
      }
    }));

    return containingListingIds;
  }

  Future<List<FavoriteListingModel>> fetchFavoriteListings(
      {required String userId}) async {
    Map<String, dynamic> parameters = {
      'user_id': userId,
    };

    Map<String, dynamic> response = await Api.post(
      url: Api.getFavouriteListingApi,
      parameter: parameters,
      useBaseUrl: true,
    );

    List<FavoriteListingModel> listings = [];
    if (response['data'] != null &&
        response['data']['listings'] != null &&
        response['data']['listings'] is List) {
      listings = (response['data']['listings'] as List)
          .map((e) => FavoriteListingModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return listings;
  }

  Future<Map<String, dynamic>> createFavoriteListing({
    required String listingName,
    required String userId,
  }) async {
    Map<String, dynamic> parameters = {
      'listing_name': listingName,
      'user_id': userId,
    };

    return await Api.post(
      url: Api.favouriteListingApi,
      parameter: parameters,
      useBaseUrl: true,
    );
  }

  Future<Map<String, dynamic>> renameFavoriteListing({
    required int listingId,
    required String listingName,
  }) async {
    Map<String, dynamic> parameters = {
      'listing_id': listingId,
      'listing_name': listingName,
    };

    return await Api.post(
      url: Api.favouriteListingApi,
      parameter: parameters,
      useBaseUrl: true,
    );
  }

  Future<Map<String, dynamic>> deleteFavoriteListing({
    required int listingId,
  }) async {
    Map<String, dynamic> parameters = {
      'type': 'delete',
      'listing_id': listingId,
    };

    return await Api.post(
      url: Api.favouriteListingApi,
      parameter: parameters,
      useBaseUrl: true,
    );
  }
}
