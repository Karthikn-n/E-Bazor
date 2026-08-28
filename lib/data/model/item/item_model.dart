import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/model/custom_field/custom_field_model.dart';
import 'package:Ebozor/data/model/seller_ratings_model.dart';

class ItemModel {
  int? id;
  String? name;
  String? slug;
  String? description;
  double? price;
  String? image;
  dynamic watermarkimage;
  double? _latitude;
  double? _longitude;
  String? address;
  String? contact;
  int? totalLikes;
  int? views;
  String? type;
  String? status;
  bool? active;
  String? videoLink;
  User? user;
  List<GalleryImages>? galleryImages;
  List<ItemOffers>? itemOffers;
  CategoryModel? category;
  List<CustomFieldModel>? customFields;
  bool? isLike;
  bool? isFeature;
  String? created;
  String? itemType;
  int? userId;
  int? categoryId;
  bool? isAlreadyOffered;
  bool? isAlreadyReported;
  String? allCategoryIds;
  String? rejectedReason;
  int? areaId;
  String? area;
  String? city;
  String? state;
  String? country;
  int? isPurchased;
  bool? hidePhoneNumber;
  List<UserRatings>? review;
  int? carMake;
  int? carModel;
  int? carTrim;
  String? carMakeName;
  String? carModelName;
  String? carTrimName;

  Set<int> get categoryPathIds {
    final ids = <int>{};
    if (categoryId != null) ids.add(categoryId!);
    for (final rawId in (allCategoryIds ?? '').split(',')) {
      final parsed = int.tryParse(rawId.trim());
      if (parsed != null) ids.add(parsed);
    }
    return ids;
  }

  String get _categorySearchText =>
      '${category?.name ?? ''} ${category?.slug ?? ''}'.toLowerCase();

  /// Root category IDs from the API are the most reliable way to decide which
  /// contact actions belong to an item. Text checks keep older payloads that do
  /// not include `all_category_ids` working.
  bool get isMotorsCategory =>
      categoryPathIds.contains(1) ||
      _categorySearchText.contains('motor') ||
      _categorySearchText.contains('car') ||
      _categorySearchText.contains('bike');

  bool get isPropertyCategory =>
      categoryPathIds.contains(3) ||
      _categorySearchText.contains('property') ||
      _categorySearchText.contains('residential') ||
      _categorySearchText.contains('commercial');

  bool get isJobsCategory {
    if (categoryPathIds.contains(4) ||
        categoryPathIds.contains(356) ||
        categoryPathIds.contains(357) ||
        _categorySearchText.contains('job') ||
        _categorySearchText.contains('hiring')) {
      return true;
    }
    if (customFields != null && customFields!.isNotEmpty) {
      return customFields!.any((cf) {
        final name = (cf.name ?? '').toLowerCase();
        return name == 'job role' ||
            name == 'monthly salary' ||
            name == 'employment type' ||
            name == 'cv required' ||
            name == 'minimum work experience' ||
            name == 'minimum education level';
      });
    }
    return false;
  }

  /// Employer-created job vacancy posts live under the "I'm hiring" branch
  /// (category 356). Candidate/"I want a job" posts use category 357 and must
  /// keep their separate CV actions.
  bool get isHiringPost {
    if (categoryPathIds.contains(356) ||
        _categorySearchText.contains('hiring')) {
      return true;
    }
    if (isJobsCategory) {
      if (categoryPathIds.contains(357) ||
          _categorySearchText.contains('want a job') ||
          _categorySearchText.contains('candidate')) {
        return false;
      }
      return true;
    }
    return false;
  }

  bool get isClassifiedsCategory =>
      categoryPathIds.contains(2) ||
      _categorySearchText.contains('classified') ||
      _categorySearchText.contains('mobile phone');

  bool get supportsChatContact => isMotorsCategory || isClassifiedsCategory;

