import 'dart:io';
import 'package:Ebozor/utils/logger.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/login/apple_login/apple_login.dart';
import 'package:Ebozor/utils/login/email_login/email_login.dart';
import 'package:Ebozor/utils/login/google_login/google_login.dart';
import 'package:Ebozor/utils/login/phone_login/phone_login.dart';
import 'package:Ebozor/utils/login/lib/login_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:Ebozor/utils/login/lib/login_status.dart';
import 'package:Ebozor/utils/login/lib/payloads.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum AuthenticationType {
  email,
  google,
  apple,
  phone;
}

abstract class AuthenticationState {}

class AuthenticationInitial extends AuthenticationState {}

class AuthenticationInProcess extends AuthenticationState {
  final AuthenticationType type;

  AuthenticationInProcess(this.type);
}

class AuthenticationSuccess extends AuthenticationState {
  final AuthenticationType type;
  final UserCredential credential;
  final LoginPayload payload;

  AuthenticationSuccess(this.type, this.credential, this.payload);
}

class AuthenticationFail extends AuthenticationState {
  final dynamic error;

  AuthenticationFail(this.error);
}

class AuthenticationFlowException implements Exception {
  final String code;

  const AuthenticationFlowException(this.code);

  @override
  String toString() => code;
}

const passwordResetRequestMessage =
    'If this email has an email/password account, a reset link will arrive shortly. Check Spam too. If you registered with Google, return to Login and use Continue with Google.';

String authenticationErrorMessage(dynamic error) {
  if (error is GoogleSignInCancelledException ||
      error is AppleLoginCancelledException) {
    return '';
  }
  if (error is PlatformException) {
    if (error.code == 'canceled' ||
        error.code == 'cancelled' ||
        error.code == '1001') {
      return '';
    }
    return 'Authentication failed (${error.code}). Please try again.';
  }
  if (error is AuthenticationFlowException) {
    switch (error.code) {
      case 'account-not-found':
        return 'No account found. Please sign up first.';
      case 'phone-account-not-found':
        return 'This mobile number is not registered. Please sign up first.';
      case 'account-already-exists':
        return 'An account already exists. Please sign in instead.';
      case 'phone-account-already-exists':
        return 'This mobile number is already registered. Please log in instead.';
      case 'email-not-verified':
        return 'Please verify your email before signing in.';
    }
  }
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'canceled':
      case 'cancelled':
      case 'web-context-canceled':
      case '1001':
        return '';
      case 'email-already-in-use':
        return 'An account already exists. Please sign in instead.';
      case 'user-not-found':
        return 'User not found.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'No account matches these credentials. Check your email and password, or sign up first.';
      case 'missing-apple-identity-token':
      case 'missing-apple-authorization-code':
      case 'missing-or-invalid-nonce':
        return 'Apple authentication could not be verified. Please try again.';
      case 'account-exists-with-different-credential':
      case 'credential-already-in-use':
        return 'An account already exists for this email. Continue with Google if you registered with Google, or use Login/Forgot Password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'invalid-phone-number':
      case 'missing-phone-number':
        return 'Please enter a valid phone number.';
      case 'missing-client-identifier':
      case 'app-not-authorized':
        return 'Phone verification is not configured for this app build. Please contact support.';
      case 'captcha-check-failed':
        return '';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      case 'quota-exceeded':
        return 'The SMS limit has been reached. Please try again later.';
      case 'invalid-verification-code':
        return 'The verification code is incorrect.';
      case 'session-expired':
        return 'The verification code expired. Please request a new one.';
      case 'network-request-failed':
        return 'Please check your internet connection.';
      case 'invalid-user-token':
        return 'The authentication token was rejected. Please try again.';
      case 'user-token-expired':
        return 'Your previous session expired. Please try signing in again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
    }
    return 'Authentication failed (${error.code}). Please try again.';
  }
  return 'Authentication failed. Please try again.';
}

class AuthenticationCubit extends Cubit<AuthenticationState> {
  AuthenticationCubit() : super(AuthenticationInitial());
  AuthenticationType? type;
  LoginPayload? payload;
  MMultiAuthentication mMultiAuthentication = MMultiAuthentication({
    "google": GoogleLogin(),
    "email": EmailLogin(),
    if (Platform.isIOS) "apple": AppleLogin(),
    "phone": PhoneLogin()
  });

  void init() {
    AppLog.i('Initializing MultiAuthentication', name: 'AuthCubit');
    mMultiAuthentication.init();
  }

