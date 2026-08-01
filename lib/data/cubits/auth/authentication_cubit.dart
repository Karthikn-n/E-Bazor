import 'dart:io';
import 'package:Ebozor/utils/logger.dart';
import 'package:Ebozor/utils/login/apple_login/apple_login.dart';
import 'package:Ebozor/utils/login/email_login/email_login.dart';
import 'package:Ebozor/utils/login/google_login/google_login.dart';
import 'package:Ebozor/utils/login/phone_login/phone_login.dart';
import 'package:Ebozor/utils/login/lib/login_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

String authenticationErrorMessage(dynamic error) {
  if (error is AuthenticationFlowException) {
    switch (error.code) {
      case 'account-not-found':
        return 'No account found. Please sign up first.';
      case 'account-already-exists':
        return 'An account already exists. Please sign in instead.';
      case 'email-not-verified':
        return 'Please verify your email before signing in.';
    }
  }
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'An account already exists. Please sign in instead.';
      case 'user-not-found':
        return 'No account found. Please sign up first.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'The email or password is incorrect.';
      case 'account-exists-with-different-credential':
      case 'credential-already-in-use':
        return 'This account uses a different sign-in method.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'invalid-phone-number':
      case 'missing-phone-number':
        return 'Please enter a valid phone number.';
      case 'invalid-verification-code':
        return 'The verification code is incorrect.';
      case 'session-expired':
        return 'The verification code expired. Please request a new one.';
      case 'network-request-failed':
        return 'Please check your internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
    }
  }
  if (error.toString().contains('google-terminated')) return '';
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
    AppLog.i('setData type: $type', name: 'AuthCubit');
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

      if (intent == AuthenticationIntent.signIn && isNewUser) {
        await FirebaseAuth.instance.signOut();
        throw const AuthenticationFlowException('account-not-found');
      }

      if (intent == AuthenticationIntent.signUp && !isNewUser) {
        await FirebaseAuth.instance.signOut();
        throw const AuthenticationFlowException('account-already-exists');
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
}
