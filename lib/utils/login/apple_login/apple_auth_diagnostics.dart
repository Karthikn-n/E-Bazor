import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Temporary, write-only diagnostics for the Apple authentication flow.
///
/// Never add Apple identity tokens, authorization codes, nonces, Firebase ID
/// tokens, backend JWTs, passwords, or raw credentials to these documents.
class AppleAuthDiagnostics {
  AppleAuthDiagnostics._(this.attemptId)
      : _document = FirebaseFirestore.instance
            .collection(collectionName)
            .doc(attemptId);

  static const String collectionName = 'apple_auth_diagnostics';
  static const int schemaVersion = 1;
  static const Duration retention = Duration(days: 7);

  final String attemptId;
  final DocumentReference<Map<String, dynamic>> _document;
  Future<void> _pendingWrites = Future<void>.value();

  static AppleAuthDiagnostics create() {
    final Random random = Random.secure();
    final String randomPart = List<int>.generate(
      12,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    final String timePart =
        DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return AppleAuthDiagnostics._('${timePart}_$randomPart');
  }

  Future<void> recordContext({
    required String intent,
    required User? existingUser,
  }) async {
    PackageInfo? packageInfo;
    IosDeviceInfo? iosDeviceInfo;
    try {
      packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {}
    if (Platform.isIOS) {
      try {
        iosDeviceInfo = await DeviceInfoPlugin().iosInfo;
      } catch (_) {}
    }

    _enqueue({
      'attemptId': attemptId,
      'schemaVersion': schemaVersion,
      'provider': 'apple',
      'intent': intent,
      'status': 'started',
      'stage': 'context_collected',
      'appVersion': packageInfo?.version ?? 'unknown',
      'buildNumber': packageInfo?.buildNumber ?? 'unknown',
      'packageName': packageInfo?.packageName ?? 'unknown',
      'firebaseProject': Firebase.app().options.projectId,
      'platform': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      if (iosDeviceInfo != null) ...{
        'deviceModel': iosDeviceInfo.model,
        'deviceMachine': iosDeviceInfo.utsname.machine,
        'isPhysicalDevice': iosDeviceInfo.isPhysicalDevice,
      },
      'existingFirebaseUser': existingUser != null,
      if (existingUser?.uid != null) 'existingFirebaseUid': existingUser!.uid,
      if (existingUser?.email != null)
        'existingFirebaseEmail': existingUser!.email,
      'startedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().toUtc().add(retention)),
      'steps': FieldValue.arrayUnion([
        _step('context_collected', 0),
      ]),
    });
  }

  void recordStage(String stage, int elapsedMilliseconds) {
    _enqueue({
      'status': stage == 'completed' ? 'completed' : 'in_progress',
      'stage': stage,
      'elapsedMs': elapsedMilliseconds,
      if (stage == 'completed') 'completedAt': FieldValue.serverTimestamp(),
      'steps': FieldValue.arrayUnion([
        _step(stage, elapsedMilliseconds),
      ]),
    });
  }

  void recordSuccess(UserCredential credential, int elapsedMilliseconds) {
    final User? user = credential.user;
    _enqueue({
      'status': 'firebase_authenticated',
      'stage': 'firebase_response_received',
      'elapsedMs': elapsedMilliseconds,
      'hasUser': user != null,
      'isNewUser': credential.additionalUserInfo?.isNewUser ?? false,
      if (user != null) ...{
        'firebaseUid': user.uid,
        if (user.email != null) 'email': user.email,
        if (user.displayName != null) 'displayName': user.displayName,
        'emailVerified': user.emailVerified,
        'providerIds':
            user.providerData.map((provider) => provider.providerId).toList(),
        if (user.metadata.creationTime != null)
          'creationTime': user.metadata.creationTime!.toUtc().toIso8601String(),
        if (user.metadata.lastSignInTime != null)
          'lastSignInTime':
              user.metadata.lastSignInTime!.toUtc().toIso8601String(),
      },
      'steps': FieldValue.arrayUnion([
        _step('firebase_response_received', elapsedMilliseconds),
      ]),
    });
  }

  void recordFailure({
    required Object error,
    required StackTrace stackTrace,
    required String stage,
    required int elapsedMilliseconds,
    required User? firebaseUserOnError,
    required bool wasCancelled,
  }) {
    final String errorCode = error is FirebaseAuthException
        ? error.code
        : error is PlatformException
            ? error.code
            : error.runtimeType.toString();
    final String errorMessage = _safeErrorMessage(error);
    final String? errorEmail =
        error is FirebaseAuthException ? error.email : null;

    _enqueue({
      'status': wasCancelled ? 'cancelled' : 'failed',
      'stage': stage,
      'elapsedMs': elapsedMilliseconds,
      'errorType': error.runtimeType.toString(),
      'errorCode': errorCode,
      'errorMessage': errorMessage,
      if (error is FirebaseAuthException) ...{
        'errorPlugin': error.plugin,
        if (error.tenantId != null) 'errorTenantId': error.tenantId,
      },
      if (error is PlatformException && error.details != null)
        'errorDetails': _sanitize(error.details.toString(), maxLength: 2000),
      'errorStack': _sanitize(stackTrace.toString(), maxLength: 8000),
      if (errorEmail != null) 'errorEmail': errorEmail,
      'hadFirebaseUserOnError': firebaseUserOnError != null,
      if (firebaseUserOnError?.uid != null)
        'firebaseUidOnError': firebaseUserOnError!.uid,
      if (firebaseUserOnError?.email != null)
        'firebaseEmailOnError': firebaseUserOnError!.email,
      'completedAt': FieldValue.serverTimestamp(),
      'steps': FieldValue.arrayUnion([
        {
          ..._step(
            wasCancelled ? 'cancelled' : 'failed',
            elapsedMilliseconds,
          ),
          'stage': stage,
          'errorCode': errorCode,
          'errorMessage': errorMessage,
        },
      ]),
    });
  }

  Future<void> flush() async {
    try {
      await _pendingWrites.timeout(const Duration(seconds: 4));
    } catch (_) {
      // Queued Firestore writes may still complete through offline persistence.
    }
  }

  void _enqueue(Map<String, dynamic> data) {
    _pendingWrites = _pendingWrites.then((_) => _write(data));
  }

  Future<void> _write(Map<String, dynamic> data) async {
    try {
      await _document.set(
        {
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      ).timeout(const Duration(seconds: 2));
    } catch (error) {
      try {
        final FirebaseCrashlytics crashlytics = FirebaseCrashlytics.instance;
        await crashlytics.setCustomKey(
          'apple_auth_firestore_write_error',
          _safeErrorMessage(error),
        );
        await crashlytics.log(
          'Apple auth Firestore write failed for attempt $attemptId.',
        );
      } catch (_) {
        // Diagnostic failures must never affect authentication.
      }
    }
  }

  Map<String, dynamic> _step(String name, int elapsedMilliseconds) => {
        'name': name,
        'elapsedMs': elapsedMilliseconds,
        'clientTimestamp': DateTime.now().toUtc().toIso8601String(),
      };

  String _safeErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      return _sanitize(error.message ?? error.code);
    }
    if (error is PlatformException) {
      return _sanitize(error.message ?? error.code);
    }
    return _sanitize(error.toString());
  }

  String _sanitize(String value, {int maxLength = 1200}) {
    String sanitized = value
        .replaceAll(
          RegExp(r'Bearer\s+\S+', caseSensitive: false),
          'Bearer [redacted]',
        )
        .replaceAll(
          RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
          '[redacted-jwt]',
        )
        .replaceAllMapped(
          RegExp(
            r'(identityToken|authorizationCode|nonce|accessToken|idToken)\s*[:=]\s*\S+',
            caseSensitive: false,
          ),
          (match) => '${match.group(1)}=[redacted]',
        )
        .replaceAll(RegExp(r'[A-Za-z0-9_-]{120,}'), '[redacted-secret]');
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }
    return sanitized;
  }
}
