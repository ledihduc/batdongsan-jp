/// Nút "Mời sale phụ trách" trên SỔ PHÒNG của một toà.
///
/// Chủ nhà tự dựng dự án thì cũng phải mời được sale vào bán — chiều ngược của
/// mã bàn giao. Trước đây mã mời chỉ hiện đúng MỘT LẦN ngay sau khi tạo toà;
/// đóng hộp thoại đi là không lấy lại được.
///
/// Điều phải giữ: nút chỉ mọc cho NGƯỜI ĐỨNG TÊN toà. Màn này cũng mở được từ
/// trang dự án của sale, và endpoint hẹp đúng thế — hiện nút cho người khác chỉ
/// để họ bấm vào và nhận 404.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/host/property/providers/room_provider.dart';
import 'package:house_booking/features/host/property/screens/building_detail_screen.dart';

import '../../helpers/pump_app.dart';

Future<void> _dung(WidgetTester t, {int? hostId, int? toi}) async {
  t.view.physicalSize = const Size(520, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  // Bơm provider rỗng: màn tự nạp phòng từ mạng, không bơm thì test chỉ thấy
  // vòng quay tải mãi và masthead không bao giờ dựng.
  await pumpApp(
    t,
    BuildingDetailScreen(
      buildingId: 5,
      buildingName: 'Toà Hoa Sữa',
      hostId: hostId,
      roomProvider: RoomProvider(),
    ),
    auth: toi == null ? null : SignedInAuthProvider(id: toi),
  );
  await t.pump();
  // Màn "Quản lí phòng" (mockup 11/09) không có chỗ cho nút rời — lối mời sale
  // nằm trong menu mở từ TÊN TOÀ.
  await t.tap(find.byKey(const ValueKey('menu-toa')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('CHỦ toà → có nút mời sale', (t) async {
    await _dung(t, hostId: 62, toi: 62);
    expect(find.text('Mời sale phụ trách'), findsOneWidget);
  });

  testWidgets('SALE mở cùng màn → KHÔNG có nút', (t) async {
    // Endpoint chỉ nhận người đứng tên toà; hiện nút ở đây là để họ bấm rồi
    // nhận 404.
    await _dung(t, hostId: 62, toi: 58);
    expect(find.text('Mời sale phụ trách'), findsNothing);
  });

  testWidgets('chưa đăng nhập → KHÔNG có nút', (t) async {
    await _dung(t, hostId: 62);
    expect(find.text('Mời sale phụ trách'), findsNothing);
  });

  testWidgets('không biết ai đứng tên → ẩn nút, không đoán', (t) async {
    // Đoán sai thì nút hiện ra rồi bấm vào nhận 404 — tệ hơn là không có nút.
    await _dung(t, toi: 62);
    expect(find.text('Mời sale phụ trách'), findsNothing);
  });
}
