import 'package:house_booking/data/services/api_client.dart';

/// Trang "Dịch vụ & hoá đơn" — xem trước dòng tiền tháng rồi mới chốt.
///
///     POST /api/host/hoa-don/xem-truoc   không ghi gì, gọi lại mỗi lần đổi lựa chọn
///     POST /api/host/hoa-don/chot        tạo hoá đơn theo đúng lựa chọn đang hiện
///
/// Xem trước là POST vì lựa chọn dịch vụ là một danh sách (id + số lượng).
class HoaDonThangApi {
  const HoaDonThangApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  /// `dichVu` = `{service_fee_id: số lượng}`. `null` = mặc định của hợp đồng
  /// (mọi dịch vụ đã gắn, mỗi thứ một lần) — KHÁC với `{}` là "tắt hết".
  Future<HoaDonThang> xemTruoc(
    int contractId,
    String thang, {
    Map<int, double>? dichVu,
    double giamTru = 0,
  }) async => HoaDonThang.fromMap(
    await _c.post(
      '/api/host/hoa-don/xem-truoc',
      body: _than(contractId, thang, dichVu, giamTru),
    ),
  );

  /// Chốt hoá đơn. `gui: true` = tạo xong gửi luôn cho khách.
  Future<ChotHoaDon> chot(
    int contractId,
    String thang, {
    Map<int, double>? dichVu,
    double giamTru = 0,
    bool gui = false,
  }) async => ChotHoaDon.fromMap(
    await _c.post(
      '/api/host/hoa-don/chot',
      body: {..._than(contractId, thang, dichVu, giamTru), 'gui': gui},
    ),
  );

  static Map<String, Object?> _than(
    int contractId,
    String thang,
    Map<int, double>? dichVu,
    double giamTru,
  ) => {
    'contract_id': contractId,
    'thang': thang,
    if (dichVu != null)
      'dich_vu': [
        for (final e in dichVu.entries) {'id': e.key, 'so_luong': e.value},
      ],
    'giam_tru': giamTru,
  };
}

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

String? _s(dynamic v) {
  final s = (v as String?)?.trim();
  return s == null || s.isEmpty ? null : s;
}

/// Một dòng trên hoá đơn (tiền phòng · điện · nước · dịch vụ · giảm trừ).
class DongTien {
  const DongTien({
    required this.loai,
    required this.moTa,
    this.soLuong = 0,
    this.donGia = 0,
    this.tien = 0,
  });

  factory DongTien.fromMap(Map<String, dynamic> m) => DongTien(
    loai: (m['category'] as String?) ?? '',
    moTa: (m['description'] as String?) ?? '',
    soLuong: _d(m['quantity']),
    donGia: _d(m['unit_price']),
    tien: _d(m['amount']),
  );

  /// 'rent' | 'electricity' | 'water' | 'service' | 'adjustment'
  final String loai;
  final String moTa;
  final double soLuong;
  final double donGia;

  /// Giảm trừ là số ÂM — đừng lấy trị tuyệt đối rồi cộng vào tổng.
  final double tien;
}

/// Dịch vụ của toà, kèm trạng thái bật/tắt cho tháng đang xem.
class DichVuThang {
  const DichVuThang({
    required this.id,
    required this.ten,
    this.donGia = 0,
    this.chuKy = 'monthly',
    this.dangBat = false,
    this.soLuong = 0,
  });

  factory DichVuThang.fromMap(Map<String, dynamic> m) => DichVuThang(
    id: _i(m['id']),
    ten: (m['ten'] as String?) ?? '',
    donGia: _d(m['don_gia']),
    chuKy: (m['chu_ky'] as String?) ?? 'monthly',
    dangBat: m['dang_bat'] == true,
    soLuong: _d(m['so_luong']),
  );

  final int id;
  final String ten;
  final double donGia;

  /// 'monthly' = nút bật/tắt · còn lại = tính theo lượt, có ô đếm số lượng.
  final String chuKy;
  final bool dangBat;
  final double soLuong;

  bool get theoLuot => chuKy != 'monthly';
}

/// Hoá đơn đã có trong hệ thống (kỳ này hoặc trong lịch sử).
class HoaDonTomTat {
  const HoaDonTomTat({
    required this.id,
    this.so = '',
    this.ky = '',
    this.tong = 0,
    this.daTra = 0,
    this.trangThai = 'draft',
    this.hanDong,
  });

  factory HoaDonTomTat.fromMap(Map<String, dynamic> m) => HoaDonTomTat(
    id: _i(m['id']),
    so: (m['so'] as String?) ?? '',
    ky: (m['ky'] as String?) ?? '',
    tong: _d(m['tong']),
    daTra: _d(m['da_tra']),
    trangThai: (m['trang_thai'] as String?) ?? 'draft',
    hanDong: _s(m['han_dong']),
  );

  final int id;
  final String so;

  /// 'YYYY-MM'.
  final String ky;
  final double tong;
  final double daTra;

  /// 'draft' | 'sent' | 'partial' | 'paid' | 'overdue' | 'cancelled'
  final String trangThai;
  final String? hanDong;

  bool get daTraDu => trangThai == 'paid';
  bool get daGui => trangThai != 'draft';
}

