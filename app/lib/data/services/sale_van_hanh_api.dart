import 'package:house_booking/data/services/api_client.dart';

/// VẬN HÀNH CỦA SALE — tab "Hoạt động" của sale (mockup 05/10/2026).
///
///     GET  /api/sale/van-hanh/tong-quan?kenh=        màn 2
///     GET  /api/sale/van-hanh/bai-dang?kenh=         màn 4
///     GET  /api/sale/van-hanh/lich?kenh=             màn 5
///     GET  /api/sale/van-hanh/lich-xem/{id}          chi tiết lịch xem
///     POST /api/sale/van-hanh/lich-xem/{id}/ket-qua  cập nhật kết quả
///     GET  /api/sale/van-hanh/don/{id}               chi tiết đơn ngắn hạn
///     GET  /api/sale/van-hanh/khach-hang?kenh=       màn 6
///     GET  /api/sale/van-hanh/chu-nha                màn 7
///     GET  /api/sale/van-hanh/toa-nha[/{id}?kenh=]   màn 8
///     GET  /api/sale/van-hanh/hop-dong?kenh=         màn 9
///     GET  /api/sale/van-hanh/bao-cao?kenh=&ky=      màn 10
///
/// Xác nhận / từ chối lịch dùng endpoint lịch xem sẵn có
/// (`PATCH /api/viewing-appointments/{id}/status`). Kênh: `dai_han` | `ngan_han`.
class SaleVanHanhApi {
  const SaleVanHanhApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  static const _goc = '/api/sale/van-hanh';

  Future<TongQuanVanHanh> tongQuan(String kenh) async => TongQuanVanHanh.fromMap(
    await _c.get('$_goc/tong-quan', queryParameters: {'kenh': kenh}),
  );

  Future<DanhSachSale<BaiDangSale>> baiDang(String kenh) async =>
      DanhSachSale.fromMap(
        await _c.get('$_goc/bai-dang', queryParameters: {'kenh': kenh}),
        BaiDangSale.fromMap,
      );

  Future<DanhSachSale<LichSale>> lich(String kenh) async => DanhSachSale.fromMap(
    await _c.get('$_goc/lich', queryParameters: {'kenh': kenh}),
    LichSale.fromMap,
  );

  Future<LichSale> chiTietLich(int id) async =>
      LichSale.fromMap(await _c.get('$_goc/lich-xem/$id'));

  Future<LichSale> chiTietDon(int id) async =>
      LichSale.fromMap(await _c.get('$_goc/don/$id'));

  Future<void> ghiKetQua(int id, {required bool muonThue, String ghiChu = ''}) =>
      _c.post(
        '$_goc/lich-xem/$id/ket-qua',
        body: {'muon_thue': muonThue, 'ghi_chu': ghiChu},
      );

  Future<void> xacNhanLich(int id) => _c.patch(
    '/api/viewing-appointments/$id/status',
    body: {'status': 'approved'},
  );

  Future<void> tuChoiLich(int id, {String lyDo = ''}) => _c.patch(
    '/api/viewing-appointments/$id/status',
    body: {'status': 'rejected', 'ly_do': lyDo},
  );

  Future<DanhSachSale<KhachCuaSale>> khachHang(String kenh) async =>
      DanhSachSale.fromMap(
        await _c.get('$_goc/khach-hang', queryParameters: {'kenh': kenh}),
        KhachCuaSale.fromMap,
      );

  Future<DanhSachSale<ChuNhaSale>> chuNha() async =>
      DanhSachSale.fromMap(await _c.get('$_goc/chu-nha'), ChuNhaSale.fromMap);

  Future<List<ToaSale>> toaNha() async {
    final m = await _c.get('$_goc/toa-nha');
    return [
      for (final x in (m['ds'] as List? ?? const []))
        ToaSale.fromMap((x as Map).cast<String, dynamic>()),
    ];
  }

  Future<ChiTietToaSale> chiTietToa(int id, String kenh) async =>
      ChiTietToaSale.fromMap(
        await _c.get('$_goc/toa-nha/$id', queryParameters: {'kenh': kenh}),
      );

