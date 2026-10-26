import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/widgets/fb_post_card.dart';

/// Bấm avatar/tên phải mở trang cá nhân, KHÔNG mở bài. Hai vùng bấm lồng nhau
/// nên rất dễ vô tình để card nuốt sự kiện — test này giữ ranh giới đó.
void main() {
  Future<void> dung(WidgetTester t, List<String> ghi) => t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FbPostCard(
          authorName: 'Đỗ Hoa',
          subtitle: 'Nga Sơn · Thanh Hóa',
          body: 'Căn hộ 180m2',
          onTap: () => ghi.add('bai'),
          onTapAuthor: () => ghi.add('nguoi'),
        ),
      ),
    ),
  );

  testWidgets('chạm tên người đăng → mở trang cá nhân, không mở bài', (t) async {
    final ghi = <String>[];
    await dung(t, ghi);
    await t.tap(find.text('Đỗ Hoa'));
    await t.pump();
    expect(ghi, ['nguoi']);
  });

  testWidgets('chạm nội dung bài → mở bài', (t) async {
    final ghi = <String>[];
    await dung(t, ghi);
    await t.tap(find.text('Căn hộ 180m2'));
    await t.pump();
    expect(ghi, ['bai']);
  });

  testWidgets('không truyền onTapAuthor → tên không nuốt cú chạm', (t) async {
    final ghi = <String>[];
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FbPostCard(
            authorName: 'Đỗ Hoa',
            onTap: () => ghi.add('bai'),
          ),
        ),
      ),
    );
    await t.tap(find.text('Đỗ Hoa'));
    await t.pump();
    expect(ghi, ['bai']);
  });
}
