import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/short_stay_api.dart';
import 'package:house_booking/features/host/short_stay/hop_thoai_gia_ngan_han.dart';

import '../../../helpers/pump_app.dart';

/// Ba mức giá lưu trú ngắn hạn — màn CHỦ NHÀ khai giá.
///
/// `PUT /api/host/short-stays/rooms/{id}/rates` đã có từ lúc dựng tính năng
/// nhưng **không nơi nào trong app gọi tới**. Đo trên staging: 10 phòng đã bật
/// kênh ngắn hạn mà `/api/short-stays/rooms` trả về RỖNG — tìm kiếm chỉ bày
/// phòng đã khai ít nhất một trong ba giá, và chủ nhà không có cách nào khai.
///
/// Điều phải giữ: **bỏ trống một hình thức = không bán hình thức đó**, và bỏ
/// trống CẢ BA thì chặn ngay tại chỗ kèm lý do — chứ không để phòng lặng lẽ
/// biến mất khỏi tìm kiếm.
class _ApiGia extends ShortStayApi {
  const _ApiGia(this._ghi);

  final List<Map<String, dynamic>> _ghi;

  @override
  Future<void> rates(int id, Map<String, dynamic> rates) async {
    _ghi.add({'room_id': id, ...rates});
  }
}

Future<List<Map<String, dynamic>>> _dung(
  WidgetTester t, {
  Map<String, dynamic> banDau = const {},
}) async {
  final ghi = <Map<String, dynamic>>[];
  t.view.physicalSize = const Size(900, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await pumpApp(
    t,
    HopThoaiGiaNganHan(roomId: 27, api: _ApiGia(ghi), banDau: banDau),
  );
  await t.pumpAndSettle();
  return ghi;
}

Future<void> _dien(WidgetTester t, String nhan, String gia) async {
  await t.enterText(find.widgetWithText(TextField, nhan).first, gia);
  await t.pump();
}

void main() {
  testWidgets('bày đủ ba hình thức, kèm luật lưu trú của từng cái', (t) async {
    await _dung(t);
    expect(find.text('Theo giờ (đ/giờ)'), findsOneWidget);
    expect(find.text('Thuê 1–24 giờ nguyên'), findsOneWidget);
    expect(find.text('Qua đêm (đ/đêm)'), findsOneWidget);
    expect(find.text('21:00 – 09:00 hôm sau'), findsOneWidget);
    expect(find.text('Theo ngày (đ/ngày)'), findsOneWidget);
  });

  testWidgets('bỏ trống CẢ BA → chặn, nói rõ hậu quả, KHÔNG gọi API', (t) async {
    final ghi = await _dung(t);
    await t.tap(find.text('Lưu'));
    await t.pumpAndSettle();
    expect(find.textContaining('không hiện trong tìm kiếm'), findsOneWidget);
    expect(ghi, isEmpty);
  });

  testWidgets('khai MỘT hình thức là đủ — hai cái kia gửi null', (t) async {
    // Nhà nghỉ theo giờ không nhận khách ở cả tuần; ép khai đủ ba là bắt người
    // ta bịa ra một cái giá họ không định bán.
    final ghi = await _dung(t);
    await _dien(t, 'Giá', '80000');
    await t.tap(find.text('Lưu'));
    await t.pumpAndSettle();

    expect(ghi.single['gia_theo_gio'], 80000);
    expect(ghi.single['gia_qua_dem'], isNull);
    expect(ghi.single['gia_theo_ngay'], isNull);
  });

  testWidgets('mốc huỷ miễn phí mặc định đúng cho từng hình thức', (t) async {
    final ghi = await _dung(t);
    await _dien(t, 'Giá', '80000');
    await t.tap(find.text('Lưu'));
    await t.pumpAndSettle();
    expect(ghi.single['huy_truoc_gio'], 1);
    expect(ghi.single['huy_truoc_dem'], 2);
    expect(ghi.single['huy_truoc_ngay'], 12);
  });

  testWidgets('giá đang có được điền sẵn, không bắt gõ lại', (t) async {
    await _dung(t, banDau: const {
      'loai_phong': 'Phòng đôi',
      'gia_theo_gio': 80000,
      'gia_theo_ngay': 450000,
      'huy_truoc_gio': 3,
    });
    expect(find.text('Phòng đôi'), findsOneWidget);
    expect(find.text('80000'), findsOneWidget);
    expect(find.text('450000'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('tên loại phòng bỏ trống → mặc định "Phòng", không gửi rỗng', (
    t,
  ) async {
    final ghi = await _dung(t);
    await t.enterText(find.widgetWithText(TextField, 'Tên loại phòng'), '');
    await _dien(t, 'Giá', '300000');
    await t.tap(find.text('Lưu'));
    await t.pumpAndSettle();
    expect(ghi.single['loai_phong'], 'Phòng');
  });
}