  Future<DanhSachSale<HopDongSale>> hopDong(String kenh) async =>
      DanhSachSale.fromMap(
        await _c.get('$_goc/hop-dong', queryParameters: {'kenh': kenh}),
        HopDongSale.fromMap,
      );

  Future<BaoCaoSale> baoCao(String kenh, String ky) async => BaoCaoSale.fromMap(
    await _c.get('$_goc/bao-cao', queryParameters: {'kenh': kenh, 'ky': ky}),
  );
}

// ── Kiểu dữ liệu ─────────────────────────────────────────────────────────────
Map<String, dynamic> _m(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};
String _s(dynamic v) => v == null ? '' : '$v'.trim();
String? _sn(dynamic v) {
  final s = _s(v);
  return s.isEmpty ? null : s;
}

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
double? _d(dynamic v) => (v as num?)?.toDouble();
DateTime? _t(dynamic v) => DateTime.tryParse(_s(v));
List<String> _ls(dynamic v) => [
  for (final x in (v as List? ?? const []))
    if (_s(x).isNotEmpty) _s(x),
];

/// Một chip lọc: khoá + nhãn + số đếm — server quyết, app chỉ vẽ.
class ChipLoc {
  const ChipLoc({required this.khoa, required this.nhan, this.so = 0});

  factory ChipLoc.fromMap(Map<String, dynamic> m) =>
      ChipLoc(khoa: _s(m['khoa']), nhan: _s(m['nhan']), so: _i(m['so']));

  final String khoa;
  final String nhan;
  final int so;
}

/// Danh sách có chip lọc (bài đăng, lịch, khách, chủ nhà, hợp đồng).
class DanhSachSale<T> {
  const DanhSachSale({this.chip = const [], this.ds = const [], this.ghiChu = ''});

  factory DanhSachSale.fromMap(
    Map<String, dynamic> m,
    T Function(Map<String, dynamic>) doc,
  ) => DanhSachSale(
    chip: [for (final x in (m['chip'] as List? ?? const [])) ChipLoc.fromMap(_m(x))],
    ds: [for (final x in (m['ds'] as List? ?? const [])) doc(_m(x))],
    ghiChu: _s(m['ghi_chu']),
  );

  final List<ChipLoc> chip;
  final List<T> ds;

  /// Lời giải thích khi danh sách rỗng có lý do (ngắn hạn không có hợp đồng).
  final String ghiChu;
}

class SoTongQuan {
  const SoTongQuan({
    this.baiDang = 0,
    this.khachMoi = 0,
    this.lichXem = 0,
    this.choChot = 0,
  });

  factory SoTongQuan.fromMap(Map<String, dynamic> m) => SoTongQuan(
    baiDang: _i(m['bai_dang']),
    khachMoi: _i(m['khach_moi']),
    lichXem: _i(m['lich_xem']),
    choChot: _i(m['cho_chot'] ?? m['da_chot']),
  );

  final int baiDang;
  final int khachMoi;
  final int lichXem;

  /// Tổng quan: chờ chốt (dài hạn) / chờ xác nhận (ngắn hạn).
  /// Báo cáo: đã chốt trong kỳ.
  final int choChot;
}

/// Một việc trong "Cần xử lý hôm nay".
class ViecSale {
  const ViecSale({
    required this.loai,
    required this.id,
    required this.tieuDe,
    this.khachId,
    this.khachTen = '',
    this.khachAnh,
    this.moTa = '',
    this.thoiGian,
    this.nhan = '',
    this.tong = 'cam',
  });

  factory ViecSale.fromMap(Map<String, dynamic> m) {
    final k = _m(m['khach']);
    return ViecSale(
      loai: _s(m['loai']),
      id: _i(m['id']),
      tieuDe: _s(m['tieu_de']),
      khachId: (k['id'] as num?)?.toInt(),
      khachTen: _s(k['ten']),
      khachAnh: _sn(k['anh']),
      moTa: _s(m['mo_ta']),
      thoiGian: _t(m['thoi_gian']),
      nhan: _s(m['nhan']),
      tong: _s(m['tong']).isEmpty ? 'cam' : _s(m['tong']),
    );
  }

