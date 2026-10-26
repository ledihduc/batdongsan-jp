import 'dart:async';

/// Debouncer 300ms cho ô tìm kiếm — tránh gửi API mỗi phím bấm.
class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 300)});

  final Duration delay;
  Timer? _timer;

  /// Gọi [action] sau [delay] kể từ lần gọi [run] cuối cùng.
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Hủy timer đang chờ (gọi khi widget dispose).
  void dispose() {
    _timer?.cancel();
  }
}
