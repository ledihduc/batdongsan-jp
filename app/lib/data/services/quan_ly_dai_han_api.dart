import 'package:house_booking/data/services/api_client.dart';

/// Bốn màn "Quản lý cho thuê dài hạn" của chủ nhà, đọc theo MỘT TOÀ:
/// Khách hàng · Hợp đồng · Hóa đơn · Doanh thu.
///
/// API: `GET /api/host/buildings/{id}/{khach-hang|hop-dong|hoa-don|doanh-thu}`
/// (backend `services/quan_ly_dai_han.py`). Server đã chốt mọi luật đếm — app
/// KHÔNG tự suy "sắp hết hạn" hay "còn nợ", nếu không hai màn ra hai số.
class QuanLyDaiHanApi {
  const QuanLyDaiHanApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<KhachHangToa> khachHang(
    int buildingId, {
    String tim = '',
    String loc = 'tat_ca',
  }) async => KhachHangToa.fromMap(
    await _c.get(
      '/api/host/buildings/$buildingId/khach-hang',
      queryParameters: {if (tim.isNotEmpty) 'tim': tim, 'loc': loc},
    ),
  );

  Future<HopDongToa> hopDong(
    int buildingId, {
    String tab = 'hieu_luc',
  }) async => HopDongToa.fromMap(
    await _c.get(
      '/api/host/buildings/$buildingId/hop-dong',
      queryParameters: {'tab': tab},
    ),
  );

  Future<HoaDonToa> hoaDon(
    int buildingId, {
    String? thang,
    String tab = 'chua_thu',
  }) async => HoaDonToa.fromMap(
    await _c.get(
      '/api/host/buildings/$buildingId/hoa-don',
      queryParameters: {if (thang != null) 'thang': thang, 'tab': tab},
    ),
  );

  Future<DoanhThuToa> doanhThu(int buildingId, {String? thang}) async =>
      DoanhThuToa.fromMap(
        await _c.get(
          '/api/host/buildings/$buildingId/doanh-thu',
          queryParameters: {if (thang != null) 'thang': thang},
        ),
      );

  /// Lập hoá đơn kỳ này cho mọi hợp đồng của toà còn thiếu. Trả về số hoá đơn
  /// vừa lập và những phòng lập không được (kèm lý do) — không nuốt lỗi.
  Future<TaoHoaDonKetQua> taoHoaDonThang(
    int buildingId, {
    String? thang,
  }) async => TaoHoaDonKetQua.fromMap(
    await _c.post(
      '/api/host/buildings/$buildingId/hoa-don/tao-thang'
      '${thang == null ? '' : '?thang=$thang'}',
    ),
  );
}

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
double? _dn(dynamic v) => (v as num?)?.toDouble();
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
String _s(dynamic v) => v as String? ?? '';

// ── MÀN 1 — Khách hàng ──────────────────────────────────────────────────────
class KhachHangToa {
  const KhachHangToa({
    this.dangO = 0,
    this.sapHetHd = 0,
    this.coCongNo = 0,
    this.danhSach = const [],
  });

  factory KhachHangToa.fromMap(Map<String, dynamic> m) {
    final t = (m['tom_tat'] as Map?)?.cast<String, dynamic>() ?? const {};
    return KhachHangToa(
      dangO: _i(t['dang_o']),
      sapHetHd: _i(t['sap_het_hd']),
      coCongNo: _i(t['co_cong_no']),
      danhSach: [
        for (final x in m['danh_sach'] as List? ?? const [])
          KhachThueToa.fromMap((x as Map).cast<String, dynamic>()),
      ],
    );
  }

  final int dangO;
  final int sapHetHd;
  final int coCongNo;
  final List<KhachThueToa> danhSach;
}

class KhachThueToa {
  const KhachThueToa({
    required this.contractId,
    required this.ten,
    required this.phong,
    this.roomId,
    this.tenantId,
    this.sdt = '',
    this.trangThai = 'dang_o',
    this.soThangDaO = 0,
    this.no,
    this.hopDongDen,
  });

  factory KhachThueToa.fromMap(Map<String, dynamic> m) => KhachThueToa(
    contractId: _i(m['contract_id']),
    roomId: (m['room_id'] as num?)?.toInt(),
    tenantId: (m['tenant_id'] as num?)?.toInt(),
    ten: _s(m['ten']),
    phong: _s(m['phong']),
    sdt: _s(m['sdt']),
    trangThai: _s(m['trang_thai']),
    soThangDaO: _i(m['so_thang_da_o']),
    no: _dn(m['no']),
    hopDongDen: m['hop_dong_den'] as String?,
  );

  final int contractId;
  final int? roomId;
  final int? tenantId;
  final String ten;
  final String phong;
  final String sdt;

  /// 'dang_o' | 'sap_het_hd'.
  final String trangThai;
  final int soThangDaO;

  /// Tổng còn thiếu của các hoá đơn chưa thu đủ; `null` = không nợ.
  final double? no;
  final String? hopDongDen;