  /// xac_nhan_lich · cap_nhat_ket_qua · cho_chu_xac_nhan (dài hạn)
  /// don_cho_xac_nhan · nhan_phong_hom_nay · tra_phong_hom_nay (ngắn hạn)
  final String loai;

  /// Id lịch xem (dài hạn) hoặc đơn đặt phòng (ngắn hạn).
  final int id;
  final String tieuDe;
  final int? khachId;
  final String khachTen;
  final String? khachAnh;
  final String moTa;
  final DateTime? thoiGian;
  final String nhan;

  /// Tông nhãn: cam · lam · xanh · do · xam.
  final String tong;
}

class TongQuanVanHanh {
  const TongQuanVanHanh({
    required this.kenh,
    this.so = const SoTongQuan(),
    this.canXuLy = const [],
  });

  factory TongQuanVanHanh.fromMap(Map<String, dynamic> m) => TongQuanVanHanh(
    kenh: _s(m['kenh']),
    so: SoTongQuan.fromMap(_m(m['so'])),
    canXuLy: [
      for (final x in (m['can_xu_ly'] as List? ?? const [])) ViecSale.fromMap(_m(x)),
    ],
  );

  final String kenh;
  final SoTongQuan so;
  final List<ViecSale> canXuLy;
}

class BaiDangSale {
  const BaiDangSale({
    required this.id,
    required this.tieuDe,
    this.gia,
    this.donVi = 'tháng',
    this.dienTich,
    this.loai = '',
    this.khuVuc = '',
    this.anh,
    this.trangThai = 'dang_dang',
    this.nhom = const [],
    this.soKhach = 0,
    this.soLichXem = 0,
    this.soChoChot = 0,
    this.luotXem = 0,
  });

  factory BaiDangSale.fromMap(Map<String, dynamic> m) => BaiDangSale(
    id: _i(m['id']),
    tieuDe: _s(m['tieu_de']),
    gia: _d(m['gia']),
    donVi: _s(m['don_vi']),
    dienTich: _d(m['dien_tich']),
    loai: _s(m['loai']),
    khuVuc: _s(m['khu_vuc']),
    anh: _sn(m['anh']),
    trangThai: _s(m['trang_thai']),
    nhom: _ls(m['nhom']),
    soKhach: _i(m['so_khach']),
    soLichXem: _i(m['so_lich_xem']),
    soChoChot: _i(m['so_cho_chot']),
    luotXem: _i(m['luot_xem']),
  );

  final int id;
  final String tieuDe;
  final double? gia;
  final String donVi;
  final double? dienTich;
  final String loai;
  final String khuVuc;
  final String? anh;

  /// dang_dang · co_lich_xem · cho_chot · da_dong · da_an · cho_duyet · bi_tu_choi
  final String trangThai;
  final List<String> nhom;
  final int soKhach;
  final int soLichXem;
  final int soChoChot;
  final int luotXem;
}

/// Một lịch xem (dài hạn) hoặc một đơn đặt phòng (ngắn hạn) — cùng thẻ.
class LichSale {
  const LichSale({
    required this.id,
    required this.loai,
    required this.phongTen,
    this.phongAnh,
    this.khachId,
    this.khachTen = '',
    this.khachAnh,
    this.khachSdt = '',
    this.batDau,
    this.ketThuc,
    this.gio = '',
    this.kieu = '',
    this.trangThai = '',
    this.ketQua,
    this.nhan = '',
    this.nhom = const [],
    this.hanhDong = const [],
    this.ma = '',
    this.diaChi = '',
    this.loiNhan = '',
    this.hinhThuc = '',
    this.soNguoi = 1,
    this.ghiChuKetQua = '',
    this.chuNhaId,
    this.chuNhaTen = '',
    this.chuNhaSdt = '',
    this.tongTien,
  });

