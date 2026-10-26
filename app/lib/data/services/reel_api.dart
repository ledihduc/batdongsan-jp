import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/data/models/reel_model.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/session_service.dart';
// Cùng lớp lưu trữ mà SessionService dùng (web: localStorage, native: secure
// storage) — khỏi thêm phụ thuộc mới chỉ để giữ 1 chuỗi khoá.
import 'package:house_booking/data/services/_session_storage_io.dart'
    if (dart.library.html) 'package:house_booking/data/services/_session_storage_web.dart'
    as store;

/// Tuỳ chọn xem reel lưu trên máy (không cần đồng bộ server).
class ReelPrefs {
  ReelPrefs._();

  static const _kDataSaver = 'reel_data_saver';
  static bool? _cached;

  /// Tiết kiệm dữ liệu: không tự phát, không nạp trước video kế.
  static Future<bool> dataSaver() async {
    if (_cached != null) return _cached!;
    try {
      _cached = (await store.readToken(_kDataSaver)) == '1';
    } catch (_) {
      _cached = false;
    }
    return _cached!;
  }

  static Future<void> setDataSaver(bool on) async {
    _cached = on;
    try {
      await store.writeToken(_kDataSaver, on ? '1' : '0');
    } catch (_) {
      // Không lưu được → vẫn áp dụng trong phiên hiện tại.
    }
  }
}

/// Client cho Video Reel (/api/reels).
class ReelApi {
  /// [client] chỉ để TEST bơm ApiClient dùng http.Client giả. Mặc định là bản
  /// thật nên mã sản phẩm không đổi.
  const ReelApi({ApiClient? client}) : _c = client ?? const ApiClient();

  final ApiClient _c;

  /// Reel theo khối. Backend tự GỘP reel `category='all'` → phần nào cũng có.
  ///
  /// [cursor] rỗng = trang đầu. Trả kèm `nextCursor` để tải tiếp; feed luôn có
  /// bài mới chèn lên đầu nên phân trang theo cursor mới không bị lặp/nhảy.
  Future<({List<Reel> reels, String nextCursor})> listPage({
    String? category,
    int limit = 20,
    String cursor = '',
  }) async {
    final r = await _c.get(
      '/api/reels',
      queryParameters: {
        if (category != null && category.isNotEmpty) 'category': category,
        'limit': limit,
        if (cursor.isNotEmpty) 'cursor': cursor,
        'viewer_key': await viewerKey(),
      },
    );
    return (
      reels: List<Map<String, dynamic>>.from(
        r['reels'] as List? ?? const [],
      ).map(Reel.fromMap).toList(),
      nextCursor: (r['next_cursor'] as String?) ?? '',
    );
  }

  Future<List<Reel>> list({String? category, int limit = 20}) async =>
      (await listPage(category: category, limit: limit)).reels;

  /// Khoá phiên ẩn danh, lưu bền trên máy — để khách (chưa đăng nhập) cũng được
  /// khử trùng lượt xem. User đã đăng nhập thì backend ưu tiên id, khoá này bỏ qua.
  static const _kViewerKey = 'reel_viewer_key';
  static String? _cachedKey;

  Future<String> viewerKey() async {
    if (_cachedKey != null) return _cachedKey!;
    String? k;
    try {
      k = await store.readToken(_kViewerKey);
    } catch (_) {
      k = null;
    }
    if (k == null || k.isEmpty) {
      final rnd = Random.secure();
      k = List.generate(16, (_) => rnd.nextInt(36).toRadixString(36)).join();
      try {
        await store.writeToken(_kViewerKey, k);
      } catch (_) {
        // Không lưu được (chế độ riêng tư…) → vẫn dùng khoá trong phiên này.
      }
    }
    return _cachedKey = k;
  }

  /// Tạo reel từ file vừa upload ([uploadId]) — worker sẽ chuẩn hoá video.
  /// Hoặc từ [videoUrl] sẵn có (seed/admin).
  Future<Reel> create({
    String? uploadId,
    String? videoUrl,
    String? thumbnailUrl,
    String caption = '',
    String category = 'all',
  }) async {
    final r = await _c.post(
      '/api/reels',
      body: {
        if (uploadId != null) 'upload_id': uploadId,
        if (videoUrl != null) 'video_url': videoUrl,
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
          'thumbnail_url': thumbnailUrl,
        'caption': caption,
        'category': category,
      },
    );
    return Reel.fromMap(Map<String, dynamic>.from(r as Map));
  }

