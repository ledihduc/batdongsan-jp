import 'package:house_booking/data/services/api_client.dart';

/// Client cho báo cáo nội dung + lưu bài viết (menu ⋯ trên mỗi bài đăng).
class ReportApi {
  const ReportApi();
  final ApiClient _c = const ApiClient();

  /// Gửi báo cáo. `reason == 'wrong_info'` là **báo sai cho người đăng**
  /// (backend gửi thông báo cho họ); các lý do khác vào hàng đợi quản trị.
  ///
  /// Idempotent ở backend: gửi lại không cộng thêm số đếm.
  Future<Map<String, dynamic>> report({
    required String targetType, // house | post
    required int targetId,
    required String reason,
    String detail = '',
  }) async {
    final r = await _c.post(
      '/api/reports',
      body: {
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
        'detail': detail,
      },
    );
    return Map<String, dynamic>.from(r as Map);
  }

  // ── Lưu bài cộng đồng ─────────────────────────────────────────────────────
  // Tin BĐS dùng WishlistProvider sẵn có, không đi qua đây.

  Future<void> savePost(int postId) =>
      _c.post('/api/social/posts/$postId/save');

  Future<void> unsavePost(int postId) =>
      _c.delete('/api/social/posts/$postId/save');

  /// Id các bài đã lưu — dùng để tô đậm biểu tượng trên feed.
  Future<Set<int>> savedPostIds() async {
    final r = await _c.get('/api/social/saved-posts');
    return List<int>.from(
      (r['post_ids'] as List? ?? const []).map((e) => (e as num).toInt()),
    ).toSet();
  }

  // ── Quản trị ──────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> queue({String status = 'pending'}) async {
    final r = await _c.get(
      '/api/reports/queue',
      queryParameters: {'status': status},
    );
    return List<Map<String, dynamic>>.from(r['reports'] as List? ?? const []);
  }

  /// action: reviewed | dismissed
  Future<void> resolve(int reportId, String action) =>
      _c.post('/api/reports/$reportId/resolve', body: {'action': action});
}
