import 'dart:async';

class Debouncer {
  final Duration duration;
  Timer? _timer;

  Debouncer(this.duration);

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

extension DurationX on Duration {
  String get formattedMS {
    if (inMilliseconds < 1000) {
      return '${inMilliseconds}ms';
    }
    return '${(inMilliseconds / 1000).toStringAsFixed(2)}s';
  }
}
