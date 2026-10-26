import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/tra_phong_screen.dart';

import '../../../../helpers/pump_app.dart';
import 'ca_thue_gia.dart';

/// CHECK-OUT & QUYẾT TOÁN.
///
/// Điều phải giữ:
///   * giờ thực ở đối chiếu với gói đã đặt, vượt bao nhiêu nói rõ bấy nhiêu;
///   * còn lại > 0 là THU THÊM, < 0 là HOÀN khách — không được lẫn dấu;
///   * checklist kiểm phòng đi theo lệnh trả phòng (ghi vào ca, không mất);
///   * mặc định vẫn khoá phòng để dọn, chọn "Không khoá" mới thôi.
Future<CaThueGia> _mo(WidgetTester t, [Map<String, dynamic>? du]) async {
  // Màn quầy dài hơn một màn hình điện thoại; viewport test mặc định 800×600
  // làm nút dưới không bấm được (tap rơi ra ngoài) chứ không phải lỗi sản phẩm.
  t.view.physicalSize = const Size(1000, 2600);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  final api = CaThueGia(du ?? mauCa());
  await pumpApp(t, TraPhongScreen(reservationId: 88, api: api));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
  return api;
}

void main() {
  testWidgets('giờ thực ở: vượt gói bao nhiêu nói rõ', (t) async {
    await _mo(
      t,
      mauCa(bayGio: '2026-09-12T18:20', quaGio: true, conPhut: 0),
    );
    expect(find.text('Tổng thời gian thực ở'), findsOneWidget);
    expect(find.text('4 giờ 20 phút'), findsOneWidget);
    expect(find.text('Vượt gói 20 phút'), findsOneWidget);
  });

  testWidgets('còn lại dương: thu thêm', (t) async {
    await _mo(t);
    expect(find.text('Khách phải trả thêm'), findsOneWidget);
    expect(find.text('235.000đ'), findsOneWidget);
    expect(find.text('Số tiền thu thêm'), findsOneWidget);
  });

  testWidgets('còn lại âm: hoàn cọc cho khách, không gọi là thu', (t) async {
    await _mo(t, mauCa(coc: 500000, daThu: 500000, conLai: -65000));
    expect(find.text('Khách được hoàn lại'), findsOneWidget);
    expect(find.text('65.000đ'), findsOneWidget);
    expect(find.text('Số tiền hoàn khách'), findsOneWidget);
    final o = t.widget<TextField>(find.byKey(const Key('tra-phong-so-tien')));
    expect(o.controller!.text, '65000');
  });

  testWidgets('checklist đi kèm lệnh trả phòng', (t) async {
    final api = await _mo(t);
    expect(find.text('0/3 mục đạt'), findsOneWidget);
    for (final m in const ['dien', 'khoa', 'taisan']) {
      await t.tap(find.byKey(Key('tra-phong-kiem-$m')));
      await t.pump();
    }
    expect(find.text('3/3 mục đạt'), findsOneWidget);

    await t.tap(find.byKey(const Key('tra-phong-xac-nhan')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    final lenh = api.ghi.firstWhere((x) => x.startsWith('tra_phong'));
    expect(lenh, contains('thu=235000'));
    expect(lenh, contains('hoan=0'));
    expect(lenh, contains('don=60'));
    expect(lenh, contains('đạt cả 3 mục'));
  });

  testWidgets('chọn không khoá dọn thì gửi 0 phút', (t) async {
    final api = await _mo(t);
    await t.tap(find.byKey(const Key('tra-phong-don-0')));
    await t.pump();
    await t.tap(find.byKey(const Key('tra-phong-xac-nhan')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(
      api.ghi.firstWhere((x) => x.startsWith('tra_phong')),
      contains('don=0'),
    );
  });

  testWidgets('hoàn cọc gửi vào ô hoàn, không gửi vào ô thu', (t) async {
    final api = await _mo(t, mauCa(coc: 500000, daThu: 500000, conLai: -65000));
    await t.tap(find.byKey(const Key('tra-phong-xac-nhan')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    final lenh = api.ghi.firstWhere((x) => x.startsWith('tra_phong'));
    expect(lenh, contains('thu=0'));
    expect(lenh, contains('hoan=65000'));
  });
}
