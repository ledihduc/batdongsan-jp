import 'package:house_booking/data/services/api_client.dart';

/// SƠ ĐỒ MỘT PHÒNG: hàng = NGÀY, cột = GIỜ, liền nhiều tuần.
///
///     GET /api/host/rooms/{id}/lich-gio?tu_ngay=YYYY-MM-DD&so_tuan=4
///
/// Dành cho lưu trú THEO GIỜ: nhìn theo ngày thì một ca 4 tiếng làm cả ngày
/// trông như đã kín, trong khi sáu tiếng buổi sáng vẫn bán được.
class LichGioApi {
  const LichGioApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  /// [moc] 'tuan' = lùi về thứ Hai cho các tuần thẳng hàng (màn sơ đồ đầy đủ);
  /// 'ngay' = bắt đầu ĐÚNG ngày xin, cho thẻ 7 ngày "từ hôm nay đi tới".
  Future<LichGio> lay(
    int roomId, {
    String? tuNgay,
    int soTuan = 4,
    String moc = 'tuan',
  }) async => LichGio.fromMap(
    await _c.get(
      '/api/host/rooms/$roomId/lich-gio',
      queryParameters: {
        if (tuNgay != null) 'tu_ngay': tuNgay,
        'so_tuan': '$soTuan',
        'moc': moc,
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

/// Một khối trên hàng ngày, đo bằng GIỜ (0.0 = 00:00, 24.0 = hết ngày).
class KhoiGio {
  const KhoiGio({
    required this.loai,
    required this.id,
    required this.gio,
    required this.soGio,
    this.tranTruoc = false,
    this.tranSau = false,
    this.trangThai = '',
    this.nhanKieu = '',
    this.ten,
    this.maDat,
    this.tong,
    this.ghiChu,
  });

  factory KhoiGio.fromMap(Map<String, dynamic> m) => KhoiGio(
    loai: m['loai'] as String? ?? 'dat',
    id: _i(m['id']),
    gio: _d(m['gio']),
    soGio: _d(m['so_gio']),
    tranTruoc: m['tran_truoc'] == true,
    tranSau: m['tran_sau'] == true,
    trangThai: m['trang_thai'] as String? ?? '',
    nhanKieu: m['nhan_kieu'] as String? ?? '',
    ten: _s(m['ten']),
    maDat: _s(m['ma_dat']),
    tong: (m['tong'] as num?)?.toDouble(),
    ghiChu: _s(m['ghi_chu']),
  );

  final String loai;
  final int id;
  final double gio;
  final double soGio;

  /// Ca bắt đầu hôm trước / kéo sang hôm sau — vẽ mũi nhọn ở mép hàng.
  final bool tranTruoc;
  final bool tranSau;
  final String trangThai;
  final String nhanKieu;
  final String? ten;
  final String? maDat;
  final double? tong;
  final String? ghiChu;

  bool get laChan => loai == 'chan';

  /// 'HH:MM' của mép trái, tính ngay trên máy để khỏi gửi thêm trường.
  String get batDau {
    final h = gio.floor();
    final p = ((gio - h) * 60).round();
    return '${h.toString().padLeft(2, '0')}:${p.toString().padLeft(2, '0')}';
  }

  String get ketThuc {
    final t = gio + soGio;
    final h = t.floor();
    final p = ((t - h) * 60).round();
    return '${(h % 24).toString().padLeft(2, '0')}:${p.toString().padLeft(2, '0')}';
  }
}

class HangNgay {
  const HangNgay({
    required this.ngay,
    required this.thu,
    this.homNay = false,
    this.cuoiTuan = false,
    this.soCa = 0,
    this.gioBan = 0,
    this.tyLe = 0,
    this.doanhThu = 0,
    this.muc = const [],
  });

  factory HangNgay.fromMap(Map<String, dynamic> m) => HangNgay(
    ngay: DateTime.tryParse('${m['ngay']}') ?? DateTime.now(),
    thu: _i(m['thu']),
    homNay: m['hom_nay'] == true,
    cuoiTuan: m['cuoi_tuan'] == true,
    soCa: _i(m['so_ca']),
    gioBan: _d(m['gio_ban']),
    tyLe: _d(m['ty_le']),
    doanhThu: _d(m['doanh_thu']),
    muc: [
      for (final x in (m['muc'] as List? ?? const []))
        KhoiGio.fromMap((x as Map).cast<String, dynamic>()),
    ],
  );

  final DateTime ngay;

  /// 1 = thứ Hai … 7 = Chủ nhật.
  final int thu;
  final bool homNay;
  final bool cuoiTuan;
  final int soCa;
  final double gioBan;
  final double tyLe;
  final double doanhThu;
  final List<KhoiGio> muc;
}

class PhongGon {
  const PhongGon(this.id, this.ma);

  factory PhongGon.fromMap(Map<String, dynamic> m) =>
      PhongGon(_i(m['id']), m['ma'] as String? ?? '');

  final int id;
  final String ma;
}

class KpiGio {
  const KpiGio({
    this.luotDat = 0,
    this.gioBan = 0,
    this.soNgay = 0,
    this.congSuat = 0,
    this.doanhThu = 0,
  });

  factory KpiGio.fromMap(Map<String, dynamic> m) => KpiGio(
    luotDat: _i(m['luot_dat']),
    gioBan: _d(m['gio_ban']),
    soNgay: _i(m['so_ngay']),
    congSuat: _d(m['cong_suat']),
    doanhThu: _d(m['doanh_thu']),
  );

  final int luotDat;
  final double gioBan;
  final int soNgay;
  final double congSuat;
  final double doanhThu;
}

class LichGio {
  const LichGio({
    required this.tuNgay,
    required this.denNgay,
    required this.soTuan,
    required this.soNgay,
    required this.kpi,
    required this.phongId,
    required this.phongMa,
    this.buildingId = 0,
    this.bayGio,
    this.xemTaiChinh = false,
    this.toaTen = '',
    this.cacPhong = const [],
    this.ngay = const [],
  });

  factory LichGio.fromMap(Map<String, dynamic> m) {
    final phong = (m['phong'] as Map?)?.cast<String, dynamic>() ?? const {};
    final toa = (m['toa'] as Map?)?.cast<String, dynamic>() ?? const {};
    return LichGio(
      tuNgay: DateTime.tryParse('${m['tu_ngay']}') ?? DateTime.now(),
      denNgay: DateTime.tryParse('${m['den_ngay']}') ?? DateTime.now(),
      soTuan: _i(m['so_tuan']),
      soNgay: _i(m['so_ngay']),
      bayGio: DateTime.tryParse('${m['bay_gio']}'),
      xemTaiChinh: m['xem_tai_chinh'] == true,
      phongId: _i(phong['id']),
      phongMa: phong['ma'] as String? ?? '',
      buildingId: _i(phong['building_id']),
      toaTen: toa['ten'] as String? ?? '',
      kpi: KpiGio.fromMap((m['kpi'] as Map?)?.cast<String, dynamic>() ?? const {}),
      cacPhong: [
        for (final x in (m['cac_phong'] as List? ?? const []))
          PhongGon.fromMap((x as Map).cast<String, dynamic>()),
      ],
      ngay: [
        for (final x in (m['ngay'] as List? ?? const []))
          HangNgay.fromMap((x as Map).cast<String, dynamic>()),
      ],
    );
  }

  final DateTime tuNgay;
  final DateTime denNgay;
  final int soTuan;
  final int soNgay;
  final DateTime? bayGio;
  final bool xemTaiChinh;
  final int phongId;
  final String phongMa;
  final int buildingId;
  final String toaTen;
  final KpiGio kpi;
  final List<PhongGon> cacPhong;
  final List<HangNgay> ngay;
}
