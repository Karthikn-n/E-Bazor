import 'package:Ebozor/app/app_theme.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:flutter/foundation.dart';

import 'package:Ebozor/data/model/user_model.dart';

import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_keys.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveUtils {
  static const _pendingEmailVerificationKey = 'pendingEmailVerification';

  ///private constructor
  HiveUtils._();

  /// initialize hive and open boxes
  static Future<void> initHive() async {
    // ✅ Hive Init
    await Hive.initFlutter();

    // ✅ Open boxes — DO NOT clear languageBox, it breaks navigation logic
    await Hive.openBox(HiveKeys.languageBox);
    await Hive.openBox(HiveKeys.userDetailsBox);
    await Hive.openBox(HiveKeys.authBox);
    await Hive.openBox(HiveKeys.themeBox);
    await Hive.openBox(HiveKeys.svgBox);
    await Hive.openBox(HiveKeys.jwtToken);
    await Hive.openBox(HiveKeys.historyBox);
  }

  static String? getJWT() {
    return Hive.box(HiveKeys.userDetailsBox).get(HiveKeys.jwtToken);
  }

  static void dontShowChooseLocationDialoge() {
    Hive.box(HiveKeys.userDetailsBox).put("showChooseLocationDialoge", false);
  }

/*  static bool isGuest() {
    return Hive.box(HiveKeys.userDetailsBox).get("isGuest") ?? true;
  }*/

/*  static void setIsNotGuest() {
    Hive.box(HiveKeys.userDetailsBox).put("isGuest", false);
  }*/

  /* static void setIsGuest() {
    Hive.box(HiveKeys.userDetailsBox).put("isGuest", true);
  }*/

  static bool isShowChooseLocationDialoge() {
    var value = Hive.box(HiveKeys.userDetailsBox).get(
      "showChooseLocationDialoge",
    );

    if (value == null) {
      return true;
    }
    return false;
  }

  static String? getUserId() {
    return Hive.box(HiveKeys.userDetailsBox).get("id").toString();
  }

  static AppTheme getCurrentTheme() {
    var current = Hive.box(HiveKeys.themeBox).get(HiveKeys.currentTheme);

    if (current == null) {
      return AppTheme.light;
    }
    if (current == "light") {
      return AppTheme.light;
    }
    if (current == "dark") {
      return AppTheme.dark;
    }
    return AppTheme.light;
  }

  static String? getCountryCode() {
    return Hive.box(HiveKeys.userDetailsBox).get("country_code");
    //return Hive.box(HiveKeys.userDetailsBox).toMap()['countryCode'];
  }

  static void setProfileNotCompleted() async {
    await Hive.box(HiveKeys.userDetailsBox)
        .put(HiveKeys.isProfileCompleted, false);
  }

  static void setCurrentTheme(AppTheme theme) {
    String newTheme;
    if (theme == AppTheme.light) {
      newTheme = "light";
    } else {
      newTheme = "dark";
    }
    Hive.box(HiveKeys.themeBox).put(HiveKeys.currentTheme, newTheme);
  }

  static void setUserData(Map data) async {
    await Hive.box(HiveKeys.userDetailsBox).putAll(data);
  }

  static void setNearbyRadius(int radius) async {
    await Hive.box(HiveKeys.userDetailsBox).put(HiveKeys.nearbyRadius, radius);
  }

  static dynamic getNearbyRadius() {
    return Hive.box(HiveKeys.userDetailsBox).get(HiveKeys.nearbyRadius);
  }

  static void clearNearbyRadius() async {
    await Hive.box(HiveKeys.userDetailsBox).delete(HiveKeys.nearbyRadius);
  }

  static dynamic getCityName() {
    return Hive.box(HiveKeys.userDetailsBox).get(HiveKeys.city);
  }

  static dynamic getAreaName() {
    return Hive.box(HiveKeys.userDetailsBox).get(HiveKeys.area);
  }

  static dynamic getAreaId() {
    return Hive.box(HiveKeys.userDetailsBox).get(HiveKeys.areaId);
  }

  static dynamic getStateName() {
    return Hive.box(HiveKeys.userDetailsBox).get(HiveKeys.stateKey);
  }

  static dynamic getCountryName() {
    return Hive.box(HiveKeys.userDetailsBox).get(HiveKeys.countryKey);
  }

  static dynamic getCurrentCityName() {
    return Hive.box(HiveKeys.userDetailsBox).get(HiveKeys.currentLocationCity);
  }

  static dynamic getCurrentAreaName() {
    return Hive.box(HiveKeys.userDetailsBox).get(HiveKeys.currentLocationArea);
  }

  static dynamic getCurrentStateName() {
    return Hive.box(HiveKeys.userDetailsBox).get(HiveKeys.currentLocationState);
  }

  static dynamic getCurrentCountryName() {
    return Hive.box(HiveKeys.userDetailsBox)
        .get(HiveKeys.currentLocationCountry);
  }

  static dynamic getCurrentLatitude() {
    return Hive.box(HiveKeys.userDetailsBox)
        .get(HiveKeys.currentLocationLatitude);
  }

  static dynamic getCurrentLongitude() {
    return Hive.box(HiveKeys.userDetailsBox)
        .get(HiveKeys.currentLocationLongitude);
  }

  static dynamic getLatitude() {
    return Hive.box(HiveKeys.userDetailsBox).get(HiveKeys.latitudeKey);
  }

  static dynamic getLongitude() {
    return Hive.box(HiveKeys.userDetailsBox).get(HiveKeys.longitudeKey);
  }

  static void setJWT(String token) async {
    await Hive.box(HiveKeys.userDetailsBox).put(HiveKeys.jwtToken, token);
  }

  static UserModel getUserDetails() {
    return UserModel.fromJson(
        Map.from(Hive.box(HiveKeys.userDetailsBox).toMap()));
  }

  static void setUserIsAuthenticated(bool value) {
    Hive.box(HiveKeys.authBox).put(HiveKeys.isAuthenticated, value);
  }

  static void setEmailVerificationPending(bool value) {
    Hive.box(HiveKeys.authBox).put(_pendingEmailVerificationKey, value);
  }

  static bool isEmailVerificationPending() {
    return Hive.box(HiveKeys.authBox).get(_pendingEmailVerificationKey) ??
        false;
  }

/*  static setUserIsNotAuthenticated() async {
    await Hive.box(HiveKeys.authBox).put(HiveKeys.isAuthenticated, false);
  }*/

  static Future<void> setUserIsNotNew() {
    return Hive.box(HiveKeys.authBox).put(HiveKeys.isUserFirstTime, false);
  }

  static Future<void> setUserSkip() {
    return Hive.box(HiveKeys.authBox).put(HiveKeys.isUserSkip, true);
  }

  static bool isLocationFilled() {
    var city = Hive.box(HiveKeys.userDetailsBox).get(HiveKeys.city);
    var state = Hive.box(HiveKeys.userDetailsBox).get(HiveKeys.stateKey);
    var country = Hive.box(HiveKeys.userDetailsBox).get(HiveKeys.countryKey);

    if (city == null && state == null && country == null) {
      return false;
    } else {
      return true;
    }
  }

  static void setLocation(
      {String? city,
      String? state,
      String? country,
      String? area,
      int? areaId,
      double? latitude,
      double? longitude}) async {
    if (Constant.isDemoModeOn) {
      await Hive.box(HiveKeys.userDetailsBox).putAll({
        HiveKeys.city: "Bhuj",
        HiveKeys.stateKey: "Gujarat",
        HiveKeys.countryKey: "India",
        HiveKeys.areaId: null,
        HiveKeys.area: null,
        HiveKeys.latitudeKey: 23.2533,
        HiveKeys.longitudeKey: 69.6693
      });
    } else {
      await Hive.box(HiveKeys.userDetailsBox).putAll({
        HiveKeys.city: city ?? null,
        HiveKeys.stateKey: state ?? null,
        HiveKeys.countryKey: country ?? null,
        HiveKeys.areaId: areaId ?? null,
        HiveKeys.area: area ?? null,
        HiveKeys.latitudeKey: latitude ?? null,
        HiveKeys.longitudeKey: longitude ?? null
      });
    }
  }

  static void setCurrentLocation(
      {required String city,
      required String state,
      required String country,
      latitude,
      longitude,
      String? area}) async {
    if (Constant.isDemoModeOn) {
      await Hive.box(HiveKeys.userDetailsBox).putAll({
        HiveKeys.currentLocationCity: "Bhuj",
        HiveKeys.currentLocationState: "Gujarat",
        HiveKeys.currentLocationCountry: "India",
        HiveKeys.currentLocationArea: null,
        HiveKeys.currentLocationLatitude: 23.2533,
        HiveKeys.currentLocationLongitude: 69.6693
      });
    } else {
      await Hive.box(HiveKeys.userDetailsBox).putAll({
        HiveKeys.currentLocationCity: city,
        HiveKeys.currentLocationState: state,
        HiveKeys.currentLocationCountry: country,
        HiveKeys.currentLocationLatitude: latitude,
        HiveKeys.currentLocationLongitude: longitude,
        HiveKeys.currentLocationArea: area
      });
    }
  }

  static void clearLocation() async {
    await Hive.box(HiveKeys.userDetailsBox).putAll({
      HiveKeys.city: null,
      HiveKeys.stateKey: null,
      HiveKeys.countryKey: null,
    });
  }

  static Future<bool> storeLanguage(
    dynamic data,
  ) async {
    Hive.box(HiveKeys.languageBox).put(HiveKeys.currentLanguageKey, data);
    // ..put("language", data);
    return true;
  }

  static dynamic getLanguage() {
    return Hive.box(HiveKeys.languageBox).get(HiveKeys.currentLanguageKey);
  }

  // static s(context) {
  //   HiveUtils.setUserIsNotAuthenticated();
  //   HiveUtils.clear();

  //   Future.delayed(
  //     Duration.zero,
  //     () {
  //       HelperUtils.killPreviousPages(context, Routes.login, {});
  //     },
  //   );
  // }

  @visibleForTesting
  static Future<void> setUserIsNew() {
    //Only testing purpose // not in production
    Hive.box(HiveKeys.authBox).put(HiveKeys.isAuthenticated, false);
    return Hive.box(HiveKeys.authBox).put(HiveKeys.isUserFirstTime, true);
  }

  static bool isUserAuthenticated() {
    return Hive.box(HiveKeys.authBox).get(HiveKeys.isAuthenticated) ?? false;
  }

  static bool isUserFirstTime() {
    return Hive.box(HiveKeys.authBox).get(HiveKeys.isUserFirstTime) ?? true;
  }

  static bool isUserSkip() {
    return Hive.box(HiveKeys.authBox).get(HiveKeys.isUserSkip) ?? false;
  }

  static Future<void> logoutUser(context,
      {required VoidCallback onLogout, bool? isRedirect}) async {
    try {
      await Hive.box(HiveKeys.userDetailsBox).clear();
    } catch (_) {}
    try {
      await Hive.box(HiveKeys.historyBox).clear();
    } catch (_) {}
    try {
      await Hive.box(HiveKeys.jwtToken).clear();
    } catch (_) {}

    HiveUtils.setUserIsAuthenticated(false);
    HiveUtils.setEmailVerificationPending(false);

    try {
      await Hive.box(HiveKeys.authBox).delete(HiveKeys.isProfileCompleted);
      await Hive.box(HiveKeys.authBox).delete(HiveKeys.isUserSkip);
    } catch (_) {}

    Constant.favoriteItemList.clear();

    onLogout.call();

    Future.delayed(
      Duration.zero,
      () {
        if (isRedirect ?? true) {
          HelperUtils.killPreviousPages(context, Routes.login, {});
        }
      },
    );
  }

  static void clear() async {
    try {
      await Hive.box(HiveKeys.userDetailsBox).clear();
    } catch (_) {}
    try {
      await Hive.box(HiveKeys.historyBox).clear();
    } catch (_) {}
    try {
      await Hive.box(HiveKeys.jwtToken).clear();
    } catch (_) {}

    HiveUtils.setUserIsAuthenticated(false);
    HiveUtils.setEmailVerificationPending(false);

    try {
      await Hive.box(HiveKeys.authBox).delete(HiveKeys.isProfileCompleted);
      await Hive.box(HiveKeys.authBox).delete(HiveKeys.isUserSkip);
    } catch (_) {}

    Constant.favoriteItemList.clear();
  }
}
