import 'dart:io';

import 'package:Ebozor/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:Ebozor/data/cubits/system/user_details.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/network_request_interseptor.dart';
import 'package:Ebozor/data/cubits/chat/get_buyer_chat_users_cubit.dart';

import 'package:Ebozor/data/cubits/report/update_report_items_list_cubit.dart';
import 'package:Ebozor/data/cubits/chat/blocked_users_list_cubit.dart';
import 'package:Ebozor/data/cubits/favorite/favorite_cubit.dart';

import 'package:Ebozor/utils/errorFilter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ApiException implements Exception {
  ApiException(this.errorMessage);

  dynamic errorMessage;

  @override
  String toString() {
    return ErrorFilter.check(errorMessage).error;
  }
}

class Api {
  static Dio _dio() => Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
  // static Map<String, dynamic> headers() {
  //   if (!HiveUtils.isUserAuthenticated()) {
  //     if (HiveUtils.getLanguage() != null &&
  //         HiveUtils.getLanguage()?['data'] != null) {
  //       return {
  //         "Accept": "application/json",
  //         "Content-Language": HiveUtils.getLanguage()['code'] ?? ""
  //       };
  //     } else {
  //       return {};
  //     }
  //   } else {
  //
  //     //here token written
  //     String? jwtToken = HiveUtils.getJWT();
  //
  //
  //     print("jwt token****$jwtToken");
  //
  //
  //     return {
  //       "Authorization": "Bearer $jwtToken",
  //       "Accept": "application/json",
  //       "Content-Language": HiveUtils.getLanguage()['code'] ?? ""
  //     };
  //   }
  // }

  static Map<String, dynamic> headers({bool useAuthToken = true}) {
    final language = HiveUtils.getLanguage();
    final jwtToken = HiveUtils.getJWT();
    final langCode = language?['code']?.toString().trim() ?? "";
    final hasAuthHeader =
        useAuthToken && HiveUtils.isUserAuthenticated() && jwtToken != null;

    AppLog.i('headers() — auth: $hasAuthHeader, lang: $langCode', name: 'Api');

    Map<String, dynamic> header = {
      "Accept": "application/json",
      "Content-Language": langCode,
      if (langCode.isNotEmpty) "Accept-Language": langCode,
      if (langCode.isNotEmpty) "X-Localization": langCode,
      if (langCode.isNotEmpty) "Language": langCode,
    };

    if (hasAuthHeader) {
      header["Authorization"] = "Bearer $jwtToken";
    }

    return header;
  }

  static const String _placeApiBaseUrl =
      "https://maps.googleapis.com/maps/api/place/";
  static String placeApiKey = "key";
  static const String input = "input";
  static const String types = "types";
  static const String placeid = "placeid";
  static String placeAPI = "${_placeApiBaseUrl}autocomplete/json";
  static String placeApiDetails = "${_placeApiBaseUrl}details/json";

//

  static String stripeIntentAPI = "https://api.stripe.com/v1/payment_intents";
  static String getCategoryFiltersApi = "get-category-filters";
  static String getCategorySubdataApi = "category-subdata";
  static String getCategoryChildrenByParentApi =
      "get-category-children-by-parent";
  static String getParentCategoryListApi = "get-parent-category-list";
  static String getParentCategoriesApi = "get-parent-categories";
  static String getCategoryTreeBySlugApi = "get-category-tree-by-slug";