  factory LichSale.fromMap(Map<String, dynamic> m) {
    final p = _m(m['phong']);
    final k = _m(m['khach']);
    final c = _m(m['chu_nha']);
    return LichSale(
      id: _i(m['id']),
      loai: _s(m['loai']),
      phongTen: _s(p['ten']),
      phongAnh: _sn(p['anh']),
      khachId: (k['id'] as num?)?.toInt(),
      khachTen: _s(k['ten']),
      khachAnh: _sn(k['anh']),
      khachSdt: _s(k['sdt']),
      batDau: _t(m['bat_dau']),
      ketThuc: _t(m['ket_thuc']),
      gio: _s(m['gio']),
      kieu: _s(m['kieu']),
      trangThai: _s(m['trang_thai']),
      ketQua: _sn(m['ket_qua']),
      nhan: _s(m['nhan']),
      nhom: _ls(m['nhom']),
      hanhDong: _ls(m['hanh_dong']),
      ma: _s(m['ma']),
      diaChi: _s(m['dia_chi']),
      loiNhan: _s(m['loi_nhan'] ?? m['ghi_chu']),
      hinhThuc: _s(m['hinh_thuc']),
      soNguoi: _i(m['so_nguoi'] ?? m['so_khach']) == 0
          ? 1
          : _i(m['so_nguoi'] ?? m['so_khach']),
      ghiChuKetQua: _s(m['ghi_chu_ket_qua']),
      chuNhaId: (c['id'] as num?)?.toInt(),
      chuNhaTen: _s(c['ten']),
      chuNhaSdt: _s(c['sdt']),
      tongTien: _d(m['tong_tien']),
    );
  }

  final int id;

  /// lich_xem · dat_phong
  final String loai;
  final String phongTen;
  final String? phongAnh;
  final int? khachId;
  final String khachTen;
  final String? khachAnh;
  final String khachSdt;
  final DateTime? batDau;
  final DateTime? ketThuc;

  /// Khung giờ thô của lịch xem: "09:00-09:30".
  final String gio;

  /// Kiểu đơn ngắn hạn: Theo giờ · Qua đêm · Theo ngày.
  final String kieu;
  final String trangThai;
  final String? ketQua;

  /// Lịch xem: cho_xac_nhan · cho_khach_chon_gio · da_xac_nhan · da_xem ·
  /// da_chot · khong_chot · da_huy · het_han.
  /// Đơn: cho_chu_xac_nhan · da_xac_nhan · dang_o · da_tra_phong · da_huy.
  final String nhan;
  final List<String> nhom;

  /// tu_choi · xac_nhan · doi_lich · cap_nhat_ket_qua · xem_chi_tiet
  final List<String> hanhDong;

  // Chỉ có ở màn chi tiết.
  final String ma;
  final String diaChi;
  final String loiNhan;
  final String hinhThuc;
  final int soNguoi;
  final String ghiChuKetQua;
  final int? chuNhaId;
  final String chuNhaTen;
  final String chuNhaSdt;
  final double? tongTien;

  bool get laDon => loai == 'dat_phong';
}

class KhachCuaSale {
  const KhachCuaSale({
    required this.ten,
    this.id,
    this.userId,
    this.anh,
    this.sdt = '',
    this.trangThai = '',
    this.soLichXem = 0,
  });

  factory KhachCuaSale.fromMap(Map<String, dynamic> m) => KhachCuaSale(
    id: (m['id'] as num?)?.toInt(),
    userId: (m['user_id'] as num?)?.toInt(),
    ten: _s(m['ten']),
    anh: _sn(m['anh']),
    sdt: _s(m['sdt']),
    trangThai: _s(m['trang_thai']),
    soLichXem: _i(m['so_lich_xem']),
  );

  final int? id;

  /// Có tài khoản thì nhắn tin được trong app.
  final int? userId;
  final String ten;
  final String? anh;
  final String sdt;

