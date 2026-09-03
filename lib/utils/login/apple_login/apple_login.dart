import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:Ebozor/utils/logger.dart';
import 'package:Ebozor/utils/login/lib/login_status.dart';
import 'package:Ebozor/utils/login/lib/login_system.dart';
import 'package:Ebozor/utils/login/lib/payloads.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleLoginCancelledException implements Exception {
  const AppleLoginCancelledException();

  @override
  String toString() => 'Apple sign-in cancelled by user';
}

/// Thrown when Apple issued a valid credential but the Firebase Identity
/// Toolkit backend refused to mint a session for it.
///
/// [serverError] holds the verbatim reason reported by
/// `accounts:signInWithIdp`, which the Firebase SDK itself swallows.
class AppleServerRejectionException implements Exception {
  final String code;
  final String? serverError;

  const AppleServerRejectionException(this.code, this.serverError);

  @override
  String toString() => serverError == null
      ? 'Apple sign-in rejected by Firebase ($code)'
      : 'Apple sign-in rejected by Firebase ($code): $serverError';
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

  /// Verbatim `accounts:signInWithIdp` response captured after an SDK failure.
  Map<String, dynamic>? serverProbe;

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
        if (serverProbe != null) 'identity_toolkit_probe': serverProbe,
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

/// Sign in with Apple, exchanged for a Firebase session.
///
/// Flow (the only one Firebase supports for native iOS apps):
///   1. Generate a random raw nonce, send SHA-256(rawNonce) to Apple.
///   2. Ask Apple for an ASAuthorizationAppleIDCredential.
///   3. Hand Firebase the identity token + the *raw* nonce.
///
/// The authorization code is deliberately NOT passed as `accessToken`. The
/// iOS plugin's `apple.com` branch builds the credential with
/// `OAuthProvider.appleCredential(withIDToken:rawNonce:fullName:)` and ignores
/// `accessToken` entirely, so doing so is a no-op that only obscures the flow.
class AppleLogin extends LoginSystem {
  static const _identityToolkitEndpoint =
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp';

  /// Diagnostic mode. Mirrors the SDK's `signInWithIdp` request *before*
  /// `signInWithCredential` runs, so the raw response body — including the
  /// `errorMessage` that firebase-ios-sdk silently discards — is captured.
  ///
  /// Identity Toolkit accepts a given Apple assertion exactly once, so with
  /// this enabled the SDK call that follows will fail as a duplicate. That is
  /// expected: the pre-probe body, not the SDK error, is the real result.
  /// Set to `false` once the backend rejection reason is known and fixed.
  static const bool _probeBeforeSdkSignIn = true;

  @override
  void init() {}

