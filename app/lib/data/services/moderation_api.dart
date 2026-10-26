import 'package:house_booking/data/services/api_client.dart';

/// Chặn người dùng (Apple Guideline 1.2 — UGC). Chặn ai thì không còn thấy
/// bài/reel/bình luận của người đó. Backend: /api/social/blocks.
class ModerationApi {
  const ModerationApi();
  final ApiClient _c = const ApiClient();

  Future<void> block(int userId) => _c.post('/api/social/blocks/$userId');

  Future<void> unblock(int userId) => _c.delete('/api/social/blocks/$userId');

  /// Danh sách người đã chặn: [{user_id, name, avatar_path}].
  Future<List<Map<String, dynamic>>> blocked() async {
    final r = await _c.get('/api/social/blocks');
    return List<Map<String, dynamic>>.from(r['blocked'] as List? ?? const []);
  }
}
