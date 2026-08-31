import 'dart:io';

import 'package:Ebozor/utils/login/apple_login/apple_auth_diagnostics.dart';
import 'package:Ebozor/utils/login/lib/login_status.dart';
import 'package:Ebozor/utils/login/lib/login_system.dart';
import 'package:Ebozor/utils/login/lib/payloads.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppleLogin extends LoginSystem {
  @override
  void init() async {}

  @override
  Future<UserCredential?> login() async {
    String stage = 'starting';
    final AppleAuthDiagnostics diagnostics = AppleAuthDiagnostics.create();
    final String attemptId = diagnostics.attemptId;
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      emit(MProgress());
      await diagnostics.recordContext(
        intent: payload is AppleLoginPayload
            ? (payload as AppleLoginPayload).intent.name
            : 'unknown',
        existingUser: firebaseAuth.currentUser,
      );
      diagnostics.recordStage(stage, stopwatch.elapsedMilliseconds);
      await _recordContext(attemptId);
      await _recordStage(stage, attemptId, stopwatch.elapsedMilliseconds);

      stage = 'clearing_previous_firebase_session';
      diagnostics.recordStage(stage, stopwatch.elapsedMilliseconds);
      await _recordStage(stage, attemptId, stopwatch.elapsedMilliseconds);
      if (firebaseAuth.currentUser != null) {
        await firebaseAuth.signOut();
      }

      stage = 'creating_native_apple_provider';
      diagnostics.recordStage(stage, stopwatch.elapsedMilliseconds);
      await _recordStage(stage, attemptId, stopwatch.elapsedMilliseconds);
      final AppleAuthProvider appleProvider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');

      // On iOS, Firebase's native provider owns the Apple request, nonce,
      // credential exchange, and Firebase session. Keeping this in one SDK
      // avoids transferring an Apple token between two auth plugins.
      stage = 'signing_into_firebase_with_native_apple_provider';
      diagnostics.recordStage(stage, stopwatch.elapsedMilliseconds);
      await _recordStage(stage, attemptId, stopwatch.elapsedMilliseconds);
      final UserCredential userCredential =
          await firebaseAuth.signInWithProvider(appleProvider);

      diagnostics.recordSuccess(
        userCredential,
        stopwatch.elapsedMilliseconds,
      );
      await _recordResult(userCredential, attemptId);
      diagnostics.recordStage('completed', stopwatch.elapsedMilliseconds);
      await _recordStage(
        'completed',
        attemptId,
        stopwatch.elapsedMilliseconds,
      );
      await diagnostics.flush();
      emit(MSuccess());
      return userCredential;
    } catch (error, stackTrace) {
      final User? firebaseUserOnError = firebaseAuth.currentUser;
      final bool wasCancelled =
          error is FirebaseAuthException && _isCancellation(error.code);
      diagnostics.recordFailure(
        error: error,
        stackTrace: stackTrace,
        stage: stage,
        elapsedMilliseconds: stopwatch.elapsedMilliseconds,
        firebaseUserOnError: firebaseUserOnError,
        wasCancelled: wasCancelled,
      );
      try {
        if (firebaseAuth.currentUser != null) {
          await firebaseAuth.signOut();
        }
      } catch (_) {
        // Never replace the original Apple authentication error.
      }
      await _recordFailure(
        error,
        stackTrace,
        stage,
        attemptId,
        stopwatch.elapsedMilliseconds,
        firebaseUserOnError != null,
      );
      await diagnostics.flush();
      emit(MFail(error));
      rethrow;
    }
  }

  Future<void> _recordContext(String attemptId) async {
    try {
      final FirebaseCrashlytics crashlytics = FirebaseCrashlytics.instance;
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String intent = payload is AppleLoginPayload
          ? (payload as AppleLoginPayload).intent.name
          : 'unknown';

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
