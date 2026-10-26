import 'package:flutter/material.dart';

import 'package:house_booking/core/telemetry/error_reporter.dart';
import '_deferred_reload_io.dart'
    if (dart.library.html) '_deferred_reload_web.dart'
    as reloader;

/// Wrap một route đằng sau `deferred as` import.
///
/// Trên Flutter Web, build tooling tự tách chunk JS riêng cho mỗi `deferred as`
/// → chunk đó chỉ được tải khi `loadLibrary()` chạy. Pattern này giảm bundle
/// JS lần đầu (initial paint) — `flutter_map`, `vector_map_tiles`,
/// `image_cropper`… sẽ không kéo theo cho user chỉ xem trang chủ.
///
/// Trên mobile (iOS/Android), `loadLibrary()` resolve ngay vì toàn bộ code
/// đã được compile cùng app bundle → không có cost runtime, chỉ là no-op.
class DeferredRouteWidget extends StatefulWidget {
  const DeferredRouteWidget({
    super.key,
    required this.loadLibrary,
    required this.builder,
    this.placeholder,
    this.errorBuilder,
  });

  /// Future hoàn tất khi chunk đã sẵn sàng (thường wrap `someLib.loadLibrary()`).
  final Future<void> Function() loadLibrary;

  /// Builder chỉ được gọi sau khi `loadLibrary` hoàn tất.
  /// Mọi reference tới symbol của deferred lib PHẢI nằm trong builder này —
  /// nếu đặt trên class field hoặc property của widget cha sẽ crash runtime.
  final WidgetBuilder builder;

  /// Placeholder hiển thị trong lúc tải chunk. Default là CircularProgressIndicator.
  final WidgetBuilder? placeholder;

  /// Builder cho trường hợp tải chunk thất bại (network lỗi…).
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  @override
  State<DeferredRouteWidget> createState() => _DeferredRouteWidgetState();
}

class _DeferredRouteWidgetState extends State<DeferredRouteWidget> {
  late final Future<void> _future = widget.loadLibrary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return widget.placeholder?.call(ctx) ??
              const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return _DeferredErrorView(
            error: snap.error!,
            stack: snap.stackTrace,
            customBuilder: widget.errorBuilder,
          );
        }
        return widget.builder(ctx);
      },
    );
  }
}

/// Xử lý lỗi tải chunk deferred. Nếu là DeferredLoadException (version-skew sau
/// deploy trên web) → tự reload 1 lần để nạp bản mới; nếu vẫn lỗi → nút thủ công.
/// Mọi lỗi đều được report về pipeline (đây là lỗi ĐƯỢC XỬ LÝ nên không đi qua
/// FlutterError.onError — phải report tại đây).
class _DeferredErrorView extends StatefulWidget {
  const _DeferredErrorView({
    required this.error,
    required this.stack,
    this.customBuilder,
  });

  final Object error;
  final StackTrace? stack;
  final Widget Function(BuildContext, Object)? customBuilder;

  @override
  State<_DeferredErrorView> createState() => _DeferredErrorViewState();
}

class _DeferredErrorViewState extends State<_DeferredErrorView> {
  bool _reloading = false;

  bool get _isDeferred {
    final s = widget.error.toString();
    return s.contains('DeferredLoadException') || s.contains('.part.js');
  }

  @override
  void initState() {
    super.initState();
    // Report về pipeline self-heal (đã redact ở backend).
    ErrorReporter.report(
      widget.error,
      widget.stack,
      route: 'deferred_load',
      context: {'kind': _isDeferred ? 'deferred_load' : 'route_load'},
    );
    // Version-skew: tự reload 1 lần (guard chống loop qua sessionStorage).
    if (_isDeferred && reloader.shouldAutoReload()) {
      _reloading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => reloader.reloadApp());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.customBuilder != null) {
      return widget.customBuilder!(context, widget.error);
    }
    if (_reloading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang cập nhật phiên bản mới…'),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Không tải được trang. Có thể do phiên bản cũ trong bộ nhớ đệm.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: reloader.reloadApp,
                icon: const Icon(Icons.refresh),
                label: const Text('Tải lại ứng dụng'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