  String? get sellerPhone {
    final itemPhone = contact?.trim();
    if (itemPhone != null && itemPhone.isNotEmpty) return itemPhone;
    final userPhone = user?.mobile?.trim();
    return userPhone != null && userPhone.isNotEmpty ? userPhone : null;
  }

  bool get hasVisiblePhoneNumber =>
      hidePhoneNumber != true && sellerPhone != null;

  double? get latitude => _latitude;

  set latitude(dynamic value) {
    if (value is int) {
      _latitude = value.toDouble();
    } else if (value is double) {
      _latitude = value;
    } else {
      _latitude = null;
    }
  }

  double? get longitude => _longitude;

  set longitude(dynamic value) {
    if (value is int) {
      _longitude = value.toDouble();
    } else if (value is double) {
      _longitude = value;
    } else {
      _longitude = null;
    }
  }

  ItemModel(
      {this.id,
      this.name,
      this.slug,
      this.category,
      this.description,
      this.price,
      this.image,
      this.watermarkimage,
      dynamic latitude,
      dynamic longitude,
      this.address,
      this.contact,
      this.type,
      this.status,
      this.active,
      this.totalLikes,
      this.views,
      this.videoLink,
      this.user,
      this.galleryImages,
      this.itemOffers,
      this.customFields,
      this.isLike,
      this.isFeature,
      this.created,
      this.itemType,
      this.userId,
      this.categoryId,
      this.isAlreadyOffered,
      this.isAlreadyReported,
      this.rejectedReason,
      this.allCategoryIds,
      this.areaId,
      this.area,
      this.city,
      this.state,
      this.country,
      this.review,
      this.isPurchased,
      this.hidePhoneNumber,
      this.carMake,
      this.carModel,
      this.carTrim,
      this.carMakeName,
      this.carModelName,
      this.carTrimName}) {
    this.latitude = latitude;
    this.longitude = longitude;
  }

