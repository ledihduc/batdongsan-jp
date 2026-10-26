import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/core/widgets/nav_tap_bounce.dart';

/// Hiệu ứng nảy của icon thanh điều hướng.
///
/// Điều dễ hỏng nhất: quên đổi key thì lần chọn THỨ HAI trở đi không nảy nữa,
/// vì tween đã nằm sẵn ở đích. Lỗi này không lộ ra ở lần thử đầu tiên.
double _tiLe(WidgetTester t) {
  final tf = t.widget<Transform>(
    find.descendant(
      of: find.byType(NavTapBounce),
      matching: find.byType(Transform),
    ),
  );
  // Đọc thẳng hệ số trục X. `getMaxScaleOnAxis` vô dụng ở đây: khi thu nhỏ,
  // trục z vẫn là 1 nên nó luôn trả về 1 và test không bao giờ đỏ.
  return tf.transform.entry(0, 0);
}

void main() {
  testWidgets('được chọn thì bắt đầu NHỎ rồi lớn dần về 1', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: NavTapBounce(selected: true, child: Icon(Icons.home)),
    ));
    await t.pump();
    expect(_tiLe(t), lessThan(1.0), reason: 'phải bắt đầu nhỏ hơn');

    await t.pumpAndSettle();
    expect(_tiLe(t), closeTo(1.0, 0.001), reason: 'phải kết thúc đúng cỡ thật');
  });

  testWidgets('được chọn thì NHÔ LÊN và ở lại trên cao', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: NavTapBounce(selected: true, child: Icon(Icons.home)),
    ));
    await t.pumpAndSettle();

    final tf = t.widget<Transform>(
      find.descendant(
        of: find.byType(NavTapBounce),
        matching: find.byType(Transform),
      ),
    );
    // entry(1,3) = dịch chuyển theo trục Y. Âm = nhô lên.
    expect(tf.transform.entry(1, 3), lessThan(0));
  });

  testWidgets('bỏ chọn thì KHÔNG nhô — đứng đúng đường cơ sở', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: NavTapBounce(selected: false, child: Icon(Icons.home)),
    ));
    await t.pumpAndSettle();

    final tf = t.widget<Transform>(
      find.descendant(
        of: find.byType(NavTapBounce),
        matching: find.byType(Transform),
      ),
    );
    expect(tf.transform.entry(1, 3), 0);
  });

  testWidgets('KHÔNG nảy khi đang ở trạng thái bỏ chọn', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: NavTapBounce(selected: false, child: Icon(Icons.home)),
    ));
    await t.pump();
    // Cả năm icon cùng nhúc nhích mỗi lần đổi tab là nhiễu, không phải phản hồi.
    expect(_tiLe(t), closeTo(1.0, 0.001));
  });

  testWidgets('chọn LẠI lần nữa vẫn nảy — key phải đổi', (t) async {
    Widget dung(bool chon) => MaterialApp(
          home: NavTapBounce(selected: chon, child: const Icon(Icons.home)),
        );

    await t.pumpWidget(dung(true));
    await t.pumpAndSettle();

    await t.pumpWidget(dung(false));
    await t.pumpAndSettle();

    await t.pumpWidget(dung(true));
    await t.pump();
    expect(_tiLe(t), lessThan(1.0), reason: 'lần chọn sau vẫn phải nảy');
  });
}
