import 'package:house_booking/data/services/api_client.dart';

/// Số liệu màn Trang chủ của chủ nhà — `GET /api/host/tong-quan`.
///
/// Một lượt gọi, số đo từ bảng thật. Trường nào server không tính được thì là
/// `null` và màn hình ẨN nó — không in số minh hoạ.
class TongQuanChuNhaApi {
  const TongQuanChuNhaApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<TongQuanChuNha> lay({int? buildingId}) async => TongQuanChuNha.fromMap(
    await _c.get(
      '/api/host/tong-quan',
      queryParameters: {if (buildingId != null) 'building_id': buildingId},
    ),
  );
}

double? _d(dynamic v) => (v as num?)?.toDouble();
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

class TongQuanChuNha {
  const TongQuanChuNha({
    required this.soToa,
    required this.soPhong,
    required this.toaMoiThangNay,
    required this.daiHanDangThue,
    required this.daiHanTong,
    required this.daiHanLapDay,
    required this.nganHanHoatDong,
    required this.nganHanCongSuat,
    required this.doanhThuThang,
    required this.doanhThuTang,
    required this.thangTruoc,
    required this.daiHan,
    required this.kinhDoanh,
    required this.nganHan,
    required this.toa,
    this.phongDaThue = 0,
    this.phongTrong = 0,
    this.tyLeLapDay,
    this.tyLeTrong,
    this.lapDayTang,
    this.lapDay6Thang = const [],
    this.toaNha = const [],
  });

  final int soToa;
  final int soPhong;
  final int toaMoiThangNay;
  final int daiHanDangThue;
  final int daiHanTong;
  final double? daiHanLapDay;
  final int nganHanHoatDong;
  final double? nganHanCongSuat;
  final double doanhThuThang;

  /// `null` khi tháng trước không có doanh thu — "tăng bao nhiêu %" vô nghĩa.
  final double? doanhThuTang;
  final int thangTruoc;
  final List<KhoiThue> daiHan;
  final List<KhoiThue> kinhDoanh;
  final List<KhoiNganHan> nganHan;
  final List<({int id, String ten})> toa;

  /// Phòng có người ở NGAY BÂY GIỜ (hợp đồng còn hiệu lực hoặc khách lưu trú
  /// đang ở). [phongDaThue] + [phongTrong] = [soPhong] — hai thẻ cộng lại đúng
  /// bằng số phòng ghi ở ô chọn toà ngay phía trên.
  final int phongDaThue;
  final int phongTrong;

  /// `null` khi chưa có phòng nào.
  final double? tyLeLapDay;
  final double? tyLeTrong;

  /// Chênh lệch ĐIỂM % so với tháng trước; `null` khi tháng trước chưa có số.
  final double? lapDayTang;

  /// 6 tháng gần nhất, cũ → mới. Điểm cuối là tháng này = [tyLeLapDay].
  final List<({int nam, int thang, double? tyLe})> lapDay6Thang;
  final List<ToaNha> toaNha;

  factory TongQuanChuNha.fromMap(Map<String, dynamic> m) => TongQuanChuNha(
    soToa: _i(m['so_toa']),
    soPhong: _i(m['so_phong']),
    toaMoiThangNay: _i(m['toa_moi_thang_nay']),
    daiHanDangThue: _i(m['dai_han_dang_thue']),
    daiHanTong: _i(m['dai_han_tong']),
    daiHanLapDay: _d(m['dai_han_lap_day']),
    nganHanHoatDong: _i(m['ngan_han_hoat_dong']),
    nganHanCongSuat: _d(m['ngan_han_cong_suat']),
    doanhThuThang: _d(m['doanh_thu_thang']) ?? 0,
    doanhThuTang: _d(m['doanh_thu_tang']),
    thangTruoc: _i(m['thang_truoc']),
    daiHan: _ds(m['dai_han'], KhoiThue.fromMap),
    kinhDoanh: _ds(m['kinh_doanh'], KhoiThue.fromMap),
    nganHan: _ds(m['ngan_han'], KhoiNganHan.fromMap),
    toa: [
      for (final t in (m['toa'] as List? ?? const []).whereType<Map>())
        (id: _i(t['building_id']), ten: t['ten'] as String? ?? ''),
    ],
    phongDaThue: _i(m['phong_da_thue']),
    phongTrong: _i(m['phong_trong']),
    tyLeLapDay: _d(m['ty_le_lap_day']),
    tyLeTrong: _d(m['ty_le_trong']),
    lapDayTang: _d(m['lap_day_tang']),
    lapDay6Thang: [
      for (final t
          in (m['lap_day_6_thang'] as List? ?? const []).whereType<Map>())
        (nam: _i(t['nam']), thang: _i(t['thang']), tyLe: _d(t['ty_le'])),
    ],
    toaNha: _ds(m['toa_nha'], ToaNha.fromMap),
  );
}

