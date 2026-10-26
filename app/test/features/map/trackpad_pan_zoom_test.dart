import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:house_booking/features/map/widgets/trackpad_pan_zoom.dart';

/// Chụm hai ngón trên touchpad.
///
/// flutter_map 7.0.2 chỉ nghe PointerScrollEvent (con lăn chuột) nên cử chỉ
/// chụm của touchpad — Flutter web gửi tới dưới dạng PointerPanZoom — rơi vào
/// hư không. Test khoá lại đúng chỗ đó: tỉ lệ của sự kiện là TÍCH LUỸ từ đầu
/// cử chỉ, cộng dồn thẳng sẽ làm zoom vọt theo cấp số nhân.
void main() {
  // ── Kéo bản đồ ────────────────────────────────────────────────────────────

  Future<MapController> _dungMap(WidgetTester tester) async {
    final ctrl = MapController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackpadPanZoom(
            controller: ctrl,
            child: FlutterMap(
              mapController: ctrl,
              options: const MapOptions(
                initialCenter: LatLng(10.7769, 106.7009),
                initialZoom: 12,
                minZoom: 4,
                maxZoom: 18,
                interactionOptions:
                    InteractionOptions(flags: kMapInteractiveFlags),
              ),
              children: const [],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return ctrl;
  }

  testWidgets('chụm RA hai lần tỉ lệ → tăng đúng MỘT mức zoom', (tester) async {
    final ctrl = await _dungMap(tester);
    final z0 = ctrl.camera.zoom;

    final c = tester.getCenter(find.byType(FlutterMap));
    final g = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await g.panZoomStart(c);
    await g.panZoomUpdate(c, scale: 2.0);
    await g.panZoomEnd();
    await tester.pump();

    expect(ctrl.camera.zoom, closeTo(z0 + 1, 0.01));
  });

  testWidgets('tỉ lệ tích luỹ KHÔNG bị cộng dồn hai lần', (tester) async {
    final ctrl = await _dungMap(tester);
    final z0 = ctrl.camera.zoom;

    final c = tester.getCenter(find.byType(FlutterMap));
    final g = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await g.panZoomStart(c);
    // Hai bước trong CÙNG một cử chỉ: 2.0 rồi 4.0 (tích luỹ) = tổng 2 mức zoom,
    // không phải 1 + 2 = 3.
    await g.panZoomUpdate(c, scale: 2.0);
    await g.panZoomUpdate(c, scale: 4.0);
    await g.panZoomEnd();
    await tester.pump();

    expect(ctrl.camera.zoom, closeTo(z0 + 2, 0.01));
  });

  testWidgets('không vượt quá maxZoom', (tester) async {
    final ctrl = await _dungMap(tester);

    final c = tester.getCenter(find.byType(FlutterMap));
    final g = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await g.panZoomStart(c);
    await g.panZoomUpdate(c, scale: 1000.0);
    await g.panZoomEnd();
    await tester.pump();

    expect(ctrl.camera.zoom, lessThanOrEqualTo(18.0));
  });

  testWidgets('cuộn hai ngón TOUCHPAD thì KÉO bản đồ, không phóng to',
      (tester) async {
    final ctrl = await _dungMap(tester);
    final z0 = ctrl.camera.zoom;
    final tam0 = ctrl.camera.center;

    final c = tester.getCenter(find.byType(FlutterMap));
    final g = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await g.addPointer(location: c);
    // Sự kiện cuộn từ touchpad — Flutter web gán kind=trackpad.
    tester.binding.handlePointerEvent(PointerScrollEvent(
      position: c,
      scrollDelta: const Offset(0, 80),
      kind: PointerDeviceKind.trackpad,
    ));
    await tester.pumpAndSettle();

    expect(ctrl.camera.zoom, z0, reason: 'touchpad cuộn KHÔNG được đổi zoom');
    expect(ctrl.camera.center, isNot(tam0), reason: 'phải kéo được bản đồ');
  });

  testWidgets('lăn CHUỘT vẫn phóng to như cũ', (tester) async {
    final ctrl = await _dungMap(tester);
    final z0 = ctrl.camera.zoom;

    final c = tester.getCenter(find.byType(FlutterMap));
    tester.binding.handlePointerEvent(PointerScrollEvent(
      position: c,
      scrollDelta: const Offset(0, -100),
      kind: PointerDeviceKind.mouse,
    ));
    await tester.pumpAndSettle();

    expect(ctrl.camera.zoom, greaterThan(z0));
  });
}
