import 'package:house_booking/data/services/api_client.dart';

/// SALE QUẢN LÝ THEO YÊU CẦU — 5 màn của mockup 23/09/2026.
///
///     GET   /api/sale/tong-quan                   màn 1
///     GET   /api/sale/yeu-cau?nhom=&q=            màn 2
///     POST  /api/sale/yeu-cau                     + Tạo yêu cầu
///     GET   /api/sale/yeu-cau/{id}                màn 3
///     POST  /api/sale/yeu-cau/{id}/chuyen-buoc    Chuyển trạng thái
///     POST  /api/sale/yeu-cau/{id}/can            gắn căn vào yêu cầu
///     GET   /api/sale/yeu-cau/{id}/nguon-can      căn được phép gắn (2 nguồn)
///     POST  /api/sale/yeu-cau/{id}/can/{can}/chon căn khách chốt
///     GET   /api/sale/khach?tab=&q=               màn 4
///     POST  /api/sale/khach                       + Thêm KH
///     GET   /api/sale/toa-doanh-thu               màn 5
///
/// Trục của sale là ĐƠN của khách, không phải cái tin: một yêu cầu đi từ
/// "Lead mới" tới "Đã chốt" qua 7 bước, mỗi bước có mốc thời gian riêng.
class SaleYeuCauApi {
  const SaleYeuCauApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<TongQuanSale> tongQuan() async =>
      TongQuanSale.fromMap(await _c.get('/api/sale/tong-quan'));

  Future<BangYeuCau> danhSach({String nhom = 'tat_ca', String q = ''}) async =>
      BangYeuCau.fromMap(
        await _c.get(
          '/api/sale/yeu-cau',
          queryParameters: {'nhom': nhom, if (q.isNotEmpty) 'q': q},
        ),
      );

  Future<YeuCauChiTiet> chiTiet(int id) async =>
      YeuCauChiTiet.fromMap(await _c.get('/api/sale/yeu-cau/$id'));

  Future<YeuCauChiTiet> tao({
    int? khachId,
    String? hoTen,
    String? sdt,
    String? loaiCan,
    String? khuVuc,
    int? nganSachMin,
    int? nganSachMax,
    DateTime? vaoOTu,
    String? ghiChu,
  }) async => YeuCauChiTiet.fromMap(
    await _c.post(
      '/api/sale/yeu-cau',
      body: {
        'khach_id': ?khachId,
        if (hoTen != null && hoTen.isNotEmpty) 'ho_ten': hoTen,
        if (sdt != null && sdt.isNotEmpty) 'sdt': sdt,
        if (loaiCan != null && loaiCan.isNotEmpty) 'loai_can': loaiCan,
        if (khuVuc != null && khuVuc.isNotEmpty) 'khu_vuc': khuVuc,
        'ngan_sach_min': ?nganSachMin,
        'ngan_sach_max': ?nganSachMax,
        if (vaoOTu != null) 'vao_o_tu': vaoOTu.toIso8601String(),
        if (ghiChu != null && ghiChu.isNotEmpty) 'ghi_chu': ghiChu,
      },
    ),
  );

  Future<YeuCauChiTiet> chuyenBuoc(int id, String buoc, {String? lyDo}) async =>
      YeuCauChiTiet.fromMap(
        await _c.post(
          '/api/sale/yeu-cau/$id/chuyen-buoc',
          body: {'buoc': buoc, 'ly_do': ?lyDo},
        ),
      );

  /// Đóng yêu cầu ở bất kỳ bước nào trong pipeline. Backend giữ nguyên các
  /// mốc đã đi qua và ghi riêng lý do đóng để không làm mất lịch sử Sale.
  Future<YeuCauChiTiet> huyYeuCau(int id, String lyDo) =>
      chuyenBuoc(id, 'dong', lyDo: lyDo);

  Future<YeuCauChiTiet> ganCan(int id, {int? houseId, int? roomId}) async =>
      YeuCauChiTiet.fromMap(
        await _c.post(
          '/api/sale/yeu-cau/$id/can',
          body: {'house_id': ?houseId, 'room_id': ?roomId},
        ),
      );

  /// Căn sale được phép gắn: phòng toà liên kết + bài đăng của chính mình.
  Future<NguonCanSale> nguonCan(int yeuCauId, {String q = ''}) async =>
      NguonCanSale.fromMap(
        await _c.get(
          '/api/sale/yeu-cau/$yeuCauId/nguon-can',
          queryParameters: {if (q.isNotEmpty) 'q': q},
        ),
      );

