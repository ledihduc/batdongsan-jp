import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/dang_o_screen.dart';

import '../../../../helpers/pump_app.dart';
import 'ca_thue_gia.dart';

/// KHÁCH ĐANG Ở — màn trực trong lúc khách còn trong phòng.
///
/// Điều phải giữ:
///   * còn bao lâu nữa phải trả phòng, quá giờ thì nói thẳng là quá;
///   * gia hạn nhanh gọi server (server làm tròn giờ chẵn), màn KHÔNG tự cộng;
///   * minibar hiện đơn giá × số lượng như phiếu đưa khách;
///   * ở lố chỉ ĐỀ XUẤT phụ thu, phải bấm mới thành tiền.
Future<CaThueGia> _mo(WidgetTester t, [Map<String, dynamic>? du]) async {
  // Màn quầy dài hơn một màn hình điện thoại; viewport test mặc định 800×600
  // làm nút dưới không bấm được (tap rơi ra ngoài) chứ không phải lỗi sản phẩm.
  t.view.physicalSize = const Size(1000, 2600);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  final api = CaThueGia(du ?? mauCa());
  await pumpApp(t, DangOScreen(reservationId: 88, api: api));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
  return api;
}

void main() {
  testWidgets('đồng hồ: còn bao lâu nữa trả phòng', (t) async {
    await _mo(t);
    expect(find.text('Còn 1 giờ 15 phút nữa trả phòng'), findsOneWidget);
    expect(find.text('Trả 18:00'), findsOneWidget);
    expect(find.text('2h45m'), findsOneWidget);
  });

  testWidgets('quá giờ: nói thẳng đã quá bao lâu', (t) async {
    await _mo(
      t,
      mauCa(
        bayGio: '2026-09-12T18:30',
        daOPhut: 240,
        conPhut: 0,
        quaGio: true,
      ),
    );
    expect(find.text('Đã quá giờ trả 30 phút'), findsOneWidget);
  });

  testWidgets('gia hạn nhanh: gọi server đúng số phút', (t) async {
    final api = await _mo(t);
    await t.tap(find.byKey(const Key('dang-o-gia-han-60')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(api.ghi, contains('gia_han:88:60:true'));
  });

  testWidgets('minibar: hiện đơn giá × số lượng và tạm tính', (t) async {
    await _mo(t);
    expect(find.text('Nước khoáng Lavie'), findsOneWidget);
    expect(find.text('10.000đ × 2'), findsOneWidget);
    expect(find.text('3 món'), findsOneWidget);
    expect(find.byKey(const Key('dang-o-tam-tinh')), findsOneWidget);
    expect(find.text('235.000đ'), findsOneWidget);
  });

  testWidgets('ở lố: chỉ đề xuất, bấm Ghi mới thành phụ thu', (t) async {
    final api = await _mo(
      t,
      mauCa(
        bayGio: '2026-09-12T18:30',
        quaGio: true,
        conPhut: 0,
        deXuatQuaGio: {
          'phut': 30,
          'so_gio': 1,
          'don_gia': 60000,
          'de_xuat': 60000,
          'ten': 'Phụ thu quá giờ (1 giờ)',
        },
      ),
    );
    expect(find.text('Khách ở lố 30 phút'), findsOneWidget);
    expect(api.ghi.where((x) => x.startsWith('phu_thu')), isEmpty);

    await t.tap(find.byKey(const Key('dang-o-ghi-qua-gio')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(
      api.ghi,
      contains('phu_thu:88:Phụ thu quá giờ (1 giờ):60000x1:qua_gio'),
    );
  });

  testWidgets('gỡ một khoản đã ghi nhầm', (t) async {
    final api = await _mo(t);
    await t.tap(find.byKey(const Key('dang-o-xoa-phu-thu-2')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(api.ghi, contains('xoa_phu_thu:88:2'));
  });

  testWidgets('sale không xem tiền: không có minibar lẫn tạm tính', (t) async {
    await _mo(t, mauCa(xemTaiChinh: false));
    expect(find.byKey(const Key('dang-o-tam-tinh')), findsNothing);
    expect(find.byKey(const Key('dang-o-them-phu-thu')), findsNothing);
    expect(find.text('Còn 1 giờ 15 phút nữa trả phòng'), findsOneWidget);
  });
}
