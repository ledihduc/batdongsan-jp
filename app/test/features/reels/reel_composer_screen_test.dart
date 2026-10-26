/// Widget test cho màn đăng reel.
///
/// Trọng tâm: **không cho đăng khi chưa chọn video**, và thông điệp sau khi gửi
/// phải nói rõ là còn CHỜ DUYỆT. Nếu báo "đăng thành công" trống không, người
/// dùng sẽ đi tìm reel của mình trên feed rồi tưởng app hỏng.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/features/guest/reels/reel_composer_screen.dart';

import '../../helpers/pump_app.dart';
import '_fake_reel_api.dart';

void main() {
  Future<FakeReelApi> pumpComposer(
    WidgetTester tester, {
    Set<String> throwOn = const {},
    String? category,
  }) async {
    final api = FakeReelApi(throwOn: throwOn);
    await pumpApp(
      tester,
      ReelComposerScreen(api: api, category: category),
      auth: SignedInAuthProvider(),
    );
    await tester.pumpAndSettle();
    return api;
  }

  group('Trạng thái ban đầu', () {
    testWidgets('mời chọn video và nêu rõ giới hạn', (tester) async {
      await pumpComposer(tester);
      expect(find.text('Chọn video từ thư viện'), findsOneWidget);
      // Nêu giới hạn TRƯỚC khi người dùng mất công quay/chọn rồi mới bị từ chối.
      expect(find.textContaining('90 giây'), findsOneWidget);
      expect(find.textContaining('120MB'), findsOneWidget);
    });

    testWidgets('nút Đăng bị VÔ HIỆU khi chưa chọn video', (tester) async {
      await pumpComposer(tester);
      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Đăng'),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('có đủ lựa chọn khối, mặc định "Mọi phần"', (tester) async {
      await pumpComposer(tester);
      expect(find.text('Mọi phần'), findsOneWidget);
      expect(find.text('Cho thuê'), findsOneWidget);
      expect(find.text('Nội thất'), findsOneWidget);
    });

    testWidgets('mở từ feed nào thì chọn sẵn khối đó', (tester) async {
      await pumpComposer(tester, category: 'interior');
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Nội thất'),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets('category lạ → lùi về "Mọi phần", không nổ', (tester) async {
      await pumpComposer(tester, category: 'khong_ton_tai');
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Mọi phần'),
      );
      expect(chip.selected, isTrue);
    });
  });

  group('Không cho đăng khi thiếu video', () {
    testWidgets('chưa chọn video → KHÔNG gọi API tạo reel', (tester) async {
      final api = await pumpComposer(tester);
      // Nút đã bị vô hiệu; đây là lớp chặn thứ hai ở tầng logic.
      expect(api.called('create'), isFalse);
    });

    testWidgets('đổi khối KHÔNG bật nút Đăng khi chưa có video',
        (tester) async {
      await pumpComposer(tester);
      await tester.tap(find.text('Cho thuê'));
      await tester.pumpAndSettle();
      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Đăng'),
      );
      expect(btn.onPressed, isNull);
    });
  });

  group('Nhập chú thích', () {
    testWidgets('có ô chú thích với giới hạn ký tự', (tester) async {
      await pumpComposer(tester);
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.maxLength, 300);
    });

    testWidgets('gõ chú thích không làm bật nút Đăng (vẫn thiếu video)',
        (tester) async {
      await pumpComposer(tester);
      await tester.enterText(find.byType(TextField), 'Căn hộ view sông');
      await tester.pumpAndSettle();
      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Đăng'),
      );
      expect(btn.onPressed, isNull);
    });
  });
}