  void setData(
      {required LoginPayload payload, required AuthenticationType type}) {
    final intent = payload is EmailLoginPayload
        ? payload.type.name
        : payload is GoogleLoginPayload
            ? payload.intent.name
            : payload is AppleLoginPayload
                ? payload.intent.name
                : payload is PhoneLoginPayload
                    ? payload.intent.name
                    : 'unknown';
    AppLog.i('setData type: $type, intent: $intent', name: 'AuthCubit');
    this.type = type;
    this.payload = payload;
  }

  void authenticate() async {
    AppLog.i('authenticate called. type: $type', name: 'AuthCubit');
    if (type == null || payload == null) {
      AppLog.w('authenticate skipped: type or payload is null',
          name: 'AuthCubit');
      return;
    }

    try {
      emit(AuthenticationInProcess(type!));
      if (type == AuthenticationType.apple) {
        await HiveUtils.clearAuthenticationSession();
      }
      mMultiAuthentication.setActive(type!.name);
      mMultiAuthentication.payload = MultiLoginPayload({
        type!.name: payload!,
      });

      AppLog.i('Calling login on MultiAuthentication', name: 'AuthCubit');
      UserCredential? credential = await mMultiAuthentication.login();
      AppLog.i('Login returned. credential present: ${credential != null}',
          name: 'AuthCubit');

      if (credential == null || credential.user == null) {
        throw const AuthenticationFlowException('authentication-failed');
      }

      final payloadData = payload!;
      final intent = _intentFor(payloadData);
      final isNewUser = credential.additionalUserInfo?.isNewUser ?? false;
      final isUnverifiedEmailRecovery = payloadData is EmailLoginPayload &&
          payloadData.recoveredUnverifiedAccount;

      if (type == AuthenticationType.email || type == AuthenticationType.phone) {
        if (intent == AuthenticationIntent.signIn && isNewUser) {
          await _deleteAccidentallyCreatedUser(credential.user!);
          throw AuthenticationFlowException(payloadData is PhoneLoginPayload
              ? 'phone-account-not-found'
              : 'account-not-found');
        }

        if (intent == AuthenticationIntent.signUp &&
            !isNewUser &&
            !isUnverifiedEmailRecovery) {
          await FirebaseAuth.instance.signOut();
          throw AuthenticationFlowException(payloadData is PhoneLoginPayload
              ? 'phone-account-already-exists'
              : 'account-already-exists');
        }
      }

      if (payloadData is EmailLoginPayload &&
          payloadData.type == EmailLoginType.login) {
        final user = credential.user!;
        AppLog.i('Email login. emailVerified: ${user.emailVerified}',
            name: 'AuthCubit');
        if (!user.emailVerified) {
          AppLog.w('Email not verified.', name: 'AuthCubit');
          await FirebaseAuth.instance.signOut();
          throw const AuthenticationFlowException('email-not-verified');
        }
      }
      emit(AuthenticationSuccess(type!, credential, payload!));
    } catch (e) {
      AppLog.e('Authentication exception', error: e, name: 'AuthCubit');
      emit(AuthenticationFail(e));
    }
  }

  AuthenticationIntent _intentFor(LoginPayload payload) {
    if (payload is EmailLoginPayload) {
      return payload.type == EmailLoginType.login
          ? AuthenticationIntent.signIn
          : AuthenticationIntent.signUp;
    }
    if (payload is GoogleLoginPayload) return payload.intent;
    if (payload is AppleLoginPayload) return payload.intent;
    if (payload is PhoneLoginPayload) return payload.intent;
    throw const AuthenticationFlowException('authentication-failed');
  }

  Future<void> _deleteAccidentallyCreatedUser(User user) async {
    AppLog.w('Rolling back a new Firebase user created during sign-in.',
        name: 'AuthCubit');
    try {
      await user.delete();
    } on FirebaseAuthException catch (error) {
      if (error.code != 'invalid-user-token' &&
          error.code != 'user-token-expired' &&
          error.code != 'user-not-found') {
        rethrow;
      }
    } finally {
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
      }
    }
  }

  void listen(Function(MLoginState state) fn) {
    mMultiAuthentication.listen((state) {
      AppLog.i('MultiAuthentication state: $state', name: 'AuthCubit');
      fn(state);
    });
  }

  void verify() {
    AppLog.i('verify called. type: $type', name: 'AuthCubit');
    mMultiAuthentication.setActive(type!.name);
    mMultiAuthentication.payload = MultiLoginPayload({
      type!.name: payload!,
    });
    AppLog.i('Requesting verification for: ${type!.name}', name: 'AuthCubit');
    mMultiAuthentication.requestVerification();
  }

  void cancelPhoneVerification() {
    final phoneSystem =
        mMultiAuthentication.systems[AuthenticationType.phone.name];
    if (phoneSystem is PhoneLogin) phoneSystem.cancelVerification();
  }
}