  /// Đánh dấu căn khách chốt — giá thuê và hoa hồng đọc từ căn này.
  Future<YeuCauChiTiet> chonCan(int yeuCauId, int canId) async =>
      YeuCauChiTiet.fromMap(
        await _c.post('/api/sale/yeu-cau/$yeuCauId/can/$canId/chon'),
      );

  Future<SoKhachSale> khach({String tab = 'dang_theo', String q = ''}) async =>
      SoKhachSale.fromMap(
        await _c.get(
          '/api/sale/khach',
          queryParameters: {'tab': tab, if (q.isNotEmpty) 'q': q},
        ),
      );

  Future<KhachSale> themKhach({
    required String hoTen,
    String sdt = '',
    String? khuVuc,
    String? ghiChu,
  }) async => KhachSale.fromMap(
    await _c.post(
      '/api/sale/khach',
      body: {
        'ho_ten': hoTen,
        'sdt': sdt,
        if (khuVuc != null && khuVuc.isNotEmpty) 'khu_vuc': khuVuc,
        if (ghiChu != null && ghiChu.isNotEmpty) 'ghi_chu': ghiChu,
      },
    ),
  );

  Future<ToaVaDoanhThu> toaDoanhThu() async =>
      ToaVaDoanhThu.fromMap(await _c.get('/api/sale/toa-doanh-thu'));

  Future<int> doiPhanTramHoaHong(int phanTram) async {
    final m = await _c.patch(
      '/api/sale/cai-dat',
      body: {'hoa_hong_phan_tram': phanTram},
    );
    return (m['hoa_hong_phan_tram'] as num?)?.toInt() ?? phanTram;
  }
}

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

class TongQuanSale {
  const TongQuanSale({
    this.yeuCauMoi = 0,
    this.dangXuLy = 0,
    this.choXemNha = 0,
    this.daChot = 0,
    this.doanhThuThang = 0,
    this.hoaHongDuKien = 0,
    this.phanTramHoaHong = 50,
  });

  factory TongQuanSale.fromMap(Map<String, dynamic> m) => TongQuanSale(
    yeuCauMoi: _i(m['yeu_cau_moi']),
    dangXuLy: _i(m['dang_xu_ly']),
    choXemNha: _i(m['cho_xem_nha']),
    daChot: _i(m['da_chot']),
    doanhThuThang: _d(m['doanh_thu_thang']),
    hoaHongDuKien: _d(m['hoa_hong_du_kien']),
    phanTramHoaHong: _i(m['phan_tram_hoa_hong']),
  );

  final int yeuCauMoi;
  final int dangXuLy;
  final int choXemNha;
  final int daChot;
  final double doanhThuThang;
  final double hoaHongDuKien;
  final int phanTramHoaHong;
}

class MucYeuCau {
  const MucYeuCau({
    required this.id,
    required this.ma,
    this.khach = '',
    this.sdt = '',
    this.khachId = 0,
    this.loaiCan = '',
    this.khuVuc = '',
    this.nganSach = '',
    this.trangThai = 'lead_moi',
    this.nhan = '',
    this.viecTiep = '',
    this.capNhat,
  });

  factory MucYeuCau.fromMap(Map<String, dynamic> m) => MucYeuCau(
    id: _i(m['id']),
    ma: m['ma'] as String? ?? '',
    khach: m['khach'] as String? ?? '',
    sdt: m['sdt'] as String? ?? '',
    khachId: _i(m['khach_id']),
    loaiCan: m['loai_can'] as String? ?? '',
    khuVuc: m['khu_vuc'] as String? ?? '',
    nganSach: m['ngan_sach'] as String? ?? '',
    trangThai: m['trang_thai'] as String? ?? 'lead_moi',
    nhan: m['nhan'] as String? ?? '',
    viecTiep: m['viec_tiep'] as String? ?? '',
    capNhat: DateTime.tryParse(m['cap_nhat'] as String? ?? ''),
  );

  final int id;
  final String ma;
  final String khach;
  final String sdt;
  final int khachId;
  final String loaiCan;
  final String khuVuc;
  final String nganSach;
  final String trangThai;
  final String nhan;
  final String viecTiep;
  final DateTime? capNhat;
}

class BangYeuCau {
  const BangYeuCau({this.dem = const {}, this.danhSach = const []});

  factory BangYeuCau.fromMap(Map<String, dynamic> m) => BangYeuCau(
    dem: {
      for (final e in (m['dem'] as Map?)?.entries ?? const <MapEntry>[])
        '${e.key}': _i(e.value),
    },
    danhSach: [
      for (final x in (m['danh_sach'] as List? ?? const []))
        MucYeuCau.fromMap((x as Map).cast<String, dynamic>()),
    ],
  );

