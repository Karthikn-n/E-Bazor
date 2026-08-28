import 'package:Ebozor/app/app.dart';
import 'package:Ebozor/app/app_localization.dart';
import 'package:Ebozor/app/app_theme.dart';
import 'package:Ebozor/app/register_cubits.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/system/app_theme_cubit.dart';
import 'package:Ebozor/ui/screens/chat/chat_audio/globals.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/notification/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:Ebozor/data/cubits/system/language_cubit.dart';

/////////////
///V-1.0.0//
////////////

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initApp();
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'application bootstrap',
      ),
    );
    runApp(const StartupFailureApp());
  }
}

class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to start the app',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please check your connection and try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: main,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EntryPoint extends StatefulWidget {
  const EntryPoint({
    super.key,
  });

  @override
  EntryPointState createState() => EntryPointState();
}

class EntryPointState extends State<EntryPoint> {
  @override
  void initState() {
    super.initState();
    FirebaseMessaging.onBackgroundMessage(
        NotificationService.onBackgroundMessageHandler);
    //ChatMessageHandler.handle();
    ChatGlobals.init();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
        providers: RegisterCubits().providers,
        child: Builder(builder: (BuildContext context) {
          return const App();
        }));
  }
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    context.read<LanguageCubit>().loadCurrentLanguage();

    AppTheme currentTheme = HiveUtils.getCurrentTheme();

    // ///Initialized notification services
    //LocalAwsomeNotification().init(context);
    /////////////
    NotificationService.init(context);

    /// Initialized dynamic links for share items feature
    //DeepLinkManager.initDeepLinks();
    context.read<AppThemeCubit>().changeTheme(currentTheme);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    //Continuously watching theme change
    AppTheme currentTheme = context.watch<AppThemeCubit>().state.appTheme;
    return BlocBuilder<LanguageCubit, LanguageState>(
      builder: (context, languageState) {
        return MaterialApp(
          initialRoute: Routes.splash,
          // App will start from here splash screen is first screen,
          navigatorKey: Constant.navigatorKey,
          //This navigator key is used for Navigate users through notification
          title: Constant.appName,
          debugShowCheckedModeBanner: false,
          onGenerateRoute: Routes.onGenerateRouted,
          theme: appThemeData[currentTheme],
          builder: (context, child) {
            TextDirection direction = TextDirection.ltr;

            if (languageState is LanguageLoader) {
              if (languageState.language['rtl'] == true) {
                direction = TextDirection.rtl;
              }
            }
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.0),
              ),
              child: Directionality(
                textDirection: direction,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          localizationsDelegates: const [
            AppLocalization.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          locale: loadLocalLanguageIfFail(languageState),
        );
      },
    );
  }

  dynamic loadLocalLanguageIfFail(LanguageState state) {
    if ((state is LanguageLoader)) {
      return Locale(state.language['code']);
    } else if (state is LanguageLoadFail) {
      return const Locale("en");
    }
  }
}

class GlobalScrollBehavior extends ScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}
