/// FbPostCard — khung bài đăng dùng chung cho MỌI feed.
///
/// Bất biến quan trọng nhất ở đây KHÔNG phải là "trông giống Facebook" (không
/// test được bằng widget test) mà là: **không vẽ nút bấm vào chẳng xảy ra gì**.
/// Tin BĐS không có like/bình luận trong model, nên card BĐS phải dùng bộ nút
/// riêng. Nếu ai đó lỡ bỏ tham số `actions`, test dưới đây đỏ.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/core/widgets/fb_post_card.dart';

void main() {
  Future<void> dung(WidgetTester t, Widget w) => t.pumpWidget(
        MaterialApp(home: Scaffold(body: SingleChildScrollView(child: w))),
      );

  group('Nội dung bài', () {
    testWidgets('hiện tên người đăng và nội dung', (t) async {
      await dung(t, const FbPostCard(authorName: 'Nguyễn An', body: 'Xin chào'));
      expect(find.text('Nguyễn An'), findsOneWidget);
      expect(find.text('Xin chào'), findsOneWidget);
    });

    testWidgets('nội dung rỗng thì KHÔNG chừa khoảng trắng thừa', (t) async {
      await dung(t, const FbPostCard(authorName: 'A', body: '   '));
      expect(find.text('   '), findsNothing);
    });

    testWidgets('dòng phụ hiện dưới tên', (t) async {
      await dung(t,
          const FbPostCard(authorName: 'A', subtitle: '3 giờ · Quận 7'));
      expect(find.text('3 giờ · Quận 7'), findsOneWidget);
    });
  });

  group('Avatar', () {
    testWidgets('không có ảnh → hiện chữ cái đầu', (t) async {
      await dung(t, const FbPostCard(authorName: 'nguyễn an'));
      expect(find.text('N'), findsOneWidget);
    });

    testWidgets('tên rỗng → hiện "?" chứ không nổ', (t) async {
      await dung(t, const FbPostCard(authorName: ''));
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('tên bắt đầu bằng chữ có dấu vẫn lấy đúng ký tự', (t) async {
      // 'Đ' là một ký tự — nếu cắt theo byte sẽ ra ký tự hỏng.
      await dung(t, const FbPostCard(authorName: 'Đức'));
      expect(find.text('Đ'), findsOneWidget);
    });
  });

  group('Hàng đếm tương tác', () {
    testWidgets('cả hai bằng 0 → ẩn hẳn hàng đếm', (t) async {
      await dung(t, const FbPostCard(authorName: 'A'));
      expect(find.textContaining('bình luận'), findsNothing);
    });

    testWidgets('có like thì hiện số', (t) async {
      await dung(t, const FbPostCard(authorName: 'A', likeCount: 12));
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('có bình luận thì hiện "N bình luận"', (t) async {
      await dung(t, const FbPostCard(authorName: 'A', commentCount: 3));
      expect(find.text('3 bình luận'), findsOneWidget);
    });
  });

  group('Hàng nút mặc định', () {
    testWidgets('mặc định là bộ ba của Facebook', (t) async {
      await dung(t, const FbPostCard(authorName: 'A'));
      expect(find.text('Thích'), findsOneWidget);
      expect(find.text('Bình luận'), findsOneWidget);
      expect(find.text('Chia sẻ'), findsOneWidget);
    });

    testWidgets('bấm Thích gọi đúng callback', (t) async {
      var dem = 0;
      await dung(
          t, FbPostCard(authorName: 'A', onLike: () => dem++));
      await t.tap(find.text('Thích'));
      expect(dem, 1);
    });

    testWidgets('đã thích → icon đặc, chưa thích → icon rỗng', (t) async {
      await dung(t, const FbPostCard(authorName: 'A', liked: true));
      expect(find.byIcon(Icons.thumb_up), findsWidgets);

      await dung(t, const FbPostCard(authorName: 'A', liked: false));
      expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
    });
  });

  group('Hàng nút TUỲ BIẾN — lý do chính tệp test này tồn tại', () {
    testWidgets('truyền actions thì KHÔNG còn nút Thích/Bình luận', (t) async {
      // Card tin BĐS: model không có like/comment. Vẽ nút Thích lên đó là tạo
      // một nút bấm vào không xảy ra gì.
      await dung(
        t,
        FbPostCard(
          authorName: 'Chủ nhà',
          actions: [
            FbAction(icon: Icons.favorite_border, nhan: 'Lưu', onTap: () {}),
            FbAction(
                icon: Icons.chat_bubble_outline, nhan: 'Liên hệ', onTap: () {}),
            FbAction(icon: Icons.arrow_forward, nhan: 'Chi tiết', onTap: () {}),
          ],
        ),
      );
      expect(find.text('Lưu'), findsOneWidget);
      expect(find.text('Liên hệ'), findsOneWidget);
      expect(find.text('Chi tiết'), findsOneWidget);
      expect(find.text('Thích'), findsNothing,
          reason: 'tin BĐS không có like — không được vẽ nút này');
      expect(find.text('Bình luận'), findsNothing);
    });

    testWidgets('mỗi nút tuỳ biến gọi đúng callback của nó', (t) async {
      final goi = <String>[];
      await dung(
        t,
        FbPostCard(
          authorName: 'A',
          actions: [
            FbAction(
                icon: Icons.favorite_border,
                nhan: 'Lưu',
                onTap: () => goi.add('luu')),
            FbAction(
                icon: Icons.arrow_forward,
                nhan: 'Chi tiết',
                onTap: () => goi.add('chi-tiet')),
          ],
        ),
      );
      await t.tap(find.text('Chi tiết'));
      await t.tap(find.text('Lưu'));
      expect(goi, ['chi-tiet', 'luu']);
    });
  });

  group('Menu ⋯', () {
    testWidgets('không truyền onMore → KHÔNG hiện nút', (t) async {
      await dung(t, const FbPostCard(authorName: 'A'));
      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });

    testWidgets('có onMore → hiện và bấm được', (t) async {
      var mo = 0;
      await dung(t, FbPostCard(authorName: 'A', onMore: () => mo++));
      await t.tap(find.byIcon(Icons.more_horiz));
      expect(mo, 1);
    });
  });

  group('Ô soạn bài', () {
    testWidgets('hiện gợi ý và bấm được', (t) async {
      var mo = 0;
      await dung(
        t,
        FbComposerBar(onTap: () => mo++, goiY: 'Bạn đang nghĩ gì?'),
      );
      expect(find.text('Bạn đang nghĩ gì?'), findsOneWidget);
      await t.tap(find.text('Bạn đang nghĩ gì?'));
      expect(mo, 1);
    });

    testWidgets('không có actions → không vẽ đường kẻ thừa', (t) async {
      await dung(t, FbComposerBar(onTap: () {}));
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('có actions thì hiện đủ', (t) async {
      await dung(
        t,
        FbComposerBar(onTap: () {}, actions: [
          FbComposerAction(
              icon: Icons.add, nhan: 'Đăng tin', mau: Colors.blue, onTap: () {}),
          FbComposerAction(
              icon: Icons.videocam, nhan: 'Reel', mau: Colors.red, onTap: () {}),
        ]),
      );
      expect(find.text('Đăng tin'), findsOneWidget);
      expect(find.text('Reel'), findsOneWidget);
    });
  });
}
