
import 'package:Ebozor/data/model/personalized/personalized_settings.dart';
import 'package:Ebozor/firebase_options.dart';
import 'package:Ebozor/main.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

PersonalizedInterestSettings personalizedInterestSettings =
    PersonalizedInterestSettings.empty();


// void initApp() async {
//   ///Note: this file's code is very necessary and sensitive if you change it, this might affect whole app , So change it carefully.
//   ///This must be used do not remove this line
//   WidgetsFlutterBinding.ensureInitialized();
//   final GoogleMapsFlutterPlatform mapsImplementation =
//       GoogleMapsFlutterPlatform.instance;
//   if (mapsImplementation is GoogleMapsFlutterAndroid) {
//     mapsImplementation.useAndroidViewSurface = false;
//   }
//
//   ///This is the widget to show uncaught runtime error in this custom widget so that user can know in that screen something is wrong instead of grey screen
//   if (kReleaseMode) {
//     ErrorWidget.builder =
//         (FlutterErrorDetails flutterErrorDetails) => SomethingWentWrong(
//               error: flutterErrorDetails,
//             );
//   }
//
//   // if (Firebase.apps.isNotEmpty) {
//   //   await Firebase.initializeApp(
//   //       options: DefaultFirebaseOptions.currentPlatform);
//   // } else {
//   //   await Firebase.initializeApp();
//   // }
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
//
//   MobileAds.instance.initialize();
//
// /*  final NativeAdFactoryExample factoryExample = NativeAdFactoryExample();
//   GoogleMobileAds.instance.nativeAdFactoryRegistry
//       .registerFactory('listTile', factoryExample);*/
//
//
//   // var box = await Hive.openBox('languageBox');
//   // await Hive.initFlutter();
//   // await Hive.openBox(HiveKeys.userDetailsBox);
//   // await Hive.openBox(HiveKeys.authBox);
//   // await box.clear();
//   // await Hive.openBox(HiveKeys.languageBox);
//   // await Hive.openBox(HiveKeys.themeBox);
//   // await Hive.openBox(HiveKeys.svgBox);
//   // await Hive.openBox(HiveKeys.jwtToken);
//   // //Hive.registerAdapter(ItemModelAdapter()); // Register your adapter
//   // await Hive.openBox(HiveKeys.historyBox);
//   //
//   // SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then(
//   //   (_) async {
//   //     SystemChrome.setSystemUIOverlayStyle(
//   //         const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
//   //
//   //     runApp(const EntryPoint());
//   //   },
//   // );
//
//
//
//
//
//
//
//     // ✅ Hive Init
//     await Hive.initFlutter();
//
//     // ✅ Open and clear boxes properly
//     var languageBox = await Hive.openBox(HiveKeys.languageBox);
//     await languageBox.clear(); // clear old language data
//
//     await Hive.openBox(HiveKeys.userDetailsBox);
//     await Hive.openBox(HiveKeys.authBox);
//     await Hive.openBox(HiveKeys.themeBox);
//     await Hive.openBox(HiveKeys.svgBox);
//     await Hive.openBox(HiveKeys.jwtToken);
//     await Hive.openBox(HiveKeys.historyBox);
//
//     SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then(
//           (_) async {
//         SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
//         runApp(const EntryPoint());
//       },
//     );
//   }

void initApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Google Maps setup
  final GoogleMapsFlutterPlatform mapsImplementation =
      GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    mapsImplementation.useAndroidViewSurface = false;
  }

  // Custom error widget in release mode
  if (kReleaseMode) {
    ErrorWidget.builder =
        (FlutterErrorDetails flutterErrorDetails) => SomethingWentWrong(
      error: flutterErrorDetails,
    );
  }

  // Firebase init
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Ads init
  MobileAds.instance.initialize();

  // Initialize hive and open boxes
  await HiveUtils.initHive();

  // ✅ Use await instead of .then() to avoid async issues
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  runApp(const EntryPoint());
}



