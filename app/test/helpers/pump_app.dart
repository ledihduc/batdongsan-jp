import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:house_booking/core/telemetry/telemetry_service.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/providers/auth_provider.dart';

import 'tile_provider_gia.dart';

/// Bọc widget bằng ĐÚNG những provider mà `main.dart` cung cấp ở gốc cây.
///
/// Vì sao cần: nhiều widget gọi `Provider.of<TelemetryService>(context)` để ghi
/// nhận sự kiện. Khi một widget thêm phụ thuộc như vậy, mọi widget test dựng nó
/// trần sẽ ném `ProviderNotFoundException` — lỗi hạ tầng test, không phải lỗi
/// sản phẩm. Gom vào một chỗ để lần sau thêm provider mới chỉ phải sửa 1 file.
///
/// [extraProviders] để bơm thêm provider riêng của từng màn (vd DrillProvider).
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<SingleChildWidget> extraProviders = const [],
  TelemetryService? telemetry,
  AuthProvider? auth,
  NavigatorObserver? navigatorObserver,
}) async {
  // Bản đồ trong test KHÔNG được đi mạng: provider tile thật chạy trên dio,
  // để lại timer treo và làm đỏ mọi test có bản đồ. Xem tile_provider_gia.dart.
  dungTileGiaChoTest();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<TelemetryService>.value(value: telemetry ?? TelemetryService()),
        // GuestGate.requireAuth() đọc provider này ở MỌI hành động cá nhân
        // (lưu, bình luận, báo cáo…). Thiếu nó thì widget test ném
        // ProviderNotFoundException ngay khi chạm nút đầu tiên.
        ChangeNotifierProvider<AuthProvider>.value(value: auth ?? AuthProvider()),
        ...extraProviders,
      ],
      child: MaterialApp(
        // Nhiều màn giờ gọi AppLocalizations.of(context); thiếu delegate thì
        // widget test ném null. Bơm delegate + GHIM locale VI: test mặc định
        // chạy locale en-US → sẽ render bản dịch tiếng Anh, trong khi assertion
        // viết bằng tiếng Việt. Ghim 'vi' để khớp hành vi app thật (mặc định VI).
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('vi'),
        home: child,
        navigatorObservers: [if (navigatorObserver != null) navigatorObserver],
      ),
    ),
  );
}

/// Biến thể khi widget cần tự dựng Scaffold/Navigator riêng (vd bottom sheet).
Future<void> pumpAppRaw(
  WidgetTester tester,
  Widget app, {
  List<SingleChildWidget> extraProviders = const [],
  TelemetryService? telemetry,
}) async {
  // Bản đồ trong test KHÔNG được đi mạng: provider tile thật chạy trên dio,
  // để lại timer treo và làm đỏ mọi test có bản đồ. Xem tile_provider_gia.dart.
  dungTileGiaChoTest();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<TelemetryService>.value(value: telemetry ?? TelemetryService()),
        ...extraProviders,
      ],
      child: app,
    ),
  );
}


/// AuthProvider giả ở trạng thái ĐÃ ĐĂNG NHẬP.
///
/// `AuthProvider()` mặc định là khách (chưa đăng nhập), nên mọi hành động cá
/// nhân sẽ bị `GuestGate` chặn và test không chạm được tới logic thật. Dùng
/// bản này cho test hành động; dùng `AuthProvider()` khi muốn test đúng đường
/// khách bị chặn.
class SignedInAuthProvider extends AuthProvider {
  SignedInAuthProvider({this.id, this.ten = 'Người dùng thử'});

  /// Id tài khoản đang đăng nhập. Cần cho những màn hỏi "người đang xem có
  /// phải chính chủ không" — vd trang dự án không được mời sale nhắn tin cho
  /// chính mình.
  final int? id;
  final String ten;

  @override
  bool get isAuthenticated => true;

  @override
  UserModel? get currentUser => id == null
      ? super.currentUser
      : UserModel(
          id: id,
          name: ten,
          email: 'u$id@test.local',
          passwordHash: '',
          phone: '',
          avatarPath: '',
          role: 'guest',
        );
}
