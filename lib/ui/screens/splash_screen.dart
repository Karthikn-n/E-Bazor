import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/auth/authentication_cubit.dart';
import 'package:Ebozor/data/cubits/auth/login_cubit.dart';
import 'package:Ebozor/data/cubits/system/fetch_language_cubit.dart';
import 'package:Ebozor/data/cubits/system/fetch_system_settings_cubit.dart';
import 'package:Ebozor/data/cubits/system/language_cubit.dart';
import 'package:Ebozor/data/cubits/system/user_details.dart';
import 'package:Ebozor/data/model/system_settings_model.dart';
import 'package:Ebozor/ui/screens/widgets/errors/no_internet.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/app_icon.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/responsiveSize.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  Timer? _minimumSplashTimer;
  bool _minimumSplashCompleted = false;
  bool _settingsLoaded = false;
  bool _languageLoaded = false;
  bool _startupRunning = false;
  bool _startupFailed = false;
  bool _hasInternet = true;
  bool _hasNavigated = false;
  bool _verificationRecoveryRunning = false;

  @override
  void initState() {
    super.initState();
    _minimumSplashTimer = Timer(const Duration(milliseconds: 800), () {
      _minimumSplashCompleted = true;
      _tryNavigate();
    });
    _subscription = Connectivity().onConnectivityChanged.listen(
          _handleConnectivity,
        );
    _checkConnectivityAndLoad();
  }

  Future<void> _checkConnectivityAndLoad() async {
    final result = await Connectivity().checkConnectivity();
    await _handleConnectivity(result);
  }

  Future<void> _handleConnectivity(List<ConnectivityResult> result) async {
    if (!mounted) return;
    final online = !result.contains(ConnectivityResult.none);
    setState(() => _hasInternet = online);
    if (online) await _loadStartupData();
  }

  Future<void> _loadStartupData() async {
    if (_startupRunning || (_settingsLoaded && _languageLoaded)) return;
    _startupRunning = true;
    _startupFailed = false;

    try {
      final settingsCubit = context.read<FetchSystemSettingsCubit>();
      await settingsCubit
          .fetchSettings(forceRefresh: true)
          .timeout(const Duration(seconds: 15));
      if (settingsCubit.state is! FetchSystemSettingsSuccess) {
        throw StateError('System settings could not be loaded');
      }

      Constant.isDemoModeOn = settingsCubit.getSetting(SystemSetting.demoMode);
      _settingsLoaded = true;

      final cachedLanguage = HiveUtils.getLanguage();
      final defaultLanguage =
          settingsCubit.getRawSettings()['default_language']?.toString();
      final needsLanguage = cachedLanguage == null ||
          cachedLanguage['data'] == null ||
          (HiveUtils.isUserFirstTime() &&
              defaultLanguage != cachedLanguage['code']);

      if (!needsLanguage) {
        _languageLoaded = true;
      } else if (defaultLanguage != null && defaultLanguage.isNotEmpty) {
        final languageCubit = context.read<FetchLanguageCubit>();
        await languageCubit
            .getLanguage(defaultLanguage)
            .timeout(const Duration(seconds: 15));
        final state = languageCubit.state;
        if (state is FetchLanguageSuccess) {
          final language = state.toMap();
          language['data'] = language.remove('file_name');
          await HiveUtils.storeLanguage(language);
          if (mounted) {
            context.read<LanguageCubit>().changeLanguage(language);
          }
          _languageLoaded = true;
        } else if (cachedLanguage?['data'] != null) {
          _languageLoaded = true;
        } else {
          throw StateError('Language could not be loaded');
        }
      }
    } catch (_) {
      _startupFailed = true;
    } finally {
      _startupRunning = false;
      if (mounted) setState(() {});
      _tryNavigate();
    }
  }

  Future<void> _tryNavigate() async {
    if (!mounted ||
        _hasNavigated ||
        !_minimumSplashCompleted ||
        !_settingsLoaded ||
        !_languageLoaded) {
      return;
    }
    if (context
            .read<FetchSystemSettingsCubit>()
            .getSetting(SystemSetting.maintenanceMode) ==
        '1') {
      _hasNavigated = true;
      Navigator.of(context).pushReplacementNamed(Routes.maintenanceMode);
    } else if (!HiveUtils.isUserAuthenticated() &&
        HiveUtils.isEmailVerificationPending()) {
      if (_verificationRecoveryRunning) return;
      _verificationRecoveryRunning = true;
      final user = await _reloadPendingVerificationUser();
      if (!mounted) return;

      if (user?.emailVerified == true) {
        _hasNavigated = true;
        context.read<LoginCubit>().loginWithUser(
              user: user!,
              type: AuthenticationType.email.name,
            );
        return;
      }

      _verificationRecoveryRunning = false;
      _hasNavigated = true;
      Navigator.of(context).pushReplacementNamed(Routes.login);
    } else if (HiveUtils.isUserFirstTime()) {
      _hasNavigated = true;
      Navigator.of(context).pushReplacementNamed(Routes.onboarding);
    } else if (HiveUtils.isUserAuthenticated()) {
      _hasNavigated = true;
      if (!HiveUtils.isLocationFilled()) {
        Navigator.of(context)
            .pushReplacementNamed(Routes.locationPermissionScreen);
      } else {
        Navigator.of(context)
            .pushReplacementNamed(Routes.main, arguments: {'from': 'main'});
      }
    } else if (HiveUtils.isUserSkip()) {
      _hasNavigated = true;
      Navigator.of(context)
          .pushReplacementNamed(Routes.main, arguments: {'from': 'main'});
    } else {
      _hasNavigated = true;
      Navigator.of(context).pushReplacementNamed(Routes.login);
    }
  }

  Future<User?> _reloadPendingVerificationUser() async {
    User? user = FirebaseAuth.instance.currentUser;
    for (var attempt = 0; attempt < 3 && user != null; attempt++) {
      await user.reload();
      user = FirebaseAuth.instance.currentUser;
      if (user?.emailVerified == true) return user;
      if (attempt < 2) await Future<void>.delayed(const Duration(seconds: 1));
    }
    return user;
  }

  @override
  void dispose() {
    _minimumSplashTimer?.cancel();
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasInternet || _startupFailed) {
      return NoInternet(onRetry: _checkConnectivityAndLoad);
    }
    return BlocListener<LoginCubit, LoginState>(
      listener: (context, state) async {
        if (!_verificationRecoveryRunning) return;
        if (state is LoginSuccess) {
          HiveUtils.setEmailVerificationPending(false);
          await HiveUtils.setUserIsAuthenticated(true);
          if (!context.mounted) return;
          context.read<UserDetailsCubit>().fill(HiveUtils.getUserDetails());
          Navigator.of(context).pushNamedAndRemoveUntil(
              Routes.locationPermissionScreen, (route) => false);
        } else if (state is LoginFailure) {
          HiveUtils.setEmailVerificationPending(false);
          Navigator.of(context).pushReplacementNamed(Routes.login);
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(statusBarColor: Colors.white),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: SizedBox(
              width: 150.rw(context),
              height: 150.rh(context),
              child: Image.asset(AppIcons.splashLogo),
            ),
          ),
        ),
      ),
    );
  }
}
