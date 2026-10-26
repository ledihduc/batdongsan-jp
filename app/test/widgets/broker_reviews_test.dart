import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/features/guest/broker/broker_profile_screen.dart';

import '../helpers/pump_app.dart';

/// Khối đánh giá + bộ lọc feed.
///
/// Điểm trung bình lấy từ HỒ SƠ (backend tính trên toàn bộ đánh giá), không
/// cộng lại từ mấy dòng đang hiển thị — chúng chỉ là 5 cái gần nhất.
Map<String, dynamic> _hoSo() => {
  'id': 7,
  'name': 'Lê Quang Vinh',
  'avatar_path': null,
  'bio': null,
  'cover_path': null,
  'rating': 4.83,
  'review_count': 6,
  'verified': true,
  'trusted': true,
  'listing_count': 2,
  'years_active': 4,
  'area_count': 3,
  'deal_count': 3,
  'specialties': <String>[],
  'main_areas': <String>[],
  'avg_response_hours': 0.5,
  'response_sample': 6,
  'verified_review_count': 6,
  'seller_kind': 'broker',
};

HouseModel _nha({required int id, required String loai}) => HouseModel(
  id: id,
  hostId: 7,
  title: 'Căn $id',
  description: '',
  price: 8000000,
  area: 50,
  address: '',
  city: 'TP.HCM',
  district: 'Quận 7',
  categoryId: 1,
  bedrooms: 2,
  bathrooms: 1,
  transactionType: loai,
);

Future<void> _dung(
  WidgetTester t, {
  List<Map<String, dynamic>> nhanXet = const [],
  List<HouseModel> nha = const [],
}) async {
  t.view.physicalSize = const Size(500, 4000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await pumpApp(
    t,
    BrokerProfileScreen(
      userId: 7,
      profileLoader: (_) async => _hoSo(),
      listingsLoader: (_) async => nha,
      reviewsLoader: (_) async => nhanXet,
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('không có nhận xét → ẩn hẳn khối, không để tiêu đề treo', (
    t,
  ) async {
    await _dung(t);
    expect(find.text('Đánh giá từ khách hàng'), findsNothing);
  });

  testWidgets('có nhận xét → hiện điểm của HỒ SƠ, không phải của mấy dòng', (
    t,
  ) async {
    await _dung(
      t,
      nhanXet: [
        {'rating': 3, 'comment': 'Tạm được', 'user_name': 'Anh A'},
      ],
    );
    expect(find.text('Đánh giá từ khách hàng'), findsOneWidget);
    // Dòng duy nhất là 3 sao, nhưng điểm hiển thị phải là 4.8 của hồ sơ.
    expect(find.text('4.8'), findsWidgets);
    expect(find.text('/ 5.0 · 6 nhận xét'), findsOneWidget);
    expect(find.text('Tạm được'), findsOneWidget);
  });

  testWidgets('bộ lọc chỉ hiện loại CÓ tin', (t) async {
    await _dung(
      t,
      nha: [_nha(id: 1, loai: 'rent'), _nha(id: 2, loai: 'rent')],
    );
    expect(find.text('Tất cả (2)'), findsOneWidget);
    expect(find.text('Cho thuê (2)'), findsOneWidget);
    // Không có tin bán → không vẽ chip bấm vào ra danh sách rỗng.
    expect(find.textContaining('Bán ('), findsNothing);
  });

  testWidgets('feed cắt còn 3 tin, nút Xem thêm mở hết', (t) async {
    // 6 tin → chỉ hiện 3, khối đánh giá vì thế vẫn nằm trong tầm cuộn.
    await _dung(
      t,
      nha: [for (var i = 1; i <= 6; i++) _nha(id: i, loai: 'rent')],
      nhanXet: [
        {'rating': 5, 'comment': 'Tốt', 'user_name': 'A'},
      ],
    );
    expect(find.text('Căn 3'), findsOneWidget);
    expect(find.text('Căn 4'), findsNothing);
    expect(find.text('Xem thêm 3 tin'), findsOneWidget);

    await t.tap(find.text('Xem thêm 3 tin'));
    await t.pumpAndSettle();
    expect(find.text('Căn 6'), findsOneWidget);
    expect(find.text('Xem thêm 3 tin'), findsNothing);
  });

  testWidgets('đổi bộ lọc thì thu gọn lại, không bung sẵn', (t) async {
    await _dung(
      t,
      nha: [
        for (var i = 1; i <= 5; i++) _nha(id: i, loai: 'rent'),
        _nha(id: 9, loai: 'sale'),
      ],
    );
    await t.tap(find.text('Xem thêm 3 tin'));
    await t.pumpAndSettle();
    expect(find.text('Căn 5'), findsOneWidget);

    await t.tap(find.text('Cho thuê (5)'));
    await t.pumpAndSettle();
    // Đã thu gọn: tin thứ 4 và 5 phải biến mất trở lại.
    expect(find.text('Căn 5'), findsNothing);
    expect(find.text('Xem thêm 2 tin'), findsOneWidget);
  });

  testWidgets('bấm lọc Bán thì feed chỉ còn tin bán', (t) async {
    await _dung(
      t,
      nha: [_nha(id: 1, loai: 'rent'), _nha(id: 2, loai: 'sale')],
    );
    expect(find.text('Căn 1'), findsOneWidget);
    await t.tap(find.text('Bán (1)'));
    await t.pumpAndSettle();
    expect(find.text('Căn 1'), findsNothing);
    expect(find.text('Căn 2'), findsOneWidget);
  });
}

