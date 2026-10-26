import 'package:house_booking/data/services/api_client.dart';

/// Tin đăng cư xử như một bài viết: tim · bình luận · ghim · ẩn · thống kê.
///
/// API: /api/houses/{id}/{like,comments,pin,visibility,thong-ke}
///
/// Backend dùng chung `social_post_likes` + `social_comments` với bài viết,
/// phân biệt bằng `target_type='house'` — nên cây trả lời lồng cấp và tombstone
/// khi xoá là y hệt bài viết, app không phải xử lý khác đi.
class HouseSocialApi {
  const HouseSocialApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  /// Bật/tắt tim. Trả `(daTim, soTim)` sau khi đổi.
  Future<({bool daTim, int soTim})> doiTim(int houseId) async {
    final r = await _c.post('/api/houses/$houseId/like');
    return (
      daTim: r['liked'] == true,
      soTim: (r['like_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<Map<String, dynamic>>> binhLuan(int houseId) async {
    final r = await _c.get('/api/houses/$houseId/comments');
    return List<Map<String, dynamic>>.from(r['comments'] as List? ?? const []);
  }

  Future<void> vietBinhLuan(
    int houseId,
    String noiDung, {
    int? parentId,
  }) async {
    await _c.post(
      '/api/houses/$houseId/comments',
      body: {
        'content': noiDung,
        if (parentId != null) 'parent_id': parentId,
      },
    );
  }

  Future<void> xoaBinhLuan(int houseId, int commentId) async {
    await _c.delete('/api/houses/$houseId/comments/$commentId');
  }

  Future<bool> ghim(int houseId, {required bool ghim}) async {
    final r = await _c.post(
      '/api/houses/$houseId/pin',
      body: {'pinned': ghim},
    );
    return r['pinned'] == true;
  }

  /// Ẩn/hiện. Chỉ đảo `published` ↔ `hidden`; tin đang chờ duyệt hoặc bị từ
  /// chối thì backend trả 409 — chuyển trạng thái đó là việc của kiểm duyệt.
  Future<String> doiHienThi(int houseId, {required bool an}) async {
    final r = await _c.post(
      '/api/houses/$houseId/visibility',
      body: {'hidden': an},
    );
    return (r['status'] as String?) ?? '';
  }

  /// Số liệu của MỘT tin — chỉ chủ tin gọi được.
  Future<ThongKeTin> thongKe(int houseId) async =>
      ThongKeTin.tuMap(await _c.get('/api/houses/$houseId/thong-ke'));
}

class ThongKeTin {
  const ThongKeTin({
    required this.luotXem,
    required this.luotLuu,
    required this.lichHen,
    required this.luotTim,
    required this.binhLuan,
  });

  final int luotXem;
  final int luotLuu;
  final int lichHen;
  final int luotTim;
  final int binhLuan;

  factory ThongKeTin.tuMap(Map<String, dynamic> m) => ThongKeTin(
    luotXem: (m['view_count'] as num?)?.toInt() ?? 0,
    luotLuu: (m['saved_count'] as num?)?.toInt() ?? 0,
    lichHen: (m['appointment_count'] as num?)?.toInt() ?? 0,
    luotTim: (m['like_count'] as num?)?.toInt() ?? 0,
    binhLuan: (m['comment_count'] as num?)?.toInt() ?? 0,
  );
}
