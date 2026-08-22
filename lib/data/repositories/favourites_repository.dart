

import 'package:Ebozor/data/model/data_output.dart';
import 'package:Ebozor/data/model/favorite_listing_model.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/utils/ApiService/api.dart';

class FavoriteRepository {
  Future<Map<String, dynamic>> manageFavorites(int id, {int? favouritelistingId}) async {
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

  Future<List<FavoriteListingModel>> fetchFavoriteListings({required String userId}) async {
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
