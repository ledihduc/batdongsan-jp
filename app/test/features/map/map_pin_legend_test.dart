import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/features/map/utils/pin_kind.dart';
import 'package:house_booking/features/map/widgets/map_pin_legend.dart';

import '../../helpers/pump_app.dart';

/// Chú giải kiêm bộ lọc loại tin.
///
/// Thứ dễ hỏng nhất: chú giải và MÀU PIN dùng hai bảng phân loại khác nhau —
/// khi đó bỏ tích "Tin bán" lại ẩn nhầm pin cho thuê. [pinKindFor] và
/// `HD.pinColorFor` phải cùng một luật, nên test khoá luật đó lại.
void main() {
  testWidgets('vào bản đồ là chú giải MỞ SẴN', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: MapPinLegend(enabled: {...PinKind.all}, onToggle: (_) {}),
      ),
    );
    await tester.pump();

    // Thấy ngay cả bốn dòng, không phải bấm mở.
    expect(find.text('Tin bán'), findsOneWidget);
    expect(find.text('Cho thuê · ngắn hạn'), findsOneWidget);
  });

  testWidgets('mặc định TÍCH HẾT bốn loại', (tester) async {
    final bat = {...PinKind.all};
    await pumpApp(
      tester,
      Scaffold(
        body: MapPinLegend(enabled: bat, onToggle: (_) {}),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.check), findsNWidgets(4));
  });

  testWidgets('bỏ tích một loại → báo đúng loại đó ra ngoài', (tester) async {
    String? nhan;
    await pumpApp(
      tester,
      Scaffold(
        body: MapPinLegend(
          enabled: {...PinKind.all},
          onToggle: (k) => nhan = k,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Tin bán'));
    expect(nhan, PinKind.sale);
  });

  _testNutGiaiThich();

  testWidgets('dạng gọn chỉ hiện chấm của loại đang bật', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: MapPinLegend(
          enabled: const {PinKind.sale},
          onToggle: (_) {},
        ),
      ),
    );
    await tester.pump();
    // Mặc định là MỞ → thu lại để kiểm dạng gọn.
    await tester.tap(find.text('Chú giải'));
    await tester.pump();

    // 1 chấm (loại đang bật) — không phải 4.
    final chams = find.byWidgetPredicate((w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).shape == BoxShape.circle);
    expect(chams, findsOneWidget);
  });
}

/// Nút "!" giải thích từng loại tin.
///
/// Điều dễ hỏng nhất: nút "!" nằm trong cùng một dòng với ô tích, nên nếu vùng
/// chạm của hai thứ dính vào nhau thì bấm đọc giải thích sẽ vô tình ẩn mất loại
/// pin đó khỏi bản đồ.
void _testNutGiaiThich() {
  testWidgets('bấm "!" KHÔNG bật/tắt loại', (tester) async {
    var soLanToggle = 0;
    await pumpApp(
      tester,
      Scaffold(
        body: MapPinLegend(
          enabled: {...PinKind.all},
          onToggle: (_) => soLanToggle++,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('!').first);
    await tester.pumpAndSettle();

    expect(soLanToggle, 0, reason: 'bấm "!" không được đổi bộ lọc');
    expect(
      find.textContaining('Thuê theo ngày'),
      findsOneWidget,
      reason: 'phải hiện lời giải thích',
    );
  });

  testWidgets('bấm "!" KHÔNG đóng bảng chú giải', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: MapPinLegend(enabled: {...PinKind.all}, onToggle: (_) {}),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('!').first);
    await tester.pumpAndSettle();

    // Bảng vẫn mở: 4 dòng vẫn còn đó.
    expect(find.text('!'), findsNWidgets(4));
    expect(find.text('Tin bán'), findsOneWidget);
  });

  testWidgets('bấm ra ngoài thì lời giải thích tự mất', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: MapPinLegend(
          enabled: {...PinKind.all},
          onToggle: (_) {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('!').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Thuê theo ngày'), findsOneWidget);

    // Chạm một chỗ trống ngoài bảng chú giải.
    await tester.tapAt(const Offset(20, 500));
    await tester.pumpAndSettle();
    expect(find.textContaining('Thuê theo ngày'), findsNothing);
  });

  testWidgets('mỗi loại có lời giải thích RIÊNG', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: MapPinLegend(
          enabled: {...PinKind.all},
          onToggle: (_) {},
        ),
      ),
    );
    await tester.pump();

    // Dòng cuối là "Tin bán".
    await tester.tap(find.text('!').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('sở hữu và sử dụng lâu dài'), findsOneWidget);
  });
}
