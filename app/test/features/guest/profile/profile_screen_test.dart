import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/data/models/login_account_type.dart';
import 'package:house_booking/features/guest/home/widgets/home_map_preview.dart';
import 'package:house_booking/features/guest/profile/ho_so_thieu.dart';
import 'package:house_booking/features/guest/profile/profile_screen.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/house_provider.dart';
import 'package:house_booking/providers/host_profile_provider.dart';
import 'package:house_booking/providers/viewing_appointment_provider.dart';
import 'package:house_booking/providers/wishlist_provider.dart';

import '../../../helpers/pump_app.dart';

/// Trang Cá nhân — TRƯỚC ĐÂY KHÔNG CÓ TEST NÀO.
///
/// Công cụ trên trang Cá nhân phải theo vai đang chọn, không theo nhãn cũ.
class _AuthGia extends AuthProvider {
  _AuthGia(this._u, this.cheDo);

  final UserModel? _u;
  final LoginAccountType cheDo;

  @override
  LoginAccountType? get loginAccountType => _u == null ? null : cheDo;

  @override
  UserModel? get currentUser => _u;
}

UserModel _nguoiDung(String role) => UserModel(
  id: 7,
  name: 'Văn',
  email: 'v@example.com',
  passwordHash: '',
  phone: '',
  avatarPath: '',
  role: role,
);

Future<void> _mo(
  WidgetTester t,
  UserModel? u, {
  LoginAccountType cheDo = LoginAccountType.customer,
}) async {
  await pumpApp(
    t,
    const Scaffold(body: ProfileScreen()),
    auth: _AuthGia(u, cheDo),
    extraProviders: [
      ChangeNotifierProvider(create: (_) => HouseProvider()),
      ChangeNotifierProvider(create: (_) => ViewingAppointmentProvider()),
      ChangeNotifierProvider(create: (_) => HostProfileProvider()),
      ChangeNotifierProvider(create: (_) => WishlistProvider()),
    ],
  );
  await t.pump();
}

