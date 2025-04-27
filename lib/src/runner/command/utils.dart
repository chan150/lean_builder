import 'dart:async';

class AsyncDebouncer {
  final Duration duration;
  Timer? _timer;

  AsyncDebouncer(this.duration);

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
