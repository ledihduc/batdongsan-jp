import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/guest/broker/broker_profile_screen.dart';

import '../helpers/pump_app.dart';

/// Thanh liên hệ chỉ vẽ nút CÓ dữ liệu.
///
/// Backend bỏ hẳn khoá `phone` khi người bán chưa bật `show_phone` (mig 0088),
/// nên vắng khoá = không được gọi. Vẽ nút xám bấm không ăn còn tệ hơn không có
/// nút: khách bấm rồi mới biết hụt.
Map<String, dynamic> _hoSo({String? phone, String? zalo}) => {
  'id': 7,
  'name': 'Lê Quang Vinh',
  'avatar_path': null,
  'bio': null,
  'cover_path': null,
  'rating': 4.8,
  'review_count': 6,
  'verified': true,
  'trusted': true,
  'listing_count': 5,
  'years_active': 4,
  'area_count': 3,
  'deal_count': 3,
  'specialties': <String>[],
  'main_areas': <String>[],
  'avg_response_hours': 0.5,
  'response_sample': 6,
  'verified_review_count': 6,
  'seller_kind': 'broker',
  if (phone != null) 'phone': phone,
  if (zalo != null) 'zalo': zalo,
};

Future<void> _dung(WidgetTester t, Map<String, dynamic> p) async {
  t.view.physicalSize = const Size(500, 2600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await pumpApp(
    t,
    BrokerProfileScreen(
      userId: 7,
      profileLoader: (_) async => p,
      listingsLoader: (_) async => const [],
      // Bắt buộc bơm: `ApiClient` đọc JWT qua secure storage, kênh platform
      // đó không bao giờ trả lời trong widget test → pumpAndSettle treo.
      reviewsLoader: (_) async => const [],
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('không có SĐT lẫn Zalo → chỉ còn Nhắn + Xem nhà', (t) async {
    await _dung(t, _hoSo());
    expect(find.text('Gọi'), findsNothing);
    expect(find.text('Zalo'), findsNothing);
    // Chỗ của Zalo nhường cho "Xem nhà" — thanh không bao giờ trống một ô.
    expect(find.text('Xem nhà'), findsOneWidget);
  });

  testWidgets('bật SĐT → hiện nút Gọi', (t) async {
    await _dung(t, _hoSo(phone: '0912345678'));
    expect(find.text('Gọi'), findsOneWidget);
  });

  testWidgets('có Zalo → nút Zalo thay chỗ Xem nhà', (t) async {
    await _dung(t, _hoSo(zalo: '0912345678'));
    expect(find.text('Zalo'), findsOneWidget);
    expect(find.text('Xem nhà'), findsNothing);
    expect(find.text('Gọi'), findsNothing);
  });

  testWidgets('SĐT rỗng chuỗi cũng coi như không có', (t) async {
    await _dung(t, _hoSo(phone: '   '));
    expect(find.text('Gọi'), findsNothing);
  });

  testWidgets('nút Nhắn luôn có mặt', (t) async {
    await _dung(t, _hoSo());
    expect(find.textContaining('Lê Quang Vinh'), findsWidgets);
  });
}