  final Map<String, int> dem;
  final List<MucYeuCau> danhSach;

  int soCua(String nhom) => dem[nhom] ?? 0;
}

class BuocPipeline {
  const BuocPipeline({
    required this.buoc,
    required this.nhan,
    this.xong = false,
    this.dangO = false,
    this.luc,
  });

  factory BuocPipeline.fromMap(Map<String, dynamic> m) => BuocPipeline(
    buoc: m['buoc'] as String? ?? '',
    nhan: m['nhan'] as String? ?? '',
    xong: m['xong'] == true,
    dangO: m['dang_o'] == true,
    luc: gioVNTuUtc(m['luc'] as String?),
  );

  final String buoc;
  final String nhan;
  final bool xong;
  final bool dangO;
  final DateTime? luc;
}

class CanLienQuan {
  const CanLienQuan({
    required this.id,
    this.houseId,
    this.roomId,
    this.ten = '',
    this.diaChi = '',
    this.anh,
    this.gia = 0,
    this.khachThich = false,
  });

  factory CanLienQuan.fromMap(Map<String, dynamic> m) => CanLienQuan(
    id: _i(m['id']),
    houseId: (m['house_id'] as num?)?.toInt(),
    roomId: (m['room_id'] as num?)?.toInt(),
    ten: m['ten'] as String? ?? '',
    diaChi: m['dia_chi'] as String? ?? '',
    anh: m['anh'] as String?,
    gia: _d(m['gia']),
    khachThich: m['khach_thich'] == true,
  );

  final int id;
  final int? houseId;
  final int? roomId;
  final String ten;
  final String diaChi;
  final String? anh;
  final double gia;
  final bool khachThich;
}

class KhachCuaYeuCau {
  const KhachCuaYeuCau({
    this.id,
    this.hoTen = '',
    this.sdt = '',
    this.khuVuc = '',
    this.coTaiKhoan = false,
  });

  factory KhachCuaYeuCau.fromMap(Map<String, dynamic> m) => KhachCuaYeuCau(
    id: (m['id'] as num?)?.toInt(),
    hoTen: m['ho_ten'] as String? ?? '',
    sdt: m['sdt'] as String? ?? '',
    khuVuc: m['khu_vuc'] as String? ?? '',
    coTaiKhoan: m['co_tai_khoan'] == true,
  );

  final int? id;
  final String hoTen;
  final String sdt;
  final String khuVuc;
  final bool coTaiKhoan;
}

class YeuCauChiTiet {
  const YeuCauChiTiet({
    required this.id,
    required this.ma,
    required this.khach,
    this.trangThai = 'lead_moi',
    this.nhan = '',
    this.viecTiep = '',
    this.nganSach = '',
    this.vaoOTu,
    this.loaiCan = '',
    this.khuVuc = '',
    this.ghiChu = '',
    this.dongLyDo,
    this.appointmentId,
    this.journeyId,
    this.canLienQuan = const [],
    this.pipeline = const [],
  });

