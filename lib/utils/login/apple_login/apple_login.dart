import 'dart:convert';
import 'dart:io';

import 'package:Ebozor/utils/logger.dart';
import 'package:Ebozor/utils/login/lib/login_status.dart';
import 'package:Ebozor/utils/login/lib/login_system.dart';
import 'package:Ebozor/utils/login/lib/payloads.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleLoginCancelledException implements Exception {
  const AppleLoginCancelledException();

  @override
  String toString() => 'Apple sign-in cancelled by user';
}

/// Represents a single step in an Apple authentication attempt.
class AppleAuthStep {
  final String name;
  final DateTime at;
  final int elapsedMs;
  final Map<String, dynamic>? details;

  AppleAuthStep({
    required this.name,
    required this.at,
    required this.elapsedMs,
    this.details,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'elapsed_ms': elapsedMs,
        'at_utc': at.toUtc().toIso8601String(),
        if (details != null) 'details': details,
      };
}

/// Diagnostic model tracking the full lifecycle of an Apple sign-in attempt.
class AppleAuthAttempt {
  final String attemptId;
  final DateTime createdAt;
  DateTime? finishedAt;
  String status; // 'in_progress', 'success', 'failed', 'cancelled'
  String? failedStage;
  Map<String, dynamic>? error;
  final List<AppleAuthStep> steps = [];

  AppleAuthAttempt({
    required this.attemptId,
    required this.createdAt,
    this.status = 'in_progress',
  });

  void addStep(String name, {Map<String, dynamic>? details}) {
    final now = DateTime.now();
    final elapsed = now.difference(createdAt).inMilliseconds;
    steps.add(AppleAuthStep(
      name: name,
      at: now,
      elapsedMs: elapsed,
      details: details,
    ));
  }

  Map<String, dynamic> toJson() => {
        'attempt_id': attemptId,
        'created_at_utc': createdAt.toUtc().toIso8601String(),
        'finished_at_utc': finishedAt?.toUtc().toIso8601String(),
        'status': status,
        'failed_stage': failedStage,
        'steps': steps.map((s) => s.toJson()).toList(),
        if (error != null) 'error': error,
      };
}

/// In-memory tracker of recent Apple auth attempts for diagnostic logs.
class AppleAuthTracker {
  static final List<AppleAuthAttempt> history = [];
  static AppleAuthAttempt? latestAttempt;

  static AppleAuthAttempt startAttempt() {
    final attemptId = 'apple_${DateTime.now().millisecondsSinceEpoch}';
    final attempt = AppleAuthAttempt(
      attemptId: attemptId,
      createdAt: DateTime.now(),
    );
    history.add(attempt);
    if (history.length > 20) history.removeAt(0);
    latestAttempt = attempt;
    return attempt;
  }
}

class AppleLogin extends LoginSystem {
  @override
  void init() async {}

