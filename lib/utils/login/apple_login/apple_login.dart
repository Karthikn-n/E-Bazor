import 'dart:convert';
import 'dart:math';

import 'package:Ebozor/utils/login/lib/login_status.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:Ebozor/utils/login/lib/login_system.dart';

class AppleLogin extends LoginSystem {
  OAuthCredential? credential;

  @override
  void init() async {}

  Future<UserCredential?> login() async {
    String stage = 'starting';
    try {
      emit(MProgress());
      await _recordStage(stage);

      stage = 'clearing_previous_firebase_session';
      await _recordStage(stage);
      if (firebaseAuth.currentUser != null) {
        await firebaseAuth.signOut();
      }

      stage = 'generating_nonce';
      await _recordStage(stage);
      final String rawNonce = _generateNonce();
      final String hashedNonce =
          sha256.convert(utf8.encode(rawNonce)).toString();

      stage = 'requesting_apple_credential';
      await _recordStage(stage);
      final AuthorizationCredentialAppleID appleIdCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      stage = 'validating_identity_token';
      await _recordStage(stage);
      final String? identityToken = appleIdCredential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-apple-identity-token',
          message: 'Apple did not return an identity token.',
        );
      }

      stage = 'creating_firebase_credential';
      await _recordStage(stage);
      credential = AppleAuthProvider.credentialWithIDToken(
        identityToken,
        rawNonce,
        AppleFullPersonName(
          givenName: appleIdCredential.givenName,
          familyName: appleIdCredential.familyName,
        ),
      );

      stage = 'signing_into_firebase';
      await _recordStage(stage);
      final UserCredential userCredential =
          await firebaseAuth.signInWithCredential(credential!);

      final User? user = userCredential.user;
      final String displayName = [
        appleIdCredential.givenName,
        appleIdCredential.familyName,
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');

      if ((userCredential.additionalUserInfo?.isNewUser ?? false) &&
          user != null &&
          displayName.isNotEmpty) {
        stage = 'updating_firebase_profile';
        await _recordStage(stage);
        await user.updateDisplayName(displayName);
      }

      await _recordStage('completed');
      emit(MSuccess());
      return userCredential;
    } catch (e, stackTrace) {
      await _recordFailure(e, stackTrace, stage);
      print("apple error catch***${e.toString()}");
      emit(MFail(e));
      rethrow;
    }
  }

  Future<void> _recordStage(String stage) async {
    try {
      final FirebaseCrashlytics crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCustomKey('auth_provider', 'apple');
      await crashlytics.setCustomKey('apple_auth_stage', stage);
      await crashlytics.log('Apple authentication stage: $stage');
    } catch (_) {
      // Telemetry must never interrupt authentication.
    }
  }

  Future<void> _recordFailure(
    Object error,
    StackTrace stackTrace,
    String stage,
  ) async {
    final bool wasCancelled = error is SignInWithAppleAuthorizationException &&
        error.code == AuthorizationErrorCode.canceled;
    if (wasCancelled) return;

    try {
      final FirebaseCrashlytics crashlytics = FirebaseCrashlytics.instance;
      final String errorCode = error is FirebaseAuthException
          ? error.code
          : error is SignInWithAppleAuthorizationException
              ? error.code.name
              : error.runtimeType.toString();

      await crashlytics.setCustomKey('auth_provider', 'apple');
      await crashlytics.setCustomKey('apple_auth_stage', stage);
      await crashlytics.setCustomKey('apple_auth_error_code', errorCode);
      await crashlytics.recordError(
        error,
        stackTrace,
        reason: 'Apple authentication failed at stage: $stage',
        fatal: false,
      );
    } catch (_) {
      // Preserve the original authentication error if telemetry fails.
    }
  }

  String _generateNonce([int length = 32]) {
    const String characters =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final Random random = Random.secure();
    return List<String>.generate(
      length,
      (_) => characters[random.nextInt(characters.length)],
    ).join();
  }

  @override
  void onEvent(MLoginState state) {
    print("Login state is $state");
  }
}