void main() {
  testWidgets('chưa đăng nhập thì KHÔNG lộ khu nào', (t) async {
    await _mo(t, null);
    expect(find.text('Quản lý cho thuê'), findsNothing);
    expect(find.text('Chỉnh sửa hồ sơ'), findsNothing);
  });

  testWidgets('tài khoản thường KHÔNG thấy khu chủ nhà', (t) async {
    await _mo(t, _nguoiDung('guest'));
    // Kéo hết trang rồi mới khẳng định KHÔNG có: danh sách dựng lười, không
    // cuộn thì "không tìm thấy" chỉ nghĩa là "chưa dựng tới".
    await t.dragFrom(const Offset(200, 500), const Offset(0, -1500));
    await t.pump();
    expect(find.text('Quản lý cho thuê'), findsNothing);
    expect(find.text('Nhà trọ & phòng'), findsNothing);
  });

  testWidgets('chủ nhà thấy khu quản lý cho thuê', (t) async {
    await _mo(t, _nguoiDung('host'), cheDo: LoginAccountType.owner);
    await t.pump();
    // Khu này nằm cuối trang cuộn → phải kéo tới mới dựng.
    await t.scrollUntilVisible(find.text('Quản lý cho thuê'), 250);
    await t.pump();
    expect(find.text('Quản lý cho thuê'), findsOneWidget);
    expect(find.text('Nhà trọ & phòng'), findsOneWidget);
  });

  testWidgets('chủ nhà vẫn vào được Tổng quan sau khi bỏ shell riêng', (
    t,
  ) async {
    // `HostHomeScreen` trước đây là tab ĐẦU của shell chủ nhà. Bỏ shell đó mà
    // quên đặt lại lối vào thì màn này thành mồ côi — không có đường nào tới.
    await _mo(t, _nguoiDung('host'), cheDo: LoginAccountType.owner);
    await t.pump();
    await t.scrollUntilVisible(find.text('Tổng quan quản lý'), 250);
    await t.pump();
    expect(find.text('Tổng quan quản lý'), findsOneWidget);
  });

  testWidgets('tài khoản thường chọn Chủ nhà thấy công cụ cho thuê', (t) async {
    await _mo(t, _nguoiDung('guest'), cheDo: LoginAccountType.owner);
    await t.scrollUntilVisible(find.text('Quản lý cho thuê'), 250);
    await t.pump();
    expect(find.text('Nhà trọ & phòng'), findsOneWidget);
  });

  testWidgets('nhãn host không lộ khu chủ nhà khi đang chọn Khách', (t) async {
    await _mo(t, _nguoiDung('host'));
    await t.dragFrom(const Offset(200, 500), const Offset(0, -1500));
    await t.pump();
    expect(find.text('Quản lý cho thuê'), findsNothing);
    expect(find.text('Nhà trọ & phòng'), findsNothing);
  });

  testWidgets('KHÔNG còn công tắc Khách thuê / Chủ nhà', (t) async {
    // Công tắc persona đã bỏ: chủ nhà không phải một "thế giới" riêng nữa mà
    // là bộ công cụ nằm trong chính màn này. Còn công tắc thì lại quay về cảnh
    // mỗi tài khoản mở ra một app khác nhau.
    for (final vai in ['guest', 'host', 'admin']) {
      await _mo(t, _nguoiDung(vai));
      await t.pump();
      expect(find.text('Chủ nhà'), findsNothing, reason: 'vai $vai');
      expect(find.text('Khách thuê'), findsNothing, reason: 'vai $vai');
    }
  });

  testWidgets('quản trị KHÔNG tự động có khu chủ nhà', (t) async {
    // admin là super-host ở tầng API, nhưng khu này là lối đi tới công cụ vận
    // hành nhà trọ của CHÍNH họ — admin không có nhà trọ nào.
    await _mo(t, _nguoiDung('admin'));
    expect(find.text('Quản lý cho thuê'), findsNothing);
  });

  testWidgets(
    'user thường có Tin nhắn và Yêu cầu dịch vụ, KHÔNG có Tin đã đăng',
    (t) async {
      await _mo(t, _nguoiDung('guest'));
      await t.dragFrom(const Offset(200, 500), const Offset(0, -800));
      await t.pump();

      // Hai lối vào trước đây KHÔNG tồn tại ở đâu trong trang cá nhân.
      expect(find.text('Tin nhắn'), findsOneWidget);
      expect(find.text('Yêu cầu dịch vụ của tôi'), findsOneWidget);
      // Mục của chủ nhà không được rò sang phần chung: phụ đề của nó nói
      // "phòng bạn cho thuê", người dùng thường đọc vào tưởng vào nhầm tài khoản.
      expect(find.text('Tin đã đăng'), findsNothing);
    },
  );

  testWidgets('khối "Bài viết của bạn" đã bỏ hẳn', (t) async {
    await _mo(t, _nguoiDung('guest'));
    await t.dragFrom(const Offset(200, 500), const Offset(0, -1500));
    await t.pump();
    // Trước đây khối này chiếm hơn một màn hình chỉ để nói "chưa có gì".
    expect(find.text('Bạn chưa có bài viết nào'), findsNothing);
  });

  // ── ĐẦU TRANG PHẢI GIỐNG NHAU Ở MỌI VAI ───────────────────────────────────
  //
  // Backend TỰ NÂNG `role` lên 'host' ngay khi đăng tin đầu tiên
  // (`houses.py` — auto-upgrade to host on first listing). Nếu đầu trang khoá
  // theo `role` thì cùng một tài khoản bán, trước và sau khi đăng tin sẽ mở ra
  // hai trang cá nhân trông khác hẳn nhau mà không có gì báo trước.

  testWidgets('bìa bản đồ có ở tài khoản thường', (t) async {
    await _mo(t, _nguoiDung('guest'));
    expect(find.byType(HomeMapPreview), findsOneWidget);
  });

  testWidgets('bìa bản đồ có ở chủ nhà — cùng một widget', (t) async {
    await _mo(t, _nguoiDung('host'));
    expect(find.byType(HomeMapPreview), findsOneWidget);
  });

  testWidgets('hồ sơ trống thì nhắc hoàn thiện', (t) async {
    await _mo(t, _nguoiDung('guest'));
    expect(find.byType(TheHoanThienHoSo), findsOneWidget);
    expect(find.text('0/3'), findsOneWidget);
  });
}
