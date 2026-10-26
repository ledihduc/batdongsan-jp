/// Dấu "vị trí của tôi" phải KHÁC HÌNH với pin tin đăng.
///
/// Bốn màu pin đã dùng hết xanh lá · cam · xanh dương · đỏ, nên bất kỳ ai sau
/// này "sửa cho dễ nhìn" bằng cách đổi lại thành chấm tròn màu khác đều đang
/// quay về đúng chỗ nhầm lẫn cũ. Test này giữ điều đó: hình chữ thập, không
/// phải đĩa tròn.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/core/widgets/marker_vi_tri_toi.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('là chữ thập định vị, KHÔNG phải chấm tròn', (t) async {
    await pumpApp(t, const Scaffold(body: Center(child: MarkerViTriToi())));
    await t.pumpAndSettle();

    expect(find.byIcon(Icons.my_location), findsWidgets);
    // Không có Container bo tròn nào — đó là hình của pin tin đăng.
    final tron = find.byWidgetPredicate((w) {
      if (w is! Container) return false;
      final d = w.decoration;
      return d is BoxDecoration && d.shape == BoxShape.circle;
    });
    expect(tron, findsNothing);
  });

  testWidgets('vẽ HAI lớp để đọc được trên cả nền sáng lẫn nền tối', (t) async {
    await pumpApp(t, const Scaffold(body: Center(child: MarkerViTriToi())));
    await t.pumpAndSettle();

    final icons = t
        .widgetList<Icon>(find.byIcon(Icons.my_location))
        .toList();
    expect(icons.length, 2);
    // Lớp trắng phải TO HƠN thì mới thành viền; bằng nhau là mất viền.
    final trang = icons.firstWhere((i) => i.color == Colors.white);
    final dam = icons.firstWhere((i) => i.color != Colors.white);
    expect(trang.size! > dam.size!, isTrue);
  });

  testWidgets('hopCho() chừa chỗ cho viền, không cắt cụt', (t) async {
    expect(MarkerViTriToi.hopCho(20) > 20, isTrue);
  });
}