  /// Dài hạn: moi · dang_tu_van · da_xem · cho_chot · da_chot.
  /// Ngắn hạn: sap_den · dang_o · da_o.
  final String trangThai;

  /// Số lịch xem (dài hạn) / số đơn đặt (ngắn hạn).
  final int soLichXem;
}

class ChuNhaSale {
  const ChuNhaSale({
    required this.id,
    required this.ten,
    this.anh,
    this.sdt = '',
    this.soToa = 0,
    this.soPhong = 0,
    this.trangThai = '',
  });

  factory ChuNhaSale.fromMap(Map<String, dynamic> m) => ChuNhaSale(
    id: _i(m['id']),
    ten: _s(m['ten']),
    anh: _sn(m['anh']),
    sdt: _s(m['sdt']),
    soToa: _i(m['so_toa']),
    soPhong: _i(m['so_phong']),
    trangThai: _s(m['trang_thai']),
  );

  final int id;
  final String ten;
  final String? anh;
  final String sdt;
  final int soToa;
  final int soPhong;

  /// dang_hop_tac · moi
  final String trangThai;
}

class ToaSale {
  const ToaSale({
    required this.id,
    required this.ten,
    this.diaChi = '',
    this.anh,
    this.soPhong = 0,
    this.chuNhaTen = '',
  });

  factory ToaSale.fromMap(Map<String, dynamic> m) => ToaSale(
    id: _i(m['id']),
    ten: _s(m['ten']),
    diaChi: _s(m['dia_chi']),
    anh: _sn(m['anh']),
    soPhong: _i(m['so_phong']),
    chuNhaTen: _s(_m(m['chu_nha'])['ten']),
  );

  final int id;
  final String ten;
  final String diaChi;
  final String? anh;
  final int soPhong;
  final String chuNhaTen;
}

class PhongSale {
  const PhongSale({
    required this.id,
    required this.ten,
    this.dienTich,
    this.loai = '',
    this.gia,
    this.donVi = 'tháng',
    this.anh,
    this.trangThai = 'trong',
  });

  factory PhongSale.fromMap(Map<String, dynamic> m) => PhongSale(
    id: _i(m['id']),
    ten: _s(m['ten']),
    dienTich: _d(m['dien_tich']),
    loai: _s(m['loai']),
    gia: _d(m['gia']),
    donVi: _s(m['don_vi']),
    anh: _sn(m['anh']),
    trangThai: _s(m['trang_thai']),
  );

  final int id;
  final String ten;
  final double? dienTich;
  final String loai;
  final double? gia;
  final String donVi;
  final String? anh;

  /// trong · co_lich_xem · dang_thue · bao_tri
  final String trangThai;
}

class ChiTietToaSale {
  const ChiTietToaSale({
    required this.toa,
    this.chip = const [],
    this.phong = const [],
    this.anh = const [],
    this.diaChiDayDu = '',
    this.chuNhaTen = '',
    this.chuNhaSdt = '',
    this.giaDien,
    this.giaNuoc,
    this.phiDichVu,
    this.tongPhong = 0,
  });

  factory ChiTietToaSale.fromMap(Map<String, dynamic> m) {
    final t = _m(m['toa']);
    final c = _m(t['chu_nha']);
    return ChiTietToaSale(
      toa: ToaSale.fromMap(t),
      chip: [for (final x in (m['chip'] as List? ?? const [])) ChipLoc.fromMap(_m(x))],
      phong: [
        for (final x in (m['phong'] as List? ?? const [])) PhongSale.fromMap(_m(x)),
      ],
      anh: _ls(m['anh']),
      diaChiDayDu: _s(t['dia_chi_day_du']),
      chuNhaTen: _s(c['ten']),
      chuNhaSdt: _s(c['sdt']),
      giaDien: _d(t['gia_dien']),
      giaNuoc: _d(t['gia_nuoc']),
      phiDichVu: _d(t['phi_dich_vu']),
      tongPhong: _i(t['tong_phong']),
    );
  }