  // Cars module endpoints
  static String getCarMakesApi = "car_makes";
  static String getCarModelsApi = "car_models";
  static String getCarModelTrimsApi = "car_model_trims";
  static String getCarMakeModelsMergedApi = "car_make_models_merged";
  static String searchCarMakeModelApi = "search-car-make-model";
  static String getCarModelsSearchApi = "get-car-models";
//api fun
  static String loginApi = "user-signup";
  static String updateProfileApi = "update-profile";
  static String getSliderApi = "get-slider";
  static String getFrontCategoriesApi = "front_categories";
  static String getPopularJobApi = "get-popular-job";
  static String getJobCategoryHomeApi = "categoryhome";
  static String getJobTypeCountApi = "job-type-count";
  static String getJobQualificationCountApi = "job-qualification-count";
  static String searchBannerSuggestionApi = "search-banner-suggestion";
  static String getSimilarProductApi = "get-similar-product";
  static String addHelpMeBuyApi = "add-helpme-buy";
  static String getJobDashboardProfileApi = "get-job-dashboard-profile";
  static String getMyJobApplicationApi = "get-my-job-application";
  static String getJobApplicationInfoApi = "get-job-application-info";
  static String addJobApplicationInfoApi = "add-job-application-info";
  static String addUserDetailApi = "add-user-detail";
  static String getUserDetailApi = "get-user-detail";
  static String getApplyInfoApi = "get-apply-info";
  static String getItemApi = "get-item";
  static String getItemCountApi = "get-item-count";
  static String getMyItemApi = "my-items";
  static String getMyItemsCountApi = "my-items-count";
  static String getNotificationListApi = "get-notification-list";
  static String deleteUserApi = "delete-user";
  static String getDevicesApi = "get-devices";
  static String logoutDeviceApi = "logout-device";
  static String manageFavouriteApi = "manage-favourite";
  static String getFavouriteListingApi = "get-favourite-listing";
  static String favouriteListingApi = "favourite-listing";
  static String getPackageApi = "get-package";
  static String getLanguageApi = "get-languages";
  static String getPaymentSettingsApi = "get-payment-settings";
  static String getSystemSettingsApi = "get-system-settings";
  static String getFavoriteItemApi = "get-favourite-item";
  static String updateItemStatusApi = "update-item-status";
  static String getReportReasonsApi = "get-report-reasons";
  static String addReportsApi = "add-reports";
  static String adReportApi = "ad-report";
  static String sendItemInquiryApi = "send-item-inquiry";
  static String getCustomFieldsApi = "get-customfields";
  static String getCustomFieldsByCategoryIdApi =
      "get-customfields-by-category-id";
  static String getFeaturedSectionApi = "get-featured-section";
  static String updateItemApi = "update-item";
  static String addItemApi = "add-item";
  static String deleteItemApi = "delete-item";
  static String setItemTotalClickApi = "set-item-total-click";
  static String makeItemFeaturedApi = "make-item-featured";
  static String assignFreePackageApi = "assign-free-package";
  static String getLimitsOfPackageApi = "get-limits";
  static String getPaymentIntentApi = "payment-intent";
  static String inAppPurchaseApi = "in-app-purchase";
  static String getTipsApi = "tips";
  static String getCountriesApi = "countries";
  static String getStatesApi = "states";
  static String getCitiesApi = "cities";
  static String getAreasApi = "areas";
  static String getBlogApi = "blogs";
  static String getBlogTagsApi = "blog-tags";
  static String getFaqApi = "faq";
  static String getItemBuyerListApi = "item-buyer-list";
  static String getSellerApi = "get-seller";
  static String addItemReviewApi = "add-item-review";
  static String getVerificationFieldApi = "verification-fields";
  static String sendVerificationRequestApi = "send-verification-request";
  static String getVerificationRequestApi = "verification-request";
  static String setUserPhoneNumberApi = "set-user-phonenumber";
  static String getMyReviewApi = "my-review";
  static String addReviewReportApi = "add-review-report";
  static String renewItemApi = "renew-item";
  static String postContactUsApi = "contact-us";
  static String getUserAddressApi = "get-user-address";
  static String userAddressChangesApi = "user-address-changes";
  @Deprecated("Use Firebase Phone Auth SMS OTP instead")
  static String sendOtpApi = "send-otp";
  @Deprecated(
      "Use Firebase Phone Auth SMS OTP and set-user-phonenumber instead")
  static String verifyOtpApi = "verify-otp";
  static String getCategoriesApi = "get-categories";
  static String getHomeCategoriesApi = "get-home-categories";
  static String carFinanceApi = "car-finance";
  static String carInspectionApi = "car-inspection";
  static String savedSearchApi = "saved-search";
  static String editSavedSearchApi = "edit-saved-search";
  static String deleteSavedSearchApi = "delete-saved-search";
  static String getCarInspectionApi = "get-car-inspection";
  static String getCarAppointmentDetailsApi = "get-car-appointment-details";
  static String carEvaluationsApi = "car-evaluations";

//Chat module apis
  static String sendMessageApi = "send-message";
  static String getChatListApi = "chat-list";
  static String itemOfferApi = "item-offer";
  static String chatMessagesApi = "chat-messages";
  static String blockUserApi = "block-user";
  static String unBlockUserApi = "unblock-user";
  static String blockedUsersListApi = "blocked-users";
  static String getPaymentDetailsApi = "payment-transactions";

//WebSocket helper apis
  static String wsAuthApi = "ws/auth";
  static String wsMessageApi = "ws/message";
  static String wsCanJoinApi = "ws/can-join";
  static String wsPingApi = "ws/ping";
  static String wsPresenceApi = "ws/presence";

//not used API List

