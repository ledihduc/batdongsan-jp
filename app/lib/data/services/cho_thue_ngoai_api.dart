import 'package:house_booking/data/services/api_client.dart';

/// Phòng CHO THUÊ NGOÀI APP — chủ nhà tự tìm được khách (Facebook, môi giới,
/// người quen) rồi đánh dấu phòng đã có người.
///
///     POST   /api/host/rooms/{id}/cho-thue-ngoai
///     DELETE /api/host/rooms/{id}/cho-thue-ngoai   (bấm nhầm thì gỡ)
///
/// Server ghi nhận bằng một hợp đồng gọn có cờ `ngoai_luong`, nên Sổ phòng,
/// Trang chủ, Điện nước, Hoá đơn đọc ra y như phòng thuê qua app — và tin đang
/// rao của phòng tự đóng lại.
class ChoThueNgoaiApi {
  const ChoThueNgoaiApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  /// Mọi tham số đều không bắt buộc: thiếu giá thì server lấy giá phòng đang
  /// rao, thiếu tên thì ghi "Khách thuê ngoài app", thiếu ngày thì từ hôm nay.
  Future<ChoThueNgoai> danhDau(
    int roomId, {
    String tenKhach = '',
    String sdt = '',
    String? ngayBatDau,
    int soThang = 12,
    double? giaThue,
    double? cocDaThu,
    int? ngayThanhToan,
    String? ghiChu,
  }) async => ChoThueNgoai.fromMap(
    await _c.post(
      '/api/host/rooms/$roomId/cho-thue-ngoai',
      body: {
        'ten_khach': tenKhach,
        'sdt': sdt,
        'ngay_bat_dau': ?ngayBatDau,
        'so_thang': soThang,
        'gia_thue': ?giaThue,
        'coc_da_thu': ?cocDaThu,
        'ngay_thanh_toan': ?ngayThanhToan,
        'ghi_chu': ?ghiChu,
      },
    ),
  );

  Future<void> boDanhDau(int roomId) async {
    await _c.delete('/api/host/rooms/$roomId/cho-thue-ngoai');
  }
}

class ChoThueNgoai {
  const ChoThueNgoai({
    required this.contractId,
    required this.roomId,
    this.trangThaiPhong = '',
    this.batDau = '',
    this.ketThuc = '',
    this.tienThue = 0,
  });

  factory ChoThueNgoai.fromMap(Map<String, dynamic> m) => ChoThueNgoai(
    contractId: (m['contract_id'] as num?)?.toInt() ?? 0,
    roomId: (m['room_id'] as num?)?.toInt() ?? 0,
    trangThaiPhong: m['trang_thai_phong'] as String? ?? '',
    batDau: m['bat_dau'] as String? ?? '',
    ketThuc: m['ket_thuc'] as String? ?? '',
    tienThue: (m['tien_thue'] as num?)?.toDouble() ?? 0,
  );

  final int contractId;
  final int roomId;

  /// 'occupied' sau khi đánh dấu.
  final String trangThaiPhong;
  final String batDau;
  final String ketThuc;
  final double tienThue;
}
