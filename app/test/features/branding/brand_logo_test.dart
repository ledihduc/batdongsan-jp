/// Khoá việc LOGO CÓ MẶT trên các màn ấn tượng đầu.
///
/// Vì sao có test này: tệp logo nằm sẵn trong `assets/` suốt một thời gian dài
/// mà KHÔNG widget nào đọc — mọi màn chỉ dựng wordmark bằng chữ, nên mở app lên
/// không thấy logo ở đâu. Không có gì trong bộ test bắt được, phải người dùng
/// báo mới biết. Test này khẳng định ảnh logo thực sự được dựng, chứ không chỉ
/// nằm trong pubspec.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/core/widgets/brand_logo.dart';
import 'package:house_booking/features/auth/splash_screen.dart';
import 'package:house_booking/features/onboarding/onboarding_screen.dart';

import '../../helpers/pump_app.dart';

/// Đường dẫn asset mà [BrandLogo] nạp — trùng với khai báo trong `pubspec.yaml`
/// và với đầu ra của `tools/gen_brand_icons.py`.
const _assetFull = 'assets/branding/logo_full.png';
const _assetMark = 'assets/branding/logo_mark.png';

/// Tìm `Image` đang trỏ vào một asset cụ thể.
Finder anhAsset(String key) => find.byWidgetPredicate(
  (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == key,
);

void main() {
  setUpAll(() {
    // Onboarding đọc/ghi prefs qua flutter_secure_storage; trả rỗng để không treo.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'readAll' ? <String, String>{} : null,
    );
  });

  group('BrandLogo', () {
    testWidgets('bản đầy đủ nạp đúng asset logo', (tester) async {
      await pumpApp(tester, const Center(child: BrandLogo.full(size: 96)));
      expect(anhAsset(_assetFull), findsOneWidget);
    });

    testWidgets('bản ghim nạp đúng asset ghim', (tester) async {
      await pumpApp(tester, const Center(child: BrandLogo.mark(size: 24)));
      expect(anhAsset(_assetMark), findsOneWidget);
    });

    testWidgets('trên nền đậm thì ghim được lót ô cream cho khỏi chìm',
        (tester) async {
      await pumpApp(
        tester,
        const ColoredBox(
          color: Color(0xFFE31B23),
          child: Center(child: BrandLogo.mark(size: 40, onDark: true)),
        ),
      );
      expect(anhAsset(_assetMark), findsOneWidget);
      final box = tester.widget<Container>(
        find.ancestor(of: anhAsset(_assetMark), matching: find.byType(Container)).first,
      );
      expect((box.decoration! as BoxDecoration).color, isNotNull);
    });
  });

  group('Logo có mặt ở màn ấn tượng đầu', () {
    testWidgets('splash', (tester) async {
      await pumpApp(tester, const SplashScreen());
      expect(anhAsset(_assetFull), findsOneWidget);
    });

    testWidgets('onboarding — slide chào mừng', (tester) async {
      await pumpApp(tester, OnboardingScreen(onFinish: () {}));
      await tester.pump();
      expect(anhAsset(_assetFull), findsOneWidget);
    });
  });
}