  static String userPurchasePackageApi = "user-purchase-package";
  static String deleteInquiryApi = "delete-inquiry";
  static String setItemEnquiryApi = "set-item_-inquiry";
  static String getItemApiEnquiry = "get-item-inquiry";
  static String interestedUsersApi = "interested-users";
  static String storeAdvertisementApi = "store-advertisement";
  static String deleteAdvertisementApi = "delete-advertisement";
  static String deleteChatMessageApi = "delete-chat-message";

//params
  static String id = "id";
  static String itemId = "item_id";
  static String mobile = "mobile";
  static String type = "type";
  static String firebaseId = "firebase_id";
  static String profile = "profile";
  static String fcmId = "fcm_id";
  static String address = "address";
  static String clientAddress = "client_address";
  static String email = "email";
  static String name = "name";
  static String amount = "amount";
  static String error = "error";
  static String message = "message";
  static String loginType = "logintype";
  static String isActive = "isActive";
  static String image = "image";
  static String category = "category";
  static String typeids = "typeids";
  static String userid = "userid";
  static String measurement = "measurement";
  static String categoryId = "category_id";
  static String title = "title";
  static String carpetArea = "carpet_area";
  static String builtUpArea = "built_up_area";
  static String plotArea = "plot_area";
  static String hectaArea = "hecta_area";
  static String acre = "acre";
  static String locationLatitude = "location_latitude";
  static String locationLongitude = "location_longitude";
  static String unitType = "unit_type";
  static String description = "description";
  static String furnished = "furnished";
  static String houseType = "house_type";
  static String taluka = "taluka";
  static String village = "village";
  static String properyType = "propery_type";
  static String price = "price";
  static String titleImage = "title_image";
  static String postCreated = "post_created";
  static String galleryImages = "gallery_images";
  static String typeId = "type_id";
  static String itemType = "item_type";
  static String imageUrl = "image_url";
  static String gallery = "gallery";
  static String parameterTypes = "parameter_types";
  static String status = "status";
  static String totalView = "total_view";
  static String addedBy = "added_by";
  static String district = "district";
  static String state = "state";
  static String houseNo = "house_no";
  static String surveyNo = "survey_no";
  static String plotNo = "plot_no";
  static String city = "city";
  static String languageCode = "language_code";
  static String country = "country";

