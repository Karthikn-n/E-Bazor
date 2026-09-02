import 'dart:convert';
import 'dart:io';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/logger.dart';
import 'package:Ebozor/utils/login/apple_login/apple_login.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LogExporter {
  LogExporter._();

  static bool _isExporting = false;

  /// Gathers all device, app, system, auth, and log info, writes to a .txt file, and opens the share sheet.
  static Future<void> exportAndShareLogs(BuildContext context) async {
    if (_isExporting) return;
    _isExporting = true;

    try {
      // Haptic feedback
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {}

      // Inform the user
      if (context.mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          'Preparing diagnostic log file...',
        );
      }

      AppLog.i('Exporting diagnostic logs initiated', name: 'LogExporter');

      final StringBuffer sb = StringBuffer();
      final DateTime now = DateTime.now();

      sb.writeln('=' * 80);
      sb.writeln('                   EBOZOR DIAGNOSTIC & DEVICE LOG REPORT');
      sb.writeln('=' * 80);
      sb.writeln('Generated At (Local): ${now.toIso8601String()}');
      sb.writeln('Generated At (UTC):   ${now.toUtc().toIso8601String()}');
      sb.writeln('Timezone:             ${now.timeZoneName} (Offset: ${now.timeZoneOffset})');
      sb.writeln();

      // -----------------------------------------------------------------------
      // 1. App Info
      // -----------------------------------------------------------------------
      sb.writeln('-' * 80);
      sb.writeln('1. INSTALLED APPLICATION INFORMATION');
      sb.writeln('-' * 80);
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        sb.writeln('App Name:           ${packageInfo.appName}');
        sb.writeln('Package Name:       ${packageInfo.packageName}');
        sb.writeln('Version:            ${packageInfo.version}');
        sb.writeln('Build Number:       ${packageInfo.buildNumber}');
        sb.writeln('Build Signature:    ${packageInfo.buildSignature}');
        sb.writeln('Installer Store:    ${packageInfo.installerStore ?? "N/A"}');
      } catch (e) {
        sb.writeln('Error reading PackageInfo: $e');
      }
      sb.writeln();

      // -----------------------------------------------------------------------
      // 2. Device & OS Info
      // -----------------------------------------------------------------------
      sb.writeln('-' * 80);
      sb.writeln('2. DEVICE & OPERATING SYSTEM INFORMATION');
      sb.writeln('-' * 80);
      try {
        final deviceInfo = DeviceInfoPlugin();
        if (kIsWeb) {
          final webInfo = await deviceInfo.webBrowserInfo;
          sb.writeln('Platform:           Web');
          sb.writeln('Browser:            ${webInfo.browserName.name}');
          sb.writeln('Platform Name:      ${webInfo.platform}');
          sb.writeln('User Agent:         ${webInfo.userAgent}');
          sb.writeln('Language:           ${webInfo.language}');
          sb.writeln('Hardware Concurrency: ${webInfo.hardwareConcurrency}');
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          sb.writeln('Platform:           iOS');
          sb.writeln('Device Name:        ${iosInfo.name}');
          sb.writeln('System Name:        ${iosInfo.systemName}');
          sb.writeln('System Version:     ${iosInfo.systemVersion}');
          sb.writeln('Model:              ${iosInfo.model}');
          sb.writeln('Localized Model:    ${iosInfo.localizedModel}');
          sb.writeln('Machine (Identifier): ${iosInfo.utsname.machine}');
          sb.writeln('Release:            ${iosInfo.utsname.release}');
          sb.writeln('Sysname:            ${iosInfo.utsname.sysname}');
          sb.writeln('Nodename:           ${iosInfo.utsname.nodename}');
          sb.writeln('Version:            ${iosInfo.utsname.version}');
          sb.writeln('Vendor Identifier:  ${iosInfo.identifierForVendor ?? "N/A"}');
          sb.writeln('Is Physical Device: ${iosInfo.isPhysicalDevice}');
        } else if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          sb.writeln('Platform:           Android');
          sb.writeln('Brand:              ${androidInfo.brand}');
          sb.writeln('Manufacturer:       ${androidInfo.manufacturer}');
          sb.writeln('Model:              ${androidInfo.model}');
          sb.writeln('Device:             ${androidInfo.device}');
          sb.writeln('Product:            ${androidInfo.product}');
          sb.writeln('Hardware:           ${androidInfo.hardware}');
          sb.writeln('Board:              ${androidInfo.board}');
          sb.writeln('Android Release:    ${androidInfo.version.release}');
          sb.writeln('SDK Int / API:      ${androidInfo.version.sdkInt}');
          sb.writeln('Security Patch:     ${androidInfo.version.securityPatch ?? "N/A"}');
          sb.writeln('Incremental:        ${androidInfo.version.incremental}');
          sb.writeln('Display:            ${androidInfo.display}');
          sb.writeln('Build ID:           ${androidInfo.id}');
          sb.writeln('Fingerprint:        ${androidInfo.fingerprint}');
          sb.writeln('Supported ABIs:     ${androidInfo.supportedAbis.join(", ")}');
          sb.writeln('Is Physical Device: ${androidInfo.isPhysicalDevice}');
          sb.writeln('Host / Type:        ${androidInfo.host} / ${androidInfo.type}');
        } else {
          sb.writeln('Platform:           ${Platform.operatingSystem}');
          sb.writeln('OS Version:         ${Platform.operatingSystemVersion}');
        }
      } catch (e) {
        sb.writeln('Error reading DeviceInfo: $e');
      }
      sb.writeln();

      // -----------------------------------------------------------------------
      // 3. Runtime & Screen Environment
      // -----------------------------------------------------------------------
      sb.writeln('-' * 80);
      sb.writeln('3. RUNTIME & SCREEN ENVIRONMENT');
      sb.writeln('-' * 80);
      sb.writeln('Build Mode:         ${kDebugMode ? "Debug" : kProfileMode ? "Profile" : "Release"}');
      sb.writeln('Operating System:   ${Platform.operatingSystem} (${Platform.operatingSystemVersion})');
      sb.writeln('Dart Version:       ${Platform.version}');
      sb.writeln('System Locale:      ${Platform.localeName}');
      sb.writeln('Processors:         ${Platform.numberOfProcessors}');

      if (context.mounted) {
        final media = MediaQuery.of(context);
        sb.writeln('Screen Size:        ${media.size.width.toStringAsFixed(1)} x ${media.size.height.toStringAsFixed(1)}');
        sb.writeln('Device Pixel Ratio: ${media.devicePixelRatio}');
        sb.writeln('Orientation:        ${media.orientation.name}');
        sb.writeln('Text Scale Factor:  ${media.textScaler.scale(1.0)}');
      }

      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        sb.writeln('Connectivity:       $connectivityResult');
      } catch (e) {
        sb.writeln('Connectivity Check: Error ($e)');
      }
      sb.writeln();

      // -----------------------------------------------------------------------
      // 4. Firebase & Auth State
      // -----------------------------------------------------------------------
      sb.writeln('-' * 80);
      sb.writeln('4. FIREBASE & AUTHENTICATION STATE');
      sb.writeln('-' * 80);
      try {
        sb.writeln('Firebase Initialized: ${Firebase.apps.isNotEmpty}');
        if (Firebase.apps.isNotEmpty) {
          sb.writeln('Firebase App Name:    ${Firebase.app().name}');
          sb.writeln('Firebase Project ID:  ${Firebase.app().options.projectId}');
        }

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          sb.writeln('Firebase User ID:     ${currentUser.uid}');
          sb.writeln('Firebase User Email:  ${currentUser.email ?? "None"}');
          sb.writeln('Firebase DisplayName: ${currentUser.displayName ?? "None"}');
          sb.writeln('Firebase Phone:       ${currentUser.phoneNumber ?? "None"}');
          sb.writeln('Firebase Is Anonymous:${currentUser.isAnonymous}');
          sb.writeln('Providers:            ${currentUser.providerData.map((p) => "${p.providerId} (${p.email ?? p.phoneNumber ?? "no id"})").join(", ")}');
        } else {
          sb.writeln('Firebase User:        No Active Firebase User');
        }

        sb.writeln('Hive Is Authenticated: ${HiveUtils.isUserAuthenticated()}');
        sb.writeln('Hive User ID:          ${HiveUtils.getUserId() ?? "None"}');
        try {
          final userDetails = HiveUtils.getUserDetails();
          sb.writeln('Hive User Name:        ${userDetails.name ?? "None"}');
          sb.writeln('Hive User Email:       ${userDetails.email ?? "None"}');
        } catch (_) {
          sb.writeln('Hive User Details:     Unable to read / Not set');
        }
        sb.writeln('Hive JWT Exists:       ${HiveUtils.getJWT() != null}');
      } catch (e) {
        sb.writeln('Error reading Firebase/Auth state: $e');
      }
      sb.writeln();

      // -----------------------------------------------------------------------
      // 5. Apple Auth Attempt History & Failure Dumps
      // -----------------------------------------------------------------------
      sb.writeln('-' * 80);
      sb.writeln('5. APPLE AUTHENTICATION ATTEMPTS & FAILURE DIAGNOSTICS');
      sb.writeln('-' * 80);
      final appleAttempts = AppleAuthTracker.history;
      if (appleAttempts.isEmpty) {
        sb.writeln('No in-memory Apple authentication attempts in this session.');
      } else {
        for (final att in appleAttempts) {
          sb.writeln('Attempt ID:    ${att.attemptId}');
          sb.writeln('Created At:    ${att.createdAt.toIso8601String()}');
          sb.writeln('Finished At:   ${att.finishedAt?.toIso8601String() ?? "In progress"}');
          sb.writeln('Status:        ${att.status.toUpperCase()}');
          if (att.failedStage != null) {
            sb.writeln('Failed Stage:  ${att.failedStage}');
          }
          if (att.error != null) {
            sb.writeln('Error:         ${const JsonEncoder.withIndent("  ").convert(att.error)}');
          }
          sb.writeln('Steps Timeline:');
          for (final step in att.steps) {
            final detailsStr = step.details != null ? ' => ${step.details}' : '';
            sb.writeln('  [${step.elapsedMs}ms] ${step.name} (${step.at.toIso8601String()})$detailsStr');
          }
          sb.writeln();
        }
      }

      // Check on-disk failure dumps in temporary directory
      try {
        final tempDir = await getTemporaryDirectory();
        final dumpFiles = tempDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.contains('ebozor_apple_auth_'))
            .toList();

        if (dumpFiles.isNotEmpty) {
          sb.writeln('Discovered ${dumpFiles.length} saved Apple Auth dump file(s) on disk:');
          for (final dumpFile in dumpFiles) {
            sb.writeln('--- File: ${dumpFile.path.split(Platform.pathSeparator).last} ---');
            try {
              final content = await dumpFile.readAsString();
              sb.writeln(content);
            } catch (err) {
              sb.writeln('Error reading dump file: $err');
            }
            sb.writeln('--- End File ---');
          }
        }
      } catch (e) {
        sb.writeln('Could not scan for on-disk Apple auth dumps: $e');
      }
      sb.writeln();

      // -----------------------------------------------------------------------
      // 6. Recorded Application Logs
      // -----------------------------------------------------------------------
      sb.writeln('-' * 80);
      sb.writeln('6. RECORDED APPLICATION LOGS');
      sb.writeln('-' * 80);
      final logs = AppLog.getRecentLogs();
      if (logs.isEmpty) {
        sb.writeln('No logs recorded in this session.');
      } else {
        for (final entry in logs) {
          sb.writeln(entry.toString());
        }
      }
      sb.writeln();
      sb.writeln('=' * 80);
      sb.writeln('                          END OF DIAGNOSTIC REPORT');
      sb.writeln('=' * 80);

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final timestampStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final logFilePath = '${tempDir.path}/ebozor_device_logs_$timestampStr.txt';
      final logFile = File(logFilePath);
      await logFile.writeAsString(sb.toString(), flush: true);

      AppLog.i('Log file created at: $logFilePath', name: 'LogExporter');

      // Share file
      final mediaQuery = context.mounted ? MediaQuery.maybeOf(context) : null;
      final size = mediaQuery?.size ?? const Size(400, 600);

      await Share.shareXFiles(
        [
          XFile(
            logFilePath,
            mimeType: 'text/plain',
            name: 'ebozor_device_logs_$timestampStr.txt',
          ),
        ],
        subject: 'Ebozor Device & Diagnostic Logs',
        text: 'Ebozor Diagnostic Report ($timestampStr)',
        sharePositionOrigin: Rect.fromLTWH(0, 0, size.width, size.height / 2),
      );
    } catch (e, stack) {
      AppLog.e('Failed to export logs: $e', error: e, stackTrace: stack, name: 'LogExporter');
      if (context.mounted) {
        HelperUtils.showSnackBarMessage(
          context,
          'Failed to export logs: $e',
        );
      }
    } finally {
      _isExporting = false;
    }
  }
}