  ItemModel copyWith(
      {int? id,
      String? name,
      String? slug,
      String? description,
      double? price,
      String? image,
      dynamic watermarkimage,
      dynamic latitude,
      dynamic longitude,
      String? address,
      String? contact,
      int? totalLikes,
      int? views,
      String? type,
      String? status,
      bool? active,
      String? videoLink,
      User? user,
      List<GalleryImages>? galleryImages,
      List<ItemOffers>? itemOffers,
      CategoryModel? category,
      List<CustomFieldModel>? customFields,
      bool? isLike,
      bool? isFeature,
      String? created,
      String? itemType,
      int? userId,
      bool? isAlreadyOffered,
      bool? isAlreadyReported,
      String? allCategoryIds,
      int? categoryId,
      int? areaId,
      String? area,
      String? city,
      String? state,
      String? country,
      int? isPurchased,
      List<UserRatings>? review}) {
    return ItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      category: category ?? this.category,
      description: description ?? this.description,
      price: price ?? this.price,
      image: image ?? this.image,
      watermarkimage: watermarkimage ?? this.watermarkimage,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      contact: contact ?? this.contact,
      type: type ?? this.type,
      status: status ?? this.status,
      active: active ?? this.active,
      totalLikes: totalLikes ?? this.totalLikes,
      views: views ?? this.views,
      videoLink: videoLink ?? this.videoLink,
      user: user ?? this.user,
      galleryImages: galleryImages ?? this.galleryImages,
      itemOffers: itemOffers ?? this.itemOffers,
      customFields: customFields ?? this.customFields,
      isLike: isLike ?? this.isLike,
      isFeature: isFeature ?? this.isFeature,
      created: created ?? this.created,
      itemType: itemType ?? this.itemType,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      isAlreadyOffered: isAlreadyOffered ?? this.isAlreadyOffered,
      isAlreadyReported: isAlreadyReported ?? this.isAlreadyReported,
      allCategoryIds: allCategoryIds ?? this.allCategoryIds,
      rejectedReason: rejectedReason ?? this.rejectedReason,
      areaId: areaId ?? this.areaId,
      area: area ?? this.area,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      isPurchased: isPurchased ?? this.isPurchased,
      review: review ?? this.review,
    );
  }

  ItemModel.fromJson(Map<String, dynamic> json) {
    if (json['area'] != null) {
      areaId = json['area']['id'];
      area = json['area']['name'];
    }

    if (json['price'] is int) {
      price = (json['price'] as int).toDouble();
    } else {
      price = json['price'];
    }

    id = json['id'];
    name = json['name'];
    slug = json['slug'];
    category = json['category'] != null
        ? CategoryModel.fromJson(json['category'])
        : null;
    totalLikes = json['total_likes'];
    views = json['clicks'];
    description = json['description'];

    image = json['image'];
    watermarkimage = json['watermark_image'];
    latitude = json['latitude'];
    longitude = json['longitude'];
    address = json['address'];
    contact = json['contact'];
    type = json['type'];
    status = _normalizedListingStatus(json);
    active = json['active'] == 0 ? false : true;
    videoLink = json['video_link'];
    isLike = json['is_liked'];
    isFeature = json['is_feature'];
    created = json['created_at'];
    itemType = json['item_type'];
    userId = json['user_id'];
    categoryId = json['category_id'];
    isAlreadyOffered = json['is_already_offered'];
    isAlreadyReported = json['is_already_reported'];
    allCategoryIds = json['all_category_ids'];
    rejectedReason = json['rejected_reason'];
    city = json['city'];
    state = json['state'];
    country = json['country'];
    hidePhoneNumber = json['hide_phone_number'] == true ||
        json['hide_phone_number'] == 1 ||
        json['hide_phone_number'] == '1' ||
        json['hide_phone_number'] == 'true';
    if (json['is_purchased'] is int) {
      isPurchased = json['is_purchased'];
    } else if (json['is_purchased'] is bool) {
      isPurchased = json['is_purchased'] == true ? 1 : 0;
    } else if (json['is_purchased'] != null) {
      isPurchased = int.tryParse(json['is_purchased'].toString());
    }

    if (json['car_make'] is int) {
      carMake = json['car_make'];
    } else if (json['car_make'] != null) {
      carMake = int.tryParse(json['car_make'].toString());
    }
    if (json['car_model'] is int) {
      carModel = json['car_model'];
    } else if (json['car_model'] != null) {
      carModel = int.tryParse(json['car_model'].toString());
    }
    if (json['car_trim'] is int) {
      carTrim = json['car_trim'];
    } else if (json['car_trim'] != null) {
      carTrim = int.tryParse(json['car_trim'].toString());
    }
    carMakeName = json['car_make_name']?.toString();
    carModelName = json['car_model_name']?.toString();
    carTrimName = json['car_trim_name']?.toString();

    if (json['review'] != null) {
      review = <UserRatings>[];
      json['review'].forEach((v) {
        review!.add(UserRatings.fromJson(v));
      });
    }
    user = json['user'] != null ? User.fromJson(json['user']) : null;
    if (json['gallery_images'] != null) {
      galleryImages = <GalleryImages>[];
      json['gallery_images'].forEach((v) {
        galleryImages!.add(GalleryImages.fromJson(v));
      });
    }
    if (json['item_offers'] != null) {
      itemOffers = <ItemOffers>[];
      json['item_offers'].forEach((v) {
        itemOffers!.add(ItemOffers.fromJson(v));
      });
    }
    if (json['custom_fields'] is List &&
        (json['custom_fields'] as List).isNotEmpty) {
      customFields = <CustomFieldModel>[];
      for (final v in (json['custom_fields'] as List)) {
        if (v is Map<String, dynamic>) {
          customFields!.add(CustomFieldModel.fromMap(v));
        } else if (v is Map) {
          customFields!
              .add(CustomFieldModel.fromMap(Map<String, dynamic>.from(v)));
        }
      }
    } else if (json['item_custom_field_values'] is List &&
        (json['item_custom_field_values'] as List).isNotEmpty) {
      customFields = <CustomFieldModel>[];
      for (final v in (json['item_custom_field_values'] as List)) {
        if (v is Map) {
          final cf = v['custom_field'];
          if (cf != null && cf is Map) {
            Map<String, dynamic> combined = Map<String, dynamic>.from(cf);
            combined['value'] = v['value'];
            combined['id'] = v['custom_field_id'] ?? combined['id'];
            customFields!.add(CustomFieldModel.fromMap(combined));
          }
        }
      }
    } else {
      customFields = <CustomFieldModel>[];
    }
  }

  /// Older API responses can return an empty status after a listing package
  /// has already been assigned. Those listings are paid/live; treating every
  /// blank value as payment-pending makes paid ads show another Pay action.
  static String? _normalizedListingStatus(Map<String, dynamic> json) {
    final rawStatus = json['status']?.toString().trim() ?? '';
    if (rawStatus.isNotEmpty) return rawStatus;

    final hasAssignedPackage =
        json['package_id'] != null || json['listing_package_id'] != null;
    if (hasAssignedPackage) return 'active';

    return rawStatus;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['slug'] = slug;
    data['description'] = description;
    data['price'] = price;
    data['total_likes'] = totalLikes;
    data['clicks'] = views;
    data['image'] = image;
    data['watermark_image'] = watermarkimage;
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    data['address'] = address;
    data['contact'] = contact;
    data['type'] = type;
    data['status'] = status;
    data['active'] = active;
    data['video_link'] = videoLink;
    data['is_liked'] = isLike;
    data['is_feature'] = isFeature;
    data['created_at'] = created;
    data['item_type'] = itemType;
    data['user_id'] = userId;
    data['category_id'] = categoryId;
    data['is_already_offered'] = isAlreadyOffered;
    data['is_already_reported'] = isAlreadyReported;
    data['all_category_ids'] = allCategoryIds;
    data['rejected_reason'] = rejectedReason;
    data['is_purchased'] = isPurchased;
    if (review != null) {
      data['review'] = review!.map((v) => v.toJson()).toList();
    }
    data['city'] = city;
    data['state'] = state;
    data['country'] = country;
    print(data['category']);
    data['category'] = category!.toJson();
    if (areaId != null && area != null) {
      data['area'] = {
        'id': areaId,
        'name': area,
      };
    }
    data['user'] = user!.toJson();

    if (galleryImages != null) {
      data['gallery_images'] = galleryImages!.map((v) => v.toJson()).toList();
    }
    if (itemOffers != null) {
      data['item_offers'] = itemOffers!.map((v) => v.toJson()).toList();
    }
    if (customFields != null) {
      data['custom_fields'] = customFields!.map((v) => v.toMap()).toList();
    }
    if (carMake != null) data['car_make'] = carMake;
    if (carModel != null) data['car_model'] = carModel;
    if (carTrim != null) data['car_trim'] = carTrim;
    if (carMakeName != null) data['car_make_name'] = carMakeName;
    if (carModelName != null) data['car_model_name'] = carModelName;
    if (carTrimName != null) data['car_trim_name'] = carTrimName;
    return data;
  }

  @override
  String toString() {
    return 'ItemModel{id: $id, name: $name,slug:$slug, description: $description, price: $price, image: $image, watermarkimage: $watermarkimage, latitude: $latitude, longitude: $longitude, address: $address, contact: $contact, total_likes: $totalLikes,isLiked: $isLike, isFeature: $isFeature,views: $views, type: $type, status: $status, active: $active, videoLink: $videoLink, user: $user, galleryImages: $galleryImages,itemOffers:$itemOffers, category: $category, customFields: $customFields,createdAt:$created,itemType:$itemType,userId:$userId,categoryId:$categoryId,isAlreadyOffered:$isAlreadyOffered,isAlreadyReported:$isAlreadyReported,allCategoryId:$allCategoryIds,rejected_reason:$rejectedReason,area_id:$areaId,area:$area,city:$city,state:$state,country:$country,is_purchased:$isPurchased,review:$review}';
  }
}