  @override
  Future<UserCredential?> login() async {
    final attempt = AppleAuthTracker.startAttempt();
    final intent = payload is AppleLoginPayload
        ? (payload as AppleLoginPayload).intent.name
        : 'unknown';
    attempt.addStep('starting', details: {'intent': intent});

    String? idToken;
    String? rawNonce;

    try {
      emit(MProgress());
      AppLog.i('Initiating Apple sign-in [${attempt.attemptId}]',
          name: 'AppleLogin');

      if (!await SignInWithApple.isAvailable()) {
        throw const AppleServerRejectionException(
          'apple-unavailable',
          'Sign in with Apple is not available on this device.',
        );
      }

      // A stale Firebase session makes the failure diagnostics ambiguous.
      if (firebaseAuth.currentUser != null) {
        attempt.addStep('clearing_previous_firebase_session');
        await firebaseAuth.signOut();
      }

      attempt.addStep('generating_nonce');
      rawNonce = _generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      attempt.addStep('requesting_apple_credential');
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      idToken = appleCredential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AppleServerRejectionException(
          'missing-identity-token',
          'Apple returned a credential without an identity token.',
        );
      }

      final claims = _decodeJwtClaims(idToken);
      attempt.addStep('apple_credential_received', details: {
        'has_authorization_code':
            (appleCredential.authorizationCode).isNotEmpty,
        'has_email': appleCredential.email != null,
        'has_given_name': appleCredential.givenName != null,
        'has_family_name': appleCredential.familyName != null,
        'jwt_aud': claims?['aud'],
        'jwt_iss': claims?['iss'],
        'jwt_sub': claims?['sub'],
        'jwt_email_present': claims?['email'] != null,
        'jwt_email_verified': claims?['email_verified'],
        'jwt_is_private_email': claims?['is_private_email'],
        'jwt_exp': claims?['exp'],
        'nonce_match': claims?['nonce'] == hashedNonce,
      });

      if (_probeBeforeSdkSignIn) {
        attempt.addStep('probing_identity_toolkit_before_sdk');
        attempt.serverProbe = await _probeIdentityToolkit(
          idToken: idToken,
          rawNonce: rawNonce,
          mirrorSdkRequest: true,
        );
        AppLog.w(
          'Pre-probe identity-toolkit response [${attempt.attemptId}]: '
          '${jsonEncode(attempt.serverProbe)}',
          name: 'AppleLogin',
        );
      }

      attempt.addStep('creating_firebase_credential');
      final firebaseCredential = AppleAuthProvider.credentialWithIDToken(
        idToken,
        rawNonce,
        AppleFullPersonName(
          givenName: appleCredential.givenName,
          familyName: appleCredential.familyName,
        ),
      );

      attempt.addStep('signing_into_firebase');
      final userCredential =
          await firebaseAuth.signInWithCredential(firebaseCredential);

      // Apple only sends the name on the very first authorization, so persist
      // it to the Firebase profile while we still have it.
      final user = userCredential.user;
      final fullName = [appleCredential.givenName, appleCredential.familyName]
          .whereType<String>()
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .join(' ');

      if (user != null &&
          fullName.isNotEmpty &&
          (user.displayName == null || user.displayName!.isEmpty)) {
        try {
          await user.updateDisplayName(fullName);
          await user.reload();
          attempt.addStep('display_name_saved', details: {'name': fullName});
        } catch (e) {
          attempt.addStep('display_name_save_failed',
              details: {'error': e.toString()});
        }
      }

      attempt.status = 'success';
      attempt.finishedAt = DateTime.now();
      attempt.addStep('completed', details: {
        'uid': user?.uid,
        'email': user?.email,
        'is_new_user': userCredential.additionalUserInfo?.isNewUser,
      });

      AppLog.i(
        'Apple sign-in completed [${attempt.attemptId}]. UID: ${user?.uid}',
        name: 'AppleLogin',
      );

      emit(MSuccess());
      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return _finishAsCancelled(attempt);
      }
      return _finishAsFailure(
        attempt,
        error: {
          'type': 'SignInWithAppleAuthorizationException',
          'code': e.code.name,
          'message': e.message,
        },
        thrown: e,
      );
    } on FirebaseAuthException catch (e, stackTrace) {
      if (_isCancellation(e.code) || _isCancellation(e.message ?? '')) {
        return _finishAsCancelled(attempt);
      }

      // The SDK reports `invalid-user-token / accessToken or refreshToken is
      // nil` whenever Identity Toolkit answers 200 with no tokens, hiding the
      // real reason. If the pre-probe already captured that response, keep it:
      // a probe run *after* the SDK call is a duplicate submission and the
      // backend answers "Duplicate credential received" regardless of cause.
      attempt.serverProbe ??= await _probeIdentityToolkit(
        idToken: idToken,
        rawNonce: rawNonce,
        mirrorSdkRequest: false,
      );
      final serverReason = _serverReasonFrom(attempt.serverProbe);

      AppLog.e(
        'Apple sign-in rejected [${attempt.attemptId}]: [${e.code}] '
        '${e.message} | identity-toolkit says: ${serverReason ?? "no probe"}',
        error: e,
        stackTrace: stackTrace,
        name: 'AppleLogin',
      );

      return _finishAsFailure(
        attempt,
        error: {
          'type': 'FirebaseAuthException',
          'code': e.code,
          'message': e.message,
          'plugin': e.plugin,
          'server_reason': serverReason,
          'stack_trace': stackTrace.toString(),
        },
        thrown: serverReason == null
            ? e
            : AppleServerRejectionException(e.code, serverReason),
      );
    } catch (error, stackTrace) {
      if (_isCancellation(error.toString())) {
        return _finishAsCancelled(attempt);
      }
      return _finishAsFailure(
        attempt,
        error: {
          'type': error.runtimeType.toString(),
          'message': error.toString(),
          'stack_trace': stackTrace.toString(),
        },
        thrown: error,
      );
    }
  }

  /// Apple requires the nonce to be URL-safe; keep to the unreserved set.
  String _generateRawNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  Map<String, dynamic>? _decodeJwtClaims(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Calls `accounts:signInWithIdp` directly.
  ///
  /// With [mirrorSdkRequest] the request is byte-for-byte what
  /// `Auth.signIn(with:)` sends (`returnIdpCredential: true`), so the captured
  /// body contains the `errorMessage` field that firebase-ios-sdk drops on the
  /// floor when it does not recognise the value. Without it, the assertion is
  /// sent with `returnIdpCredential: false` to force a hard HTTP 4xx instead.
  ///
  /// Diagnostic only — the resulting tokens cannot be injected back into the
  /// Firebase SDK session.
  Future<Map<String, dynamic>?> _probeIdentityToolkit({
    required String? idToken,
    required String? rawNonce,
    required bool mirrorSdkRequest,
  }) async {
    if (idToken == null || rawNonce == null) return null;

    try {
      final options = Firebase.app().options;
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        validateStatus: (_) => true,
      ));

      final response = await dio.post<dynamic>(
        _identityToolkitEndpoint,
        queryParameters: {'key': options.apiKey},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (Platform.isIOS && options.iosBundleId != null)
              'X-Ios-Bundle-Identifier': options.iosBundleId,
          },
        ),
        data: {
          'postBody': 'id_token=$idToken&providerId=apple.com&nonce=$rawNonce',
          'requestUri': 'https://${options.projectId}.firebaseapp.com',
          'returnIdpCredential': mirrorSdkRequest,
          'returnSecureToken': true,
        },
      );

      return {
        'mirrors_sdk_request': mirrorSdkRequest,
        'http_status': response.statusCode,
        'body': _redactTokens(response.data),
      };
    } catch (e) {
      return {'probe_failed': e.toString()};
    }
  }

  /// Strips session tokens so the dump can be shared safely, while keeping
  /// every field that explains a rejection.
  dynamic _redactTokens(dynamic body) {
    const secretKeys = {
      'idToken',
      'refreshToken',
      'oauthIdToken',
      'oauthAccessToken',
    };
    if (body is Map) {
      return body.map((key, value) => MapEntry(
            key.toString(),
            secretKeys.contains(key.toString())
                ? '<redacted len=${value.toString().length}>'
                : _redactTokens(value),
          ));
    }
    if (body is List) return body.map(_redactTokens).toList();
    return body;
  }

  String? _serverReasonFrom(Map<String, dynamic>? probe) {
    if (probe == null || probe['probe_failed'] != null) return null;
    final body = probe['body'];
    final mirrored = probe['mirrors_sdk_request'] == true;

    // returnIdpCredential=true: a 200 can still carry the rejection here. This
    // is the field the SDK discards, so it is the authoritative answer.
    if (body is Map && body['errorMessage'] != null) {
      return body['errorMessage'].toString();
    }
    // returnIdpCredential=false: the rejection arrives as a normal HTTP error.
    if (body is Map && body['error'] is Map) {
      final message = (body['error'] as Map)['message']?.toString();
      if (message == null) return null;
      return mirrored
          ? message
          : '$message (replayed after the SDK call — a duplicate-credential '
              'reply here reflects the replay, not the original rejection)';
    }
    if (probe['http_status'] == 200) {
      return mirrored
          ? 'identity-toolkit returned a complete session for this assertion — '
              'the backend and project config are healthy, so the failure is in '
              'the iOS SDK/plugin layer'
          : 'identity-toolkit accepted the same assertion on direct retry';
    }
    return null;
  }

  Future<UserCredential?> _finishAsCancelled(AppleAuthAttempt attempt) async {
    attempt.status = 'cancelled';
    attempt.finishedAt = DateTime.now();
    attempt.addStep('cancelled');
    AppLog.i('Apple sign-in cancelled by user [${attempt.attemptId}]',
        name: 'AppleLogin');
    emit(MFail(const AppleLoginCancelledException()));
    throw const AppleLoginCancelledException();
  }

  Future<UserCredential?> _finishAsFailure(
    AppleAuthAttempt attempt, {
    required Map<String, dynamic> error,
    required Object thrown,
  }) async {
    attempt.status = 'failed';
    attempt.failedStage =
        attempt.steps.isNotEmpty ? attempt.steps.last.name : 'unknown';
    attempt.finishedAt = DateTime.now();
    attempt.error = error;
    attempt.addStep('failure', details: {
      'stage': attempt.failedStage,
      'code': error['code'],
      'message': error['message'],
      if (error['server_reason'] != null)
        'server_reason': error['server_reason'],
    });

    AppLog.w(
      'Apple sign-in failed [${attempt.attemptId}] at ${attempt.failedStage}: '
      '${error['code'] ?? error['type']} ${error['message'] ?? ''}',
      name: 'AppleLogin',
    );

    await _saveFailureFile(attempt);

    try {
      if (firebaseAuth.currentUser != null) {
        await firebaseAuth.signOut();
      }
    } catch (_) {}

    emit(MFail(thrown));
    throw thrown;
  }

  static Future<void> _saveFailureFile(AppleAuthAttempt attempt) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file =
          File('${tempDir.path}/ebozor_apple_auth_${attempt.attemptId}.txt');
      final content = const JsonEncoder.withIndent('  ').convert({
        'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
        'attempt': attempt.toJson(),
      });
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
        lower.contains('user-cancelled') ||
        lower.contains('user_cancelled');
  }

  @override
  void onEvent(MLoginState state) {}
}
