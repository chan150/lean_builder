import 'dart:async' show FutureOr, Timer;

/// {@template debouncer}
/// A utility class that debounces function calls.
///
/// This class is useful for delaying an operation until a certain amount of time
/// has passed since the last invocation. This is particularly helpful when
/// handling events that might fire in rapid succession (like file system changes),
/// but you only want to respond once after the activity has settled.
///
/// Example usage:
/// ```dart
/// final debouncer = Debouncer(Duration(milliseconds: 300));
///
/// void handleFileChange() {
///   debouncer.run(() {
///     // This will only execute 300ms after the last call to handleFileChange
///     rebuildProject();
///   });
/// }
/// ```
/// {@endtemplate}
class Debouncer {
  /// The duration of the debounce period
  final Duration duration;

  /// The timer that tracks the debounce period
  Timer? _timer;

  /// {@macro debouncer}
  Debouncer(this.duration);

  /// Runs the given action after the debounce period has elapsed.
  ///
  /// If this method is called again before the period elapses,
  /// the previous pending action is canceled and a new period begins.
  ///
  /// [action] The function to execute after the debounce period
  void run(FutureOr<void> Function() action) {
    cancel();
    _timer = Timer(duration, () async {
      await action();
      _timer = null;
    });
  }

  /// Cancels any pending operation without executing it
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Whether there's a pending operation
  bool get isActive => _timer != null && _timer!.isActive;
}

/// {@template duration_x}
/// Extension methods for [Duration] to provide additional functionality.
/// {@endtemplate}
extension DurationX on Duration {
  /// {@template duration_x.formatted_ms}
  /// Returns a human-readable string representation of the duration.
  ///
  /// For durations less than 1 second, returns the value in milliseconds (e.g., "450ms").
  /// For durations of 1 second or more, returns the value in seconds with 2 decimal places (e.g., "1.50s").
  /// {@endtemplate}
  String get formattedMS {
    if (inMilliseconds < 1000) {
      return '${inMilliseconds}ms';
    }
    return '${(inMilliseconds / 1000).toStringAsFixed(2)}s';
  }
}
