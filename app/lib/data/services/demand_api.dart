import 'package:house_booking/data/models/demand_post.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Tin NHU CẦU (`/api/demands`) — "Cần thuê" / "Cần mua".
///
/// Đọc thì công khai, đăng/sửa thì cần đăng nhập (backend chặn, client chỉ cần
/// gọi cổng đăng nhập trước cho đỡ mất công gõ form rồi bị 401).
class DemandApi {
  /// [client] chỉ để test bơm MockClient — code sản phẩm dùng mặc định.
  const DemandApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<List<DemandPost>> list({
    String? kind,
    String? provinceCode,
    int? categoryId,
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    final rows = await _c.getList(
      '/api/demands',
      queryParameters: {
        if (kind != null) 'kind': kind,
        if (provinceCode != null) 'province_code': provinceCode,
        if (categoryId != null) 'category_id': categoryId,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'limit': limit,
        'offset': offset,
      },
    );
    return rows
        .map((e) => DemandPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Tin của tôi — gồm CẢ tin đã đóng/hết hạn, để còn gia hạn được.
  Future<List<DemandPost>> mine() async {
    final rows = await _c.getList('/api/demands/mine');
    return rows
        .map((e) => DemandPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DemandPost> create(Map<String, dynamic> body) async {
    final r = await _c.post('/api/demands', body: body);
    return DemandPost.fromJson(r);
  }

  Future<DemandPost> close(int id) async {
    final r = await _c.patch('/api/demands/$id', body: {'status': 'closed'});
    return DemandPost.fromJson(r);
  }

  /// Gia hạn 30 ngày KỂ TỪ BÂY GIỜ (backend không cộng dồn vào hạn cũ).
  Future<DemandPost> extend(int id) async {
    final r = await _c.patch('/api/demands/$id', body: {'extend': true});
    return DemandPost.fromJson(r);
  }
}
