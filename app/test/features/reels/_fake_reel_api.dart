import 'dart:typed_data';

import 'package:house_booking/data/models/reel_model.dart';
import 'package:house_booking/data/services/reel_api.dart';

/// ReelApi giả — ghi lại lời gọi và trả dữ liệu dựng sẵn, KHÔNG chạm mạng.
///
/// Vì sao kế thừa `ReelApi` thay vì tạo interface riêng: giữ nguyên mã sản
/// phẩm. Widget vẫn khai kiểu `ReelApi`, chỉ khác là test truyền bản giả vào.
class FakeReelApi extends ReelApi {
  FakeReelApi({
    this.commentsResult = const [],
    this.queueResult = const [],
    this.analyticsResult = const {},
    this.listResult = const [],
    this.throwOn = const {},
  });

  /// Tên phương thức → ném lỗi khi được gọi. Dùng để test đường lỗi.
  final Set<String> throwOn;

  List<Map<String, dynamic>> commentsResult;
  List<Map<String, dynamic>> queueResult;
  Map<String, dynamic> analyticsResult;
  List<Reel> listResult;

  /// Nhật ký lời gọi: `('tên', [tham số...])`.
  final List<(String, List<Object?>)> calls = [];

  void _log(String name, [List<Object?> args = const []]) {
    calls.add((name, args));
    if (throwOn.contains(name)) throw Exception('lỗi giả: $name');
  }

  bool called(String name) => calls.any((c) => c.$1 == name);
  int countOf(String name) => calls.where((c) => c.$1 == name).length;
  List<Object?>? argsOf(String name) =>
      calls.where((c) => c.$1 == name).map((c) => c.$2).firstOrNull;

  // ── Bình luận ──────────────────────────────────────────────────────────────
  @override
  Future<List<Map<String, dynamic>>> comments(int reelId) async {
    _log('comments', [reelId]);
    return commentsResult;
  }

  @override
  Future<Map<String, dynamic>> addComment(
    int reelId,
    String content, {
    int? parentId,
  }) async {
    _log('addComment', [reelId, content, parentId]);
    return {'id': 999, 'content': content, 'parent_id': parentId};
  }

  @override
  Future<void> deleteComment(int commentId) async =>
      _log('deleteComment', [commentId]);

  // ── Kiểm duyệt ─────────────────────────────────────────────────────────────
  @override
  Future<List<Map<String, dynamic>>> moderationQueue({
    String status = 'pending',
  }) async {
    _log('moderationQueue', [status]);
    return queueResult;
  }

  @override
  Future<void> moderate(int reelId, String action, {String reason = ''}) async =>
      _log('moderate', [reelId, action, reason]);

  @override
  Future<Map<String, dynamic>> analytics({int days = 30}) async {
    _log('analytics', [days]);
    return analyticsResult;
  }

  // ── Feed / tương tác ───────────────────────────────────────────────────────
  @override
  Future<List<Reel>> list({String? category, int limit = 20}) async {
    _log('list', [category, limit]);
    return listResult;
  }

  @override
  Future<({List<Reel> reels, String nextCursor})> listPage({
    String? category,
    int limit = 20,
    String cursor = '',
  }) async {
    _log('listPage', [category, limit, cursor]);
    return (reels: listResult, nextCursor: '');
  }

  @override
  Future<({bool liked, int likeCount})> toggleLike(int reelId) async {
    _log('toggleLike', [reelId]);
    return (liked: true, likeCount: 1);
  }

  @override
  Future<void> addView(int reelId, {int watchedMs = 0}) async =>
      _log('addView', [reelId, watchedMs]);

  @override
  Future<void> report(int reelId,
          {String reason = 'other', String detail = ''}) async =>
      _log('report', [reelId, reason, detail]);

  // ── Đăng reel ──────────────────────────────────────────────────────────────
  @override
  Future<String> uploadReelVideo(Uint8List bytes, String filename) async {
    _log('uploadReelVideo', [bytes.length, filename]);
    return 'raw_20260101120000_abcdef12.mp4';
  }

  @override
  Future<Reel> create({
    String? uploadId,
    String? videoUrl,
    String? thumbnailUrl,
    String caption = '',
    String category = 'all',
  }) async {
    _log('create', [uploadId, videoUrl, caption, category]);
    return Reel.fromMap({'id': 1, 'caption': caption, 'category': category});
  }
}

/// Dữ liệu reel mẫu — đủ trường để widget dựng được.
Map<String, dynamic> fakeReelMap({
  int id = 1,
  String caption = 'Căn hộ view sông',
  String category = 'all',
  int likeCount = 0,
  int commentCount = 0,
  bool likedByMe = false,
}) =>
    {
      'id': id,
      'user_id': 7,
      'author_name': 'Chị Hoa',
      'author_avatar': null,
      'video_url': '/uploads/reel_$id.mp4',
      'thumbnail_url': '/uploads/reel_$id.jpg',
      'caption': caption,
      'category': category,
      'like_count': likeCount,
      'view_count': 12,
      'comment_count': commentCount,
      'liked_by_me': likedByMe,
      'created_at': '2026-07-18T10:00:00',
    };

Map<String, dynamic> fakeComment({
  int id = 1,
  String content = 'Còn phòng không ạ?',
  int? parentId,
  int replyCount = 0,
  bool isDeleted = false,
  String authorName = 'Anh Nam',
}) =>
    {
      'id': id,
      'content': content,
      'parent_id': parentId,
      'reply_count': replyCount,
      'is_deleted': isDeleted,
      'author_name': authorName,
      'author_avatar': null,
      'created_at': '2026-07-18T11:00:00',
    };