  @override
  Future<UserCredential?> login() async {
    final attempt = AppleAuthTracker.startAttempt();
    final intent = payload is AppleLoginPayload
        ? (payload as AppleLoginPayload).intent.name
        : 'unknown';
    attempt.addStep('starting', details: {'intent': intent});

    try {
      emit(MProgress());
      AppLog.i('Initiating Firebase Apple login [${attempt.attemptId}]',
          name: 'AppleLogin');

      // Clear any previous Firebase session
      if (firebaseAuth.currentUser != null) {
        attempt.addStep('clearing_previous_firebase_session');
        await firebaseAuth.signOut();
      }

      attempt.addStep('generating_apple_nonce');
      final rawNonce = generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      attempt.addStep('requesting_apple_credential');
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final identityToken = appleCredential.identityToken;
      final authorizationCode = appleCredential.authorizationCode;

      attempt.addStep('apple_credential_received', details: {
        'has_identity_token': identityToken?.isNotEmpty ?? false,
        'has_authorization_code': authorizationCode.isNotEmpty,
        'has_email': appleCredential.email?.isNotEmpty ?? false,
        'has_given_name': appleCredential.givenName?.isNotEmpty ?? false,
        'has_family_name': appleCredential.familyName?.isNotEmpty ?? false,
      });

      if (identityToken == null || identityToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-apple-identity-token',
          message: 'Apple did not return an identity token.',
        );
      }

      attempt.addStep('creating_firebase_apple_credential');
      final firebaseCredential = OAuthProvider('apple.com').credential(
        idToken: identityToken,
        rawNonce: rawNonce,
        accessToken: authorizationCode.isNotEmpty ? authorizationCode : null,
      );

      attempt.addStep('signing_into_firebase_with_apple_credential');
      final userCredential =
          await firebaseAuth.signInWithCredential(firebaseCredential);

      // Save display name if Apple provided it
      final fullName = [
        appleCredential.givenName,
        appleCredential.familyName,
      ]
          .whereType<String>()
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .join(' ');

      if (fullName.isNotEmpty &&
          userCredential.user != null &&
          (userCredential.user!.displayName == null ||
              userCredential.user!.displayName!.isEmpty)) {
        try {
          await userCredential.user!.updateDisplayName(fullName);
          await userCredential.user!.reload();
          attempt.addStep('apple_display_name_saved', details: {'name': fullName});
        } catch (_) {}
      }

      attempt.status = 'success';
      attempt.finishedAt = DateTime.now();
      attempt.addStep('completed', details: {
        'uid': userCredential.user?.uid,
        'email': userCredential.user?.email,
      });

      AppLog.i(
        'Apple login completed successfully [${attempt.attemptId}]. UID: ${userCredential.user?.uid}, Email: ${userCredential.user?.email}',
        name: 'AppleLogin',
      );

      emit(MSuccess());
      return userCredential;
    } on FirebaseAuthException catch (e, stackTrace) {
      final isCancel =
          _isCancellation(e.code) || _isCancellation(e.message ?? '');
      attempt.status = isCancel ? 'cancelled' : 'failed';
      attempt.failedStage = attempt.steps.isNotEmpty
          ? attempt.steps.last.name
          : 'signing_into_firebase_with_native_apple_provider';
      attempt.finishedAt = DateTime.now();
      attempt.error = {
        'type': 'FirebaseAuthException',
        'code': e.code,
        'message': e.message,
        'plugin': e.plugin,
        'stack_trace': stackTrace.toString(),
      };
      attempt.addStep('failure', details: {
        'stage': attempt.failedStage,
        'code': e.code,
        'message': e.message,
      });

      AppLog.w(
          'FirebaseAuthException in AppleLogin [${attempt.attemptId}]: [${e.code}] ${e.message}',
          name: 'AppleLogin');

      // Persist failure dump to disk
      await _saveFailureFile(attempt);

      if (isCancel) {
        emit(MFail(const AppleLoginCancelledException()));
        throw const AppleLoginCancelledException();
      }
      try {
        if (firebaseAuth.currentUser != null) {
          await firebaseAuth.signOut();
        }
      } catch (_) {}
      emit(MFail(e));
      rethrow;
    } catch (error, stackTrace) {
      final isCancel = _isCancellation(error.toString());
      attempt.status = isCancel ? 'cancelled' : 'failed';
      attempt.failedStage =
          attempt.steps.isNotEmpty ? attempt.steps.last.name : 'unknown';
      attempt.finishedAt = DateTime.now();
      attempt.error = {
        'type': error.runtimeType.toString(),
        'message': error.toString(),
        'stack_trace': stackTrace.toString(),
      };
      attempt.addStep('failure', details: {
        'stage': attempt.failedStage,
        'error': error.toString(),
      });

      AppLog.e('Exception in AppleLogin [${attempt.attemptId}]: $error',
          error: error, stackTrace: stackTrace, name: 'AppleLogin');

      // Persist failure dump to disk
      await _saveFailureFile(attempt);

      if (isCancel) {
        emit(MFail(const AppleLoginCancelledException()));
        throw const AppleLoginCancelledException();
      }
      try {
        if (firebaseAuth.currentUser != null) {
          await firebaseAuth.signOut();
        }
      } catch (_) {}
      emit(MFail(error));
      rethrow;
    }
  }



  static Future<void> _saveFailureFile(AppleAuthAttempt attempt) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file =
          File('${tempDir.path}/ebozor_apple_auth_${attempt.attemptId}.txt');
      final content = const JsonEncoder.withIndent('  ').convert(
        {
          'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
          'attempt': attempt.toJson(),
        },
      );
      await file.writeAsString(content, flush: true);
      AppLog.i('Saved Apple auth failure dump to: ${file.path}',
          name: 'AppleLogin');
    } catch (e) {
      AppLog.w('Failed to save Apple auth failure dump: $e', name: 'AppleLogin');
    }
  }

  bool _isCancellation(String text) {
    final lower = text.toLowerCase();
    return lower.contains('canceled') ||
        lower.contains('cancelled') ||
        lower.contains('web-context-canceled') ||
        lower.contains('1001') ||
        lower.contains('user-cancelled') ||
        lower.contains('user_cancelled');
  }

  @override
  void onEvent(MLoginState state) {}
}
