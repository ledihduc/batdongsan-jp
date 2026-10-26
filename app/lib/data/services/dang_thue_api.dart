import 'package:house_booking/data/services/api_client.dart';

/// Phòng người dùng đang thuê dài hạn.
class DangThueApi {
  const DangThueApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<List<PhongDangThue>> cuaToi() async {
    final list = await _c.getList('/api/guest/dang-thue');
    return list
        .whereType<Map>()
        .map((e) => PhongDangThue.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Hồ sơ phòng dùng chung sổ dữ liệu với chủ nhà: hóa đơn, điện nước,
  /// hợp đồng, tài sản và lịch sử sửa chữa.
  Future<Map<String, dynamic>> hoSo(int contractId) async =>
      Map<String, dynamic>.from(
        await _c.get('/api/guest/dang-thue/$contractId/ho-so'),
      );

  /// Khách báo sự cố phòng mình đang thuê → sổ sửa chữa của chủ nhà.
  Future<void> baoSuCo({
    required int contractId,
    required String loai,
    required String moTa,
    List<String> anh = const [],
  }) async {
    await _c.post(
      '/api/guest/dang-thue/$contractId/su-co',
      body: {'loai': loai, 'mo_ta': moTa, 'anh': anh},
    );
  }
}

class PhongDangThue {
  const PhongDangThue({
    required this.contractId,
    required this.roomId,
    required this.maPhong,
    required this.tenToa,
    this.diaChi = '',
    this.tienThue = 0,
    this.datCoc = 0,
    this.tuNgay = '',
    this.denNgay = '',
    this.status = 'active',
    this.nguoiThue = '',
    this.chiSoTrangThai,
    this.chiSoLyDo,
  });

  final int contractId;
  final int roomId;
  final String maPhong;
  final String tenToa;
  final String diaChi;
  final double tienThue;
  final double datCoc;
  final String tuNgay;
  final String denNgay;
  final String status;
  final String nguoiThue;
  final String? chiSoTrangThai;
  final String? chiSoLyDo;

  factory PhongDangThue.fromMap(Map<String, dynamic> m) => PhongDangThue(
    contractId: (m['contract_id'] as num?)?.toInt() ?? 0,
    roomId: (m['room_id'] as num?)?.toInt() ?? 0,
    maPhong: m['ma_phong'] as String? ?? '',
    tenToa: m['ten_toa'] as String? ?? '',
    diaChi: m['dia_chi'] as String? ?? '',
    tienThue: (m['tien_thue'] as num?)?.toDouble() ?? 0,
    datCoc: (m['dat_coc'] as num?)?.toDouble() ?? 0,
    tuNgay: m['tu_ngay'] as String? ?? '',
    denNgay: m['den_ngay'] as String? ?? '',
    status: m['status'] as String? ?? 'active',
    nguoiThue: m['nguoi_thue'] as String? ?? '',
    chiSoTrangThai: m['chi_so_trang_thai'] as String?,
    chiSoLyDo: m['chi_so_ly_do'] as String?,
  );
}
