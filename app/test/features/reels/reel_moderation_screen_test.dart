/// Widget test cho màn kiểm duyệt reel (admin).
///
/// Đây là màn quyết định nội dung nào được lên sóng, nên trọng tâm là:
/// KHÔNG cho từ chối mà thiếu lý do (user bị từ chối phải biết vì sao, nếu
/// không họ sẽ đăng lại y hệt), và dải số liệu phải cảnh báo khi pipeline hỏng.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/features/admin/reel_moderation_screen.dart';

import '../../helpers/pump_app.dart';
import '_fake_reel_api.dart';

Map<String, dynamic> _queued({
  int id = 1,
  String caption = 'Reel chờ duyệt',
  String status = 'pending',
  int reportCount = 0,
  String? rejectReason,
}) =>
    {
      'id': id,
      'caption': caption,
      'status': status,
      'category': 'lease',
      'thumbnail_url': null,
      'video_url': '/uploads/v.mp4',
      'report_count': reportCount,
      'reject_reason': rejectReason,
      'author_name': 'Chị Hoa',
      'created_at': '2026-07-18T10:00:00',
    };

void main() {
  Future<FakeReelApi> pumpScreen(
    WidgetTester tester, {
    List<Map<String, dynamic>> queue = const [],
    Map<String, dynamic> analytics = const {},
    Set<String> throwOn = const {},
  }) async {
    final api = FakeReelApi(
      queueResult: queue,
      analyticsResult: analytics,
      throwOn: throwOn,
    );
    await pumpApp(
      tester,
      ReelModerationScreen(api: api),
      auth: SignedInAuthProvider(),
    );
    await tester.pumpAndSettle();
    return api;
  }

  group('Tải hàng đợi', () {
    testWidgets('mặc định mở tab Chờ duyệt', (tester) async {
      final api = await pumpScreen(tester);
      expect(api.argsOf('moderationQueue'), ['pending']);
    });

    testWidgets('hàng đợi rỗng → hiện trạng thái rỗng, không phải lỗi',
        (tester) async {
      await pumpScreen(tester);
      expect(find.text('Không có reel nào'), findsOneWidget);
    });

    testWidgets('hiện reel chờ duyệt', (tester) async {
      await pumpScreen(tester, queue: [_queued(caption: 'Nhà xưởng Long Hậu')]);
      expect(find.text('Nhà xưởng Long Hậu'), findsOneWidget);
    });

    testWidgets('API lỗi → danh sách rỗng, KHÔNG vỡ màn', (tester) async {
      await pumpScreen(tester, throwOn: {'moderationQueue'});
      expect(find.text('Không có reel nào'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('analytics lỗi KHÔNG chặn việc kiểm duyệt', (tester) async {
      // Số liệu chỉ để tham khảo; hỏng thì admin vẫn phải duyệt được.
      await pumpScreen(
        tester,
        queue: [_queued(caption: 'vẫn phải hiện')],
        throwOn: {'analytics'},
      );
      expect(find.text('vẫn phải hiện'), findsOneWidget);
    });

    testWidgets('hiện số báo cáo để admin ưu tiên', (tester) async {
      await pumpScreen(tester, queue: [_queued(reportCount: 5)]);
      expect(find.textContaining('5 báo cáo'), findsOneWidget);
    });
  });

  group('Dải số liệu vận hành', () {
    testWidgets('hiện các chỉ số chính', (tester) async {
      await pumpScreen(tester, analytics: {
        'total': 12,
        'pending_moderation': 3,
        'total_views': 450,
        'total_likes': 88,
        'total_comments': 20,
        'storage_mb': 15.5,
        'failure_rate': 0.0,
      });
      expect(find.text('12'), findsWidgets);
      expect(find.text('450'), findsWidgets);
      expect(find.text('15.5 MB'), findsOneWidget);
    });

    testWidgets('tỉ lệ lỗi hiển thị theo phần trăm', (tester) async {
      await pumpScreen(tester, analytics: {'failure_rate': 0.25});
      expect(find.text('25.0%'), findsOneWidget);
    });

    testWidgets('không có số liệu → KHÔNG hiện dải, không nổ', (tester) async {
      await pumpScreen(tester, throwOn: {'analytics'});
      expect(find.textContaining('Số liệu vận hành'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Duyệt', () {
    testWidgets('bấm Duyệt → gọi approve đúng reel', (tester) async {
      final api = await pumpScreen(tester, queue: [_queued(id: 77)]);
      await tester.tap(find.text('Duyệt').first);
      await tester.pumpAndSettle();
      final args = api.argsOf('moderate');
      expect(args?[0], 77);
      expect(args?[1], 'approve');
    });

    testWidgets('duyệt xong thì TẢI LẠI hàng đợi', (tester) async {
      final api = await pumpScreen(tester, queue: [_queued()]);
      await tester.tap(find.text('Duyệt').first);
      await tester.pumpAndSettle();
      expect(api.countOf('moderationQueue'), 2);
    });
  });

  group('Từ chối — bắt buộc có lý do', () {
    testWidgets('mở hộp thoại hỏi lý do, CHƯA gọi API', (tester) async {
      final api = await pumpScreen(tester, queue: [_queued()]);
      await tester.tap(find.text('Từ chối').first);
      await tester.pumpAndSettle();
      expect(find.text('Từ chối reel'), findsOneWidget);
      expect(api.called('moderate'), isFalse);
    });

    testWidgets('lý do RỖNG → không cho gửi', (tester) async {
      // User bị từ chối mà không biết vì sao sẽ đăng lại y hệt.
      final api = await pumpScreen(tester, queue: [_queued()]);
      await tester.tap(find.text('Từ chối').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Từ chối'));
      await tester.pumpAndSettle();
      expect(api.called('moderate'), isFalse);
      expect(find.text('Từ chối reel'), findsOneWidget, reason: 'hộp thoại còn mở');
    });

    testWidgets('lý do chỉ có khoảng trắng cũng KHÔNG cho gửi', (tester) async {
      final api = await pumpScreen(tester, queue: [_queued()]);
      await tester.tap(find.text('Từ chối').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.widgetWithText(FilledButton, 'Từ chối'));
      await tester.pumpAndSettle();
      expect(api.called('moderate'), isFalse);
    });

    testWidgets('có lý do → gửi kèm đúng nội dung', (tester) async {
      final api = await pumpScreen(tester, queue: [_queued(id: 9)]);
      await tester.tap(find.text('Từ chối').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Nội dung không liên quan');
      await tester.tap(find.widgetWithText(FilledButton, 'Từ chối'));
      await tester.pumpAndSettle();
      final args = api.argsOf('moderate');
      expect(args?[0], 9);
      expect(args?[1], 'reject');
      expect(args?[2], 'Nội dung không liên quan');
    });

    testWidgets('bấm Hủy → không từ chối', (tester) async {
      final api = await pumpScreen(tester, queue: [_queued()]);
      await tester.tap(find.text('Từ chối').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();
      expect(api.called('moderate'), isFalse);
    });
  });
}
