import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/features/guest/broker/broker_profile_screen.dart';
import 'package:house_booking/providers/auth_provider.dart';

import '../../helpers/pump_app.dart';

/// VAI CHỦ NHÀ trong thanh điều hướng (đổi 12/09/2026).
///
/// Điều phải giữ:
///   * chủ nhà dùng CHUNG trang cá nhân với sale — khác mỗi chỗ không đăng tin;
///   * không có nút "Thêm tin", và trạng thái rỗng phải chỉ đường khác chứ
///     không mời bấm một nút không tồn tại.
class _AuthGia extends AuthProvider {
  _AuthGia(this._u);

  final UserModel? _u;

  @override
  UserModel? get currentUser => _u;
}

UserModel _nguoi(String role) => UserModel(
  id: 9,
  name: 'Vũ Đình Văn',
  email: 'v@t.com',
  phone: '0900000000',
  passwordHash: '',
  avatarPath: '',
  role: role,
);

void main() {
  /// Trang hồ sơ dài hơn một màn hình; viewport test mặc định 800×600 làm mục
  /// "Tin đăng" nằm ngoài cây dựng, không phải lỗi sản phẩm.
  void manRong(WidgetTester t) {
    t.view.physicalSize = const Size(1200, 3000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets('chủ nhà: trang cá nhân KHÔNG có nút Thêm tin', (t) async {
    manRong(t);
    await pumpApp(
      t,
      BrokerProfileScreen(
        userId: 9,
        name: 'Vũ Đình Văn',
        laChuTrang: true,
        choDangBai: false,
        profileLoader: (_) async => <String, dynamic>{
          'id': 9,
          'name': 'Vũ Đình Văn',
          'role': 'host',
        },
        listingsLoader: (_) async => const <HouseModel>[],
        reviewsLoader: (_) async => const <Map<String, dynamic>>[],
      ),
      auth: _AuthGia(_nguoi('host')),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 80));

    expect(find.text('Thêm tin'), findsNothing);
    expect(find.textContaining('Tin rao do sale phụ trách đăng'), findsOneWidget);
  });

  testWidgets('sale: vẫn đăng tin được như cũ', (t) async {
    manRong(t);
    await pumpApp(
      t,
      BrokerProfileScreen(
        userId: 9,
        name: 'Vũ Đình Văn',
        laChuTrang: true,
        profileLoader: (_) async => <String, dynamic>{
          'id': 9,
          'name': 'Vũ Đình Văn',
          'role': 'guest',
        },
        listingsLoader: (_) async => const <HouseModel>[],
        reviewsLoader: (_) async => const <Map<String, dynamic>>[],
      ),
      auth: _AuthGia(_nguoi('guest')),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 80));

    expect(find.text('Thêm tin'), findsOneWidget);
  });
}
