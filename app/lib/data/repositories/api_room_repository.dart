import 'package:house_booking/data/models/room_model.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Repository for /api/host/buildings/{id}/rooms and /api/host/rooms endpoints.
class ApiRoomRepository {
  final ApiClient _client = const ApiClient();

  Future<List<RoomModel>> fetchRooms(int buildingId) async {
    final list = await _client.getList('/api/host/buildings/$buildingId/rooms');
    return list
        .map((e) => RoomModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Tạo phòng kèm KÊNH KHAI THÁC đầu tiên và giá tiện ích.
  ///
  /// `kenh` do server mở luôn trong cùng transaction — gọi lượt thứ hai để mở
  /// kênh thì lượt đó hỏng là để lại phòng không thuộc kênh nào, tức là không
  /// ra chợ được.
  ///
  /// Ba giá tiện ích gửi `null` khi người dùng để trống (= theo giá toà) và
  /// gửi `0` khi họ thực sự gõ 0 (= miễn phí). Hai thứ đó khác nhau, nên ở đây
  /// chỉ đính khoá khi khác `null`.
  Future<RoomModel> createRoom(
    int buildingId, {
    required String code,
    double? areaM2,
    int capacity = 1,
    double basePrice = 0,
    String? note,
    List<String> images = const [],
    String? kenh,
    int? toiThieu,
    double? datCoc,
    int? mienPhiThang,
    double? giaDien,
    double? giaNuoc,
    double? phiDichVu,
    List<String> dichVuGom = const [],
    List<String> doTrongPhong = const [],
    String? tang,
    String? huong,
  }) async {
    final resp = await _client.post(
      '/api/host/buildings/$buildingId/rooms',
      body: {
        'code': code,
        if (areaM2 != null) 'area_m2': areaM2,
        'capacity': capacity,
        'base_price': basePrice,
        if (note != null) 'note': note,
        'images': images,
        if (kenh != null) 'kenh': kenh,
        if (toiThieu != null) 'toi_thieu': toiThieu,
        if (datCoc != null) 'dat_coc': datCoc,
        if (mienPhiThang != null) 'mien_phi_thang': mienPhiThang,
        if (giaDien != null) 'gia_dien': giaDien,
        if (giaNuoc != null) 'gia_nuoc': giaNuoc,
        if (phiDichVu != null) 'phi_dich_vu': phiDichVu,
        'dich_vu_gom': dichVuGom,
        'do_trong_phong': doTrongPhong,
        'tang': ?tang,
        'huong': ?huong,
      },
    );
    return RoomModel.fromJson(Map<String, dynamic>.from(resp));
  }

  /// Xoá phòng. Server chặn nếu phòng đã có hợp đồng, đơn đặt hoặc đang có
  /// lịch — app không tự đoán trước, cứ gọi rồi hiện đúng câu server trả về.
  Future<void> deleteRoom(int roomId) async {
    await _client.delete('/api/host/rooms/$roomId');
  }

  Future<RoomModel> updateRoom(
    int roomId, {
    String? code,
    double? areaM2,
    int? capacity,
    double? basePrice,
    String? note,
    List<String>? images,
    double? giaDien,
    double? giaNuoc,
    double? phiDichVu,
    List<String>? dichVuGom,
    List<String>? doTrongPhong,
    // Ba giá tiện ích phân biệt "không đổi" với "xoá về theo toà": `null` là
    // KHÔNG GỬI khoá (PATCH bỏ qua), còn muốn trả về theo giá toà thì gửi
    // `xoaGiaTienIch: true`. Không có cờ này thì ô đã điền rồi là không bao
    // giờ xoá trắng lại được.
    bool xoaGiaTienIch = false,
    // Tầng / hướng: cùng kiểu cờ — `guiViTri` gửi cả khoá có giá trị `null` để
    // xoá được ô đã khai.
    String? tang,
    String? huong,
    bool guiViTri = false,
  }) async {
    final body = <String, dynamic>{
      if (code != null) 'code': code,
      if (areaM2 != null) 'area_m2': areaM2,
      if (capacity != null) 'capacity': capacity,
      if (basePrice != null) 'base_price': basePrice,
      if (note != null) 'note': note,
      if (images != null) 'images': images,
      if (giaDien != null || xoaGiaTienIch) 'gia_dien': giaDien,
      if (giaNuoc != null || xoaGiaTienIch) 'gia_nuoc': giaNuoc,
      if (phiDichVu != null || xoaGiaTienIch) 'phi_dich_vu': phiDichVu,
      if (dichVuGom != null) 'dich_vu_gom': dichVuGom,
      if (doTrongPhong != null) 'do_trong_phong': doTrongPhong,
      if (tang != null || guiViTri) 'tang': tang,
      if (huong != null || guiViTri) 'huong': huong,
    };
    final resp = await _client.patch('/api/host/rooms/$roomId', body: body);
    return RoomModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<RoomModel> duplicateRoom(int roomId) async {
    final resp = await _client.post('/api/host/rooms/$roomId/duplicate');
    return RoomModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<RoomModel> setMaintenance(
    int roomId, {
    required String maintenanceStart,
    String? maintenanceEnd,
  }) async {
    final resp = await _client.post(
      '/api/host/rooms/$roomId/maintenance',
      body: {
        'maintenance_start': maintenanceStart,
        if (maintenanceEnd != null) 'maintenance_end': maintenanceEnd,
      },
    );
    return RoomModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<RoomModel> endMaintenance(int roomId) async {
    final resp = await _client.post('/api/host/rooms/$roomId/maintenance/end');
    return RoomModel.fromJson(Map<String, dynamic>.from(resp));
  }
}
