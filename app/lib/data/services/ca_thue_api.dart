import 'package:house_booking/data/services/api_client.dart';

/// VÒNG ĐỜI MỘT CA THUÊ ngắn hạn — dùng chung cho cả bốn màn của quầy lễ tân:
/// chi tiết đặt phòng · nhận phòng · đang ở · trả phòng.
///
///     GET    /api/host/ca-thue/{id}
///     POST   /api/host/ca-thue/{id}/phu-thu
///     DELETE /api/host/ca-thue/{id}/phu-thu/{pid}
///     POST   /api/host/ca-thue/{id}/thanh-toan
///     POST   /api/host/ca-thue/{id}/gia-han
///     POST   /api/host/ca-thue/{id}/nhan-phong
///     POST   /api/host/ca-thue/{id}/tra-phong
///
/// Một lượt `lay()` đủ cho MỌI màn: bốn màn hỏi cùng một thứ ở bốn thời điểm
/// khác nhau của ca, nên tách bốn endpoint chỉ tạo ra bốn cách trả lời lệch
/// nhau cho cùng câu hỏi "ca này thu bao nhiêu".
class CaThueApi {
  const CaThueApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<CaThue> lay(int id) async =>
      CaThue.fromMap(await _c.get('/api/host/ca-thue/$id'));

  Future<void> themPhuThu(
    int id, {
    required String ten,
    required double donGia,
    double soLuong = 1,
    String loai = 'dich_vu',
    String? ghiChu,
  }) => _c.post('/api/host/ca-thue/$id/phu-thu', body: {
    'ten': ten,
    'don_gia': donGia,
    'so_luong': soLuong,
    'loai': loai,
    if (ghiChu != null) 'ghi_chu': ghiChu,
  });

  Future<void> xoaPhuThu(int id, int phuThuId) =>
      _c.delete('/api/host/ca-thue/$id/phu-thu/$phuThuId');

  Future<void> ghiThanhToan(
    int id, {
    required double soTien,
    String loai = 'thu',
    String hinhThuc = 'tien_mat',
    String? ghiChu,
  }) => _c.post('/api/host/ca-thue/$id/thanh-toan', body: {
    'so_tien': soTien,
    'loai': loai,
    'hinh_thuc': hinhThuc,
    if (ghiChu != null) 'ghi_chu': ghiChu,
  });

  Future<void> giaHan(int id, {required int themPhut, bool tinhTien = true}) =>
      _c.post('/api/host/ca-thue/$id/gia-han', body: {
        'them_phut': themPhut,
        'tinh_tien': tinhTien,
      });

  Future<void> nhanPhong(
    int id, {
    double thu = 0,
    String hinhThuc = 'tien_mat',
    String? ghiChu,
  }) => _c.post('/api/host/ca-thue/$id/nhan-phong', body: {
    'thu': thu,
    'hinh_thuc': hinhThuc,
    if (ghiChu != null) 'ghi_chu': ghiChu,
  });

  Future<Map<String, dynamic>> traPhong(
    int id, {
    double thuThem = 0,
    double hoanLai = 0,
    String hinhThuc = 'tien_mat',
    int? phutDon,
    String? kiemPhong,
    String? ghiChu,
  }) => _c.post('/api/host/ca-thue/$id/tra-phong', body: {
    'thu_them': thuThem,
    'hoan_lai': hoanLai,
    'hinh_thuc': hinhThuc,
    if (phutDon != null) 'phut_don': phutDon,
    if (kiemPhong != null) 'kiem_phong': kiemPhong,
    if (ghiChu != null) 'ghi_chu': ghiChu,
  });
}

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

String? _s(dynamic v) {
  final s = v is String ? v.trim() : null;
  return s == null || s.isEmpty ? null : s;
}

DateTime? _t(dynamic v) => v == null ? null : DateTime.tryParse('$v');

/// Tiến độ ca — dùng cho đồng hồ đếm ngược ở cả màn đón khách lẫn màn đang ở.
class TienDoCa {
  const TienDoCa({
    this.tongPhut = 1,
    this.daOPhut = 0,
    this.conPhut = 0,
    this.phanTram = 0,
    this.quaGio = false,
    this.conToiGioVao = 0,
  });

  factory TienDoCa.fromMap(Map<String, dynamic> m) => TienDoCa(
    tongPhut: _i(m['tong_phut']),
    daOPhut: _i(m['da_o_phut']),
    conPhut: _i(m['con_phut']),
    phanTram: _d(m['phan_tram']),
    quaGio: m['qua_gio'] == true,
    conToiGioVao: _i(m['con_toi_gio_vao']),
  );

