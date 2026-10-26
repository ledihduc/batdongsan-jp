import 'package:flutter/foundation.dart';
import 'package:house_booking/core/lifecycle/user_scope_cleanup.dart';
import 'package:house_booking/data/models/room_model.dart';
import 'package:house_booking/data/repositories/api_room_repository.dart';
import 'package:house_booking/data/services/api_client.dart';

/// RoomProvider — manages rooms for the currently selected building.
class RoomProvider extends ChangeNotifier implements UserScoped {
  final ApiRoomRepository _repo = ApiRoomRepository();

  List<RoomModel> _rooms = [];
  bool _isLoading = false;
  String? _error;
  int? _currentBuildingId;

  List<RoomModel> get rooms => List.unmodifiable(_rooms);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get currentBuildingId => _currentBuildingId;
  int get maintenanceCount =>
      _rooms.where((r) => r.isMaintenance).length;

  @override
  void resetUserScope() {
    _rooms = [];
    _isLoading = false;
    _error = null;
    _currentBuildingId = null;
    notifyListeners();
  }

  Future<void> fetchRooms(int buildingId) async {
    _currentBuildingId = buildingId;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _rooms = await _repo.fetchRooms(buildingId);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Không thể tải danh sách phòng';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<RoomModel?> createRoom(
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
    try {
      final r = await _repo.createRoom(
        buildingId,
        code: code,
        areaM2: areaM2,
        capacity: capacity,
        basePrice: basePrice,
        note: note,
        images: images,
        kenh: kenh,
        toiThieu: toiThieu,
        datCoc: datCoc,
        mienPhiThang: mienPhiThang,
        giaDien: giaDien,
        giaNuoc: giaNuoc,
        phiDichVu: phiDichVu,
        dichVuGom: dichVuGom,
        doTrongPhong: doTrongPhong,
        tang: tang,
        huong: huong,
      );
      _rooms = [..._rooms, r];
      notifyListeners();
      return r;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  /// Sửa phòng đang có. KHÔNG đụng tới kênh khai thác — kênh có vòng đời
  /// riêng (đang rao · giữ chỗ · đã bán) và nằm ở endpoint khác.
  ///
  /// Trước hôm nay provider thiếu hẳn hàm này dù `ApiRoomRepository.updateRoom`
  /// đã có: chủ nhà tạo phòng xong là **không sửa lại được gì** — sai mã phòng,
  /// sai giá điện, thiếu một món đồ, đều phải sống chung.
  Future<bool> updateRoom(
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
    bool xoaGiaTienIch = false,
    String? tang,
    String? huong,
    bool guiViTri = false,
  }) async {
    try {
      final r = await _repo.updateRoom(
        roomId,
        code: code,
        areaM2: areaM2,
        capacity: capacity,
        basePrice: basePrice,
        note: note,
        images: images,
        giaDien: giaDien,
        giaNuoc: giaNuoc,
        phiDichVu: phiDichVu,
        dichVuGom: dichVuGom,
        doTrongPhong: doTrongPhong,
        xoaGiaTienIch: xoaGiaTienIch,
        tang: tang,
        huong: huong,
        guiViTri: guiViTri,
      );
      _rooms = [
        for (final x in _rooms)
          if (x.id == roomId) r else x,
      ];
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Xoá phòng khỏi sổ. Trả `null` khi xong, hoặc câu lỗi của server để màn
  /// hình hiện nguyên văn — "Phòng đã có hợp đồng, không xoá được." nói rõ
  /// phải làm gì hơn bất cứ câu chung chung nào app tự nghĩ ra.
  Future<String?> deleteRoom(int roomId) async {
    try {
      await _repo.deleteRoom(roomId);
      _rooms = [
        for (final x in _rooms)
          if (x.id != roomId) x,
      ];
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return e.message;
    }
  }

  Future<RoomModel?> duplicateRoom(int roomId) async {
    try {
      final r = await _repo.duplicateRoom(roomId);
      _rooms = [..._rooms, r];
      notifyListeners();
      return r;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<RoomModel?> setMaintenance(
    int roomId, {
    required String maintenanceStart,
    String? maintenanceEnd,
  }) async {
    try {
      final updated = await _repo.setMaintenance(
        roomId,
        maintenanceStart: maintenanceStart,
        maintenanceEnd: maintenanceEnd,
      );
      _rooms = _rooms.map((r) => r.id == roomId ? updated : r).toList();
      notifyListeners();
      return updated;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<RoomModel?> endMaintenance(int roomId) async {
    try {
      final updated = await _repo.endMaintenance(roomId);
      _rooms = _rooms.map((r) => r.id == roomId ? updated : r).toList();
      notifyListeners();
      return updated;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }
}
