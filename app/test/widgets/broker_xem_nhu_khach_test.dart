/// XEM NHƯ KHÁCH — chính chủ soi trang mình dưới con mắt người lạ.
///
/// Vì sao tính năng này tồn tại: sửa-tại-chỗ có một điểm mù. Chính chủ LUÔN
/// nhìn bản có nút ✏️, có tin nháp, có lời mời điền chỗ trống — nên không bao
/// giờ thấy trang mình thực sự trống đến mức nào với khách.
///
/// Điều phải giữ bằng test:
///  1. Bản xem thử là ĐÚNG bản khách (`laChuTrang: false`), không phải một chế
///     độ hiển thị thứ ba tự vẽ lại.
///  2. Có đường THOÁT nhìn thấy được — mất hết nút sửa mà không giải thích thì
///     người dùng tưởng trang hỏng.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/features/guest/broker/broker_profile_screen.dart';

import '../helpers/pump_app.dart';

Map<String, dynamic> _hoSo() => {
  'id': 7,
  'name': 'Lê Quang Vinh',
  'avatar_path': null,
  'bio': 'Sáu năm cho thuê căn hộ.',
  'cover_path': null,
  'rating': 4.8,
  'review_count': 6,
  'verified': true,
  'trusted': true,
  'listing_count': 1,
  'years_active': 4,
  'area_count': 3,
  'deal_count': 3,
  'specialties': <String>[],
  'main_areas': <String>[],
  'avg_response_hours': 0.5,
  'response_sample': 6,
  'verified_review_count': 6,
  'seller_kind': 'broker',
  'phone': '0900000000',
};

HouseModel _tin() => HouseModel(
  id: 11,
  hostId: 7,
  title: 'Căn hộ 2PN Thủ Đức',
  description: '',
  categoryId: 1,
  price: 7000000,
  area: 55,
  address: '1 Võ Văn Ngân',
  city: 'TP.HCM',
  district: 'Thủ Đức',
  bedrooms: 2,
  bathrooms: 1,
  status: 'published',
);

Future<void> _dung(WidgetTester t, {required bool laChuTrang}) async {
  t.view.physicalSize = const Size(500, 2600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await pumpApp(
    t,
    BrokerProfileScreen(
      userId: 7,
      laChuTrang: laChuTrang,
      onMoCaiDat: laChuTrang ? () {} : null,
      profileLoader: (_) async => _hoSo(),
      listingsLoader: (_) async => [_tin()],
      reviewsLoader: (_) async => const [],
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('chủ trang → có nút mắt NGAY CẠNH nút cài đặt', (t) async {
    await _dung(t, laChuTrang: true);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('khách xem trang người khác → KHÔNG có nút mắt', (t) async {
    // Mời người lạ "xem thử trang này dưới mắt khách" là vô nghĩa — họ đang là
    // khách rồi.
    await _dung(t, laChuTrang: false);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
  });

  testWidgets('bấm nút mắt → mở bản xem thử, có dải nhắc và đường thoát', (
    t,
  ) async {
    await _dung(t, laChuTrang: true);
    await t.tap(find.byIcon(Icons.visibility_outlined));
    await t.pumpAndSettle();

    expect(find.text('Xem như khách'), findsOneWidget);
    expect(find.text('Đây là những gì người khác nhìn thấy'), findsOneWidget);
    expect(find.text('Thoát'), findsOneWidget);
  });

  testWidgets('trong bản xem thử → mọi nút SỬA biến mất', (t) async {
    await _dung(t, laChuTrang: true);
    expect(find.byType(DsEditChip), findsWidgets);

    await t.tap(find.byIcon(Icons.visibility_outlined));
    await t.pumpAndSettle();

    // Đây là toàn bộ giá trị của tính năng: thấy đúng thứ khách thấy.
    expect(find.byType(DsEditChip), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
    // Tìm theo TOOLTIP chứ không theo icon: dải nhắc cũng vẽ hình con mắt, nên
    // `byIcon(visibility_outlined)` sẽ trúng nó và test báo sai chỗ.
    expect(find.byTooltip('Xem trang dưới mắt khách'), findsNothing);
  });

  testWidgets('bản xem thử CÓ thanh Gọi/Nhắn mà bản chủ trang không có', (
    t,
  ) async {
    await _dung(t, laChuTrang: true);
    var sc = t.widget<Scaffold>(find.byType(Scaffold).first);
    expect(sc.bottomNavigationBar, isNull);

    await t.tap(find.byIcon(Icons.visibility_outlined));
    await t.pumpAndSettle();

    // Thanh này che 76px cuối trang — chính chủ không thấy nó ở bản của mình
    // nên dễ tưởng khách đọc được cả phần bị che.
    sc = t.widget<Scaffold>(find.byType(Scaffold).last);
    expect(sc.bottomNavigationBar, isNotNull);
  });

  testWidgets('bấm Thoát → về lại bản của mình, nút sửa quay lại', (t) async {
    await _dung(t, laChuTrang: true);
    await t.tap(find.byIcon(Icons.visibility_outlined));
    await t.pumpAndSettle();

    await t.tap(find.text('Thoát'));
    await t.pumpAndSettle();

    expect(find.text('Trang của tôi'), findsOneWidget);
    expect(find.byType(DsEditChip), findsWidgets);
  });
}