  final int tongPhut;
  final int daOPhut;
  final int conPhut;
  final double phanTram;

  /// Đã quá giờ trả mà khách còn trong phòng.
  final bool quaGio;

  /// Phút còn lại tới giờ nhận (0 nếu đã tới giờ).
  final int conToiGioVao;
}

class TienCa {
  const TienCa({
    this.tienPhong = 0,
    this.phuThu = 0,
    this.phaiThu = 0,
    this.coc = 0,
    this.daThu = 0,
    this.conLai = 0,
    this.hoanLai = 0,
  });

  factory TienCa.fromMap(Map<String, dynamic> m) => TienCa(
    tienPhong: _d(m['tien_phong']),
    phuThu: _d(m['phu_thu']),
    phaiThu: _d(m['phai_thu']),
    coc: _d(m['coc']),
    daThu: _d(m['da_thu']),
    conLai: _d(m['con_lai']),
    hoanLai: _d(m['hoan_lai']),
  );

  final double tienPhong;
  final double phuThu;
  final double phaiThu;
  final double coc;
  final double daThu;

  /// >0 = khách trả thêm · <0 = hoàn lại khách.
  final double conLai;
  final double hoanLai;
}

class PhuThuCa {
  const PhuThuCa({
    required this.id,
    required this.ten,
    this.loai = 'dich_vu',
    this.donGia = 0,
    this.soLuong = 1,
    this.thanhTien = 0,
    this.ghiChu,
  });

  factory PhuThuCa.fromMap(Map<String, dynamic> m) => PhuThuCa(
    id: _i(m['id']),
    ten: m['ten'] as String? ?? '',
    loai: m['loai'] as String? ?? 'dich_vu',
    donGia: _d(m['don_gia']),
    soLuong: _d(m['so_luong']),
    thanhTien: _d(m['thanh_tien']),
    ghiChu: _s(m['ghi_chu']),
  );

  final int id;
  final String ten;
  final String loai;
  final double donGia;
  final double soLuong;
  final double thanhTien;
  final String? ghiChu;
}

class ThanhToanCa {
  const ThanhToanCa({
    required this.id,
    this.loai = 'thu',
    this.soTien = 0,
    this.hinhThuc = 'tien_mat',
    this.ghiChu,
    this.luc,
  });

  factory ThanhToanCa.fromMap(Map<String, dynamic> m) => ThanhToanCa(
    id: _i(m['id']),
    loai: m['loai'] as String? ?? 'thu',
    soTien: _d(m['so_tien']),
    hinhThuc: m['hinh_thuc'] as String? ?? 'tien_mat',
    ghiChu: _s(m['ghi_chu']),
    luc: _t(m['luc']),
  );

  final int id;

  /// 'thu' = cầm tiền của khách · 'hoan' = trả lại khách.
  final String loai;
  final double soTien;
  final String hinhThuc;
  final String? ghiChu;
  final DateTime? luc;

  bool get laHoan => loai == 'hoan';
}

/// Đề xuất phụ thu quá giờ — server TÍNH nhưng KHÔNG tự cộng; người trực bấm
/// mới thành tiền, vì miễn 10 phút cho khách quen là chuyện thường ngày.
class DeXuatQuaGio {
  const DeXuatQuaGio({
    required this.phut,
    required this.soGio,
    required this.ten,
    this.donGia,
    this.deXuat,
  });

  factory DeXuatQuaGio.fromMap(Map<String, dynamic> m) => DeXuatQuaGio(
    phut: _i(m['phut']),
    soGio: _i(m['so_gio']),
    ten: m['ten'] as String? ?? 'Phụ thu quá giờ',
    donGia: (m['don_gia'] as num?)?.toDouble(),
    deXuat: (m['de_xuat'] as num?)?.toDouble(),
  );

  final int phut;
  final int soGio;
  final String ten;
  final double? donGia;
  final double? deXuat;
}

class PhongCa {
  const PhongCa({
    required this.id,
    required this.ma,
    this.tang,
    this.sucChua,
    this.anh = const [],
    this.hang,
    this.giuong,
  });

  factory PhongCa.fromMap(Map<String, dynamic> m) => PhongCa(
    id: _i(m['id']),
    ma: m['ma'] as String? ?? '',
    tang: (m['tang'] as num?)?.toInt(),
    sucChua: (m['suc_chua'] as num?)?.toInt(),
    anh: [for (final a in (m['anh'] as List? ?? const [])) '$a'],
    hang: _s(m['hang']),
    giuong: _s(m['giuong']),
  );

