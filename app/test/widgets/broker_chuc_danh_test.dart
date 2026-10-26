/// CHỨC DANH dưới tên trên trang cá nhân.
///
/// Mọi tài khoản đăng ký đều mang `account_type='sale'` (mặc định của hệ thống
/// vai), nên nếu lấy thẳng cột đó mà in ra thì một người vừa lập tài khoản,
/// chưa đăng gì, chưa có dự án nào, vẫn được app gắn cho danh "Chuyên viên tư
/// vấn BĐS". Dòng đó nằm ngay cạnh tick xanh nên khách đọc thành đã xác minh.
///
/// Quy tắc: KHÔNG tin công khai + KHÔNG dự án = chưa phải người bán.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/features/guest/broker/broker_profile_screen.dart';

import '../helpers/pump_app.dart';

Map<String, dynamic> _hoSo({
  int listingCount = 0,
  List<String> duAn = const [],
  String sellerKind = 'broker',
}) => {
  'id': 7,
  'name': 'Lê Quang Vinh',
  'avatar_path': null,
  'bio': 'x',
  'cover_path': null,
  'rating': 4.8,
  'review_count': 6,
  'verified': true,
  'trusted': false,
  'listing_count': listingCount,
  'distributing': duAn,
  'years_active': 4,
  'area_count': 3,
  'deal_count': 3,
  'specialties': <String>[],
  'main_areas': <String>[],
  'avg_response_hours': 0.5,
  'response_sample': 6,
  'verified_review_count': 6,
  'seller_kind': sellerKind,
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

Future<void> _dung(
  WidgetTester t, {
  int listingCount = 0,
  List<String> duAn = const [],
  String sellerKind = 'broker',
  List<HouseModel> tin = const [],
}) async {
  t.view.physicalSize = const Size(500, 2600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await pumpApp(
    t,
    BrokerProfileScreen(
      userId: 7,
      profileLoader: (_) async =>
          _hoSo(listingCount: listingCount, duAn: duAn, sellerKind: sellerKind),
      listingsLoader: (_) async => tin,
      reviewsLoader: (_) async => const [],
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('0 tin + 0 dự án → "Thành viên", KHÔNG phải chuyên viên', (
    t,
  ) async {
    await _dung(t);
    expect(find.text('Thành viên'), findsOneWidget);
    expect(find.text('Chuyên viên tư vấn BĐS'), findsNothing);
  });

  testWidgets('có tin đăng → là chuyên viên tư vấn BĐS', (t) async {
    await _dung(t, listingCount: 3, tin: [_tin()]);
    expect(find.text('Chuyên viên tư vấn BĐS'), findsOneWidget);
    expect(find.text('Thành viên'), findsNothing);
  });

  testWidgets('0 tin nhưng CÓ dự án phân phối → vẫn là chuyên viên', (t) async {
    // Sale dựng dự án trước rồi mới gắn tin là luồng hợp lệ — đừng hạ danh
    // người đang làm đúng thứ tự đó.
    await _dung(t, duAn: ['Vinhomes Grand Park S1']);
    expect(find.text('Chuyên viên tư vấn BĐS'), findsOneWidget);
    expect(find.text('Thành viên'), findsNothing);
  });

  testWidgets('chủ nhà có tin → "Chủ nhà"', (t) async {
    await _dung(t, listingCount: 2, sellerKind: 'owner', tin: [_tin()]);
    expect(find.text('Chủ nhà'), findsOneWidget);
  });

  testWidgets('chủ nhà mà 0 tin + 0 dự án → cũng chỉ là "Thành viên"', (
    t,
  ) async {
    // Quy tắc áp cho MỌI vai: chưa làm gì thì chưa có danh gì.
    await _dung(t, sellerKind: 'owner');
    expect(find.text('Thành viên'), findsOneWidget);
    expect(find.text('Chủ nhà'), findsNothing);
  });
}
