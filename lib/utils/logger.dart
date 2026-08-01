import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

/// Centralised logging utility.
///
/// All methods are no-ops in **release** builds (`kDebugMode == false`),
/// so sensitive values (tokens, phone numbers, API keys) are never leaked.
///
/// Usage:
///   AppLog.i('Loaded user', name: 'ProfileScreen');
///   AppLog.e('Firebase error', error: e, name: 'PhoneLogin');
class AppLog {
  AppLog._();

  /// Info-level log (white/default colour in DevTools).
  static void i(String message, {String name = 'App'}) {
    if (kDebugMode) {
      dev.log(message, name: name);
    }
  }

  /// Warning-level log – prefixed with ⚠️.
  static void w(String message, {String name = 'App'}) {
    if (kDebugMode) {
      dev.log('⚠️ $message', name: name);
    }
  }

  /// Error-level log – prefixed with 🔴, includes optional error + stack.
  static void e(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String name = 'App',
  }) {
    if (kDebugMode) {
      dev.log(
        '🔴 $message',
        name: name,
        error: error,
        stackTrace: stackTrace,
        level: 1000, // SEVERE
      );
    }
  }

  /// Prints long strings in ≤800-char chunks (avoids Android logcat truncation).
  static void long(String text, {String name = 'App'}) {
    if (kDebugMode) {
      const chunkSize = 800;
      for (var i = 0; i < text.length; i += chunkSize) {
        final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
        dev.log(text.substring(i, end), name: name);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Legacy helpers kept for backward-compat; will be removed after migration.
// ---------------------------------------------------------------------------

/// @deprecated Use [AppLog] instead.
class Logger {
  static void error(dynamic error, {String? name = 'LOG'}) {
    AppLog.e(error.toString(), name: name ?? 'LOG');
  }

  static void impornant(dynamic value, {String? name}) {
    AppLog.w(value.toString(), name: name ?? 'LOG');
  }

  static void throwTestError() {
    throw 'Test Exception';
  }
}
