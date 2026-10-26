import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/login_account_type.dart';
import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/features/guest/profile/sale_settings_screen.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/locale_provider.dart';
import 'package:provider/provider.dart';

import '../helpers/pump_app.dart';

/// Cài đặt của người bán.
///
/// Điều quan trọng nhất cần giữ: màn này KHÔNG vẽ mục không chạy được. Bản
/// thiết kế tham chiếu có ví tiền, gói Pro, điểm uy tín 98/100, Face ID, thiết
/// bị đang đăng nhập, hotline riêng — hệ thống không có thứ nào. Một nút bấm
/// vào không xảy ra gì là lý do Apple 2.1 từ chối, nên nó phải có test canh.
Future<void> _dung(
  WidgetTester t, {
  Map<String, dynamic>? hoSo,
  String vai = 'host',
  String loaiTaiKhoan = 'sale',
  LoginAccountType cheDo = LoginAccountType.sale,
}) async {
  t.view.physicalSize = const Size(500, 3200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);

  await pumpApp(
    t,
    SaleSettingsScreen(profileLoader: (_) async => hoSo ?? _hoSoMau),
    auth: _AuthSale(vai, loaiTaiKhoan, cheDo),
    extraProviders: [
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
    ],
  );
  await t.pumpAndSettle();
}

final _hoSoMau = <String, dynamic>{
  'name': 'Lê Quang Vinh',
  'rating': 4.8,
  'review_count': 6,
  'listing_count': 5,
  'trusted': true,
  'verified': true,
  'zalo': '0912345678',
  'facebook': 'https://www.facebook.com/vuanha.sale',
};

