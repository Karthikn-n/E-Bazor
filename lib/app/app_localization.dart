//For localization of app

import 'dart:convert';

import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalization {
  final Locale locale;

  //it will hold key of text and it's values in given language
  late Map<String, String> _localizedValues;

  AppLocalization(this.locale);

  //to access app-localization instance any where in app using context
  static AppLocalization? of(BuildContext context) {
    return Localizations.of(context, AppLocalization);
  }

  //to load json(language) from assets
  Future loadJson() async {
    String jsonStringValues =
        await rootBundle.loadString('assets/languages/template.json');
    // Start with template fallback values
    Map<String, dynamic> mappedJson = {};
    try {
      mappedJson = json.decode(jsonStringValues) as Map<String, dynamic>;
    } catch (_) {}

    final dynamic storedLang = HiveUtils.getLanguage();
    if (storedLang is Map) {
      final dynamic data = storedLang['data'] ?? storedLang['file_name'];
      if (data is Map) {
        data.forEach((key, value) {
          if (value != null && value.toString().trim().isNotEmpty) {
            mappedJson[key.toString()] = value.toString();
          }
        });
      }
    }

    _localizedValues =
        mappedJson.map((key, value) => MapEntry(key, value.toString()));
  }

  //to get translated value of given title/key
  String? getTranslatedValues(String? key) {
    if (key == null) return null;
    return _localizedValues[key];
  }

  //need to declare custom delegate
  static const LocalizationsDelegate<AppLocalization> delegate =
      _AppLocalizationDelegate();
}

//Custom app delegate
class _AppLocalizationDelegate extends LocalizationsDelegate<AppLocalization> {
  const _AppLocalizationDelegate();

  //providing all supported languages
  @override
  bool isSupported(Locale locale) {
    //
    return true;
  }

  //load languageCode.json files
  @override
  Future<AppLocalization> load(Locale locale) async {
    AppLocalization localization = AppLocalization(locale);
    await localization.loadJson();
    return localization;
  }

  @override
  bool shouldReload(LocalizationsDelegate<AppLocalization> old) {
    return true;
  }
}
