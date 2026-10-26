import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Tốc độ zoom theo con lăn chuột — giữ đúng mặc định của flutter_map để cảm
/// giác không đổi so với trước.
const double kScrollWheelVelocity = 0.005;

/// Cờ tương tác dành cho [FlutterMap] khi dùng kèm [TrackpadPanZoom]: giống
/// mặc định nhưng TẮT zoom-bằng-con-lăn, vì lớp bọc tự xử lý mọi sự kiện cuộn.
/// Không tắt thì flutter_map giành xử lý trước (nó đăng ký với
/// `pointerSignalResolver` ở lớp trong nên luôn thắng).
const int kMapInteractiveFlags =
    InteractiveFlag.all & ~InteractiveFlag.scrollWheelZoom;

/// Cho bản đồ dùng được bằng TOUCHPAD trên web.
///
/// flutter_map 7.0.2 quy MỌI sự kiện cuộn về ZOOM. Trên laptop, cuộn hai ngón
/// là cách tự nhiên để KÉO bản đồ đi chỗ khác — nên người dùng touchpad không
/// di chuyển được bản đồ, cứ cuộn là nó phóng to.
///
/// May là Flutter web đã tự phân biệt nguồn sự kiện: cuộn từ touchpad tới với
/// `PointerDeviceKind.trackpad`, cuộn từ con lăn chuột tới với `mouse`. Nhờ vậy
/// không phải đoán theo ngưỡng độ lớn của delta — thứ khác nhau theo từng
/// trình duyệt và hệ điều hành. Quy ước cuối cùng, giống Google Maps:
///
/// | Cử chỉ                | Hành vi   |
/// |-----------------------|-----------|
/// | Cuộn hai ngón touchpad| kéo bản đồ|
/// | Chụm hai ngón         | phóng to  |
/// | Lăn chuột             | phóng to  |
/// | Kéo giữ chuột/1 ngón  | kéo bản đồ|
class TrackpadPanZoom extends StatefulWidget {
  const TrackpadPanZoom({
    required this.controller,
    required this.child,
    this.minZoom = 4,
    this.maxZoom = 18,
    super.key,
  });

  final MapController controller;
  final Widget child;
  final double minZoom;
  final double maxZoom;

  @override
  State<TrackpadPanZoom> createState() => _TrackpadPanZoomState();
}

class _TrackpadPanZoomState extends State<TrackpadPanZoom> {
  /// Tỉ lệ của cử chỉ chụm ở khung hình trước, để tính phần TĂNG THÊM. Sự kiện
  /// mang tỉ lệ tích luỹ từ đầu cử chỉ; cộng dồn thẳng sẽ zoom theo cấp số nhân.
  double _scaleTruoc = 1;

  void _zoomQuanh(Offset viTri, double zoomMoi) {
    final cam = widget.controller.camera;
    final z = zoomMoi.clamp(widget.minZoom, widget.maxZoom);
    if ((z - cam.zoom).abs() < 0.0001) return;
    // Zoom quanh CON TRỎ (không phải tâm màn hình) — đúng cách flutter_map xử
    // lý con lăn chuột; zoom quanh tâm làm chỗ đang xem trôi đi.
    widget.controller.move(cam.focusedZoomCenter(viTri.toPoint(), z), z);
  }

  void _keo(Offset delta) {
    if (delta == Offset.zero) return;
    final cam = widget.controller.camera;
    // Cuộn xuống = xem phần bản đồ phía dưới = tâm đi xuống → cộng delta.
    final diem = cam.project(cam.center) + delta.toPoint().rotate(cam.rotationRad);
    widget.controller.move(cam.unproject(diem), cam.zoom);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (e) {
        if (e is PointerScrollEvent) {
          if (e.kind == PointerDeviceKind.trackpad) {
            _keo(e.scrollDelta);
          } else {
            final cam = widget.controller.camera;
            _zoomQuanh(
              e.localPosition,
              cam.zoom - e.scrollDelta.dy * kScrollWheelVelocity,
            );
          }
        } else if (e is PointerScaleEvent && e.scale != 1.0) {
          // Chụm hai ngón: trình duyệt gửi ctrl+wheel, Flutter đổi thành scale.
          final cam = widget.controller.camera;
          // log2 vì thang zoom của bản đồ là log cơ số 2 — nhân đôi tỉ lệ đúng
          // bằng một mức zoom.
          _zoomQuanh(
            e.localPosition,
            cam.zoom + math.log(e.scale) / math.ln2,
          );
        }
      },
      // Cử chỉ pan-zoom của touchpad trên desktop (macOS) — mang cả kéo lẫn chụm.
      onPointerPanZoomStart: (_) => _scaleTruoc = 1,
      onPointerPanZoomUpdate: (e) {
        if (e.panDelta != Offset.zero) _keo(-e.panDelta);
        if (e.scale != _scaleTruoc) {
          final cam = widget.controller.camera;
          final buoc = math.log(e.scale / _scaleTruoc) / math.ln2;
          _scaleTruoc = e.scale;
          if (buoc != 0) _zoomQuanh(e.localPosition, cam.zoom + buoc);
        }
      },
      onPointerPanZoomEnd: (_) => _scaleTruoc = 1,
      child: widget.child,
    );
  }
}