void main() {
  testWidgets('KHÔNG có mục nào hệ thống chưa làm được', (t) async {
    await _dung(t);
    for (final bia in [
      'Số dư ví',
      'Nâng cấp',
      'Gói Pro',
      'Điểm uy tín sàn',
      'Tự động đẩy tin',
      'Mẫu tin nhắn',
      'Face ID',
      'Thiết bị đang đăng nhập',
      'Liên kết mạng xã hội',
      'Hotline',
      'Âm thanh',
      'Phiên bản ứng dụng',
    ]) {
      expect(find.textContaining(bia), findsNothing, reason: bia);
    }
  });

  testWidgets('đủ các mục có thật', (t) async {
    await _dung(t);
    for (final m in [
      'Thông tin cá nhân & giới thiệu',
      'Liên hệ công khai',
      'Xác minh chủ nhà (CCCD)',
      'Trang Sale của tôi',
      'Xem trang',
      'Sửa liên hệ',
      'Link Trang Sale',
      'Tin đăng của tôi',
      'Dự án & phòng đang quản lý',
      'Mã liên kết chủ nhà',
      'Lịch hẹn dẫn khách',
      'Tin nhắn với khách',
    ]) {
      expect(find.text(m), findsOneWidget, reason: m);
    }
  });

  testWidgets('tóm tắt đủ Zalo và Facebook công khai', (t) async {
    await _dung(t);
    expect(find.textContaining('Zalo · Facebook'), findsOneWidget);
  });

  testWidgets('tài khoản Khách mặc định không thấy phím tắt Trang Sale', (
    t,
  ) async {
    await _dung(
      t,
      vai: 'guest',
      loaiTaiKhoan: 'customer',
      cheDo: LoginAccountType.customer,
    );
    expect(find.text('Trang Sale của tôi'), findsNothing);
    expect(find.text('Xem trang'), findsNothing);
  });

  testWidgets('số liệu đầu trang lấy từ API, không bịa', (t) async {
    await _dung(t);
    expect(find.text('4.8/5'), findsOneWidget);
    expect(find.text('6 nhận xét'), findsOneWidget);
    expect(find.text('5'), findsOneWidget); // tin đang đăng
  });

  testWidgets('chưa có đánh giá → "Chưa có", không hiện 0.0/5', (t) async {
    await _dung(
      t,
      hoSo: {'name': 'Sale mới', 'review_count': 0, 'listing_count': 0},
    );
    expect(find.text('Chưa có'), findsOneWidget);
    expect(find.textContaining('/5'), findsNothing);
  });

  testWidgets('chưa xác minh → không gắn nhãn "Đã duyệt"', (t) async {
    await _dung(t, hoSo: {'name': 'X', 'verified': false});
    expect(find.text('Đã duyệt'), findsNothing);
    expect(find.textContaining('Chưa xác minh'), findsOneWidget);
  });

  testWidgets('có đăng xuất và yêu cầu xoá tài khoản (Apple 5.1.1)', (t) async {
    await _dung(t);
    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(find.byIcon(Icons.delete_forever), findsOneWidget);
  });

  // ── KHU QUẢN LÝ NHÀ ────────────────────────────────────────────────────────
  //
  // Chỉ hiển thị công cụ của vai đang chọn, độc lập với nhãn tài khoản cũ.
  //
  // CẬP NHẬT 08/09/2026: tab Cá nhân của CHỦ NHÀ nay chính là màn tổng quan
  // quản lý (`HostHomeScreen`), nên mục "Tổng quan quản lý" ở đây đã bỏ — để
  // lại thì chủ nhà mở cài đặt rồi bấm vào, quay về đúng màn vừa rời.

  testWidgets('người bán thường KHÔNG thấy khu quản lý nhà', (t) async {
    await _dung(t, vai: 'guest');
    expect(find.text('QUẢN LÝ NHÀ CHO THUÊ'), findsNothing);
    expect(find.text('Tổng quan quản lý'), findsNothing);
  });

  testWidgets('chủ nhà thấy khu quản lý nhà', (t) async {
    await _dung(t, vai: 'host', cheDo: LoginAccountType.owner);
    expect(find.text('QUẢN LÝ NHÀ CHO THUÊ'), findsOneWidget);
    expect(find.text('Hoá đơn'), findsOneWidget);
  });

  testWidgets('KHÔNG còn lối vào vòng tròn về chính màn tổng quan', (t) async {
    await _dung(t, vai: 'host', cheDo: LoginAccountType.owner);
    expect(find.text('Tổng quan quản lý'), findsNothing);
  });

  testWidgets('lối vào chuyển từ tab Cá nhân sang vẫn còn đủ', (t) async {
    // Bốn mục này TRƯỚC ĐÂY chỉ có trong `ProfileScreen`. Đổi tab Cá nhân
    // thành trang hồ sơ mà quên chúng là mất hẳn đường tới.
    await _dung(t, vai: 'host', cheDo: LoginAccountType.owner);
    expect(find.text('Yêu cầu dịch vụ của tôi'), findsOneWidget);
    expect(find.text('Liên kết với sale'), findsOneWidget);
    expect(find.text('Hoá đơn'), findsOneWidget);
  });

  testWidgets('tài khoản thường chọn Chủ nhà có công cụ cho thuê', (t) async {
    await _dung(
      t,
      vai: 'guest',
      loaiTaiKhoan: 'customer',
      cheDo: LoginAccountType.owner,
    );
    expect(find.text('QUẢN LÝ NHÀ CHO THUÊ'), findsOneWidget);
    expect(find.text('Hoá đơn'), findsOneWidget);
    expect(find.text('Trang Sale của tôi'), findsNothing);
  });

  testWidgets('nhãn chủ nhà cũ không hiện công cụ khi đang chọn Khách', (
    t,
  ) async {
    await _dung(t, vai: 'host', cheDo: LoginAccountType.customer);
    expect(find.text('QUẢN LÝ NHÀ CHO THUÊ'), findsNothing);
    expect(find.text('Trang Sale của tôi'), findsNothing);
  });
}

/// Người bán đã đăng nhập — màn cài đặt đọc tên/SĐT/email từ đây.
class _AuthSale extends AuthProvider {
  _AuthSale(this.vai, this.loaiTaiKhoan, this.cheDo);

  final String vai;
  final String loaiTaiKhoan;
  final LoginAccountType cheDo;

  @override
  LoginAccountType get loginAccountType => cheDo;

  @override
  bool get isAuthenticated => true;

  @override
  UserModel? get currentUser => UserModel(
    id: 4,
    name: 'Lê Quang Vinh',
    email: 'sale1@ancu365.vn',
    passwordHash: '',
    phone: '0908123456',
    avatarPath: '',
    role: vai,
    accountType: loaiTaiKhoan,
  );
}
