import 'dart:io' show stdout;

class Logger {
  // Private constructor prevents instantiation
  Logger._();

  // ANSI color codes
  static const String _reset = '\x1B[0m';
  static const String _red = '\x1B[31m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _blue = '\x1B[34m';
  static const String _cyan = '\x1B[36m';

  static void log(String message, {String color = ''}) {
    stdout.write('$color$message$_reset\n');
  }

  static void error(String message) {
    log(message, color: _red);
  }

  static void success(String message) {
    log(message, color: _green);
  }

  static void warning(String message) {
    log(message, color: _yellow);
  }

  static void info(String message) {
    log(message, color: _blue);
  }

  static void debug(String message) {
    log(message, color: _cyan);
  }

  static void severe(String message, [Object? error, StackTrace? stackTrace]) {
    final details = [if (error != null) 'Error: $error', if (stackTrace != null) 'StackTrace: $stackTrace'].join('\n');

    log('$message${details.isEmpty ? '' : '\n$details'}', color: _red);
  }
}