  final ToaSale toa;
  final List<ChipLoc> chip;
  final List<PhongSale> phong;
  final List<String> anh;
  final String diaChiDayDu;
  final String chuNhaTen;
  final String chuNhaSdt;
  final double? giaDien;
  final double? giaNuoc;
  final double? phiDichVu;
  final int tongPhong;
}

class HopDongSale {
  const HopDongSale({
    required this.khoa,
    required this.phongTen,
    this.appointmentId,
    this.contractId,
    this.phongAnh,
    this.khachTen = '',
    this.ngayTao,
    this.nhan = '',
    this.nhom = '',
  });

  factory HopDongSale.fromMap(Map<String, dynamic> m) {
    final p = _m(m['phong']);
    return HopDongSale(
      khoa: _s(m['khoa']),
      appointmentId: (m['appointment_id'] as num?)?.toInt(),
      contractId: (m['contract_id'] as num?)?.toInt(),
      phongTen: _s(p['ten']),
      phongAnh: _sn(p['anh']),
      khachTen: _s(_m(m['khach'])['ten']),
      ngayTao: _t(m['ngay_tao']),
      nhan: _s(m['nhan']),
      nhom: _s(m['nhom']),
    );
  }

  final String khoa;
  final int? appointmentId;
  final int? contractId;
  final String phongTen;
  final String? phongAnh;
  final String khachTen;
  final DateTime? ngayTao;

  /// cho_chu_xac_nhan · dang_ky_hop_dong · hoan_tat · da_ket_thuc
  final String nhan;

  /// dang_xu_ly · hieu_luc · da_ket_thuc
  final String nhom;
}

class DiemBieuDo {
  const DiemBieuDo({required this.ngay, this.luotXem = 0, this.yeuCau = 0});

  factory DiemBieuDo.fromMap(Map<String, dynamic> m) => DiemBieuDo(
    ngay: _t(m['ngay']) ?? DateTime(2000),
    luotXem: _i(m['luot_xem']),
    yeuCau: _i(m['yeu_cau']),
  );

  final DateTime ngay;
  final int luotXem;
  final int yeuCau;
}

class KyBaoCao {
  const KyBaoCao({required this.khoa, required this.nhan});

  factory KyBaoCao.fromMap(Map<String, dynamic> m) =>
      KyBaoCao(khoa: _s(m['khoa']), nhan: _s(m['nhan']));

  final String khoa;
  final String nhan;
}

class BaoCaoSale {
  const BaoCaoSale({
    required this.ky,
    this.cacKy = const [],
    this.so = const SoTongQuan(),
    this.bieuDo = const [],
    this.hoaHongDuKien,
    this.hoaHongDaNhan,
    this.doanhThu,
    this.phanTram,
  });

  factory BaoCaoSale.fromMap(Map<String, dynamic> m) {
    final h = m['hoa_hong'] is Map ? _m(m['hoa_hong']) : null;
    return BaoCaoSale(
      ky: KyBaoCao.fromMap(_m(m['ky'])),
      cacKy: [for (final x in (m['cac_ky'] as List? ?? const [])) KyBaoCao.fromMap(_m(x))],
      so: SoTongQuan.fromMap(_m(m['so'])),
      bieuDo: [
        for (final x in (m['bieu_do'] as List? ?? const [])) DiemBieuDo.fromMap(_m(x)),
      ],
      hoaHongDuKien: h == null ? null : _d(h['du_kien']),
      hoaHongDaNhan: h == null ? null : _d(h['da_nhan']),
      doanhThu: h == null ? null : _d(h['doanh_thu']),
      phanTram: h == null ? null : (h['phan_tram'] as num?)?.toInt(),
    );
  }

  final KyBaoCao ky;
  final List<KyBaoCao> cacKy;
  final SoTongQuan so;
  final List<DiemBieuDo> bieuDo;

  /// Chỉ dài hạn có hoa hồng.
  final double? hoaHongDuKien;
  final double? hoaHongDaNhan;
  final double? doanhThu;
  final int? phanTram;
}
