/// Test khoá nút Đăng xuất khi màn gọi nằm TRONG Navigator lồng (như _TabNavigator
/// của GuestShell). Bug đã sửa: hộp thoại xác nhận của logoutFlow được push lên
/// Navigator GỐC (showDialog useRootNavigator mặc định true) nhưng nút bấm pop
/// bằng `context` ngoài — Navigator gần nhất của nó là Navigator LỒNG → pop nhắm
/// nhầm, hộp thoại không đóng, `await showDialog` treo, logout không chạy. Triệu
/// chứng: bấm Đăng xuất "không có gì xảy ra" (kể cả ẩn danh — lỗi thuần code).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/telemetry/telemetry_service.dart';
import 'package:house_booking/features/guest/profile/settings_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/chat_provider.dart';
import 'package:house_booking/providers/notification_provider.dart';
import 'package:house_booking/providers/wishlist_provider.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'readAll' ? <String, String>{} : null,
    );
  });

  // Trang có nút gọi logoutFlow, nhưng ĐẶT TRONG một Navigator lồng để tái hiện
  // đúng ngữ cảnh _TabNavigator của GuestShell (dialog ở root, context ở nhánh).
  Widget trigger() => Navigator(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (inner) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => logoutFlow(inner),
                child: const Text('nút đăng xuất'),
              ),
            ),
          ),
        ),
      );

  Widget buildApp() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => trigger()),
        GoRoute(
          path: '/login',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('MÀN ĐĂNG NHẬP'))),
        ),
      ],
    );
    return MultiProvider(
      providers: [
        Provider<TelemetryService>.value(value: TelemetryService()),
        ChangeNotifierProvider<AuthProvider>.value(value: SignedInAuthProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('vi'),
        routerConfig: router,
      ),
    );
  }

  testWidgets('xác nhận Đăng xuất → hộp thoại đóng và điều hướng về /login',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('nút đăng xuất'));
    await tester.pumpAndSettle();
    // Hộp thoại xác nhận hiện (title "Đăng xuất").
    expect(find.text('MÀN ĐĂNG NHẬP'), findsNothing);

    // Bấm nút "Đăng xuất" trong hộp thoại (nút đỏ — nhãn trùng title, lấy .last).
    await tester.tap(find.text('Đăng xuất').last);
    await tester.pumpAndSettle();

    // Sau fix: điều hướng về /login. Trước fix: hộp thoại treo, không tới đây.
    expect(find.text('MÀN ĐĂNG NHẬP'), findsOneWidget,
        reason: 'logout phải đóng hộp thoại và đưa về màn đăng nhập');
  });
}
