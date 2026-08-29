import 'package:Ebozor/utils/login/lib/login_status.dart';
import 'package:Ebozor/utils/login/lib/login_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class AppleLogin extends LoginSystem {
  @override
  void init() async {}

  @override
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

      stage = 'creating_native_apple_provider';
      await _recordStage(stage);
      final AppleAuthProvider appleProvider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');

      // On iOS, Firebase's native provider owns the Apple request, nonce,
      // credential exchange, and Firebase session. Keeping this in one SDK
      // avoids transferring an Apple token between two auth plugins.
      stage = 'signing_into_firebase_with_native_apple_provider';
      await _recordStage(stage);
      final UserCredential userCredential =
          await firebaseAuth.signInWithProvider(appleProvider);

      await _recordStage('completed');
      emit(MSuccess());
      return userCredential;
    } catch (error, stackTrace) {
      try {
        if (firebaseAuth.currentUser != null) {
          await firebaseAuth.signOut();
        }
      } catch (_) {
        // Never replace the original Apple authentication error.
      }
      await _recordFailure(error, stackTrace, stage);
      emit(MFail(error));
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
    final bool wasCancelled =
        error is FirebaseAuthException && _isCancellation(error.code);
    if (wasCancelled) return;

    try {
      final FirebaseCrashlytics crashlytics = FirebaseCrashlytics.instance;
      final String errorCode = error is FirebaseAuthException
          ? error.code
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

  bool _isCancellation(String code) =>
      code == 'canceled' ||
      code == 'cancelled' ||
      code == 'web-context-canceled';

  @override
  void onEvent(MLoginState state) {}
}
