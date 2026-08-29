import 'package:Ebozor/data/model/personalized/personalized_settings.dart';
import 'package:Ebozor/firebase_options.dart';
import 'package:Ebozor/main.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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

Future<void> initApp() async {
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

  // AppDelegate may already configure the default iOS Firebase app from
  // GoogleService-Info.plist. Do not initialize the same app twice.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 15));
  }

  await _configureCrashlytics();
  await _setBootstrapStage('initializing_local_storage');

  // Ads init
  MobileAds.instance.initialize();

  // Initialize hive and open boxes
  await HiveUtils.initHive().timeout(const Duration(seconds: 15));

  await _setBootstrapStage('configuring_orientation');

  // ✅ Use await instead of .then() to avoid async issues
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).timeout(const Duration(seconds: 5));
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  await _setBootstrapStage('running_app');
  runApp(const EntryPoint());
}

Future<void> _configureCrashlytics() async {
  try {
    final FirebaseCrashlytics crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

    FlutterError.onError = crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      crashlytics.recordError(
        error,
        stackTrace,
        reason: 'Uncaught asynchronous platform error',
        fatal: true,
      );
      return true;
    };

    await crashlytics.setCustomKey('app_bootstrap_stage', 'firebase_ready');
  } catch (error) {
    debugPrint('Crashlytics setup failed: $error');
  }
}

Future<void> _setBootstrapStage(String stage) async {
  try {
    await FirebaseCrashlytics.instance.setCustomKey(
      'app_bootstrap_stage',
      stage,
    );
  } catch (_) {
    // Crash reporting must never prevent the application from starting.
  }
}
