import 'package:house_booking/data/services/api_client.dart';

/// SƠ ĐỒ PHÒNG × NGÀY nhiều tuần liền của cả toà.
///
///     GET /api/host/buildings/{id}/lich-tuan?tu_ngay=YYYY-MM-DD&so_tuan=4
///
/// Khác [LichNganHanApi] ở TRỤC HOÀNH: lịch ngày trả lời "lúc này phòng nào
/// trống", sơ đồ tuần trả lời "tháng tới còn khe nào bán được, ngày nào ế".
class LichTuanApi {
  const LichTuanApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<LichTuan> lay(int buildingId, {String? tuNgay, int soTuan = 4}) async =>
      LichTuan.fromMap(
        await _c.get(
          '/api/host/buildings/$buildingId/lich-tuan',
          queryParameters: {
            if (tuNgay != null) 'tu_ngay': tuNgay,
            'so_tuan': '$soTuan',
          },
        ),
      );
}

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

String? _s(dynamic v) {
  final s = v is String ? v.trim() : null;
  return s == null || s.isEmpty ? null : s;
}

/// Một khối trên sơ đồ, đo bằng CỘT NGÀY (1.0 = một ngày).
class KhoiTuan {
  const KhoiTuan({
    required this.loai,
    required this.id,
    required this.cot,
    required this.soCot,
    this.tu,
    this.den,
    this.tranTruoc = false,
    this.tranSau = false,
    this.trangThai = '',
    this.nhanKieu = '',
    this.ten,
    this.maDat,
    this.tong,
    this.ghiChu,
  });

  factory KhoiTuan.fromMap(Map<String, dynamic> m) => KhoiTuan(
    loai: m['loai'] as String? ?? 'dat',
    id: _i(m['id']),
    cot: _d(m['cot']),
    soCot: _d(m['so_cot']),
    tu: DateTime.tryParse('${m['tu_that'] ?? m['tu']}'),
    den: DateTime.tryParse('${m['den_that'] ?? m['den']}'),
    tranTruoc: m['tran_truoc'] == true,
    tranSau: m['tran_sau'] == true,
    trangThai: m['trang_thai'] as String? ?? '',
    nhanKieu: m['nhan_kieu'] as String? ?? '',
    ten: _s(m['ten']),
    maDat: _s(m['ma_dat']),
    tong: (m['tong'] as num?)?.toDouble(),
    ghiChu: _s(m['ghi_chu']),
  );

  /// 'dat' = ca thuê · 'chan' = khoá tay (dọn phòng, sửa chữa).
  final String loai;
  final int id;

  /// Mép trái tính bằng cột ngày kể từ [LichTuan.tuNgay] (2.625 = 15:00 ngày 3).
  final double cot;
  final double soCot;
  final DateTime? tu;
  final DateTime? den;
  final bool tranTruoc;
  final bool tranSau;
  final String trangThai;
  final String nhanKieu;
  final String? ten;
  final String? maDat;
  final double? tong;
  final String? ghiChu;

  bool get laChan => loai == 'chan';
}

class NgayTuan {
  const NgayTuan({
    required this.ngay,
    required this.thu,
    this.homNay = false,
    this.cuoiTuan = false,
    this.ban = 0,
    this.congSuat = 0,
  });

  factory NgayTuan.fromMap(Map<String, dynamic> m) => NgayTuan(
    ngay: DateTime.tryParse('${m['ngay']}') ?? DateTime.now(),
    thu: _i(m['thu']),
    homNay: m['hom_nay'] == true,
    cuoiTuan: m['cuoi_tuan'] == true,
    ban: _i(m['ban']),
    congSuat: _d(m['cong_suat']),
  );

  final DateTime ngay;

  /// 1 = thứ Hai … 7 = Chủ nhật.
  final int thu;
  final bool homNay;
  final bool cuoiTuan;

  /// Số phòng có khách trong ngày này.
  final int ban;
  final double congSuat;
}

class HangPhongTuan {
  const HangPhongTuan({
    required this.id,
    required this.ma,
    this.sucChua,
    this.hang,
    this.muc = const [],
  });

  factory HangPhongTuan.fromMap(Map<String, dynamic> m) => HangPhongTuan(
    id: _i(m['id']),
    ma: m['ma'] as String? ?? '',
    sucChua: (m['suc_chua'] as num?)?.toInt(),
    hang: _s(m['hang']),
    muc: [
      for (final x in (m['muc'] as List? ?? const []))
        KhoiTuan.fromMap((x as Map).cast<String, dynamic>()),
    ],
  );

  final int id;
  final String ma;
  final int? sucChua;
  final String? hang;
  final List<KhoiTuan> muc;
}

class KpiTuan {
  const KpiTuan({
    this.luotDat = 0,
    this.demBan = 0,
    this.soPhong = 0,
    this.congSuat = 0,
    this.doanhThu = 0,
  });

  factory KpiTuan.fromMap(Map<String, dynamic> m) => KpiTuan(
    luotDat: _i(m['luot_dat']),
    demBan: _i(m['dem_ban']),
    soPhong: _i(m['so_phong']),
    congSuat: _d(m['cong_suat']),
    doanhThu: _d(m['doanh_thu']),
  );

  final int luotDat;

  /// Số ô phòng×ngày đã bán trong cả kỳ.
  final int demBan;
  final int soPhong;
  final double congSuat;
  final double doanhThu;
}

class LichTuan {
  const LichTuan({
    required this.tuNgay,
    required this.denNgay,
    required this.soNgay,
    required this.soTuan,
    required this.kpi,
    this.bayGio,
    this.xemTaiChinh = false,
    this.toaTen = '',
    this.toaDiaChi = '',
    this.ngay = const [],
    this.phong = const [],
  });

  factory LichTuan.fromMap(Map<String, dynamic> m) {
    final toa = (m['toa'] as Map?)?.cast<String, dynamic>() ?? const {};
    return LichTuan(
      tuNgay: DateTime.tryParse('${m['tu_ngay']}') ?? DateTime.now(),
      denNgay: DateTime.tryParse('${m['den_ngay']}') ?? DateTime.now(),
      soNgay: _i(m['so_ngay']),
      soTuan: _i(m['so_tuan']),
      bayGio: DateTime.tryParse('${m['bay_gio']}'),
      xemTaiChinh: m['xem_tai_chinh'] == true,
      toaTen: toa['ten'] as String? ?? '',
      toaDiaChi: toa['dia_chi'] as String? ?? '',
      kpi: KpiTuan.fromMap((m['kpi'] as Map?)?.cast<String, dynamic>() ?? const {}),
      ngay: [
        for (final x in (m['ngay'] as List? ?? const []))
          NgayTuan.fromMap((x as Map).cast<String, dynamic>()),
      ],
      phong: [
        for (final x in (m['phong'] as List? ?? const []))
          HangPhongTuan.fromMap((x as Map).cast<String, dynamic>()),
      ],
    );
  }

  final DateTime tuNgay;
  final DateTime denNgay;
  final int soNgay;
  final int soTuan;
  final DateTime? bayGio;
  final bool xemTaiChinh;
  final String toaTen;
  final String toaDiaChi;
  final KpiTuan kpi;
  final List<NgayTuan> ngay;
  final List<HangPhongTuan> phong;
}
