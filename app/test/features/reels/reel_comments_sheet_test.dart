/// Widget test cho sheet bình luận reel.
///
/// Trọng tâm: dựng cây trả lời từ danh sách PHẲNG mà backend trả về. Đây là
/// chỗ dễ sai nhất — backend gửi `parent_id`, widget phải tự gom thành gốc +
/// replies. Gom sai thì bình luận trả lời nhảy lung tung hoặc biến mất.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/features/guest/reels/reel_comments_sheet.dart';

import '../../helpers/pump_app.dart';
import '_fake_reel_api.dart';

void main() {
  Future<FakeReelApi> pumpSheet(
    WidgetTester tester, {
    List<Map<String, dynamic>> comments = const [],
    Set<String> throwOn = const {},
    void Function(int)? onCountChanged,
    bool signedIn = true,
  }) async {
    final api = FakeReelApi(commentsResult: comments, throwOn: throwOn);
    await pumpApp(
      tester,
      Scaffold(
        body: ReelCommentsSheet(
          reelId: 5,
          api: api,
          onCountChanged: onCountChanged,
        ),
      ),
      auth: signedIn ? SignedInAuthProvider() : null,
    );
    await tester.pumpAndSettle();
    return api;
  }

  group('Tải danh sách', () {
    testWidgets('gọi API đúng reel khi mở sheet', (tester) async {
      final api = await pumpSheet(tester);
      expect(api.argsOf('comments'), [5]);
    });

    testWidgets('chưa có bình luận → hiện lời mời, không hiện lỗi',
        (tester) async {
      await pumpSheet(tester);
      expect(find.textContaining('Chưa có bình luận'), findsOneWidget);
      expect(find.text('0 bình luận'), findsOneWidget);
    });

    testWidgets('API lỗi → báo lỗi tử tế, KHÔNG màn hình trắng', (tester) async {
      await pumpSheet(tester, throwOn: {'comments'});
      expect(find.textContaining('Không tải được'), findsOneWidget);
    });

    testWidgets('hiện đúng số lượng và nội dung', (tester) async {
      await pumpSheet(tester, comments: [
        fakeComment(id: 1, content: 'Còn phòng không ạ?'),
        fakeComment(id: 2, content: 'Giá bao nhiêu?'),
      ]);
      expect(find.text('2 bình luận'), findsOneWidget);
      expect(find.text('Còn phòng không ạ?'), findsOneWidget);
      expect(find.text('Giá bao nhiêu?'), findsOneWidget);
    });

    testWidgets('báo số lượng ngược lên màn cha', (tester) async {
      int? reported;
      await pumpSheet(
        tester,
        comments: [fakeComment(id: 1), fakeComment(id: 2), fakeComment(id: 3)],
        onCountChanged: (n) => reported = n,
      );
      expect(reported, 3, reason: 'màn cha cần số này để cập nhật thẻ reel');
    });
  });

  group('Dựng cây trả lời từ danh sách phẳng', () {
    testWidgets('reply hiển thị dưới đúng bình luận gốc', (tester) async {
      await pumpSheet(tester, comments: [
        fakeComment(id: 1, content: 'gốc A', replyCount: 1),
        fakeComment(id: 2, content: 'gốc B'),
        fakeComment(id: 3, content: 'trả lời A', parentId: 1),
      ]);
      // Cả 3 đều phải hiện — reply KHÔNG được rơi mất khi gom cây.
      expect(find.text('gốc A'), findsOneWidget);
      expect(find.text('gốc B'), findsOneWidget);
      expect(find.text('trả lời A'), findsOneWidget);
    });

    testWidgets('reply mồ côi (parent không tồn tại) không làm vỡ sheet',
        (tester) async {
      // Xảy ra thật khi bình luận gốc bị xoá cứng giữa 2 lần tải.
      await pumpSheet(tester, comments: [
        fakeComment(id: 1, content: 'gốc'),
        fakeComment(id: 9, content: 'mồ côi', parentId: 404),
      ]);
      expect(find.text('gốc'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bình luận đã xoá hiện bia mộ, KHÔNG hiện nội dung cũ',
        (tester) async {
      await pumpSheet(tester, comments: [
        fakeComment(id: 1, content: 'nội dung nhạy cảm', isDeleted: true),
      ]);
      expect(find.text('Bình luận đã bị xoá'), findsOneWidget);
      expect(find.text('nội dung nhạy cảm'), findsNothing);
    });

    testWidgets('bình luận đã xoá KHÔNG cho trả lời/xoá tiếp', (tester) async {
      await pumpSheet(tester, comments: [
        fakeComment(id: 1, content: 'x', isDeleted: true),
      ]);
      expect(find.text('Trả lời'), findsNothing);
      expect(find.text('Xoá'), findsNothing);
    });
  });

  group('Gửi bình luận', () {
    testWidgets('nội dung rỗng KHÔNG gọi API', (tester) async {
      final api = await pumpSheet(tester);
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      expect(api.called('addComment'), isFalse);
    });

    testWidgets('chỉ có khoảng trắng cũng KHÔNG gọi API', (tester) async {
      final api = await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), '    ');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      expect(api.called('addComment'), isFalse);
    });

    testWidgets('cắt khoảng trắng thừa trước khi gửi', (tester) async {
      final api = await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), '  xin chào  ');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(api.argsOf('addComment')?[1], 'xin chào');
    });

    testWidgets('gửi xong thì TẢI LẠI danh sách', (tester) async {
      // Không tải lại thì người dùng không thấy bình luận mình vừa gửi.
      final api = await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), 'test');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(api.countOf('comments'), 2, reason: 'lần đầu + lần tải lại');
    });

    testWidgets('gửi xong thì XOÁ ô nhập', (tester) async {
      await pumpSheet(tester);
      await tester.enterText(find.byType(TextField), 'test');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      final f = tester.widget<TextField>(find.byType(TextField));
      expect(f.controller?.text, isEmpty);
    });
  });

  group('Trả lời', () {
    testWidgets('bấm Trả lời → hiện thanh "Đang trả lời"', (tester) async {
      await pumpSheet(tester, comments: [
        fakeComment(id: 1, content: 'gốc', authorName: 'Chị Lan'),
      ]);
      await tester.tap(find.text('Trả lời'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đang trả lời'), findsOneWidget);
      expect(find.textContaining('Chị Lan'), findsWidgets);
    });

    testWidgets('gửi kèm parent_id đúng bình luận đang trả lời',
        (tester) async {
      final api = await pumpSheet(tester, comments: [
        fakeComment(id: 42, content: 'gốc'),
      ]);
      await tester.tap(find.text('Trả lời'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'trả lời đây');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(api.argsOf('addComment')?[2], 42);
    });

    testWidgets('huỷ trả lời → quay về bình luận gốc (parent_id null)',
        (tester) async {
      final api = await pumpSheet(tester, comments: [
        fakeComment(id: 42, content: 'gốc'),
      ]);
      await tester.tap(find.text('Trả lời'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đang trả lời'), findsNothing);

      await tester.enterText(find.byType(TextField), 'bình luận thường');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(api.argsOf('addComment')?[2], isNull);
    });

    testWidgets('reply KHÔNG có nút Trả lời — tránh cây quá sâu',
        (tester) async {
      await pumpSheet(tester, comments: [
        fakeComment(id: 1, content: 'gốc', replyCount: 1),
        fakeComment(id: 2, content: 'reply', parentId: 1),
      ]);
      // Chỉ bình luận gốc mới được trả lời → đúng 1 nút.
      expect(find.text('Trả lời'), findsOneWidget);
    });
  });

  group('Xoá bình luận', () {
    testWidgets('hỏi xác nhận trước khi xoá', (tester) async {
      final api = await pumpSheet(tester, comments: [fakeComment(id: 1)]);
      await tester.tap(find.text('Xoá'));
      await tester.pumpAndSettle();
      expect(find.text('Xoá bình luận?'), findsOneWidget);
      expect(api.called('deleteComment'), isFalse, reason: 'chưa xác nhận');
    });

    testWidgets('bấm Hủy → KHÔNG xoá', (tester) async {
      final api = await pumpSheet(tester, comments: [fakeComment(id: 1)]);
      await tester.tap(find.text('Xoá'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(api.called('deleteComment'), isFalse);
    });

    testWidgets('xác nhận → gọi API đúng id rồi tải lại', (tester) async {
      final api = await pumpSheet(tester, comments: [fakeComment(id: 77)]);
      await tester.tap(find.text('Xoá'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xoá'));
      await tester.pumpAndSettle();
      expect(api.argsOf('deleteComment'), [77]);
      expect(api.countOf('comments'), 2);
    });
  });
}
