import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/guest/broker/broker_profile_screen.dart';

import '../helpers/pump_app.dart';

/// Chip phản hồi chỉ hiện khi có PHÉP ĐO đứng sau.
///
/// Bối cảnh: staging từng có `avg_response_hours = 0.6` ở 1.053 hồ sơ trong khi
/// bảng lịch hẹn rỗng. Test này giữ cho con số đó không tự đứng dậy làm huy
/// hiệu được nữa. Chip nằm trong thẻ danh tính (không còn hàng huy hiệu riêng —
/// nó trùng nội dung với thẻ).
Map<String, dynamic> _hoSo({
  required int mau,
  double? gio,
  bool trusted = false,
}) => {
  'id': 7,
  'name': 'Hồ Tâm',
  'avatar_path': null,
  'bio': null,
  'cover_path': null,
  'rating': 4.9,
  'review_count': 19,
  'verified': true,
  'trusted': trusted,
  'listing_count': 19,
  'years_active': 4,
  'area_count': 11,
  'deal_count': 0,
  'specialties': <String>[],
  'main_areas': <String>[],
  'avg_response_hours': gio,
  'response_sample': mau,
  'verified_review_count': 0,
  'seller_kind': 'broker',
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
  testWidgets('có giờ phản hồi nhưng 0 lần đo → KHÔNG hiện chip', (t) async {
    await _dung(t, _hoSo(mau: 0, gio: 0.6));
    expect(find.textContaining('Phản hồi trong'), findsNothing);
  });

  testWidgets('dưới 5 lần đo vẫn chưa đủ', (t) async {
    await _dung(t, _hoSo(mau: 4, gio: 0.6));
    expect(find.textContaining('Phản hồi trong'), findsNothing);
  });

  testWidgets('đủ 5 lần đo thì hiện chip với số phút thật', (t) async {
    await _dung(t, _hoSo(mau: 5, gio: 0.6));
    expect(find.text('Phản hồi trong 36 phút'), findsOneWidget);
  });

  testWidgets('đủ mẫu, phản hồi chậm → vẫn nói đúng số giờ', (t) async {
    await _dung(t, _hoSo(mau: 20, gio: 9));
    expect(find.text('Phản hồi trong 9 giờ'), findsOneWidget);
  });

  testWidgets('backend nói chưa uy tín → không gắn nhãn hạng', (t) async {
    await _dung(t, _hoSo(mau: 0, trusted: false));
    expect(find.text('UY TÍN'), findsNothing);
    // Xác minh danh tính là cờ do admin đặt, không phải số đo → vẫn hiện.
    expect(find.text('Đã xác minh danh tính'), findsOneWidget);
  });

  testWidgets('trusted → gắn nhãn hạng cạnh tên', (t) async {
    await _dung(t, _hoSo(mau: 0, trusted: true));
    expect(find.text('UY TÍN'), findsOneWidget);
  });
}
