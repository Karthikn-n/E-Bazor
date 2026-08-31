import 'dart:convert';
import 'dart:io';

import 'package:Ebozor/utils/login/apple_login/apple_auth_diagnostics.dart';
import 'package:Ebozor/utils/login/lib/login_status.dart';
import 'package:Ebozor/utils/login/lib/login_system.dart';
import 'package:Ebozor/utils/login/lib/payloads.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleLogin extends LoginSystem {
  @override
  void init() async {}

  @override
  Future<UserCredential?> login() async {
    String stage = 'starting';
    final String attemptId =
        DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      emit(MProgress());
      await _recordContext(attemptId);
      await _recordStage(stage, attemptId, stopwatch.elapsedMilliseconds);

      stage = 'clearing_previous_firebase_session';
      await _recordStage(stage, attemptId, stopwatch.elapsedMilliseconds);
      if (firebaseAuth.currentUser != null) {
        await firebaseAuth.signOut();
      }

      stage = 'generating_apple_nonce';
      await _recordStage(stage, attemptId, stopwatch.elapsedMilliseconds);
      final String rawNonce = generateNonce();
      final String hashedNonce =
          sha256.convert(utf8.encode(rawNonce)).toString();

      stage = 'requesting_apple_credential';
      await _recordStage(stage, attemptId, stopwatch.elapsedMilliseconds);
      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final String? identityToken = appleCredential.identityToken;
      final String authorizationCode = appleCredential.authorizationCode;
      AppleAuthDiagnostics.instance.recordStep(
        'apple_credential_received',
        details: {
          'has_identity_token': identityToken?.isNotEmpty ?? false,
          'has_authorization_code': authorizationCode.isNotEmpty,
          'has_email': appleCredential.email?.isNotEmpty ?? false,
          'has_given_name': appleCredential.givenName?.isNotEmpty ?? false,
          'has_family_name': appleCredential.familyName?.isNotEmpty ?? false,
        },
      );

      if (identityToken == null || identityToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-apple-identity-token',
          message: 'Apple did not return an identity token.',
        );
      }
      if (authorizationCode.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-apple-authorization-code',
          message: 'Apple did not return an authorization code.',
        );
      }

      stage = 'creating_firebase_apple_credential';
      await _recordStage(stage, attemptId, stopwatch.elapsedMilliseconds);
      final OAuthCredential firebaseCredential =
          OAuthProvider('apple.com').credential(
        idToken: identityToken,
        rawNonce: rawNonce,
        accessToken: authorizationCode,
      );

      stage = 'signing_into_firebase_with_apple_credential';
      await _recordStage(stage, attemptId, stopwatch.elapsedMilliseconds);
      final UserCredential userCredential =
          await firebaseAuth.signInWithCredential(firebaseCredential);

      await _applyAppleDisplayName(userCredential.user, appleCredential);

      await _recordResult(userCredential, attemptId);
      await _recordStage(
        'completed',
        attemptId,
        stopwatch.elapsedMilliseconds,
      );
      emit(MSuccess());
      return userCredential;
    } catch (error, stackTrace) {
      final Object authError = _normalizeAppleError(error);
      final bool hadFirebaseUserOnError = firebaseAuth.currentUser != null;
      try {
        if (firebaseAuth.currentUser != null) {
          await firebaseAuth.signOut();
        }
      } catch (_) {
        // Never replace the original Apple authentication error.
      }
      await _recordFailure(
        authError,
        stackTrace,
        stage,
        attemptId,
        stopwatch.elapsedMilliseconds,
        hadFirebaseUserOnError,
      );
      emit(MFail(authError));
      Error.throwWithStackTrace(authError, stackTrace);
    }
  }

  Future<void> _applyAppleDisplayName(
    User? user,
    AuthorizationCredentialAppleID appleCredential,
  ) async {
    if (user == null || user.displayName?.isNotEmpty == true) return;
    final String displayName = [
      appleCredential.givenName,
      appleCredential.familyName,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    if (displayName.isEmpty) return;

    try {
      await user.updateDisplayName(displayName);
      await user.reload();
      AppleAuthDiagnostics.instance.recordStep(
        'apple_display_name_saved',
      );
    } catch (error) {
      AppleAuthDiagnostics.instance.recordStep(
        'apple_display_name_save_failed',
        details: {'error': _safeErrorMessage(error)},
      );
    }
  }

  Object _normalizeAppleError(Object error) {
    if (error is SignInWithAppleAuthorizationException &&
        error.code == AuthorizationErrorCode.canceled) {
      return FirebaseAuthException(
        code: 'canceled',
        message: error.message,
      );
    }
    return error;
  }

  Future<void> _recordContext(String attemptId) async {
    final String intent = payload is AppleLoginPayload
        ? (payload as AppleLoginPayload).intent.name
        : 'unknown';
    try {
      await AppleAuthDiagnostics.instance.begin(
        attemptId: attemptId,
        intent: intent,
        hadExistingFirebaseUser: firebaseAuth.currentUser != null,
      );
    } catch (_) {
      // Diagnostics must never interrupt authentication.
    }

    try {
      final FirebaseCrashlytics crashlytics = FirebaseCrashlytics.instance;
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();

      await crashlytics.setCustomKey('auth_provider', 'apple');
      await crashlytics.setCustomKey('apple_auth_attempt_id', attemptId);
      await crashlytics.setCustomKey('apple_auth_intent', intent);
      await crashlytics.setCustomKey(
        'apple_auth_existing_firebase_user',
        firebaseAuth.currentUser != null,
      );
      await crashlytics.setCustomKey(
        'apple_auth_app_version',
        packageInfo.version,
      );
      await crashlytics.setCustomKey(
        'apple_auth_build_number',
        packageInfo.buildNumber,
      );
      await crashlytics.setCustomKey(
        'apple_auth_firebase_project',
        Firebase.app().options.projectId,
      );
      await crashlytics.setCustomKey(
        'apple_auth_os_version',
        Platform.operatingSystemVersion,
      );
      await crashlytics.log('Apple authentication attempt: $attemptId');
    } catch (_) {
      // Telemetry must never interrupt authentication.
    }
  }

  Future<void> _recordStage(
    String stage,
    String attemptId,
    int elapsedMilliseconds,
  ) async {
    AppleAuthDiagnostics.instance.recordStep(stage);
    try {
      final FirebaseCrashlytics crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCustomKey('auth_provider', 'apple');
      await crashlytics.setCustomKey('apple_auth_attempt_id', attemptId);
      await crashlytics.setCustomKey('apple_auth_stage', stage);
      await crashlytics.setCustomKey(
        'apple_auth_elapsed_ms',
        elapsedMilliseconds,
      );
      await crashlytics.log(
        'Apple authentication [$attemptId] stage: $stage '
        '(${elapsedMilliseconds}ms)',
      );
    } catch (_) {
      // Telemetry must never interrupt authentication.
    }
  }

  Future<void> _recordResult(
    UserCredential credential,
    String attemptId,
  ) async {
    AppleAuthDiagnostics.instance.recordFirebaseResult(credential);
    try {
      final FirebaseCrashlytics crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCustomKey('apple_auth_attempt_id', attemptId);
      await crashlytics.setCustomKey(
        'apple_auth_result_has_user',
        credential.user != null,
      );
      await crashlytics.setCustomKey(
        'apple_auth_result_is_new_user',
        credential.additionalUserInfo?.isNewUser ?? false,
      );
      await crashlytics.setCustomKey(
        'apple_auth_result_has_email',
        credential.user?.email?.isNotEmpty ?? false,
      );
      await crashlytics.setCustomKey(
        'apple_auth_result_has_display_name',
        credential.user?.displayName?.isNotEmpty ?? false,
      );
    } catch (_) {
      // Telemetry must never interrupt authentication.
    }
  }

  Future<void> _recordFailure(
    Object error,
    StackTrace stackTrace,
    String stage,
    String attemptId,
    int elapsedMilliseconds,
    bool hadFirebaseUserOnError,
  ) async {
    final bool wasCancelled =
        error is FirebaseAuthException && _isCancellation(error.code);
    AppleAuthDiagnostics.instance.markFailure(
      error,
      stackTrace,
      stage: stage,
    );
    if (wasCancelled) return;

    try {
      final FirebaseCrashlytics crashlytics = FirebaseCrashlytics.instance;
      final String errorCode = error is FirebaseAuthException
          ? error.code
          : error.runtimeType.toString();

      await crashlytics.setCustomKey('auth_provider', 'apple');
      await crashlytics.setCustomKey('apple_auth_attempt_id', attemptId);
      await crashlytics.setCustomKey('apple_auth_stage', stage);
      await crashlytics.setCustomKey('apple_auth_error_code', errorCode);
      await crashlytics.setCustomKey(
        'apple_auth_error_message',
        _safeErrorMessage(error),
      );
      await crashlytics.setCustomKey(
        'apple_auth_had_firebase_user_on_error',
        hadFirebaseUserOnError,
      );
      await crashlytics.setCustomKey(
        'apple_auth_elapsed_ms',
        elapsedMilliseconds,
      );
      await crashlytics.recordError(
        error,
        stackTrace,
        reason: 'Apple authentication [$attemptId] failed at stage: $stage',
        fatal: false,
      );
    } catch (_) {
      // Preserve the original authentication error if telemetry fails.
    }
  }

  String _safeErrorMessage(Object error) {
    final String message = error is FirebaseAuthException
        ? error.message ?? error.code
        : error.toString();
    final String sanitized = message
        .replaceAll(RegExp(r'[A-Za-z0-9_-]{80,}'), '[redacted]')
        .replaceAll(
          RegExp(
            r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
            caseSensitive: false,
          ),
          '[redacted-email]',
        );

    return sanitized.substring(
      0,
      sanitized.length > 500 ? 500 : sanitized.length,
    );
  }

  bool _isCancellation(String code) =>
      code == 'canceled' ||
      code == 'cancelled' ||
      code == 'web-context-canceled';

  @override
  void onEvent(MLoginState state) {}
}
