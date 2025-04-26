import 'package:ansicolor/ansicolor.dart';

class Logger {
  static final Logger _instance = Logger._internal();

  factory Logger() {
    return _instance;
  }

  Logger._internal();

  static LogLevel _currentLevel = LogLevel.fine;

  static set level(LogLevel newLevel) {
    _currentLevel = newLevel;
  }

  void log(LogLevel level, String message) {
    if (level.index >= _currentLevel.index) {
      final pen = _getLevelPen(level);
      print('${pen('[${level.name.toUpperCase()}]')} $message');
    }
  }

  static void fine(String message) {
    _instance.log(LogLevel.fine, message);
  }

  static void info(String message) {
    _instance.log(LogLevel.info, message);
  }

  static void warning(String message) {
    _instance.log(LogLevel.warning, message);
  }

  static void error(String message, {StackTrace? stackTrace}) {
    _instance.log(LogLevel.error, '$message\n$stackTrace');
  }

  static void debug(String message) {
    _instance.log(LogLevel.debug, message);
  }

  static void success(String message) {
    _instance.log(LogLevel.success, message);
  }

  AnsiPen _getLevelPen(LogLevel level) {
    switch (level) {
      case LogLevel.fine:
        return AnsiPen()..white(bold: true);
      case LogLevel.success:
        return AnsiPen()..rgb(r: 0.11, g: 0.69, b: 0.38);
      case LogLevel.debug:
        return AnsiPen()..rgb(r: 0.463, g: 0.557, b: 0.6);
      case LogLevel.info:
        return AnsiPen()..rgb(r: 0.067, g: 0.612, b: 0.6);
      case LogLevel.warning:
        return AnsiPen()..rgb(r: 0.612, g: 0.439, b: 0.067);
      case LogLevel.error:
        return AnsiPen()..rgb(r: 0.678, g: 0.216, b: 0.216);
    }
  }
}

enum LogLevel { fine, debug, info, success, warning, error }
