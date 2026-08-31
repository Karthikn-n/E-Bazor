import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Builds an in-memory Apple sign-in report. It is never uploaded; the tester
/// must explicitly choose Share report and a destination in the iOS share UI.
class AppleAuthDiagnostics {
  AppleAuthDiagnostics._();

  static final AppleAuthDiagnostics instance = AppleAuthDiagnostics._();
  static const bool enabled = bool.fromEnvironment(
    'ENABLE_AUTH_DIAGNOSTICS',
    defaultValue: false,
  );

  Map<String, dynamic>? _report;
  final List<Map<String, dynamic>> _reports = [];
  Stopwatch? _clock;

  bool get hasFailure => _report?['status'] == 'failed';

  void clear() {
    _report = null;
    _reports.clear();
    _clock = null;
  }

  Future<void> begin({
    required String attemptId,
    required String intent,
    required bool hadExistingFirebaseUser,
  }) async {
    _report = null;
    _clock = null;
    if (!enabled) return;
    _clock = Stopwatch()..start();

    final package = await PackageInfo.fromPlatform();
    final device = <String, dynamic>{
      'platform': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
    };
    if (Platform.isIOS) {
      try {
        final ios = await DeviceInfoPlugin().iosInfo;
        device.addAll({
          'model': ios.model,
          'machine': ios.utsname.machine,
          'system_name': ios.systemName,
          'system_version': ios.systemVersion,
          'is_physical_device': ios.isPhysicalDevice,
        });
      } catch (_) {}
    }

    final report = <String, dynamic>{
      'schema_version': 1,
      'attempt_id': attemptId,
      'created_at_utc': DateTime.now().toUtc().toIso8601String(),
      'provider': 'apple',
      'intent': intent,
      'status': 'in_progress',
      'app': {
        'version': package.version,
        'build_number': package.buildNumber,
        'package_name': package.packageName,
      },
      'firebase': {
        'project_id': Firebase.app().options.projectId,
        'had_user_before_attempt': hadExistingFirebaseUser,
      },
      'device': device,
      'steps': <Map<String, dynamic>>[],
    };
    _report = report;
    _reports.add(report);
    if (_reports.length > 10) {
      _reports.removeAt(0);
    }
  }

  void recordStep(String name, {Map<String, dynamic>? details}) {
    final report = _report;
    if (report == null) return;
    (report['steps'] as List<Map<String, dynamic>>).add({
      'name': name,
      'elapsed_ms': _clock?.elapsedMilliseconds ?? 0,
      'at_utc': DateTime.now().toUtc().toIso8601String(),
      if (details != null) 'details': details,
    });
  }

  void recordFirebaseResult(UserCredential credential) {
    final report = _report;
    if (report == null) return;
    final user = credential.user;
    report['firebase_result'] = {
      'has_user': user != null,
      'uid': user?.uid,
      'email': user?.email,
      'email_verified': user?.emailVerified,
      'display_name_received': user?.displayName?.isNotEmpty ?? false,
      'is_new_user': credential.additionalUserInfo?.isNewUser,
      'provider_ids':
          user?.providerData.map((item) => item.providerId).toList(),
    };
    recordStep('firebase_credential_received');
  }

  void recordBackendRequest({
    required String firebaseUid,
    required String? email,
    required bool hasName,
    required bool hasPhone,
  }) {
    final report = _report;
    if (report == null) return;
    report['backend_request'] = {
      'endpoint': 'user-signup',
      'type': 'apple',
      'firebase_uid': firebaseUid,
      'email': email,
      'has_name': hasName,
      'has_phone': hasPhone,
      'excluded': ['fcm_id', 'apple_token', 'firebase_token'],
    };
    recordStep('backend_user_signup_request');
  }

  void recordBackendSuccess(Map<String, dynamic> result) {
    final report = _report;
    if (report == null) return;
    final data = result['data'];
    report['backend_result'] = {
      'has_session_token': result['token']?.toString().isNotEmpty ?? false,
      if (data is Map) ...{
        'data_keys': data.keys.map((key) => key.toString()).toList()..sort(),
        'user_id': data['id']?.toString(),
        'email': data['email']?.toString(),
        'has_name': data['name']?.toString().isNotEmpty ?? false,
      },
      'excluded': ['token'],
    };
    recordStep('backend_user_signup_success');
  }

  void markSuccess() {
    if (_report == null) return;
    recordStep('flow_completed');
    _report!['status'] = 'success';
    _report!['finished_at_utc'] = DateTime.now().toUtc().toIso8601String();
  }

  void markFailure(
    Object error,
    StackTrace stackTrace, {
    required String stage,
  }) {
    final report = _report;
    if (report == null) return;
    if (error is FirebaseAuthException &&
        const {'canceled', 'cancelled', 'web-context-canceled'}
            .contains(error.code)) {
      report['status'] = 'cancelled';
      return;
    }

    final details = <String, dynamic>{
      'type': error.runtimeType.toString(),
      'message': _sanitize(error.toString(), 1200),
      'stack_trace': _sanitize(stackTrace.toString(), 3500),
    };
    if (error is FirebaseAuthException) {
      details.addAll({
        'code': error.code,
        'plugin': error.plugin,
        'firebase_message': _sanitize(error.message ?? '', 1200),
        'tenant_id': error.tenantId,
      });
    }

    recordStep('failure', details: {'stage': stage});
    report['status'] = 'failed';
    report['failed_stage'] = stage;
    report['error'] = details;
    report['finished_at_utc'] = DateTime.now().toUtc().toIso8601String();
  }

  Widget welcomeShareGesture({
    required BuildContext context,
    required Widget child,
  }) {
    if (!enabled) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: () async {
        await HapticFeedback.mediumImpact();
        if (_reports.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Try Apple sign-in or sign-up first.'),
            ),
          );
          return;
        }
        await _confirmAndShare(context);
      },
      child: child,
    );
  }

  Future<void> _confirmAndShare(BuildContext context) async {
    if (_reports.isEmpty || !context.mounted) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Share sign-in diagnostics?'),
        content: const Text(
          'The text report includes up to 10 Apple attempts from this app '
          'session, including the email and Firebase account ID returned to '
          'the app, app/device details, sign-in steps, and errors. '
          'It excludes passwords and all Apple, Firebase, FCM, and app tokens.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Share text file'),
          ),
        ],
      ),
    );
    if (approved != true || !context.mounted) return;

    final exportedAt = DateTime.now().toUtc();
    final text = const JsonEncoder.withIndent('  ').convert({
      'generated_at_utc': exportedAt.toIso8601String(),
      'attempt_count': _reports.length,
      'attempts': _reports,
    });
    final fileId = exportedAt.microsecondsSinceEpoch.toRadixString(36);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/ebozor_apple_auth_$fileId.txt');
    await file.writeAsString(text, flush: true);
    if (!context.mounted) return;

    final size = MediaQuery.sizeOf(context);
    try {
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/plain')],
        subject: 'Ebozor Apple sign-in diagnostics ($fileId)',
        text: 'Apple sign-in diagnostic report',
        sharePositionOrigin: Rect.fromLTWH(
          size.width / 2,
          size.height / 2,
          1,
          1,
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report copied to the clipboard.')),
        );
      }
    }
  }

  static String _sanitize(String value, int limit) {
    final cleaned = value
        .replaceAll(
          RegExp(r'(bearer\s+)[^\s,]+', caseSensitive: false),
          r'$1[redacted]',
        )
        .replaceAll(RegExp(r'[A-Za-z0-9_-]{80,}'), '[redacted-token]');
    return cleaned.substring(
        0, cleaned.length > limit ? limit : cleaned.length);
  }
}
