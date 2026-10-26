import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/features/guest/broker/broker_profile_screen.dart';

import '../helpers/pump_app.dart';

/// Hồ sơ môi giới: bố cục theo bản thiết kế (bìa · tên + tick · 4 thẻ số liệu ·
/// nhận xét) và — quan trọng nhất — KHÔNG bịa số liệu khi backend không có.
///
/// Dữ liệu bơm qua các loader chứ không qua MockClient: `ApiClient` luôn đọc JWT
/// từ flutter_secure_storage, mà kênh platform đó KHÔNG trả lời trong widget
/// test → future treo, màn kẹt ở vòng quay chờ.
Future<List<HouseModel>> _noListings(int _) async => const [];

/// Bắt buộc bơm cùng với hai loader kia: `ApiClient` đọc JWT qua secure
/// storage, kênh platform đó không bao giờ trả lời trong widget test.
Future<List<Map<String, dynamic>>> _noReviews(int _) async => const [];

/// Bơm vài khung thay cho pumpAndSettle (vòng quay chờ quay mãi → settle timeout).
Future<void> _tick(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('hiện tên, tick tin cậy và 4 thẻ số liệu THẬT', (tester) async {
    await pumpApp(
      tester,
      BrokerProfileScreen(
        userId: 7,
        listingsLoader: _noListings,
        reviewsLoader: _noReviews,
        profileLoader: (_) async => <String, dynamic>{
          'id': 7,
          'name': 'Vũ Mai',
          'trusted': true,
          'rating': 5.0,
          'review_count': 186,
          'listing_count': 7,
          'area_count': 3,
          'years_active': 2,
        },
      ),
    );
    await _tick(tester);

    expect(find.text('Vũ Mai'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsOneWidget);
    // 3 thẻ: số tin · đánh giá · năm tham gia.
    //
    // KHÔNG còn thẻ "Khu vực": nhãn nổi trên bìa bản đồ đã ghi số khu vực rồi,
    // để cả hai là nói hai lần trên cùng một màn.
    expect(find.text('7'), findsOneWidget);
    expect(find.text('186'), findsOneWidget);
    expect(find.text('2+'), findsOneWidget);
    expect(find.text('Khu vực'), findsNothing);
  });

  testWidgets('số liệu bằng 0 thì ẨN thẻ, không trưng "0 năm tham gia"', (
    tester,
  ) async {
    await pumpApp(
      tester,
      BrokerProfileScreen(
        userId: 7,
        listingsLoader: _noListings,
        reviewsLoader: _noReviews,
        profileLoader: (_) async => <String, dynamic>{
          'id': 7,
          'name': 'Người mới',
          'listing_count': 2,
          'area_count': 0,
          'review_count': 0,
          'years_active': 0,
        },
      ),
    );
    await _tick(tester);

    expect(find.text('2'), findsOneWidget); // chỉ còn thẻ "Tin đăng"
    expect(find.text('Khu vực'), findsNothing);
    expect(find.text('Năm'), findsNothing);
    expect(find.text('Đánh giá'), findsNothing);
  });

  testWidgets('KHÔNG dán nhãn "tự khai" lên mặt người bán', (tester) async {
    await pumpApp(
      tester,
      BrokerProfileScreen(
        userId: 7,
        listingsLoader: _noListings,
        reviewsLoader: _noReviews,
        profileLoader: (_) async => <String, dynamic>{
          'id': 7,
          'name': 'A',
          'listing_count': 1,
          'seller_kind': 'broker',
        },
      ),
    );
    await _tick(tester);

    // Nhãn này đã bỏ: đặt ngay dưới tên thì đọc như lời cảnh báo, bào mòn
    // đúng cái uy tín trang này sinh ra để xây. Im lặng khi chưa xác minh đã
    // đủ trung thực — tick chỉ hiện khi có dữ liệu thật đỡ lưng.
    expect(find.text('Môi giới (tự khai)'), findsNothing);
  });

  testWidgets('chưa khai vai trò → KHÔNG hiện nhãn nào (không đoán bừa)', (
    tester,
  ) async {
    await pumpApp(
      tester,
      BrokerProfileScreen(
        userId: 7,
        listingsLoader: _noListings,
        reviewsLoader: _noReviews,
        profileLoader: (_) async => <String, dynamic>{
          'id': 7,
          'name': 'A',
          'listing_count': 1,
        },
      ),
    );
    await _tick(tester);

    expect(find.text('Chủ nhà tự đăng (tự khai)'), findsNothing);
    expect(find.text('Môi giới (tự khai)'), findsNothing);
  });

  testWidgets('hồ sơ lỗi/404 → báo không tìm thấy, không dựng khung rỗng', (
    tester,
  ) async {
    await pumpApp(
      tester,
      BrokerProfileScreen(
        userId: 9,
        listingsLoader: _noListings,
        reviewsLoader: _noReviews,
        profileLoader: (_) async => throw Exception('404'),
      ),
    );
    await _tick(tester);

    expect(find.text('Không tìm thấy hồ sơ này.'), findsOneWidget);
  });

  testWidgets('KHÔNG còn mục nhận xét khách hàng', (tester) async {
    await pumpApp(
      tester,
      BrokerProfileScreen(
        userId: 7,
        listingsLoader: _noListings,
        reviewsLoader: _noReviews,
        profileLoader: (_) async => <String, dynamic>{
          'id': 7,
          'name': 'A',
          'listing_count': 0,
        },
      ),
    );
    await _tick(tester);

    // Mục này đã bỏ hẳn: review gắn theo TIN chứ không theo con người, và
    // ai đăng nhập cũng viết được (cờ "chỉ người đã ở" đang tắt) — trưng lên
    // trang bán hàng là mời bơm sao bằng tài khoản phụ.
    expect(find.text('Nhận xét khách hàng'), findsNothing);
  });

  testWidgets('Trang Sale có đủ phím liên hệ Zalo và Facebook', (tester) async {
    await pumpApp(
      tester,
      BrokerProfileScreen(
        userId: 7,
        listingsLoader: _noListings,
        reviewsLoader: _noReviews,
        profileLoader: (_) async => <String, dynamic>{
          'id': 7,
          'name': 'Sale Vua Nhà',
          'listing_count': 1,
          'zalo': '0912345678',
          'facebook': 'https://www.facebook.com/vuanha.sale',
        },
      ),
    );
    await _tick(tester);

    expect(find.text('Zalo'), findsOneWidget);
    expect(find.text('Facebook'), findsOneWidget);
    expect(find.byIcon(Icons.facebook_rounded), findsOneWidget);
  });
}
