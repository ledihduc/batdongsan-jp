import 'package:house_booking/data/models/phong_xem_truoc.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Hai luồng dựng toà, đối xứng và **không được lẫn**:
///
///     sale dựng toà   → `claim_code`   → CHỦ NHÀ nhập → nhận quyền SỞ HỮU
///     chủ nhà dựng    → `ma_moi_sale`  → SALE nhập     → nhận quyền PHỤ TRÁCH
///
/// Đưa nhầm mã là mất toà: `claim_code` trong tay sale biến họ thành chủ sở
/// hữu. Hai mã đi qua hai endpoint khác nhau, cố ý.
class MoiSaleApi {
  const MoiSaleApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  /// Chủ nhà sinh mã mời. Gọi lại khi đã có mã thì trả LẠI mã cũ — đổi mã mỗi
  /// lần bấm là làm hỏng mã vừa gửi cho sale qua Zalo.
  Future<String> sinhMa(int buildingId) async {
    final r = await _c.post('/api/host/buildings/$buildingId/ma-moi-sale');
    return r['ma'] as String? ?? '';
  }

  /// Thu hồi mã cũ và sinh mã mới — dùng khi mã lỡ lọt ra ngoài.
  Future<String> thuHoi(int buildingId) async {
    final r = await _c.delete('/api/host/buildings/$buildingId/ma-moi-sale');
    return r['ma'] as String? ?? '';
  }

  /// Sale xem mình sắp nhận cái gì trước khi bấm.
  Future<LoiMoiToa> xemTruoc(String ma) async =>
      LoiMoiToa.fromMap(await _c.get('/api/buildings/moi-sale/$ma'));

  Future<LoiMoiToa> nhan(String ma) async => LoiMoiToa.fromMap(
    await _c.post('/api/buildings/moi-sale', body: {'code': ma}),
  );

  /// Chiều còn lại: SALE xem mã BÀN GIAO để đưa cho chủ nhà.
  ///
  /// `claim_code` vốn chỉ trả về đúng một lần trong phản hồi tạo toà — đóng
  /// app rồi mở lại là mất mã. Đây là đường xem lại.
  Future<MaBanGiao> maBanGiao(int buildingId) async => MaBanGiao.fromMap(
    await _c.get('/api/host/buildings/$buildingId/ma-ban-giao'),
  );

  /// Đổi mã — dùng khi mã cũ lỡ lọt ra ngoài. Ai đọc được cũng chiếm được toà.
  Future<MaBanGiao> doiMaBanGiao(int buildingId) async => MaBanGiao.fromMap(
    await _c.post('/api/host/buildings/$buildingId/ma-ban-giao'),
  );
}

class MaBanGiao {
  const MaBanGiao({required this.buildingId, this.ma, this.daBanGiao = false});

  final int buildingId;

  /// `null` khi toà ĐÃ bàn giao — mã bị xoá vĩnh viễn, không sinh lại được.
  final String? ma;
  final bool daBanGiao;

  factory MaBanGiao.fromMap(Map<String, dynamic> m) => MaBanGiao(
    buildingId: (m['building_id'] as num?)?.toInt() ?? 0,
    ma: m['ma'] as String?,
    daBanGiao: m['da_ban_giao'] as bool? ?? false,
  );
}

class LoiMoiToa {
  const LoiMoiToa({
    required this.buildingId,
    required this.ten,
    this.diaChi = '',
    this.soPhong = 0,
    this.chuTen = '',
    this.daCoSale = false,
    this.soPhongNhan = 0,
    this.phong = const [],
    this.conLai = 0,
  });

  final int buildingId;
  final String ten;
  final String diaChi;
  final int soPhong;

  /// Chủ nhà chủ động mời nên tự lộ danh tính — khác hẳn luật giấu chủ nhà
  /// khỏi khách và sale lạ.
  final String chuTen;
  final bool daCoSale;

  /// Chỉ có ở phản hồi lúc NHẬN: số phòng vừa gán cho sale này.
  final int soPhongNhan;

  /// Danh sách phòng để sale biết mình sắp nhận HÀNG GÌ, không chỉ bao nhiêu.
  final List<PhongXemTruoc> phong;

  /// Số phòng máy chủ cắt bớt khỏi [phong] (toà lớn). 0 = đã liệt kê hết.
  final int conLai;

  factory LoiMoiToa.fromMap(Map<String, dynamic> m) => LoiMoiToa(
    buildingId: (m['building_id'] as num?)?.toInt() ?? 0,
    ten: m['ten'] as String? ?? '',
    diaChi: m['dia_chi'] as String? ?? '',
    soPhong: (m['so_phong'] as num?)?.toInt() ?? 0,
    chuTen: m['chu_ten'] as String? ?? '',
    daCoSale: m['da_co_sale'] as bool? ?? false,
    soPhongNhan: (m['so_phong_nhan'] as num?)?.toInt() ?? 0,
    phong: PhongXemTruoc.danhSach(m['phong']),
    conLai: (m['con_lai'] as num?)?.toInt() ?? 0,
  );
}