  static String bathroom = "bathroom";
  static String aboutUs = "about_us";
  static String contactUs = "contact_us";
  static String faq = "faqs";
  static String termsAndConditions = "terms_conditions";
  static String privacyPolicy = "privacy_policy";
  static String currencySymbol = "currency_symbol";
  static String company = "company";
  static String data = "data";
  static String actionType = "action_type";
  static String customerId = "customer_id";
  static String itemsId = "items_id";
  static String customersId = "customers_id";
  static String enqStatus = "status";
  static String search = "search";
  static String createdAt = "created_at";
  static String sendType = "send_type";
  static String created = "created";
  static String compName = "company_name";
  static String compWebsite = "company_website";
  static String compEmail = "company_email";
  static String compAdrs = "company_address";
  static String tele1 = "company_tel1";
  static String tele2 = "company_tel2";
  static String maintenanceMode = "maintenance_mode";
  static String maxPrice = "max_price";
  static String minPrice = "min_price";
  static String postedSince = "posted_since";
  static String item = "item";
  static String page = "page";
  static String topRated = "top_rated";
  static String promoted = "promoted";
  static String packageId = "package_id";
  static String notification = "notification";
  static String v360degImage = "threeD_image";
  static String videoLink = "video_link";
  static String categoryIds = "category_ids";
  static String sortBy = "sort_by";
  static String stateId = "state_id";
  static String countryId = "country_id";
  static String cityId = "city_id";
  static String countryCode = "country_code";
  static String personalDetail = "show_personal_details";
  static String soldTo = "sold_to";
  static String ratings = "ratings";
  static String review = "review";
  static String platformType = "platform_type";
  static String sellerReviewId = "seller_review_id";
  static String reportReason = "report_reason";
  static String slug = "slug";
  static String categorySlug = "category_slug";
  static String carMakeId = "carMakeId";
  static String carModelId = "carModelId";
  static String featuredSectionId = "featured_section_id";
  static String featuredSectionSlug = "featured_section_slug";
  static String radius = "radius";
  static String latitude = "latitude";
  static String longitude = "longitude";
  static String areaId = "area_id";
  static String limit = "limit";
  static String offset = "offset";
  static String searchUrl = "search_url";
  static String apiSearchUrl = "api_search_url";
  static String subscribeEmail = "subscribe_email";
  static String location = "location";
  static String parentCategoryId = "parent_category_id";

