/// Test khoá màn onboarding mới (giới thiệu 2 thế giới). Onboarding trước đây
/// KHÔNG có test. Khẳng định: 3 slide; slide đầu định vị 2 thế giới; lướt sang
/// thấy chức năng chính mỗi bên; slide cuối nút "Bắt đầu" gọi onFinish; KHÔNG
/// giới thiệu chức năng đã tắt (mua/bán) hay chưa có luồng khách (đặt homestay).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/features/onboarding/onboarding_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null, // write cờ onboarding_done → nuốt, không cần lưu thật
    );
  });

  Future<void> pump(WidgetTester tester, {VoidCallback? onFinish}) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: OnboardingScreen(onFinish: onFinish ?? () {}),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('slide đầu định vị 2 thế giới BĐS + Xây dựng', (tester) async {
    await pump(tester);
    expect(find.text('Bất động sản'), findsOneWidget);
    expect(find.text('Xây dựng'), findsOneWidget);
    // Nút điều hướng đầu là "Tiếp theo", chưa phải "Bắt đầu".
    expect(find.text('Tiếp theo'), findsOneWidget);
    expect(find.text('Bắt đầu'), findsNothing);
  });

  testWidgets('lướt tới slide BĐS + Xây dựng thấy chức năng chính',
      (tester) async {
    await pump(tester);
    // Slide 2 — BĐS.
    await tester.tap(find.text('Tiếp theo'));
    await tester.pumpAndSettle();
    expect(find.text('Tìm nhà'), findsOneWidget);
    expect(find.text('Quản lý nhà trọ'), findsOneWidget);
    // KHÔNG hứa suông: không có mua/bán, không có đặt homestay.
    expect(find.textContaining('Mua'), findsNothing);
    expect(find.textContaining('homestay'), findsNothing);

    // Slide 3 — Xây dựng.
    await tester.tap(find.text('Tiếp theo'));
    await tester.pumpAndSettle();
    expect(find.text('Thiết kế'), findsOneWidget);
    expect(find.text('Mẫu nhà đẹp'), findsOneWidget);
    // Slide cuối → nút "Bắt đầu".
    expect(find.text('Bắt đầu'), findsOneWidget);
  });

  testWidgets('nút Bắt đầu ở slide cuối gọi onFinish', (tester) async {
    var done = false;
    await pump(tester, onFinish: () => done = true);
    await tester.tap(find.text('Tiếp theo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp theo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
  });

  testWidgets('nút Bỏ qua gọi onFinish ngay', (tester) async {
    var done = false;
    await pump(tester, onFinish: () => done = true);
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
  });
}