class User {
  int? id;
  String? name;
  String? mobile;
  String? email;
  String? type;
  String? profile;
  String? resume;
  String? fcmId;
  String? firebaseId;
  int? status;
  String? apiToken;
  dynamic address;
  String? createdAt;
  String? updatedAt;
  int? showPersonalDetails;
  int? isVerified;
  int? reviewsCount;
  dynamic averageRating;
  int? overallCount;
  String? countryCode;

  User(
      {this.id,
      this.name,
      this.mobile,
      this.email,
      this.type,
      this.profile,
      this.resume,
      this.fcmId,
      this.firebaseId,
      this.status,
      this.apiToken,
      this.address,
      this.createdAt,
      this.updatedAt,
      this.isVerified,
      this.showPersonalDetails,
      this.reviewsCount,
      this.averageRating,
      this.overallCount,
      this.countryCode});

  User.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    mobile = json['mobile'];
    email = json['email'];
    type = json['type'];
    profile = json['profile'];
    resume = json['resume'];
    fcmId = json['fcm_id'];
    firebaseId = json['firebase_id'];
    status = json['status'];
    apiToken = json['api_token'];
    address = json['address'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    isVerified = json['is_verified'];
    showPersonalDetails = json['show_personal_details'];
    reviewsCount = json['reviews_count'];
    averageRating = json['average_rating'];
    overallCount = json['overall_count'];
    countryCode = json['country_code'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['mobile'] = mobile;
    data['email'] = email;
    data['type'] = type;
    data['profile'] = profile;
    data['resume'] = resume;
    data['fcm_id'] = fcmId;
    data['firebase_id'] = firebaseId;
    data['status'] = status;
    data['api_token'] = apiToken;
    data['address'] = address;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['is_verified'] = isVerified;
    data['show_personal_details'] = showPersonalDetails;
    data['reviews_count'] = reviewsCount;
    data['average_rating'] = averageRating;
    data['overall_count'] = overallCount;
    data['country_code'] = countryCode;
    return data;
  }
}

class GalleryImages {
  int? id;
  String? image;
  String? createdAt;
  String? updatedAt;
  int? itemId;