  static Future<Map<String, dynamic>> post({
    required String url,
    dynamic parameter,
    Options? options,
    bool? useBaseUrl,
    bool useAuthToken = true,
  }) async {
    try {
      final Dio dio = _dio();
      dio.interceptors.add(NetworkRequestInterseptor());

      late FormData formData;

      if (parameter is Map<String, dynamic>) {
        Map<String, dynamic> formMap = {};

        parameter.forEach((key, value) {
          if (value is File) {
// If the value is a File, convert it to MultipartFile
            formMap[key] = MultipartFile.fromFileSync(value.path,
                filename: value.path.split('/').last);
          } else if (value is List<File>) {
// If the value is a List of Files, convert each to MultipartFile
            formMap[key] = value
                .map((file) => MultipartFile.fromFileSync(file.path,
                    filename: file.path.split('/').last))
                .toList();
          } else {
// Otherwise, add the value as it is
            formMap[key] = value;
          }
        });

// Create a new FormData object from the map
        formData = FormData.fromMap(
          formMap,
          ListFormat.multiCompatible,
        );
      } else {
        throw ArgumentError(
            'Invalid parameter type. Expected Map<String, dynamic>.');
      }

      final response = await dio.post(
        ((useBaseUrl ?? true) ? Constant.baseUrl : "") + url,
        data: formData,
        options: Options(
          contentType: "multipart/form-data",
          headers: headers(useAuthToken: useAuthToken),
        ),
      );

      var resp = response.data;

      if (resp['error'] ?? false) {
        final details = resp['details']?.toString() ?? '';
        final msg = resp['message']?.toString() ?? 'Error occurred';
        throw ApiException(details.isNotEmpty ? "$msg ($details)" : msg);
      }

      return Map.from(resp);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 && useAuthToken) {
        userExpired();
      }

      if (e.response?.statusCode == 503) {
        throw "server-not-available";
      }

      throw ApiException(_extractDioErrorMessage(e));
    } on ApiException catch (e) {
      throw ApiException(e.errorMessage);
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  static String _extractDioErrorMessage(DioException e) {
    if (e.response?.data is Map) {
      final data = e.response!.data as Map;
      String? serverMsg = data['message']?.toString() ??
          data['error_message']?.toString() ??
          data['details']?.toString();
      if (data['errors'] is Map) {
        final errs = (data['errors'] as Map)
            .values
            .map((v) {
              if (v is List) return v.join(", ");
              return v.toString();
            })
            .where((v) => v.isNotEmpty)
            .join("; ");
        if (errs.isNotEmpty) {
          serverMsg = serverMsg != null ? "$serverMsg ($errs)" : errs;
        }
      }
      if (serverMsg != null && serverMsg.isNotEmpty) {
        return serverMsg;
      }
    }
    if (e.error is SocketException) {
      return "no-internet";
    }
    return "Something went wrong with error ${e.response?.statusCode ?? e.message}";
  }

  static void userExpired() {
    HelperUtils.showSnackBarMessage(Constant.navigatorKey.currentContext!,
        "userIsDeactivated".translate(Constant.navigatorKey.currentContext!),
        messageDuration: 3);
    Future.delayed(Duration(seconds: 2), () {
      HiveUtils.clear();
      Constant.favoriteItemList.clear();
      Constant.navigatorKey.currentContext!.read<UserDetailsCubit>().clear();
      Constant.navigatorKey.currentContext!.read<FavoriteCubit>().resetState();
      Constant.navigatorKey.currentContext!
          .read<UpdatedReportItemCubit>()
          .clearItem();
      Constant.navigatorKey.currentContext!
          .read<GetBuyerChatListCubit>()
          .resetState();
      Constant.navigatorKey.currentContext!
          .read<BlockedUsersListCubit>()
          .resetState();
      HiveUtils.logoutUser(
        Constant.navigatorKey.currentContext!,
        onLogout: () {},
      );
    });
  }

  static Future<Map<String, dynamic>> delete(
      {required String url,
      Map<String, dynamic>? queryParameters,
      bool? useBaseUrl}) async {
    try {
      final Dio dio = _dio();
      dio.interceptors.add(NetworkRequestInterseptor());

      final response = await dio.delete(
          ((useBaseUrl ?? true) ? Constant.baseUrl : "") + url,
          queryParameters: queryParameters,
          options: Options(headers: headers()));

      if (response.data['error'] == true) {
        throw ApiException(response.data['message'].toString());
      }
      return Map.from(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        userExpired();
      }
      if (e.response?.statusCode == 503) {
        throw "server-not-available";
      }

      throw ApiException(_extractDioErrorMessage(e));
    } on ApiException catch (e) {
      throw ApiException(e.errorMessage);
    } catch (e, st) {
      throw ApiException(st.toString());
    }
  }

  static Future<Map<String, dynamic>> get(
      {required String url,
      Map<String, dynamic>? queryParameters,
      bool? useBaseUrl}) async {
    try {
      final Dio dio = _dio();
      dio.interceptors.add(NetworkRequestInterseptor());

      final response = await dio.get(
          ((useBaseUrl ?? true) ? Constant.baseUrl : "") + url,
          queryParameters: queryParameters,
          options: Options(headers: headers()));

      if (response.data['error'] == true) {
        throw ApiException(response.data['message'].toString());
      }
      return Map.from(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        userExpired();
      }
      if (e.response?.statusCode == 503) {
        throw "server-not-available";
      }

      throw ApiException(_extractDioErrorMessage(e));
    } on ApiException catch (e) {
      throw ApiException(e.errorMessage);
    } catch (e, st) {
      throw ApiException(st.toString());
    }
  }
}
