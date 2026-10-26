import 'package:house_booking/data/services/api_client.dart';

/// Gắn một TIN ĐÃ ĐĂNG vào dự án.
///
/// API: POST /api/host/buildings/{id}/gan-tin
///
/// Vì sao cần: mô hình dữ liệu vốn chỉ đi một chiều — dựng dự án → thêm phòng →
/// đăng phòng lên chợ. Ai lỡ đăng tin lẻ trước rồi mới dựng dự án thì tin đó
/// vĩnh viễn đứng ngoài, dù trong đầu người bán nó rõ ràng là "phòng của toà
/// S1". Endpoint này nối chiều còn thiếu để thứ tự làm việc không còn bị ép.
///
/// Backend tự sinh một `Room` từ dữ liệu của tin rồi nối hai chiều — người bán
/// không phải nghĩ theo khái niệm "phòng", chỉ chọn tin thuộc dự án nào.
class DuAnGanTinApi {
  const DuAnGanTinApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  /// Trả về mã phòng vừa sinh (vd "P03") để báo lại cho người dùng biết tin của
  /// họ đã nằm ở đâu trong dự án.
  Future<String> gan({required int duAnId, required int tinId}) async {
    final r = await _c.post(
      '/api/host/buildings/$duAnId/gan-tin',
      body: {'house_id': tinId},
    );
    return (r['room_code'] as String?) ?? '';
  }
}