List<T> _ds<T>(dynamic raw, T Function(Map<String, dynamic>) f) => [
  for (final e in (raw as List? ?? const []).whereType<Map>())
    f(Map<String, dynamic>.from(e)),
];

/// Một toà trong danh sách "Tòa nhà của bạn".
class ToaNha {
  const ToaNha({
    required this.buildingId,
    required this.ten,
    this.diaChi = '',
    this.anhBia,
    this.tong = 0,
    this.daThue = 0,
    this.tyLe = 0,
    this.loai = const [],
    this.hoatDong = false,
  });

  final int buildingId;
  final String ten;
  final String diaChi;
  final String? anhBia;

  /// Mọi phòng của toà.
  final int tong;

  /// Có người ở NGAY BÂY GIỜ.
  final int daThue;
  final int tyLe;

  /// Nhãn SUY từ việc toà đang làm (bảng toà không có cột loại hình), đúng thứ
  /// tự hiện trên thẻ: 'khach_san' | 'kinh_doanh' | 'ngan_han' | 'dai_han' |
  /// 'cho_thue'.
  final List<String> loai;
  final bool hoatDong;

  factory ToaNha.fromMap(Map<String, dynamic> m) => ToaNha(
    buildingId: _i(m['building_id']),
    ten: m['ten'] as String? ?? '',
    diaChi: m['dia_chi'] as String? ?? '',
    anhBia: m['anh_bia'] as String?,
    tong: _i(m['tong']),
    daThue: _i(m['da_thue']),
    tyLe: _i(m['ty_le']),
    loai: [
      for (final k in (m['loai'] as List? ?? const []))
        if (k is String) k,
    ],
    hoatDong: m['hoat_dong'] as bool? ?? false,
  );
}

/// Một toà trong khối Dài hạn / Kinh doanh.
class KhoiThue {
  const KhoiThue({
    required this.buildingId,
    required this.ten,
    this.diaChi = '',
    this.anhBia,
    this.tong = 0,
    this.dangThue = 0,
    this.tyLe = 0,
    this.phongNo = 0,
    this.hoaDonNo = 0,
    this.tienNo = 0,
    this.yeuCauDienNuoc = 0,
  });

  final int buildingId;
  final String ten;
  final String diaChi;
  final String? anhBia;
  final int tong;
  final int dangThue;
  final int tyLe;
  final int phongNo;

  /// Số hoá đơn còn nợ và TỔNG tiền còn phải thu của toà. "3 phòng chưa thu"
  /// không trả lời được câu chủ nhà hỏi trước nhất: còn bao nhiêu tiền.
  final int hoaDonNo;
  final double tienNo;
  final int yeuCauDienNuoc;

  factory KhoiThue.fromMap(Map<String, dynamic> m) => KhoiThue(
    buildingId: _i(m['building_id']),
    ten: m['ten'] as String? ?? '',
    diaChi: m['dia_chi'] as String? ?? '',
    anhBia: m['anh_bia'] as String?,
    tong: _i(m['tong']),
    dangThue: _i(m['dang_thue']),
    tyLe: _i(m['ty_le']),
    phongNo: _i(m['phong_no']),
    hoaDonNo: _i(m['hoa_don_no']),
    tienNo: (m['tien_no'] as num?)?.toDouble() ?? 0,
    yeuCauDienNuoc: _i(m['yeu_cau_dien_nuoc']),
  );
}

/// Một toà trong khối Ngắn hạn.
class KhoiNganHan {
  const KhoiNganHan({
    required this.buildingId,
    required this.ten,
    this.diaChi = '',
    this.anhBia,
    this.tong = 0,
    this.dangSuDung = 0,
    this.trong = 0,
    this.tyLe = 0,
  });

  final int buildingId;
  final String ten;
  final String diaChi;
  final String? anhBia;
  final int tong;

  /// Có khách ĐANG Ở ngay lúc này — đơn 14–17h thì 18h phòng trống lại.
  final int dangSuDung;
  final int trong;
  final int tyLe;

  factory KhoiNganHan.fromMap(Map<String, dynamic> m) => KhoiNganHan(
    buildingId: _i(m['building_id']),
    ten: m['ten'] as String? ?? '',
    diaChi: m['dia_chi'] as String? ?? '',
    anhBia: m['anh_bia'] as String?,
    tong: _i(m['tong']),
    dangSuDung: _i(m['dang_su_dung']),
    trong: _i(m['trong']),
    tyLe: _i(m['ty_le']),
  );
}