  final int id;
  final String ma;
  final int? tang;
  final int? sucChua;
  final List<String> anh;

  /// Hạng phòng (loại phòng) — thứ khách chọn khi đặt.
  final String? hang;
  final String? giuong;
}

/// Một ca thuê, đủ cho cả bốn màn.
class CaThue {
  const CaThue({
    required this.id,
    required this.maDat,
    required this.trangThai,
    required this.vao,
    required this.ra,
    required this.bayGio,
    required this.phong,
    required this.tienDo,
    this.kieu = '',
    this.nhanKieu = '',
    this.nguon = '',
    this.ghiChu,
    this.toaTen = '',
    this.toaDiaChi = '',
    this.toaId,
    this.xemTaiChinh = false,
    this.khachTen,
    this.khachSdt,
    this.tien,
    this.phuThu = const [],
    this.thanhToan = const [],
    this.deXuatQuaGio,
    this.giaGio,
    this.saleTen,
  });

  factory CaThue.fromMap(Map<String, dynamic> m) {
    final toa = (m['toa'] as Map?)?.cast<String, dynamic>() ?? const {};
    final khach = (m['khach'] as Map?)?.cast<String, dynamic>();
    final tien = (m['tien'] as Map?)?.cast<String, dynamic>();
    final qg = (m['de_xuat_qua_gio'] as Map?)?.cast<String, dynamic>();
    final sale = (m['sale'] as Map?)?.cast<String, dynamic>();
    final now = DateTime.now();
    return CaThue(
      id: _i(m['id']),
      maDat: m['ma_dat'] as String? ?? '',
      trangThai: m['trang_thai'] as String? ?? '',
      kieu: m['kieu'] as String? ?? '',
      nhanKieu: m['nhan_kieu'] as String? ?? '',
      nguon: m['nguon'] as String? ?? '',
      vao: _t(m['vao']) ?? now,
      ra: _t(m['ra']) ?? now,
      bayGio: _t(m['bay_gio']) ?? now,
      ghiChu: _s(m['ghi_chu']),
      phong: PhongCa.fromMap(
        (m['phong'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      toaId: (toa['id'] as num?)?.toInt(),
      toaTen: toa['ten'] as String? ?? '',
      toaDiaChi: toa['dia_chi'] as String? ?? '',
      tienDo: TienDoCa.fromMap(
        (m['tien_do'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      xemTaiChinh: m['xem_tai_chinh'] == true,
      khachTen: _s(khach?['ten']),
      khachSdt: _s(khach?['sdt']),
      tien: tien == null ? null : TienCa.fromMap(tien),
      phuThu: [
        for (final x in (m['phu_thu'] as List? ?? const []))
          PhuThuCa.fromMap((x as Map).cast<String, dynamic>()),
      ],
      thanhToan: [
        for (final x in (m['thanh_toan'] as List? ?? const []))
          ThanhToanCa.fromMap((x as Map).cast<String, dynamic>()),
      ],
      deXuatQuaGio: qg == null ? null : DeXuatQuaGio.fromMap(qg),
      giaGio: (m['gia_gio'] as num?)?.toDouble(),
      saleTen: _s(sale?['ten']),
    );
  }

  final int id;
  final String maDat;

  /// pending · approved · checked_in · checked_out · cancelled
  final String trangThai;

  /// theo_gio · qua_dem · theo_ngay
  final String kieu;
  final String nhanKieu;
  final String nguon;
  final DateTime vao;
  final DateTime ra;

  /// Giờ máy chủ lúc trả lời — mọi phép đếm ngược đi từ đây, không từ giờ máy
  /// người dùng (máy lệch giờ là chuyện thường).
  final DateTime bayGio;
  final String? ghiChu;
  final PhongCa phong;
  final int? toaId;
  final String toaTen;
  final String toaDiaChi;
  final TienDoCa tienDo;

  /// Sale phụ trách xem được lịch nhưng KHÔNG xem tiền — khối tiền vắng mặt.
  final bool xemTaiChinh;
  final String? khachTen;
  final String? khachSdt;
  final TienCa? tien;
  final List<PhuThuCa> phuThu;
  final List<ThanhToanCa> thanhToan;
  final DeXuatQuaGio? deXuatQuaGio;
  final double? giaGio;

  /// Sale dẫn khách về (ảnh chụp lúc đặt). Rỗng với ca vãng lai tại quầy.
  final String? saleTen;

  bool get dangO => trangThai == 'checked_in';
  bool get choNhan => trangThai == 'pending' || trangThai == 'approved';
  bool get daTra => trangThai == 'checked_out';
}
