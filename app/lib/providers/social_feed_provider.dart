import 'package:flutter/foundation.dart';
import 'package:house_booking/data/models/social_post_model.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/social_api.dart';

/// State feed Cộng đồng: danh sách bài, phân trang cursor, cập nhật lạc quan.
///
/// Dùng 2 kiểu: (1) instance app-scoped cho tab Cộng đồng (không lọc = tất cả
/// category), (2) instance cục bộ trong màn từng khối (lọc cố định theo
/// category + địa danh). Bộ lọc thay đổi → reset cursor + tải lại.
class SocialFeedProvider extends ChangeNotifier {
  final SocialApi _api = SocialApi();

  final List<SocialPost> _posts = [];
  List<SocialPost> get posts => List.unmodifiable(_posts);

  // ── Bộ lọc hiện hành ─────────────────────────────────────────────────────
  String? _category;
  String? _provinceCode;
  String? _districtCode;
  String? _wardSlug;
  String? _query;
  String? get category => _category;
  String? get provinceCode => _provinceCode;
  String? get districtCode => _districtCode;
  String? get wardSlug => _wardSlug;
  String? get query => _query;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  String? _error;
  String? get error => _error;

  int? _nextBeforeId;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  bool _loadedOnce = false;
  bool get loadedOnce => _loadedOnce;

  /// Đặt bộ lọc rồi tải lại từ đầu. Truyền null để giữ nguyên field đó không đổi
  /// là KHÔNG được — dùng [clearLocation] để bỏ địa danh. Category null = tất cả.
  Future<void> applyFilters({
    String? category,
    String? provinceCode,
    String? districtCode,
    String? wardSlug,
    String? query,
  }) async {
    _category = category;
    _provinceCode = provinceCode;
    _districtCode = districtCode;
    _wardSlug = wardSlug;
    _query = query;
    await loadInitial(force: true);
  }

  /// Tải trang đầu (idempotent — chỉ chạy lần đầu trừ khi [force]).
  Future<void> loadInitial({bool force = false}) async {
    if (_isLoading) return;
    if (_loadedOnce && !force) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _fetch(beforeId: null);
      _posts
        ..clear()
        ..addAll(res.posts);
      _nextBeforeId = res.nextBeforeId;
      _hasMore = res.nextBeforeId != null;
      _loadedOnce = true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Không tải được bảng tin';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadInitial(force: true);

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _nextBeforeId == null) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final res = await _fetch(beforeId: _nextBeforeId);
      _posts.addAll(res.posts);
      _nextBeforeId = res.nextBeforeId;
      _hasMore = res.nextBeforeId != null;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      // Nuốt lỗi trang sau — không phá vỡ list đang hiển thị.
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<({List<SocialPost> posts, int? nextBeforeId})> _fetch({
    required int? beforeId,
  }) {
    return _api.fetchFeed(
      beforeId: beforeId,
      limit: 20,
      category: _category,
      provinceCode: _provinceCode,
      districtCode: _districtCode,
      wardSlug: _wardSlug,
      query: _query,
    );
  }

  /// Chèn bài mới lên đầu feed. Bỏ qua nếu bài không khớp bộ lọc category.
  void addPostToTop(SocialPost post) {
    if (_category != null && post.category != _category) return;
    _posts.insert(0, post);
    notifyListeners();
  }

  /// Thay thế 1 bài sau khi sửa (nội dung/ảnh mới) — giữ nguyên vị trí.
  void updatePost(SocialPost post) {
    final idx = _posts.indexWhere((p) => p.id == post.id);
    if (idx >= 0) {
      _posts[idx] = post;
      notifyListeners();
    }
  }

  void removePost(int postId) {
    _posts.removeWhere((p) => p.id == postId);
    notifyListeners();
  }

  /// Thích/bỏ thích lạc quan: đổi UI ngay, gọi API, rollback nếu lỗi.
  Future<void> toggleLike(int postId) async {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx < 0) return;
    final original = _posts[idx];
    final willLike = !original.likedByMe;
    _posts[idx] = original.copyWith(
      likedByMe: willLike,
      likeCount: (original.likeCount + (willLike ? 1 : -1)).clamp(0, 1 << 30),
    );
    notifyListeners();
    try {
      final res = await _api.toggleLike(postId);
      final cur = _posts.indexWhere((p) => p.id == postId);
      if (cur >= 0) {
        _posts[cur] =
            _posts[cur].copyWith(likedByMe: res.liked, likeCount: res.likeCount);
        notifyListeners();
      }
    } catch (_) {
      final cur = _posts.indexWhere((p) => p.id == postId);
      if (cur >= 0) {
        _posts[cur] = original; // rollback
        notifyListeners();
      }
    }
  }

  /// Đồng bộ số bình luận khi user thêm/xoá từ màn chi tiết.
  void bumpCommentCount(int postId, int delta) {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx < 0) return;
    _posts[idx] = _posts[idx].copyWith(
      commentCount: (_posts[idx].commentCount + delta).clamp(0, 1 << 30),
    );
    notifyListeners();
  }

  void clear() {
    _posts.clear();
    _nextBeforeId = null;
    _hasMore = true;
    _loadedOnce = false;
    _error = null;
    notifyListeners();
  }
}
