import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/nhan_phong_screen.dart';

import '../../../../helpers/pump_app.dart';
import 'ca_thue_gia.dart';

/// CHECK-IN 3 BƯỚC.
///
/// Điều phải giữ:
///   * không tick đối chiếu giấy tờ thì KHÔNG qua được bước sau — đây là bước
///     bắt buộc theo quy định lưu trú, không phải gợi ý;
///   * chưa bàn giao đủ thì cũng chưa sang bước thu tiền;
///   * ô tiền điền sẵn đúng số "còn lại" của server;
///   * bấm xác nhận gọi ĐÚNG một lần, kèm ghi chú của hai bước trước.
Future<CaThueGia> _mo(WidgetTester t, [Map<String, dynamic>? du]) async {
  // Màn quầy dài hơn một màn hình điện thoại; viewport test mặc định 800×600
  // làm nút dưới không bấm được (tap rơi ra ngoài) chứ không phải lỗi sản phẩm.
  t.view.physicalSize = const Size(1000, 2600);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  final api = CaThueGia(du ?? mauCa(trangThai: 'approved', conToiGioVao: 35));
  await pumpApp(t, NhanPhongScreen(reservationId: 88, api: api));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
  return api;
}

Future<void> _quaBaiBuoc(WidgetTester t) async {
  await t.tap(find.byKey(const Key('nhan-phong-doi-chieu')));
  await t.pump();
  await t.tap(find.byKey(const Key('nhan-phong-tiep')));
  await t.pump();
  for (final m in const ['khoa', 'dien', 'do']) {
    await t.tap(find.byKey(Key('nhan-phong-ban-giao-$m')));
    await t.pump();
  }
  await t.tap(find.byKey(const Key('nhan-phong-tiep')));
  await t.pump();
}

void main() {
  testWidgets('chưa đối chiếu giấy tờ thì nút tiếp tục khoá', (t) async {
    await _mo(t);
    expect(find.text('Bước 1/3'), findsOneWidget);
    final nut = t.widget<FilledButton>(
      find.ancestor(
        of: find.text('Tiếp tục'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(nut.onPressed, isNull);

    await t.tap(find.byKey(const Key('nhan-phong-doi-chieu')));
    await t.pump();
    final nut2 = t.widget<FilledButton>(
      find.ancestor(
        of: find.text('Tiếp tục'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(nut2.onPressed, isNotNull);
  });

  testWidgets('bàn giao thiếu mục thì chưa sang được bước thu tiền', (t) async {
    await _mo(t);
    await t.tap(find.byKey(const Key('nhan-phong-doi-chieu')));
    await t.pump();
    await t.tap(find.byKey(const Key('nhan-phong-tiep')));
    await t.pump();
    expect(find.text('Bước 2/3'), findsOneWidget);

    await t.tap(find.byKey(const Key('nhan-phong-ban-giao-khoa')));
    await t.pump();
    await t.tap(find.byKey(const Key('nhan-phong-tiep')));
    await t.pump();
    expect(find.text('Bước 2/3'), findsOneWidget, reason: 'thiếu 2 mục');
  });

  testWidgets('bước 3 điền sẵn đúng số còn phải thu', (t) async {
    await _mo(t);
    await _quaBaiBuoc(t);
    expect(find.text('Bước 3/3'), findsOneWidget);
    expect(find.text('Cần thu khi nhận phòng'), findsOneWidget);
    final o = t.widget<TextField>(find.byKey(const Key('nhan-phong-so-thu')));
    expect(o.controller!.text, '235000');
  });

  testWidgets('xác nhận: gửi tiền, hình thức và ghi chú hai bước trước', (t) async {
    final api = await _mo(t);
    await _quaBaiBuoc(t);
    await t.tap(find.byKey(const Key('nhan-phong-ht-chuyen_khoan')));
    await t.pump();
    await t.tap(find.byKey(const Key('nhan-phong-tiep')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));

    final lenh = api.ghi.firstWhere((x) => x.startsWith('nhan_phong'));
    expect(lenh, startsWith('nhan_phong:88:235000:chuyen_khoan:'));
    expect(lenh, contains('Đã đối chiếu giấy tờ khách'));
    expect(lenh, contains('Bàn giao đủ'));
  });
}
