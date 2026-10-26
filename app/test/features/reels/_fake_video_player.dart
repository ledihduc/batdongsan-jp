import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Nền tảng video_player giả — cho phép widget test dựng được VideoPlayerController.
///
/// Vì sao cần: `video_player` nói chuyện với nền tảng qua platform channel. Trong
/// widget test không có nền tảng thật, nên `controller.initialize()` treo hoặc ném
/// MissingPluginException, và MỌI test chạm tới trình phát reel sẽ hỏng.
///
/// Bản giả này báo "khởi tạo xong" ngay lập tức với kích thước dọc 9:16.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  FakeVideoPlayerPlatform({
    this.size = const Size(720, 1280),
    this.duration = const Duration(seconds: 10),
    this.failInit = false,
  });

  final Size size;
  final Duration duration;

  /// Bật để mô phỏng video hỏng — kiểm nhánh "Không phát được video này".
  final bool failInit;

  /// Nhật ký để test khẳng định hành vi (đã gọi play/pause chưa…).
  final List<String> calls = [];

  int _nextId = 1;
  final Map<int, StreamController<VideoEvent>> _events = {};

  static FakeVideoPlayerPlatform install({
    bool failInit = false,
    Size size = const Size(720, 1280),
  }) {
    final p = FakeVideoPlayerPlatform(failInit: failInit, size: size);
    VideoPlayerPlatform.instance = p;
    return p;
  }

  @override
  Future<void> init() async => calls.add('init');

  @override
  Future<int?> create(DataSource dataSource) async {
    calls.add('create:${dataSource.uri}');
    if (failInit) throw PlatformException(code: 'VideoError', message: 'hỏng');
    final id = _nextId++;
    // `onListen` chứ KHÔNG phải Future.microtask: controller đăng ký lắng nghe
    // SAU khi create() trả về, mà broadcast stream vứt bỏ sự kiện phát ra lúc
    // chưa có người nghe → initialize() treo mãi và mọi test dính video hỏng.
    late final StreamController<VideoEvent> c;
    c = StreamController<VideoEvent>.broadcast(onListen: () {
      c.add(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: duration,
        size: size,
        rotationCorrection: 0,
      ));
    });
    _events[id] = c;
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) =>
      _events[textureId]?.stream ?? const Stream.empty();

  @override
  Future<void> dispose(int textureId) async {
    calls.add('dispose:$textureId');
    await _events.remove(textureId)?.close();
  }

  @override
  Future<void> play(int textureId) async => calls.add('play:$textureId');

  @override
  Future<void> pause(int textureId) async => calls.add('pause:$textureId');

  @override
  Future<void> setLooping(int textureId, bool looping) async =>
      calls.add('setLooping:$looping');

  @override
  Future<void> setVolume(int textureId, double volume) async =>
      calls.add('setVolume:$volume');

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {}

  @override
  Future<void> seekTo(int textureId, Duration position) async =>
      calls.add('seekTo:${position.inMilliseconds}');

  @override
  Future<Duration> getPosition(int textureId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildView(int textureId) => const SizedBox.shrink();

  // ── Trợ giúp cho test ──────────────────────────────────────────────────────
  bool get didPlay => calls.any((c) => c.startsWith('play:'));
  bool get didPause => calls.any((c) => c.startsWith('pause:'));
  int get createdCount => calls.where((c) => c.startsWith('create:')).length;

  /// Âm lượng cuối cùng được đặt — 0 nghĩa là đang tắt tiếng.
  double? get lastVolume {
    final v = calls.where((c) => c.startsWith('setVolume:')).lastOrNull;
    return v == null ? null : double.tryParse(v.split(':')[1]);
  }
}
