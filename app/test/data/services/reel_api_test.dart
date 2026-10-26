/// Unit test cho ReelApi — tầng ánh xạ giữa HTTP và model.
///
/// Trọng tâm: **URL và tham số gửi đi phải đúng**, và **payload thiếu trường
/// không được làm nổ app**. Backend đổi tên field là chuyện xảy ra thật; tầng
/// này phải chịu được, vì nó nằm giữa mọi màn hình reel và mạng.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/reel_api.dart';

void main() {
  /// Ghi lại request cuối và trả về [body] dựng sẵn.
  ({ReelApi api, List<http.Request> sent}) build(
    Object body, {
    int status = 200,
  }) {
    final sent = <http.Request>[];
    final client = MockClient((req) async {
      sent.add(req);
      return http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    return (api: ReelApi(client: ApiClient(client: client)), sent: sent);
  }

  group('listPage — đường dẫn & tham số', () {
    test('gửi category, limit và viewer_key', () async {
      final t = build({'reels': [], 'next_cursor': ''});
      await t.api.listPage(category: 'lease', limit: 5);
      final q = t.sent.single.url.queryParameters;
      expect(t.sent.single.url.path, '/api/reels');
      expect(q['category'], 'lease');
      expect(q['limit'], '5');
      expect(q['viewer_key'], isNotEmpty,
          reason: 'thiếu khoá này thì khách không được khử trùng lượt xem');
    });

    test('KHÔNG gửi cursor khi ở trang đầu', () async {
      final t = build({'reels': [], 'next_cursor': ''});
      await t.api.listPage();
      expect(t.sent.single.url.queryParameters.containsKey('cursor'), isFalse);
    });

    test('gửi cursor khi lật trang', () async {
      final t = build({'reels': [], 'next_cursor': ''});
      await t.api.listPage(cursor: '2026-01-01T00:00:00|5');
      expect(t.sent.single.url.queryParameters['cursor'],
          '2026-01-01T00:00:00|5');
    });

    test('trả về cursor trang kế', () async {
      final t = build({'reels': [], 'next_cursor': 'abc|9'});
      expect((await t.api.listPage()).nextCursor, 'abc|9');
    });

    test('thiếu next_cursor → chuỗi rỗng, KHÔNG null', () async {
      final t = build({'reels': []});
      expect((await t.api.listPage()).nextCursor, '');
    });

    test('phản hồi thiếu hẳn "reels" → danh sách rỗng, không nổ', () async {
      final t = build(<String, dynamic>{});
      expect((await t.api.listPage()).reels, isEmpty);
    });

    test('ánh xạ đúng dữ liệu reel', () async {
      final t = build({
        'reels': [
          {'id': 7, 'caption': 'Nhà xưởng', 'like_count': 3, 'comment_count': 2},
        ],
      });
      final r = (await t.api.listPage()).reels.single;
      expect(r.id, 7);
      expect(r.caption, 'Nhà xưởng');
      expect(r.likeCount, 3);
      expect(r.commentCount, 2);
    });
  });

  group('Khoá người xem (viewer key)', () {
    test('dùng LẠI cùng một khoá giữa các lời gọi', () async {
      // Khoá đổi mỗi lần thì mỗi lượt xem thành một người khác → số liệu ảo.
      final t = build({'reels': []});
      await t.api.listPage();
      await t.api.listPage();
      final k1 = t.sent[0].url.queryParameters['viewer_key'];
      final k2 = t.sent[1].url.queryParameters['viewer_key'];
      expect(k1, k2);
    });
  });

  group('addView — số liệu lượt xem', () {
    test('gửi watched_ms và viewer_key trong body', () async {
      final t = build(<String, dynamic>{});
      await t.api.addView(9, watchedMs: 4200);
      final body = jsonDecode(t.sent.single.body) as Map<String, dynamic>;
      expect(t.sent.single.url.path, '/api/reels/9/view');
      expect(body['watched_ms'], 4200);
      expect(body['viewer_key'], isNotEmpty);
    });

    test('lỗi mạng bị NUỐT — không chặn trải nghiệm xem', () async {
      // Ghi nhận lượt xem hỏng không đáng để làm gián đoạn người đang xem.
      final t = build(<String, dynamic>{}, status: 500);
      await t.api.addView(9, watchedMs: 5000); // không được ném
    });
  });

  group('Bình luận', () {
    test('lấy danh sách đúng đường dẫn', () async {
      final t = build({'comments': [
        {'id': 1, 'content': 'hay'},
      ]});
      final cs = await t.api.comments(5);
      expect(t.sent.single.url.path, '/api/reels/5/comments');
      expect(cs.single['content'], 'hay');
    });

    test('thiếu "comments" → rỗng', () async {
      final t = build(<String, dynamic>{});
      expect(await t.api.comments(5), isEmpty);
    });

    test('gửi bình luận gốc KHÔNG kèm parent_id', () async {
      final t = build({'id': 1});
      await t.api.addComment(5, 'xin chào');
      final body = jsonDecode(t.sent.single.body) as Map<String, dynamic>;
      expect(body['content'], 'xin chào');
      expect(body.containsKey('parent_id'), isFalse);
    });

    test('trả lời thì kèm parent_id', () async {
      final t = build({'id': 2});
      await t.api.addComment(5, 'ok', parentId: 42);
      expect((jsonDecode(t.sent.single.body) as Map)['parent_id'], 42);
    });

    test('xoá bình luận dùng đúng đường dẫn KHÔNG lồng reel', () async {
      // /api/reels/comments/{id} — không phải /api/reels/{reelId}/comments/{id}
      final t = build(<String, dynamic>{});
      await t.api.deleteComment(77);
      expect(t.sent.single.url.path, '/api/reels/comments/77');
      expect(t.sent.single.method, 'DELETE');
    });
  });

  group('Tương tác', () {
    test('toggleLike đọc đúng kết quả', () async {
      final t = build({'liked': true, 'like_count': 5});
      final r = await t.api.toggleLike(3);
      expect((r.liked, r.likeCount), (true, 5));
    });

    test('toggleLike thiếu trường → mặc định an toàn', () async {
      final t = build(<String, dynamic>{});
      final r = await t.api.toggleLike(3);
      expect((r.liked, r.likeCount), (false, 0));
    });

    test('report gửi lý do và ghi chú', () async {
      final t = build(<String, dynamic>{});
      await t.api.report(4, reason: 'scam', detail: 'lừa đảo');
      final body = jsonDecode(t.sent.single.body) as Map<String, dynamic>;
      expect(t.sent.single.url.path, '/api/reels/4/report');
      expect(body['reason'], 'scam');
      expect(body['detail'], 'lừa đảo');
    });
  });

  group('Tạo reel', () {
    test('gửi upload_id khi tạo từ file vừa tải', () async {
      final t = build({'id': 1});
      await t.api.create(uploadId: 'raw_x.mp4', caption: 'c', category: 'lease');
      final body = jsonDecode(t.sent.single.body) as Map<String, dynamic>;
      expect(body['upload_id'], 'raw_x.mp4');
      expect(body['caption'], 'c');
      expect(body['category'], 'lease');
      expect(body.containsKey('video_url'), isFalse);
    });

    test('thumbnail_url rỗng thì KHÔNG gửi', () async {
      final t = build({'id': 1});
      await t.api.create(videoUrl: '/v.mp4', thumbnailUrl: '');
      final body = jsonDecode(t.sent.single.body) as Map<String, dynamic>;
      expect(body.containsKey('thumbnail_url'), isFalse);
    });
  });

  group('Quản trị', () {
    test('hàng đợi kiểm duyệt lọc theo status', () async {
      final t = build({'reels': []});
      await t.api.moderationQueue(status: 'hidden');
      expect(t.sent.single.url.path, '/api/reels/moderation/queue');
      expect(t.sent.single.url.queryParameters['status'], 'hidden');
    });

    test('moderate gửi hành động và lý do', () async {
      final t = build(<String, dynamic>{});
      await t.api.moderate(8, 'reject', reason: 'sai nội dung');
      final body = jsonDecode(t.sent.single.body) as Map<String, dynamic>;
      expect(body['action'], 'reject');
      expect(body['reason'], 'sai nội dung');
    });

    test('analytics truyền số ngày', () async {
      final t = build({'total': 1});
      await t.api.analytics(days: 7);
      expect(t.sent.single.url.queryParameters['days'], '7');
    });
  });

  group('Lỗi từ máy chủ', () {
    test('4xx ném ApiException kèm mã trạng thái', () async {
      final t = build({'detail': 'Không có quyền'}, status: 403);
      expect(
        () => t.api.comments(1),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)),
      );
    });

    test('429 (quá nhiều yêu cầu) phân biệt được để UI báo đúng', () async {
      final t = build({'detail': 'quá nhiều'}, status: 429);
      expect(
        () => t.api.addComment(1, 'x'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 429)),
      );
    });
  });
}
