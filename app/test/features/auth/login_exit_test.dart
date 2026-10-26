import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/telemetry/telemetry_service.dart';
import 'package:house_booking/features/auth/login_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/auth_provider.dart';

import '../../helpers/pump_app.dart';

/// Khách bấm nhầm vào "Đăng nhập" rồi đổi ý thì phải ra được.
///
/// Màn này không có AppBar, và tới đây bằng redirect (`/host` khi chưa đăng
/// nhập) hay bằng link dán thẳng thì stack rỗng — không có gì để bấm back.
/// Trước khi có nút thoát, cả hai đường đó là ngõ cụt.
Widget _app(GoRouter router) => MultiProvider(
  providers: [
    Provider<TelemetryService>.value(value: TelemetryService()),
    ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
  ],
  child: MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('vi'),
  ),
);

GoRouter _router(String batDau) => GoRouter(
  initialLocation: batDau,
  routes: [
    GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('TRANG CHỦ'))),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
  ],
);

void main() {
  testWidgets('vào thẳng /login (stack rỗng) → nút nhà đưa về trang chủ', (
    tester,
  ) async {
    final r = _router('/login');
    await tester.pumpWidget(_app(r));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.text('TRANG CHỦ'), findsOneWidget);
  });

  testWidgets('/login được push → mũi tên back, quay về màn trước', (
    tester,
  ) async {
    final r = _router('/');
    await tester.pumpWidget(_app(r));
    await tester.pumpAndSettle();

    r.push('/login');
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('TRANG CHỦ'), findsOneWidget);
  });

  testWidgets('coLoiThoat=false (màn này CHÍNH LÀ /) → không vẽ nút thoát', (
    tester,
  ) async {
    await pumpApp(tester, const LoginScreen(coLoiThoat: false));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.home_outlined), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });
}