  bool get sapHetHd => trangThai == 'sap_het_hd';
}

// ── MÀN 2 — Hợp đồng ────────────────────────────────────────────────────────
class HopDongToa {
  const HopDongToa({
    this.hieuLuc = 0,
    this.sapHetHan = 0,
    this.choGiaHan = 0,
    this.daKetThuc = 0,
    this.danhSach = const [],
  });

  factory HopDongToa.fromMap(Map<String, dynamic> m) {
    final t = (m['tom_tat'] as Map?)?.cast<String, dynamic>() ?? const {};
    return HopDongToa(
      hieuLuc: _i(t['hieu_luc']),
      sapHetHan: _i(t['sap_het_han']),
      choGiaHan: _i(t['cho_gia_han']),
      daKetThuc: _i(t['da_ket_thuc']),
      danhSach: [
        for (final x in m['danh_sach'] as List? ?? const [])
          HopDongMuc.fromMap((x as Map).cast<String, dynamic>()),
      ],
    );
  }

  final int hieuLuc;
  final int sapHetHan;
  final int choGiaHan;
  final int daKetThuc;
  final List<HopDongMuc> danhSach;
}

class HopDongMuc {
  const HopDongMuc({
    required this.id,
    required this.phong,
    required this.khach,
    required this.tu,
    required this.den,
    required this.giaThue,
    required this.tienCoc,
    this.nhom = 'hieu_luc',
    this.nhan = '',
    this.tongThang = 0,
    this.daQuaThang = 0,
    this.conThang = 0,
    this.phanTram = 0,
  });

  factory HopDongMuc.fromMap(Map<String, dynamic> m) => HopDongMuc(
    id: _i(m['id']),
    phong: _s(m['phong']),
    khach: _s(m['khach']),
    tu: _s(m['tu']),
    den: _s(m['den']),
    giaThue: _d(m['gia_thue']),
    tienCoc: _d(m['tien_coc']),
    nhom: _s(m['nhom']),
    nhan: _s(m['nhan']),
    tongThang: _i(m['tong_thang']),
    daQuaThang: _i(m['da_qua_thang']),
    conThang: _i(m['con_thang']),
    phanTram: _i(m['phan_tram']),
  );

  final int id;
  final String phong;
  final String khach;
  final String tu;
  final String den;
  final double giaThue;
  final double tienCoc;

  /// 'hieu_luc' | 'sap_het_han' | 'cho_gia_han' | 'da_ket_thuc'.
  final String nhom;

  /// "Còn 3 tháng" · "Sắp hết hạn" · "Quá hạn 5 ngày" — server đặt tên.
  final String nhan;
  final int tongThang;
  final int daQuaThang;
  final int conThang;
  final int phanTram;
}

// ── MÀN 3 — Hóa đơn ─────────────────────────────────────────────────────────
class HoaDonToa {
  const HoaDonToa({
    this.thang = '',
    this.chuaTaoSo = 0,
    this.chuaThu = 0,
    this.quaHan = 0,
    this.daThu = 0,
    this.tongCanThu = 0,
    this.danhSach = const [],
    this.chuaTao = const [],
  });

  factory HoaDonToa.fromMap(Map<String, dynamic> m) {
    final t = (m['tom_tat'] as Map?)?.cast<String, dynamic>() ?? const {};
    return HoaDonToa(
      thang: _s(m['thang']),
      chuaTaoSo: _i(t['chua_tao']),
      chuaThu: _i(t['chua_thu']),
      quaHan: _i(t['qua_han']),
      daThu: _i(t['da_thu']),
      tongCanThu: _d(t['tong_can_thu']),
      danhSach: [
        for (final x in m['danh_sach'] as List? ?? const [])
          HoaDonMuc.fromMap((x as Map).cast<String, dynamic>()),
      ],
      chuaTao: [
        for (final x in m['chua_tao'] as List? ?? const [])
          HoaDonChuaTao.fromMap((x as Map).cast<String, dynamic>()),
      ],
    );
  }

  final String thang;
  final int chuaTaoSo;
  final int chuaThu;
  final int quaHan;
  final int daThu;
  final double tongCanThu;
  final List<HoaDonMuc> danhSach;
  final List<HoaDonChuaTao> chuaTao;
}

class HoaDonMuc {
  const HoaDonMuc({
    required this.id,
    required this.phong,
    required this.khach,
    required this.ky,
    required this.tong,
    this.trangThai = 'chua_thanh_toan',
    this.nhan = '',
    this.tienPhong = 0,
    this.dien = 0,
    this.nuoc = 0,
    this.dichVu = 0,
    this.daThu = 0,
    this.conLai = 0,
    this.han,
    this.daGui = true,
  });