  /// Upload video theo kiểu STREAMING (multipart) — KHÔNG base64.
  ///
  /// Trả `upload_id` để truyền vào [create]. Dùng http.MultipartRequest nên
  /// file được gửi theo luồng, không phình bộ nhớ như base64 trước đây.
  Future<String> uploadReelVideo(Uint8List bytes, String filename) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/reels/upload');
    final req = http.MultipartRequest('POST', uri);
    final token = await SessionService.instance.getToken();
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    req.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      String msg = 'Tải video thất bại';
      try {
        msg = (jsonDecode(body) as Map)['detail']?.toString() ?? msg;
      } catch (_) {}
      throw ApiException(streamed.statusCode, msg);
    }
    return (jsonDecode(body) as Map)['upload_id'] as String;
  }

  Future<({bool liked, int likeCount})> toggleLike(int reelId) async {
    final r = await _c.post('/api/reels/$reelId/like');
    return (
      liked: (r['liked'] as bool?) ?? false,
      likeCount: (r['like_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Ghi nhận lượt xem — fire-and-forget, nuốt lỗi (không chặn trải nghiệm xem).
  ///
  /// Backend CHỈ tính khi [watchedMs] ≥3s và mỗi người 1 lần/reel.
  Future<void> addView(int reelId, {int watchedMs = 0}) async {
    try {
      await _c.post(
        '/api/reels/$reelId/view',
        body: {'watched_ms': watchedMs, 'viewer_key': await viewerKey()},
      );
    } catch (_) {}
  }

  // ── Bình luận reel ────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> comments(int reelId) async {
    final r = await _c.get('/api/reels/$reelId/comments');
    return List<Map<String, dynamic>>.from(r['comments'] as List? ?? const []);
  }

  Future<Map<String, dynamic>> addComment(
    int reelId,
    String content, {
    int? parentId,
  }) async {
    final r = await _c.post(
      '/api/reels/$reelId/comments',
      body: {'content': content, if (parentId != null) 'parent_id': parentId},
    );
    return Map<String, dynamic>.from(r as Map);
  }

  Future<void> deleteComment(int commentId) =>
      _c.delete('/api/reels/comments/$commentId');

  Future<void> delete(int reelId) => _c.delete('/api/reels/$reelId');

  /// Reel của tôi — KÈM trạng thái duyệt (pending/published/rejected + lý do).
  Future<List<Map<String, dynamic>>> mine() async {
    final r = await _c.get('/api/reels/mine');
    return List<Map<String, dynamic>>.from(r['reels'] as List? ?? const []);
  }

  /// Báo cáo reel vi phạm.
  Future<void> report(
    int reelId, {
    String reason = 'other',
    String detail = '',
  }) => _c.post(
    '/api/reels/$reelId/report',
    body: {'reason': reason, 'detail': detail},
  );

  // ── Kiểm duyệt (admin) ──────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> moderationQueue({
    String status = 'pending',
  }) async {
    final r = await _c.get(
      '/api/reels/moderation/queue',
      queryParameters: {'status': status},
    );
    return List<Map<String, dynamic>>.from(r['reels'] as List? ?? const []);
  }

  /// Số liệu vận hành reel (P3) — CHỈ admin.
  Future<Map<String, dynamic>> analytics({int days = 30}) async {
    final r = await _c.get(
      '/api/reels/analytics/summary',
      queryParameters: {'days': days},
    );
    return Map<String, dynamic>.from(r as Map);
  }

  /// action: approve | reject | hide
  Future<void> moderate(int reelId, String action, {String reason = ''}) =>
      _c.post(
        '/api/reels/$reelId/moderate',
        body: {'action': action, 'reason': reason},
      );

  /// Upload file video (mp4/webm/mov) → trả URL. Dùng chung endpoint /api/upload
  /// (backend đã nới cap cho video).
  Future<String> uploadVideo(Uint8List bytes, String filename) =>
      _c.uploadImage(bytes, filename);
}