  GalleryImages(
      {this.id, this.image, this.createdAt, this.updatedAt, this.itemId});

  GalleryImages.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    image = json['image'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    itemId = json['item_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['image'] = image;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['item_id'] = itemId;
    return data;
  }
}

class ItemOffers {
  int? id;
  int? sellerId;
  int? buyerId;
  String? createdAt;
  String? updatedAt;
  double? amount;

  ItemOffers(
      {this.id,
      this.sellerId,
      this.createdAt,
      this.updatedAt,
      this.buyerId,
      this.amount});

  ItemOffers.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    buyerId = json['buyer_id'];
    sellerId = json['seller_id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];

    // Handle amount being int or double
    if (json['amount'] is int) {
      amount = (json['amount'] as int).toDouble();
    } else if (json['amount'] is double) {
      amount = json['amount'];
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['buyer_id'] = buyerId;
    data['seller_id'] = sellerId;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['amount'] = amount;
    return data;
  }
}

/*class ItemOffers {
  int? id;
  int? sellerId;
  int? buyerId;
  String? createdAt;
  String? updatedAt;
  double? amount;

  ItemOffers(
      {this.id,
      this.sellerId,
      this.createdAt,
      this.updatedAt,
      this.buyerId,
      this.amount});

  ItemOffers.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    buyerId = json['buyer_id'];
    sellerId = json['seller_id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    amount = json['amount'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['buyer_id'] = buyerId;
    data['seller_id'] = sellerId;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['amount'] = amount;
    return data;
  }
}*/