  factory HoaDonMuc.fromMap(Map<String, dynamic> m) => HoaDonMuc(
    id: _i(m['id']),
    phong: _s(m['phong']),
    khach: _s(m['khach']),
    ky: _s(m['ky']),
    tong: _d(m['tong']),
    trangThai: _s(m['trang_thai']),
    nhan: _s(m['nhan']),
    tienPhong: _d(m['tien_phong']),
    dien: _d(m['dien']),
    nuoc: _d(m['nuoc']),
    dichVu: _d(m['dich_vu']),
    daThu: _d(m['da_thu']),
    conLai: _d(m['con_lai']),
    han: m['han'] as String?,
    daGui: m['da_gui'] as bool? ?? true,
  );

  final int id;
  final String phong;
  final String khach;
  final String ky;

  /// 'qua_han' | 'chua_thanh_toan' | 'da_thanh_toan'.
  final String trangThai;
  final String nhan;
  final double tienPhong;
  final double dien;
  final double nuoc;
  final double dichVu;
  final double tong;
  final double daThu;
  final double conLai;
  final String? han;

  /// Hoá đơn đã gửi cho khách chưa (`status != draft`). Nháp vẫn tính vào
  /// tiền phải thu, nhưng khách chưa nhận được gì — nói "chưa thanh toán" là
  /// đổ lỗi cho người chưa thấy hoá đơn.
  final bool daGui;

  bool get daTra => trangThai == 'da_thanh_toan';
  bool get treHan => trangThai == 'qua_han';
}

class HoaDonChuaTao {
  const HoaDonChuaTao({
    required this.contractId,
    required this.phong,
    required this.khach,
    this.giaThue = 0,
    this.ngayThanhToan,
  });

  factory HoaDonChuaTao.fromMap(Map<String, dynamic> m) => HoaDonChuaTao(
    contractId: _i(m['contract_id']),
    phong: _s(m['phong']),
    khach: _s(m['khach']),
    giaThue: _d(m['gia_thue']),
    ngayThanhToan: (m['ngay_thanh_toan'] as num?)?.toInt(),
  );

  final int contractId;
  final String phong;
  final String khach;
  final double giaThue;
  final int? ngayThanhToan;
}

class TaoHoaDonKetQua {
  const TaoHoaDonKetQua({
    this.thang = '',
    this.vuaLap = 0,
    this.khongLapDuoc = const [],
  });

  factory TaoHoaDonKetQua.fromMap(Map<String, dynamic> m) => TaoHoaDonKetQua(
    thang: _s(m['thang']),
    vuaLap: (m['vua_lap'] as List? ?? const []).length,
    khongLapDuoc: [
      for (final x in m['khong_lap_duoc'] as List? ?? const [])
        (
          phong: _s((x as Map)['phong']),
          viSao: _s(x['vi_sao']),
        ),
    ],
  );

  final String thang;
  final int vuaLap;
  final List<({String phong, String viSao})> khongLapDuoc;
}

// ── MÀN 4 — Doanh thu ───────────────────────────────────────────────────────
class DoanhThuToa {
  const DoanhThuToa({
    this.thang = '',
    this.doanhThu = 0,
    this.daThu = 0,
    this.daThuPhanTram = 0,
    this.chuaThu = 0,
    this.chuaThuPhanTram = 0,
    this.quaHan = 0,
    this.sauThang = const [],
    this.coCau = const [],
    this.topPhong = const [],
    this.congNo = const [],
  });

  factory DoanhThuToa.fromMap(Map<String, dynamic> m) => DoanhThuToa(
    thang: _s(m['thang']),
    doanhThu: _d(m['doanh_thu']),
    daThu: _d(m['da_thu']),
    daThuPhanTram: _i(m['da_thu_phan_tram']),
    chuaThu: _d(m['chua_thu']),
    chuaThuPhanTram: _i(m['chua_thu_phan_tram']),
    quaHan: _d(m['qua_han']),
    sauThang: [
      for (final x in m['sau_thang'] as List? ?? const [])
        (
          thang: _s((x as Map)['thang']),
          nhan: _s(x['nhan']),
          tien: _d(x['tien']),
        ),
    ],
    coCau: [
      for (final x in m['co_cau'] as List? ?? const [])
        (
          ma: _s((x as Map)['ma']),
          nhan: _s(x['nhan']),
          tien: _d(x['tien']),
          phanTram: _i(x['phan_tram']),
        ),
    ],
    topPhong: [
      for (final x in m['top_phong'] as List? ?? const [])
        (phong: _s((x as Map)['phong']), tien: _d(x['tien'])),
    ],
    congNo: [
      for (final x in m['cong_no'] as List? ?? const [])
        (phong: _s((x as Map)['phong']), tien: _d(x['tien'])),
    ],
  );

  final String thang;
  final double doanhThu;
  final double daThu;
  final int daThuPhanTram;
  final double chuaThu;
  final int chuaThuPhanTram;
  final double quaHan;
  final List<({String thang, String nhan, double tien})> sauThang;
  final List<({String ma, String nhan, double tien, int phanTram})> coCau;
  final List<({String phong, double tien})> topPhong;
  final List<({String phong, double tien})> congNo;
}
