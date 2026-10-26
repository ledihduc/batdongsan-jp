import 'package:house_booking/data/models/social_comment_model.dart';
import 'package:house_booking/data/models/social_post_model.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Lớp gọi API cho Cộng đồng (mạng xã hội). Bọc [ApiClient] — tự đính kèm JWT.
class SocialApi {
  final ApiClient _c = const ApiClient();

  /// Feed, mới nhất trước. Lọc tuỳ chọn theo [category] + địa danh + [query].
  /// [beforeId] để phân trang lùi (cursor).
  Future<({List<SocialPost> posts, int? nextBeforeId})> fetchFeed({
    int? beforeId,
    int limit = 20,
    String? category,
    String? provinceCode,
    String? districtCode,
    String? wardSlug,
    String? query,
    int? userId,
  }) async {
    final res = await _c.get(
      '/api/social/feed',
      queryParameters: {
        if (beforeId != null) 'before_id': beforeId,
        'limit': limit,
        if (userId != null) 'user_id': userId,
        if (category != null && category.isNotEmpty) 'category': category,
        if (provinceCode != null && provinceCode.isNotEmpty)
          'province_code': provinceCode,
        if (districtCode != null && districtCode.isNotEmpty)
          'district_code': districtCode,
        if (wardSlug != null && wardSlug.isNotEmpty) 'ward_slug': wardSlug,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    final posts = (res['posts'] as List? ?? [])
        .map((e) => SocialPost.fromMap(e as Map<String, dynamic>))
        .toList();
    return (posts: posts, nextBeforeId: res['next_before_id'] as int?);
  }

  Future<SocialPost> createPost({
    required String content,
    required List<String> images,
    required String category,
    String? provinceCode,
    String? districtCode,
    String? wardSlug,
    String? locationText,
    double? lat,
    double? lng,
  }) async {
    final res = await _c.post(
      '/api/social/posts',
      body: {
        'content': content,
        'images': images,
        'category': category,
        if (provinceCode != null) 'province_code': provinceCode,
        if (districtCode != null) 'district_code': districtCode,
        if (wardSlug != null) 'ward_slug': wardSlug,
        if (locationText != null && locationText.isNotEmpty)
          'location_text': locationText,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      },
    );
    return SocialPost.fromMap(res);
  }

  /// Sửa bài (chỉ nội dung + ảnh). Category & địa danh giữ nguyên phía server.
  Future<SocialPost> editPost({
    required int postId,
    required String content,
    required List<String> images,
  }) async {
    final res = await _c.patch(
      '/api/social/posts/$postId',
      body: {'content': content, 'images': images},
    );
    return SocialPost.fromMap(res);
  }

  Future<void> deletePost(int postId) async {
    await _c.delete('/api/social/posts/$postId');
  }

  /// Lấy chi tiết 1 bài (dùng cho deep-link từ thông báo). Ném lỗi nếu đã xoá.
  Future<SocialPost> fetchPost(int postId) async {
    final res = await _c.get('/api/social/posts/$postId');
    return SocialPost.fromMap(res);
  }

  /// Bật/tắt thích. Trả về trạng thái + số like mới (nguồn sự thật từ server).
  Future<({bool liked, int likeCount})> toggleLike(int postId) async {
    final res = await _c.post('/api/social/posts/$postId/like');
    return (
      liked: (res['liked'] as bool?) ?? false,
      likeCount: (res['like_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Lấy TẤT CẢ bình luận (phẳng, kèm parent_id) để client dựng cây lồng cấp.
  Future<List<SocialComment>> fetchComments(
    int postId, {
    int limit = 100,
  }) async {
    final res = await _c.get(
      '/api/social/posts/$postId/comments',
      queryParameters: {'limit': limit},
    );
    return (res['comments'] as List? ?? [])
        .map((e) => SocialComment.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Thêm bình luận, hoặc trả lời 1 bình luận khi truyền [parentId].
  Future<SocialComment> addComment(
    int postId,
    String content, {
    int? parentId,
  }) async {
    final res = await _c.post(
      '/api/social/posts/$postId/comments',
      body: {'content': content, if (parentId != null) 'parent_id': parentId},
    );
    return SocialComment.fromMap(res);
  }

  Future<void> deleteComment(int commentId) async {
    await _c.delete('/api/social/comments/$commentId');
  }

  /// Upload 1 ảnh (bytes) → URL tuyệt đối dùng cho bài đăng.
  Future<String> uploadImage(List<int> bytes, String filename) {
    return _c.uploadImage(bytes, filename);
  }
}