  factory YeuCauChiTiet.fromMap(Map<String, dynamic> m) => YeuCauChiTiet(
    id: _i(m['id']),
    ma: m['ma'] as String? ?? '',
    khach: KhachCuaYeuCau.fromMap(
      (m['khach'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    trangThai: m['trang_thai'] as String? ?? 'lead_moi',
    nhan: m['nhan'] as String? ?? '',
    viecTiep: m['viec_tiep'] as String? ?? '',
    nganSach: m['ngan_sach'] as String? ?? '',
    vaoOTu: DateTime.tryParse(m['vao_o_tu'] as String? ?? ''),
    loaiCan: m['loai_can'] as String? ?? '',
    khuVuc: m['khu_vuc'] as String? ?? '',
    ghiChu: m['ghi_chu'] as String? ?? '',
    dongLyDo: m['dong_ly_do'] as String?,
    appointmentId: (m['appointment_id'] as num?)?.toInt(),
    journeyId: (m['journey_id'] as num?)?.toInt(),
    canLienQuan: [
      for (final x in (m['can_lien_quan'] as List? ?? const []))
        CanLienQuan.fromMap((x as Map).cast<String, dynamic>()),
    ],
    pipeline: [
      for (final x in (m['pipeline'] as List? ?? const []))
        BuocPipeline.fromMap((x as Map).cast<String, dynamic>()),
    ],
  );

  final int id;
  final String ma;
  final KhachCuaYeuCau khach;
  final String trangThai;
  final String nhan;
  final String viecTiep;
  final String nganSach;
  final DateTime? vaoOTu;
  final String loaiCan;
  final String khuVuc;
  final String ghiChu;
  final String? dongLyDo;

  /// Có khi yêu cầu sinh từ lịch xem KHÁCH TỰ ĐẶT (mig 0134): việc đầu tiên
  /// là xác nhận lịch đó, bước sẽ tự nhảy theo lịch.
  final int? appointmentId;

  /// Hồ sơ thuê sau buổi xem — sale gửi hợp đồng + số cọc ở đó.
  final int? journeyId;
  final List<CanLienQuan> canLienQuan;
  final List<BuocPipeline> pipeline;

  /// Căn khách chốt — giá thuê và hoa hồng của đơn đọc từ đây. `null` khi
  /// sale chưa chỉ ra khách thuê căn nào.
  CanLienQuan? get canChot {
    for (final c in canLienQuan) {
      if (c.khachThich) return c;
    }
    return null;
  }

  /// Bước kế tiếp để nút "Chuyển trạng thái" biết đẩy tới đâu; `null` khi đã
  /// chốt — không vẽ nút dẫn tới hư không.
  String? get buocKe {
    for (final b in pipeline) {
      if (!b.xong) return b.buoc;
    }
    return null;
  }

  bool get daChot => trangThai == 'da_chot';
}

/// Một căn trong khay chọn — đến từ toà liên kết hoặc bài đăng của sale.
class CanCoTheGan {
  const CanCoTheGan({
    this.houseId,
    this.roomId,
    this.ten = '',
    this.diaChi = '',
    this.gia = 0,
    this.anh,
    this.trangThai = '',
    this.daGan = false,
  });

  factory CanCoTheGan.fromMap(Map<String, dynamic> m) => CanCoTheGan(
    houseId: (m['house_id'] as num?)?.toInt(),
    roomId: (m['room_id'] as num?)?.toInt(),
    ten: m['ten'] as String? ?? '',
    diaChi: m['dia_chi'] as String? ?? '',
    gia: _d(m['gia']),
    anh: m['anh'] as String?,
    trangThai: m['trang_thai'] as String? ?? '',
    daGan: m['da_gan'] == true,
  );

  final int? houseId;
  final int? roomId;
  final String ten;
  final String diaChi;
  final double gia;
  final String? anh;
  final String trangThai;
  final bool daGan;
}

class NguonCanSale {
  const NguonCanSale({this.toaLienKet = const [], this.baiDang = const []});

  factory NguonCanSale.fromMap(Map<String, dynamic> m) => NguonCanSale(
    toaLienKet: [
      for (final x in (m['toa_lien_ket'] as List? ?? const []))
        CanCoTheGan.fromMap((x as Map).cast<String, dynamic>()),
    ],
    baiDang: [
      for (final x in (m['bai_dang'] as List? ?? const []))
        CanCoTheGan.fromMap((x as Map).cast<String, dynamic>()),
    ],
  );

  final List<CanCoTheGan> toaLienKet;
  final List<CanCoTheGan> baiDang;

  bool get rong => toaLienKet.isEmpty && baiDang.isEmpty;
}

class KhachSale {
  const KhachSale({
    required this.id,
    this.hoTen = '',
    this.sdt = '',
    this.khuVuc = '',
    this.trangThai = 'dang_tu_van',
    this.nhan = '',
    this.coTaiKhoan = false,
    this.soYeuCau = 0,
    this.ganNhat = '',
  });

  factory KhachSale.fromMap(Map<String, dynamic> m) => KhachSale(
    id: _i(m['id']),
    hoTen: m['ho_ten'] as String? ?? '',
    sdt: m['sdt'] as String? ?? '',
    khuVuc: m['khu_vuc'] as String? ?? '',
    trangThai: m['trang_thai'] as String? ?? 'dang_tu_van',
    nhan: m['nhan'] as String? ?? '',
    coTaiKhoan: m['co_tai_khoan'] == true,
    soYeuCau: _i(m['so_yeu_cau']),
    ganNhat: m['gan_nhat'] as String? ?? '',
  );

  final int id;
  final String hoTen;
  final String sdt;
  final String khuVuc;
  final String trangThai;
  final String nhan;
  final bool coTaiKhoan;
  final int soYeuCau;
  final String ganNhat;
}

class SoKhachSale {
  const SoKhachSale({
    this.tongKhach = 0,
    this.dangTuVan = 0,
    this.daThue = 0,
    this.danhSach = const [],
  });

  factory SoKhachSale.fromMap(Map<String, dynamic> m) => SoKhachSale(
    tongKhach: _i(m['tong_khach']),
    dangTuVan: _i(m['dang_tu_van']),
    daThue: _i(m['da_thue']),
    danhSach: [
      for (final x in (m['danh_sach'] as List? ?? const []))
        KhachSale.fromMap((x as Map).cast<String, dynamic>()),
    ],
  );

  final int tongKhach;
  final int dangTuVan;
  final int daThue;
  final List<KhachSale> danhSach;
}

class ToaLienKet {
  const ToaLienKet({
    required this.id,
    this.ten = '',
    this.diaChi = '',
    this.soPhong = 0,
    this.phongTrong = 0,
  });

  factory ToaLienKet.fromMap(Map<String, dynamic> m) => ToaLienKet(
    id: _i(m['id']),
    ten: m['ten'] as String? ?? '',
    diaChi: m['dia_chi'] as String? ?? '',
    soPhong: _i(m['so_phong']),
    phongTrong: _i(m['phong_trong']),
  );

  final int id;
  final String ten;
  final String diaChi;
  final int soPhong;
  final int phongTrong;
}

class ThangTien {
  const ThangTien({
    required this.thang,
    this.donDaChot = 0,
    this.doanhThu = 0,
    this.hoaHongDuKien = 0,
  });

  factory ThangTien.fromMap(Map<String, dynamic> m) => ThangTien(
    thang: DateTime.tryParse(m['thang'] as String? ?? '') ?? DateTime.now(),
    donDaChot: _i(m['don_da_chot']),
    doanhThu: _d(m['doanh_thu']),
    hoaHongDuKien: _d(m['hoa_hong_du_kien']),
  );

  final DateTime thang;
  final int donDaChot;
  final double doanhThu;
  final double hoaHongDuKien;
}

class GiaoDichGanDay {
  const GiaoDichGanDay({
    required this.yeuCauId,
    this.ma = '',
    this.khach = '',
    this.giaThue = 0,
    this.chotLuc,
  });

  factory GiaoDichGanDay.fromMap(Map<String, dynamic> m) => GiaoDichGanDay(
    yeuCauId: _i(m['yeu_cau_id']),
    ma: m['ma'] as String? ?? '',
    khach: m['khach'] as String? ?? '',
    giaThue: _d(m['gia_thue']),
    chotLuc: DateTime.tryParse(m['chot_luc'] as String? ?? ''),
  );

  final int yeuCauId;
  final String ma;
  final String khach;
  final double giaThue;
  final DateTime? chotLuc;
}

class ToaVaDoanhThu {
  const ToaVaDoanhThu({
    this.toa = const [],
    this.soChuLienKet = 0,
    this.donDaChot = 0,
    this.doanhThuThang = 0,
    this.hoaHongDuKien = 0,
    this.hoaHongDaNhan = 0,
    this.theoThang = const [],
    this.ganDay = const [],
  });

  factory ToaVaDoanhThu.fromMap(Map<String, dynamic> m) => ToaVaDoanhThu(
    toa: [
      for (final x in (m['toa'] as List? ?? const []))
        ToaLienKet.fromMap((x as Map).cast<String, dynamic>()),
    ],
    soChuLienKet: _i(m['so_chu_lien_ket']),
    donDaChot: _i(m['don_da_chot']),
    doanhThuThang: _d(m['doanh_thu_thang']),
    hoaHongDuKien: _d(m['hoa_hong_du_kien']),
    hoaHongDaNhan: _d(m['hoa_hong_da_nhan']),
    theoThang: [
      for (final x in (m['theo_thang'] as List? ?? const []))
        ThangTien.fromMap((x as Map).cast<String, dynamic>()),
    ],
    ganDay: [
      for (final x in (m['gan_day'] as List? ?? const []))
        GiaoDichGanDay.fromMap((x as Map).cast<String, dynamic>()),
    ],
  );

  final List<ToaLienKet> toa;
  final int soChuLienKet;
  final int donDaChot;
  final double doanhThuThang;
  final double hoaHongDuKien;
  final double hoaHongDaNhan;
  final List<ThangTien> theoThang;
  final List<GiaoDichGanDay> ganDay;
}

/// Mốc pipeline server ghi bằng `utcnow()` và trả chuỗi KHÔNG kèm múi giờ.
/// `DateTime.parse` coi chuỗi đó là giờ máy → màn hiện giờ UTC, lệch 7 tiếng.
/// Chuỗi không có múi thì coi là UTC rồi đổi sang giờ Việt Nam.
DateTime? gioVNTuUtc(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final coMui = iso.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(iso);
  final d = DateTime.tryParse(coMui ? iso : '${iso}Z');
  if (d == null) return null;
  final vn = d.toUtc().add(const Duration(hours: 7));
  return DateTime(vn.year, vn.month, vn.day, vn.hour, vn.minute);
}
