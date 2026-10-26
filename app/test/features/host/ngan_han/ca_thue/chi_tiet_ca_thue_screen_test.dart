import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/chi_tiet_ca_thue_screen.dart';

import '../../../../helpers/pump_app.dart';
import 'ca_thue_gia.dart';

/// CHI TIẾT ĐẶT PHÒNG — cửa vào luồng quầy lễ tân.
///
/// Điều phải giữ:
///   * mã đặt, gói thuê, giờ nhận/trả hiện đúng như phiếu đưa khách;
///   * ca CHƯA nhận thì đếm ngược tới giờ đón, ca đang ở thì không đếm nữa;
///   * số "còn lại cần thu" lấy NGUYÊN từ server, màn không tự cộng trừ;
///   * sale không xem tiền thì khối tiền biến mất hẳn, không hiện 0đ.
Future<CaThueGia> _mo(WidgetTester t, Map<String, dynamic> du) async {
  // Màn quầy dài hơn một màn hình điện thoại; viewport test mặc định 800×600
  // làm nút dưới không bấm được (tap rơi ra ngoài) chứ không phải lỗi sản phẩm.
  t.view.physicalSize = const Size(1000, 2600);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  final api = CaThueGia(du);
  await pumpApp(t, ChiTietCaThueScreen(reservationId: 88, api: api));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
  return api;
}

void main() {
  testWidgets('ca sắp tới: đếm ngược tới giờ đón khách', (t) async {
    await _mo(
      t,
      mauCa(
        trangThai: 'approved',
        bayGio: '2026-09-12T13:25',
        daOPhut: 0,
        conPhut: 240,
        conToiGioVao: 35,
      ),
    );
    expect(find.text('#BK-8821'), findsOneWidget);
    expect(find.text('Còn 35 phút nữa khách đến'), findsOneWidget);
    expect(find.text('Tiến hành Check-in ngay'), findsOneWidget);
  });

  testWidgets('gói theo giờ: hiện giờ nhận, giờ trả và độ dài ca', (t) async {
    await _mo(t, mauCa(trangThai: 'approved', conToiGioVao: 35));
    expect(find.text('Gói thuê theo giờ (4 tiếng)'), findsOneWidget);
    // 14:00 hiện hai chỗ: đồng hồ đếm ngược và ô "Giờ nhận" của gói thuê.
    expect(find.text('14:00'), findsNWidgets(2));
    expect(find.text('18:00'), findsOneWidget);
    expect(find.text('4h00m'), findsOneWidget);
  });

  testWidgets('tiền: lấy nguyên con số của server, không tự cộng', (t) async {
    await _mo(t, mauCa());
    expect(find.byKey(const Key('ca-thue-con-lai')), findsOneWidget);
    expect(find.text('235.000đ'), findsOneWidget);
    expect(find.text('Còn lại cần thu'), findsOneWidget);
  });

  testWidgets('khách đang ở: mời sang màn trực, không mời check-in lại', (t) async {
    await _mo(t, mauCa());
    expect(find.text('Quản lý khách đang ở'), findsOneWidget);
    expect(find.text('Tiến hành Check-in ngay'), findsNothing);
    expect(find.byKey(const Key('ca-thue-dem-nguoc')), findsNothing);
  });

  testWidgets('không xem được tài chính thì khối tiền vắng mặt hẳn', (t) async {
    await _mo(t, mauCa(xemTaiChinh: false));
    expect(find.byKey(const Key('ca-thue-con-lai')), findsNothing);
    expect(find.text('CHI PHÍ & TIỀN CỌC'), findsNothing);
    expect(find.text('Phòng P201'), findsOneWidget);
  });

  testWidgets('đơn chờ duyệt: mời Duyệt/Từ chối, chưa mời check-in', (t) async {
    final du = mauCa(trangThai: 'pending', conToiGioVao: 120);
    du['sale'] = {'id': 2, 'ten': 'Nguyễn Sale'};
    await _mo(t, du);
    expect(find.byKey(const Key('ca-thue-duyet')), findsOneWidget);
    expect(find.byKey(const Key('ca-thue-tu-choi')), findsOneWidget);
    expect(find.text('Tiến hành Check-in ngay'), findsNothing);
    expect(find.textContaining('qua sale Nguyễn Sale'), findsOneWidget);
  });

  testWidgets('gia hạn: chọn mốc rồi mới gọi server', (t) async {
    final api = await _mo(t, mauCa());
    await t.tap(find.byKey(const Key('ca-thue-gia-han')));
    await t.pumpAndSettle();
    expect(api.ghi.where((x) => x.startsWith('gia_han')), isEmpty);

    await t.tap(find.byKey(const Key('gia-han-60')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(api.ghi, contains('gia_han:88:60:true'));
  });

  testWidgets('khách không đến: chưa tới giờ nhận thì không có nút', (t) async {
    await _mo(t, mauCa(trangThai: 'approved', bayGio: '2026-09-12T13:25'));
    expect(find.byKey(const Key('ca-thue-khong-den')), findsNothing);
  });

  testWidgets('khách không đến: qua giờ nhận mà chưa nhận thì có nút', (t) async {
    await _mo(t, mauCa(trangThai: 'approved', bayGio: '2026-09-12T14:30'));
    expect(find.byKey(const Key('ca-thue-khong-den')), findsOneWidget);
  });

  testWidgets('khách không đến: đã nhận phòng thì không có nút', (t) async {
    await _mo(t, mauCa(trangThai: 'checked_in', bayGio: '2026-09-12T14:30'));
    expect(find.byKey(const Key('ca-thue-khong-den')), findsNothing);
  });
}