class HoaDonThang {
  const HoaDonThang({
    required this.contractId,
    required this.thang,
    required this.roomId,
    this.buildingId = 0,
    this.tenToa = '',
    this.diaChi = '',
    this.anhToa,
    this.maPhong = '',
    this.trangThaiPhong = '',
    this.khachTen = '',
    this.khachSdt = '',
    this.tienThue = 0,
    this.hanDong = '',
    this.conNgay = 0,
    this.hoaDon,
    this.dienDung = 0,
    this.giaDien = 0,
    this.tienDien = 0,
    this.nuocDung = 0,
    this.giaNuoc = 0,
    this.tienNuoc = 0,
    this.chiSoTrangThai = 'chua_gui',
    this.canhBaoChiSo,
    this.dichVu = const [],
    this.tienPhong = 0,
    this.tienDichVu = 0,
    this.giamTru = 0,
    this.tong = 0,
    this.dong = const [],
    this.lichSu = const [],
  });

  factory HoaDonThang.fromMap(Map<String, dynamic> m) {
    final toa = (m['toa'] as Map?)?.cast<String, dynamic>() ?? const {};
    final phong = (m['phong'] as Map?)?.cast<String, dynamic>() ?? const {};
    final khach = (m['khach'] as Map?)?.cast<String, dynamic>() ?? const {};
    final dien = (m['dien'] as Map?)?.cast<String, dynamic>() ?? const {};
    final nuoc = (m['nuoc'] as Map?)?.cast<String, dynamic>() ?? const {};
    final hd = (m['hoa_don'] as Map?)?.cast<String, dynamic>();
    return HoaDonThang(
      contractId: _i(m['contract_id']),
      thang: (m['thang'] as String?) ?? '',
      roomId: _i(phong['id']),
      buildingId: _i(toa['id']),
      tenToa: (toa['ten'] as String?) ?? '',
      diaChi: (toa['dia_chi'] as String?) ?? '',
      anhToa: _s(toa['anh']),
      maPhong: (phong['ma'] as String?) ?? '',
      trangThaiPhong: (phong['trang_thai'] as String?) ?? '',
      khachTen: (khach['ten'] as String?) ?? '',
      khachSdt: (khach['sdt'] as String?) ?? '',
      tienThue: _d(m['tien_thue']),
      hanDong: (m['han_dong'] as String?) ?? '',
      conNgay: _i(m['con_ngay']),
      hoaDon: hd == null ? null : HoaDonTomTat.fromMap(hd),
      dienDung: _d(dien['dung']),
      giaDien: _d(dien['gia']),
      tienDien: _d(dien['tien']),
      nuocDung: _d(nuoc['dung']),
      giaNuoc: _d(nuoc['gia']),
      tienNuoc: _d(nuoc['tien']),
      chiSoTrangThai: (m['chi_so_trang_thai'] as String?) ?? 'chua_gui',
      canhBaoChiSo: _s(m['canh_bao_chi_so']),
      dichVu: [
        for (final x in (m['dich_vu'] as List? ?? const []))
          DichVuThang.fromMap((x as Map).cast<String, dynamic>()),
      ],
      tienPhong: _d(m['tien_phong']),
      tienDichVu: _d(m['tien_dich_vu']),
      giamTru: _d(m['giam_tru']),
      tong: _d(m['tong']),
      dong: [
        for (final x in (m['dong'] as List? ?? const []))
          DongTien.fromMap((x as Map).cast<String, dynamic>()),
      ],
      lichSu: [
        for (final x in (m['lich_su'] as List? ?? const []))
          if (x != null) HoaDonTomTat.fromMap((x as Map).cast<String, dynamic>()),
      ],
    );
  }

  final int contractId;

  /// 'YYYY-MM'.
  final String thang;
  final int roomId;
  final int buildingId;
  final String tenToa;
  final String diaChi;
  final String? anhToa;
  final String maPhong;
  final String trangThaiPhong;
  final String khachTen;
  final String khachSdt;
  final double tienThue;

  /// 'YYYY-MM-DD'.
  final String hanDong;

  /// Âm = đã quá hạn.
  final int conNgay;

  /// Hoá đơn của kỳ này nếu đã tạo — `null` = chưa có.
  final HoaDonTomTat? hoaDon;
  final double dienDung;
  final double giaDien;
  final double tienDien;
  final double nuocDung;
  final double giaNuoc;
  final double tienNuoc;

  /// 'chua_gui' | 'cho_duyet' | 'thieu_anh' | 'can_chup_lai' | 'da_duyet'
  final String chiSoTrangThai;

  /// Vì sao tiền điện nước đang là 0 — hiện nguyên văn, đừng im lặng.
  final String? canhBaoChiSo;
  final List<DichVuThang> dichVu;
  final double tienPhong;
  final double tienDichVu;

  /// Số DƯƠNG (server đã đổi dấu) — trên màn hiện "-50.000đ".
  final double giamTru;
  final double tong;
  final List<DongTien> dong;
  final List<HoaDonTomTat> lichSu;

  /// Chỉ số đã duyệt → tiền điện nước mới thật sự vào hoá đơn.
  bool get chiSoDaDuyet => chiSoTrangThai == 'da_duyet';

  /// Lựa chọn đang hiện, để gửi lại cho server ở lượt xem trước kế tiếp.
  Map<int, double> get chon => {
    for (final d in dichVu)
      if (d.dangBat) d.id: d.theoLuot ? d.soLuong : 1,
  };
}

class ChotHoaDon {
  const ChotHoaDon({
    required this.invoiceId,
    this.so = '',
    this.tong = 0,
    this.trangThai = 'draft',
    this.daGui = false,
  });

  factory ChotHoaDon.fromMap(Map<String, dynamic> m) => ChotHoaDon(
    invoiceId: _i(m['invoice_id']),
    so: (m['so'] as String?) ?? '',
    tong: _d(m['tong']),
    trangThai: (m['trang_thai'] as String?) ?? 'draft',
    daGui: m['da_gui'] == true,
  );

  final int invoiceId;
  final String so;
  final double tong;
  final String trangThai;
  final bool daGui;
}
