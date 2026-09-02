import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

/// Representation of an in-memory log entry.
class LogEntry {
  final DateTime timestamp;
  final String level;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  @override
  String toString() {
    final timeStr = timestamp.toIso8601String();
    final errStr = error != null ? '\n  Error: $error' : '';
    final stackStr = stackTrace != null ? '\n  StackTrace: $stackTrace' : '';
    return '[$timeStr] [$level] [$tag] $message$errStr$stackStr';
  }
}

/// Centralised logging utility.
///
/// Records logs in an in-memory buffer for diagnostics/export and logs to DevTools in debug mode.
class AppLog {
  AppLog._();

  static const int _maxBufferSize = 1000;
  static final List<LogEntry> _logBuffer = [];

  static void _addEntry(LogEntry entry) {
    if (_logBuffer.length >= _maxBufferSize) {
      _logBuffer.removeAt(0);
    }
    _logBuffer.add(entry);
  }

  /// Returns a snapshot copy of all recorded log entries.
  static List<LogEntry> getRecentLogs() {
    return List.unmodifiable(_logBuffer);
  }

  /// Returns recent logs formatted as a plain-text block.
  static String getFormattedLogs() {
    if (_logBuffer.isEmpty) return 'No logs recorded.';
    return _logBuffer.map((e) => e.toString()).join('\n');
  }

  /// Clears the recorded in-memory logs.
  static void clearLogs() {
    _logBuffer.clear();
  }

  /// Info-level log.
  static void i(String message, {String name = 'App'}) {
    _addEntry(LogEntry(
      timestamp: DateTime.now(),
      level: 'INFO',
      tag: name,
      message: message,
    ));

    if (kDebugMode) {
      dev.log(message, name: name);
    }
  }

  /// Warning-level log – prefixed with ⚠️.
  static void w(String message, {String name = 'App'}) {
    _addEntry(LogEntry(
      timestamp: DateTime.now(),
      level: 'WARN',
      tag: name,
      message: message,
    ));

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
    _addEntry(LogEntry(
      timestamp: DateTime.now(),
      level: 'ERROR',
      tag: name,
      message: message,
      error: error,
      stackTrace: stackTrace,
    ));

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

  /// Prints long strings in ≤800-char chunks.
  static void long(String text, {String name = 'App'}) {
    _addEntry(LogEntry(
      timestamp: DateTime.now(),
      level: 'DEBUG',
      tag: name,
      message: text,
    ));

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
