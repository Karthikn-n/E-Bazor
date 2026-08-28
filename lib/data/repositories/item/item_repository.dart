import 'dart:convert';
import 'dart:io';

import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:dio/dio.dart';
import 'package:Ebozor/data/model/item_filter_model.dart';
import 'package:Ebozor/utils/ApiService/api.dart';
import 'package:Ebozor/data/model/data_output.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:path/path.dart' as path;

class ItemRepository {
  static void _sanitizeContact(Map<String, dynamic> parameters) {
    if (parameters.containsKey('contact')) {
      final raw = parameters['contact']?.toString().trim() ?? '';
      final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        parameters['contact'] = digits;
      } else {
        final userMobile =
            HiveUtils.getUserDetails().mobile?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
        if (userMobile.isNotEmpty) {
          parameters['contact'] = userMobile;
        }
      }
    }
  }

  Future<ItemModel> createItem(
    Map<String, dynamic> itemDetails,
    File? mainImage,
    List<File>? otherImages,
  ) async {
    try {
      Map<String, dynamic> parameters = {};
      parameters.addAll(itemDetails);
      _sanitizeContact(parameters);

      // Main image
      if (mainImage != null) {
        MultipartFile image = await MultipartFile.fromFile(mainImage.path,
            filename: path.basename(mainImage.path));
        parameters["image"] = image;
      }

      if (otherImages != null && otherImages.isNotEmpty) {
        List<Future<MultipartFile>> futures = otherImages.map((imageFile) {
          return MultipartFile.fromFile(imageFile.path,
              filename: path.basename(imageFile.path));
        }).toList();

        List<MultipartFile> galleryImages = await Future.wait(futures);

        if (galleryImages.isNotEmpty) {
          parameters["gallery_images"] = galleryImages;
        }
      }

      parameters["show_only_to_premium"] = 1;

      Map<String, dynamic> response = await Api.post(
        url: Api.addItemApi,
        parameter: parameters, /* useAuthToken: true*/
      );

      if (response['error'] == true) {
        final errDetails = response['details']?.toString() ?? '';
        final errMsg = response['message']?.toString() ?? 'Error Occurred';
        throw ApiException(
            errDetails.isNotEmpty ? "$errMsg: $errDetails" : errMsg);
      }

      dynamic resData = response['data'];
      if (resData is List && resData.isNotEmpty) {
        return ItemModel.fromJson(resData[0]);
      } else if (resData is Map<String, dynamic>) {
        if (resData['data'] is List && (resData['data'] as List).isNotEmpty) {
          return ItemModel.fromJson(resData['data'][0]);
        }
        return ItemModel.fromJson(resData);
      }
      return ItemModel.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<DataOutput<ItemModel>> fetchMyFeaturedItems({int? page}) async {
    try {
      Map<String, dynamic> parameters = {"status": "featured", "page": page};

      Map<String, dynamic> response = await Api.get(
        url: Api.getMyItemApi,
        queryParameters: parameters, /*useAuthToken: true*/
      );
      List<ItemModel> itemList = (response['data']['data'] as List)
          .map((element) => ItemModel.fromJson(element))
          .toList();

      return DataOutput(
          total: response['data']['total'] ?? 0, modelList: itemList);
    } catch (e) {
      rethrow;
    }
  }

  Future<DataOutput<ItemModel>> fetchMyItems(
      {String? getItemsWithStatus, int? page}) async {
    try {
      Map<String, dynamic> parameters = {
        if (getItemsWithStatus != null) "status": getItemsWithStatus,
        if (page != null) Api.page: page
      };

      if (parameters['status'] == "") parameters.remove('status');
      Map<String, dynamic> response = await Api.get(
        url: Api.getMyItemApi,
        queryParameters: parameters, /*useAuthToken: true*/
      );
      List<ItemModel> itemList = (response['data']['data'] as List)
          .map((element) => ItemModel.fromJson(element))
          .toList();

      return DataOutput(
          total: response['data']['total'] ?? 0, modelList: itemList);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, int>> fetchMyItemsCount({String? categorySlug}) async {
    try {
      Map<String, dynamic> parameters = {
        if (categorySlug != null && categorySlug.isNotEmpty)
          "category_slug": categorySlug,
      };

      Map<String, dynamic> response = await Api.get(
        url: Api.getMyItemsCountApi,
        queryParameters: parameters,
      );

      var data = response['data'];
      if (data is Map) {
        return {
          "all_ads": int.tryParse(data['all_ads']?.toString() ?? '0') ?? 0,
          "live": int.tryParse(data['live']?.toString() ?? '0') ?? 0,
          "drafts": int.tryParse(data['drafts']?.toString() ?? '0') ?? 0,
          "payment_pending":
              int.tryParse(data['payment_pending']?.toString() ?? '0') ?? 0,
          "under_review":
              int.tryParse(data['under_review']?.toString() ?? '0') ?? 0,
          "inactive": int.tryParse(data['inactive']?.toString() ?? '0') ?? 0,
          "rejected": int.tryParse(data['rejected']?.toString() ?? '0') ?? 0,
          "expired": int.tryParse(data['expired']?.toString() ?? '0') ?? 0,
        };
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<DataOutput<ItemModel>> fetchItemFromItemId(int id,
      {int? categoryId, String? status}) async {
    Map<String, dynamic> parameters = {
      Api.id: id,
    };
    if (categoryId != null) {
      parameters[Api.categoryId] = categoryId;
    }
    if (status != null && status.isNotEmpty) {
      parameters['status'] = status;
    }

    Map<String, dynamic> response = await Api.get(
      url: Api.getItemApi,
      queryParameters: parameters,
    );

    List rawList = [];
    if (response['data'] is List) {
      rawList = response['data'];
    } else if (response['data'] is Map && response['data']['data'] is List) {
      rawList = response['data']['data'];
    } else if (response['data'] is Map) {
      rawList = [response['data']];
    }

    List<ItemModel> modelList = rawList
        .map((e) => ItemModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return DataOutput(total: modelList.length, modelList: modelList);
  }

  Future<DataOutput<ItemModel>> fetchItemFromItemSlug(String slug,
      {int? categoryId, String? status}) async {
    Map<String, dynamic> parameters = {
      "slug": slug,
    };
    if (categoryId != null) {
      parameters[Api.categoryId] = categoryId;
    }
    if (status != null && status.isNotEmpty) {
      parameters['status'] = status;
    }

    Map<String, dynamic> response = await Api.get(
      url: Api.getItemApi,
      queryParameters: parameters,
    );

    List rawList = [];
    if (response['data'] is List) {
      rawList = response['data'];
    } else if (response['data'] is Map && response['data']['data'] is List) {
      rawList = response['data']['data'];
    } else if (response['data'] is Map) {
      rawList = [response['data']];
    }

    List<ItemModel> modelList = rawList
        .map((e) => ItemModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return DataOutput(total: modelList.length, modelList: modelList);
  }

  Future<Map> changeMyItemStatus(
      {required int itemId, required String status, int? userId}) async {
    Map response = await Api.post(url: Api.updateItemStatusApi, parameter: {
      Api.status: status,
      Api.itemId: itemId,
      Api.soldTo: userId
    });
    return response;
  }

  Future<Map> createFeaturedAds({required int itemId}) async {
    Map response = await Api.post(url: Api.makeItemFeaturedApi, parameter: {
      "item_id": itemId,
    });
    return response;
  }

  Future<DataOutput<ItemModel>> fetchItemFromCatId(
      {required int categoryId,
      required int page,
      String? search,
      String? sortBy,
      String? country,
      String? state,
      String? city,
      int? areaId,
      ItemFilterModel? filter}) async {
    Map<String, dynamic> parameters = {
      Api.categoryId: categoryId,
      Api.page: page,
    };

    final effRadius = filter?.radius ?? HiveUtils.getNearbyRadius();
    final effLat = filter?.latitude ??
        HiveUtils.getLatitude() ??
        HiveUtils.getCurrentLatitude();
    final effLong = filter?.longitude ??
        HiveUtils.getLongitude() ??
        HiveUtils.getCurrentLongitude();

    if (effRadius != null && effLat != null && effLong != null) {
      parameters['radius'] = effRadius;
      parameters['latitude'] = effLat;
      parameters['longitude'] = effLong;
    } else {
      final effCountry = (filter?.country != null &&
              filter!.country!.trim().isNotEmpty)
          ? filter.country!.trim()
          : (country != null && country.trim().isNotEmpty)
              ? country.trim()
              : HiveUtils.getCountryName();

      final effState = (filter?.state != null &&
              filter!.state!.trim().isNotEmpty)
          ? filter.state!.trim()
          : (state != null && state.trim().isNotEmpty)
              ? state.trim()
              : HiveUtils.getStateName();

      final effCity = (filter?.city != null && filter!.city!.trim().isNotEmpty)
          ? filter.city!.trim()
          : (city != null && city.trim().isNotEmpty)
              ? city.trim()
              : HiveUtils.getCityName();

      final effAreaId = filter?.areaId ?? areaId ?? HiveUtils.getAreaId();

      if (effCountry != null && effCountry.trim().isNotEmpty) {
        parameters['country'] = effCountry.trim();
      }
      if (effState != null && effState.trim().isNotEmpty) {
        parameters['state'] = effState.trim();
      }
      if (effCity != null && effCity.trim().isNotEmpty) {
        parameters['city'] = effCity.trim();
      }
      if (effAreaId != null && effAreaId > 0) {
        parameters['area_id'] = effAreaId;
      }
    }

    if (filter != null) {
      if (filter.minPrice != null &&
          filter.minPrice!.trim().isNotEmpty &&
          filter.minPrice != '0') {
        parameters['min_price'] = filter.minPrice!.trim();
      }
      if (filter.maxPrice != null && filter.maxPrice!.trim().isNotEmpty) {
        parameters['max_price'] = filter.maxPrice!.trim();
      }
      if (filter.postedSince != null && filter.postedSince!.trim().isNotEmpty) {
        parameters['posted_since'] = filter.postedSince!.trim();
      }
      if (filter.categorySlug != null &&
          filter.categorySlug!.trim().isNotEmpty) {
        parameters['category_slug'] = filter.categorySlug!.trim();
      }

      // Add custom fields / filters separately to the parameters
      if (filter.customFields != null && filter.customFields!.isNotEmpty) {
        filter.customFields!.forEach((key, value) {
          if (value == null) return;
          String paramKey = key;
          if (!key.startsWith('filters[') &&
              !key.startsWith('custom_fields[') &&
              int.tryParse(key) == null) {
            paramKey = "filters[$key]";
          }
          if (value is List) {
            if (paramKey.startsWith("filters[")) {
              parameters[paramKey] = jsonEncode(value);
            } else {
              parameters[paramKey] = value.map((v) => v.toString()).join(',');
            }
          } else if (value is Set) {
            if (paramKey.startsWith("filters[")) {
              parameters[paramKey] = jsonEncode(value.toList());
            } else {
              parameters[paramKey] = value.map((v) => v.toString()).join(',');
            }
          } else {
            parameters[paramKey] = value.toString();
          }
        });
      }
    }

    if (search != null && search.trim().isNotEmpty) {
      parameters[Api.search] = search.trim();
    }

    if (sortBy != null && sortBy.trim().isNotEmpty) {
      parameters[Api.sortBy] = sortBy.trim();
    }

    // Clean up empty strings and nulls
    parameters.removeWhere((k, v) =>
        v == null || (v is String && v.trim().isEmpty) || v == 'null');

    Map<String, dynamic> response =
        await Api.get(url: Api.getItemApi, queryParameters: parameters);

    List<ItemModel> items = (response['data']['data'] as List)
        .map((e) => ItemModel.fromJson(e))
        .toList();

    return DataOutput(total: response['data']['total'] ?? 0, modelList: items);
  }

/*  Future<DataOutput<ItemModel>> fetchItemFromCatId(
      {required int categoryId,
      required int page,
      String? search,
      String? sortBy,
      String? country,
      String? state,
      String? city,
      int? areaId,
      ItemFilterModel? filter}) async {
    Map<String, dynamic> parameters = {
      Api.categoryId: categoryId,
      Api.page: page,
      if (city != null && city != "") 'city': city,
      if (areaId != null && areaId != "") 'area_id': areaId,
      if (country != null && country != "") 'country': country,
      if (state != null && state != "") 'state': state,
    };

    if (filter != null) {
      parameters.addAll(filter.toMap());

      if (filter.areaId == null) {
        parameters.remove('area_id');
      }

      parameters.remove('area');

      // Add custom fields separately to the parameters
      if (filter.customFields != null) {
        filter.customFields!.forEach((key, value) {
          if (value is List) {
            parameters[key] = value.map((v) => v.toString()).join(',');
          } else {
            parameters[key] = value.toString();
          }
        });
      }
    }

    if (search != null) {
      parameters[Api.search] = search;
    }

    if (sortBy != null) {
      parameters[Api.sortBy] = sortBy;
    }

    Map<String, dynamic> response =
        await Api.get(url: Api.getItemApi, queryParameters: parameters);

    List<ItemModel> items = (response['data']['data'] as List)
        .map((e) => ItemModel.fromJson(e))
        .toList();

    return DataOutput(total: response['data']['total'] ?? 0, modelList: items);
  }*/

  Future<DataOutput<ItemModel>> fetchPopularItems(
      {required String sortBy, required int page}) async {
    Map<String, dynamic> parameters = {Api.sortBy: sortBy, Api.page: page};

    Map<String, dynamic> response =
        await Api.get(url: Api.getItemApi, queryParameters: parameters);

    List<ItemModel> items = (response['data']['data'] as List)
        .map((e) => ItemModel.fromJson(e))
        .toList();

    return DataOutput(total: response['data']['total'] ?? 0, modelList: items);
  }

  Future<ItemModel> editItem(
    Map<String, dynamic> itemDetails,
    File? mainImage,
    List<File>? otherImages,
  ) async {
    Map<String, dynamic> parameters = {};
    parameters.addAll(itemDetails);
    _sanitizeContact(parameters);

    if (mainImage != null) {
      MultipartFile image = await MultipartFile.fromFile(mainImage.path,
          filename: path.basename(mainImage.path));
      parameters['image'] = image;
    }

    if (otherImages != null && otherImages.isNotEmpty) {
      List<Future<MultipartFile>> futures = otherImages.map((imageFile) {
        return MultipartFile.fromFile(imageFile.path,
            filename: path.basename(imageFile.path));
      }).toList();

      List<MultipartFile> galleryImages = await Future.wait(futures);

      if (galleryImages.isNotEmpty) {
        parameters["gallery_images"] = galleryImages;
      }
    }

    Map<String, dynamic> response = await Api.post(
      url: Api.updateItemApi,
      parameter: parameters, /* useAuthToken: true*/
    );

    final editedItem = ItemModel.fromJson(response['data'][0]);
    final requestedStatus = itemDetails[Api.status]?.toString().trim() ?? '';

    // update-item currently returns a blank status for some unpaid ads even
    // when the request contains `status`. Restore it through the dedicated
    // status endpoint and always keep the edit result consistent locally.
    if (requestedStatus.isNotEmpty &&
        (editedItem.status?.trim().isEmpty ?? true) &&
        editedItem.id != null) {
      try {
        await changeMyItemStatus(
          itemId: editedItem.id!,
          status: requestedStatus,
        );
      } catch (_) {
        // The content edit succeeded. Payment-pending items can still be
        // represented as a blank status by the API until package assignment.
      }
      editedItem.status = requestedStatus;
    }

    return editedItem;
  }

  Future<void> deleteItem(int id) async {
    await Api.post(
      url: Api.deleteItemApi,
      parameter: {Api.id: id}, /* useAuthToken: true*/
    );
  }

  Future<void> itemTotalClick(int id) async {
    await Api.post(url: Api.setItemTotalClickApi, parameter: {Api.itemId: id});
  }

  Future<Map> makeAnOfferItem(int id, double? amount) async {
    Map response = await Api.post(
        url: Api.itemOfferApi,
        parameter: {Api.itemId: id, if (amount != null) Api.amount: amount});
    return response;
  }

  ///////////////
  /// search api called here
  Future<DataOutput<ItemModel>> searchItem(
      String query, ItemFilterModel? filter,
      {required int page}) async {
    Map<String, dynamic> parameters = {
      Api.search: query,
      Api.page: page,
    };

    if (filter != null && filter.radius != null) {
      if (filter.latitude != null && filter.longitude != null) {
        parameters['latitude'] = filter.latitude;
        parameters['longitude'] = filter.longitude;
        parameters['radius'] = filter.radius;
      }
    } else {
      String? effCountry =
          (filter?.country != null && filter!.country!.isNotEmpty)
              ? filter.country
              : HiveUtils.getCountryName();
      String? effState = (filter?.state != null && filter!.state!.isNotEmpty)
          ? filter.state
          : HiveUtils.getStateName();
      String? effCity = (filter?.city != null && filter!.city!.isNotEmpty)
          ? filter.city
          : HiveUtils.getCityName();
      int? effAreaId = filter?.areaId ?? HiveUtils.getAreaId();

      if (effCity != null && effCity.isNotEmpty) parameters['city'] = effCity;
      if (effState != null && effState.isNotEmpty)
        parameters['state'] = effState;
      if (effCountry != null && effCountry.isNotEmpty)
        parameters['country'] = effCountry;
      if (effAreaId != null) parameters['area_id'] = effAreaId;
    }

    if (filter != null) {
      if (filter.minPrice != null &&
          filter.minPrice!.isNotEmpty &&
          filter.minPrice != '0') {
        parameters['min_price'] = filter.minPrice;
      }
      if (filter.maxPrice != null && filter.maxPrice!.isNotEmpty) {
        parameters['max_price'] = filter.maxPrice;
      }
      if (filter.categoryId != null && filter.categoryId!.isNotEmpty) {
        parameters['category_id'] = filter.categoryId;
      }
      if (filter.postedSince != null && filter.postedSince!.isNotEmpty) {
        parameters['posted_since'] = filter.postedSince;
      }
      if (filter.categorySlug != null && filter.categorySlug!.isNotEmpty) {
        parameters['category_slug'] = filter.categorySlug;
      }
      if (filter.customFields != null && filter.customFields!.isNotEmpty) {
        filter.customFields!.forEach((key, value) {
          if (value == null) return;
          String paramKey = key;
          if (!key.startsWith('filters[') &&
              !key.startsWith('custom_fields[') &&
              int.tryParse(key) == null) {
            paramKey = "filters[$key]";
          }
          if (value is List) {
            if (paramKey.startsWith("filters[")) {
              parameters[paramKey] = jsonEncode(value);
            } else {
              parameters[paramKey] = value.map((v) => v.toString()).join(',');
            }
          } else if (value is Set) {
            if (paramKey.startsWith("filters[")) {
              parameters[paramKey] = jsonEncode(value.toList());
            } else {
              parameters[paramKey] = value.map((v) => v.toString()).join(',');
            }
          } else {
            parameters[paramKey] = value.toString();
          }
        });
      }
    }

    Map<String, dynamic> response =
        await Api.get(url: Api.getItemApi, queryParameters: parameters);

    List<ItemModel> items = (response['data']['data'] as List)
        .map((e) => ItemModel.fromJson(e))
        .toList();

    return DataOutput(total: response['data']['total'] ?? 0, modelList: items);
  }

  Future<DataOutput<ItemModel>> fetchSimilarProducts({
    required int categoryId,
    required int itemId,
  }) async {
    try {
      Map<String, dynamic> parameters = {
        "category_id": categoryId,
        "item_id": itemId,
      };

      Map<String, dynamic> response = await Api.post(
        url: Api.getSimilarProductApi,
        parameter: parameters,
      );

      List<ItemModel> itemList = [];
      int total = 0;

      if (response['data'] != null) {
        final data = response['data'];
        total = data['total_data'] ??
            (data['items'] is List ? (data['items'] as List).length : 0);
        if (data['items'] is List) {
          itemList = (data['items'] as List)
              .map((element) => ItemModel.fromJson(element))
              .toList();
        } else if (data['data'] is List) {
          itemList = (data['data'] as List)
              .map((element) => ItemModel.fromJson(element))
              .toList();
        }
      }

      return DataOutput(
        total: total,
        modelList: itemList,
      );
    } catch (e) {
      rethrow;
    }
  }
}
