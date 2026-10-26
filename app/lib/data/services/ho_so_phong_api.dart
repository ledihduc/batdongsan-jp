import 'package:house_booking/data/models/room_model.dart';
import 'package:house_booking/data/services/api_client.dart';

/// HỒ SƠ PHÒNG — `GET /api/host/rooms/{id}/ho-so`, sổ sửa chữa, tài sản bàn
/// giao, kỳ thanh toán của hợp đồng, và lập hoá đơn tháng này.
///
/// Một lượt gọi cho cả màn; số đo ở server cùng luật với sổ phòng
/// (`services/so_phong.py`). Khối nào `null` là server không tính được hoặc
/// người xem không có quyền (sale không thấy người và tiền) — màn ẨN khối đó,
/// không in số minh hoạ.
class HoSoPhongApi {
  const HoSoPhongApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  Future<HoSoPhong> lay(int roomId) async =>
      HoSoPhong.fromMap(await _c.get('/api/host/rooms/$roomId/ho-so'));

  Future<SuaChua> ghiSuaChua(
    int roomId, {
    required String tieuDe,
    required String ngay,
    String? moTa,
    String? nguoiThucHien,
    double? chiPhi,
    bool dangXuLy = false,
  }) async => SuaChua.fromMap(
    await _c.post(
      '/api/host/rooms/$roomId/sua-chua',
      body: {
        'tieu_de': tieuDe,
        'ngay': ngay,
        'mo_ta': ?moTa,
        'nguoi_thuc_hien': ?nguoiThucHien,
        'chi_phi': ?chiPhi,
        'trang_thai': dangXuLy ? 'dang_xu_ly' : 'da_xong',
      },
    ),
  );

  Future<SuaChua> danhDauXong(int id) async => SuaChua.fromMap(
    await _c.patch('/api/host/sua-chua/$id', body: {'trang_thai': 'da_xong'}),
  );

  Future<void> xoaSuaChua(int id) async {
    await _c.delete('/api/host/sua-chua/$id');
  }

  Future<TaiSan> themTaiSan(
    int roomId, {
    required String ten,
    String? loai,
    String? thongSo,
    String tinhTrang = 'tot',
    String? ghiChu,
  }) async => TaiSan.fromMap(
    await _c.post(
      '/api/host/rooms/$roomId/tai-san',
      body: {
        'ten': ten,
        'loai': ?loai,
        'thong_so': ?thongSo,
        'tinh_trang': tinhTrang,
        'ghi_chu': ?ghiChu,
      },
    ),
  );

  /// Gửi ĐỦ các ô của form: ô để trống gửi `null` là xoá thông số / ghi chú.
  Future<TaiSan> suaTaiSan(
    int id, {
    required String ten,
    required String? loai,
    required String? thongSo,
    required String tinhTrang,
    required String? ghiChu,
  }) async => TaiSan.fromMap(
    await _c.patch(
      '/api/host/tai-san/$id',
      body: {
        'ten': ten,
        'loai': loai,
        'thong_so': thongSo,
        'tinh_trang': tinhTrang,
        'ghi_chu': ghiChu,
      },
    ),
  );

  Future<void> xoaTaiSan(int id) async {
    await _c.delete('/api/host/tai-san/$id');
  }

  /// Ba ô của khối Tài chính gửi cùng lúc; `null` = về "chưa khai".
  Future<void> capNhatThanhToan(
    int contractId, {
    required int? ngayThanhToan,
    required String? hinhThuc,
    required double? cocDaThu,
  }) async {
    await _c.patch(
      '/api/host/contracts/$contractId/thanh-toan',
      body: {
        'ngay_thanh_toan': ngayThanhToan,
        'hinh_thuc_thanh_toan': hinhThuc,
        'coc_da_thu': cocDaThu,
      },
    );
  }

  /// `daCo` = tháng này đã có hoá đơn từ trước — server trả lại đúng hoá đơn đó.
  Future<({int invoiceId, bool daCo})> lapHoaDonThangNay(int contractId) async {
    final m = await _c.post('/api/host/contracts/$contractId/hoa-don-thang-nay');
    return (invoiceId: _i(m['invoice_id']), daCo: m['da_co'] == true);
  }
}

double? _d(dynamic v) => (v as num?)?.toDouble();
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
String? _s(dynamic v) {
  final s = (v as String?)?.trim();
  return s == null || s.isEmpty ? null : s;
}

class HoSoPhong {
  const HoSoPhong({
    required this.room,
    required this.toa,
    this.xemTaiChinh = false,
    this.suaDuoc = false,
    this.hopDong,
    this.hoaDonGanNhat,
    this.hoaDon = const [],
    this.dienNuoc,
    this.taiSan = const [],
    this.suaChua = const [],
    this.suaChuaTon = 0,
    this.soHopDongCu = 0,
  });

  final RoomModel room;
  final ({int id, String ten, String diaChi}) toa;

  /// Người xem là chủ phòng / admin — thấy người, tiền, điện nước.
  final bool xemTaiChinh;

  /// Được ghi sổ sửa chữa, tài sản, sửa phòng.
  final bool suaDuoc;
  final HopDongHienTai? hopDong;
  final HoaDonGanNhat? hoaDonGanNhat;

  /// Sáu kỳ gần nhất CỦA PHÒNG, gồm cả hợp đồng cũ — khách trả phòng giữa
  /// tháng vẫn để lại hoá đơn treo. Mới nhất lên đầu.
  final List<HoaDonGanNhat> hoaDon;
  final DienNuocPhong? dienNuoc;
  final List<TaiSan> taiSan;
  final List<SuaChua> suaChua;

  /// Số việc sửa còn đang xử lý.
  final int suaChuaTon;
  final int soHopDongCu;

  factory HoSoPhong.fromMap(Map<String, dynamic> m) {
    final t = Map<String, dynamic>.from(m['toa'] as Map? ?? const {});
    Map<String, dynamic>? con(String k) =>
        m[k] is Map ? Map<String, dynamic>.from(m[k] as Map) : null;
    List<Map<String, dynamic>> ds(String k) => [
      for (final x in (m[k] as List? ?? const []).whereType<Map>())
        Map<String, dynamic>.from(x),
    ];
    return HoSoPhong(
      room: RoomModel.fromJson(Map<String, dynamic>.from(m['room'] as Map)),
      toa: (
        id: _i(t['id']),
        ten: t['ten'] as String? ?? '',
        diaChi: t['dia_chi'] as String? ?? '',
      ),
      xemTaiChinh: m['xem_tai_chinh'] == true,
      suaDuoc: m['sua_duoc'] == true,
      hopDong: con('hop_dong') == null
          ? null
          : HopDongHienTai.fromMap(con('hop_dong')!),
      hoaDonGanNhat: con('hoa_don_gan_nhat') == null
          ? null
          : HoaDonGanNhat.fromMap(con('hoa_don_gan_nhat')!),
      hoaDon: [
        for (final x in (m['hoa_don'] as List? ?? const []))
          HoaDonGanNhat.fromMap(Map<String, dynamic>.from(x as Map)),
      ],
      dienNuoc: con('dien_nuoc') == null
          ? null
          : DienNuocPhong.fromMap(con('dien_nuoc')!),
      taiSan: [for (final x in ds('tai_san')) TaiSan.fromMap(x)],
      suaChua: [for (final x in ds('sua_chua')) SuaChua.fromMap(x)],
      suaChuaTon: _i(m['sua_chua_ton']),
      soHopDongCu: _i(m['so_hop_dong_cu']),
    );
  }
}

class HopDongHienTai {
  const HopDongHienTai({
    required this.id,
    required this.batDau,
    required this.ketThuc,
    this.tienThue = 0,
    this.tienCoc = 0,
    this.tongThang,
    this.daOThang = 0,
    this.conLaiNgay,
    this.tyLe = 0,
    this.kenh = 'dai_han',
    this.soNguoi = 0,
    this.khach,
    this.ngayThanhToan,
    this.hinhThucThanhToan,
    this.cocDaThu,
    this.ngoaiLuong = false,
    this.ghiChu,
  });

  final int id;

  /// `YYYY-MM-DD`.
  final String batDau;
  final String ketThuc;
  final double tienThue;
  final double tienCoc;
  final int? tongThang;
  final int daOThang;

  /// Âm = quá hạn mà hợp đồng chưa được đóng.
  final int? conLaiNgay;

  /// % thời gian hợp đồng đã trôi qua, 0..100.
  final double tyLe;

  /// 'dai_han' | 'mat_bang'.
  final String kenh;
  final int soNguoi;
  final KhachChinh? khach;

  /// Ngày thu tiền hàng tháng 1..31; `null` = chưa khai.
  final int? ngayThanhToan;

  /// chuyen_khoan | tien_mat | ca_hai; `null` = chưa khai.
  final String? hinhThucThanhToan;

  /// Tiền cọc đã thu; `null` = chưa ghi nhận (khác 0 = chưa thu đồng nào).
  final double? cocDaThu;

  /// True = chủ nhà tự tìm khách ngoài app rồi đánh dấu. Người thuê KHÔNG có
  /// tài khoản: đừng chờ họ gửi ảnh công tơ, chủ nhà tự chụp.
  final bool ngoaiLuong;

  /// "Thuê qua Facebook, chưa làm giấy tờ" — thường là thứ duy nhất để tra.
  final String? ghiChu;

  static const nhanHinhThuc = <String, String>{
    'chuyen_khoan': 'Chuyển khoản',
    'tien_mat': 'Tiền mặt',
    'ca_hai': 'Chuyển khoản / Tiền mặt',
  };

  factory HopDongHienTai.fromMap(Map<String, dynamic> m) => HopDongHienTai(
    id: _i(m['id']),
    batDau: m['bat_dau'] as String? ?? '',
    ketThuc: m['ket_thuc'] as String? ?? '',
    tienThue: _d(m['tien_thue']) ?? 0,
    tienCoc: _d(m['tien_coc']) ?? 0,
    tongThang: (m['tong_thang'] as num?)?.toInt(),
    daOThang: _i(m['da_o_thang']),
    conLaiNgay: (m['con_lai_ngay'] as num?)?.toInt(),
    tyLe: _d(m['ty_le']) ?? 0,
    kenh: m['kenh'] as String? ?? 'dai_han',
    soNguoi: _i(m['so_nguoi']),
    khach: m['khach'] is Map
        ? KhachChinh.fromMap(Map<String, dynamic>.from(m['khach'] as Map))
        : null,
    ngayThanhToan: (m['ngay_thanh_toan'] as num?)?.toInt(),
    hinhThucThanhToan: _s(m['hinh_thuc_thanh_toan']),
    cocDaThu: _d(m['coc_da_thu']),
    ngoaiLuong: m['ngoai_luong'] == true,
    ghiChu: _s(m['ghi_chu']),
  );
}

class KhachChinh {
  const KhachChinh({
    required this.tenantId,
    required this.ten,
    this.sdt = '',
    this.email,
    this.coCccd = false,
    this.cccdDuoi,
  });

  final int tenantId;
  final String ten;
  final String sdt;
  final String? email;

  /// Đã lưu đủ ảnh HAI mặt CCCD.
  final bool coCccd;

  /// 3 số CUỐI của CCCD — số đầy đủ không bao giờ được lưu.
  final String? cccdDuoi;

  factory KhachChinh.fromMap(Map<String, dynamic> m) => KhachChinh(
    tenantId: _i(m['tenant_id']),
    ten: m['ten'] as String? ?? '',
    sdt: m['sdt'] as String? ?? '',
    email: _s(m['email']),
    coCccd: m['co_cccd'] == true,
    cccdDuoi: _s(m['cccd_duoi']),
  );
}

class HoaDonGanNhat {
  const HoaDonGanNhat({
    required this.id,
    required this.so,
    required this.ky,
    this.tong = 0,
    this.daTra = 0,
    this.trangThai = 'draft',
    this.hanDong = '',
  });

  final int id;
  final String so;

  /// `YYYY-MM`.
  final String ky;
  final double tong;
  final double daTra;

  /// draft | sent | paid | overdue.
  final String trangThai;
  final String hanDong;

  factory HoaDonGanNhat.fromMap(Map<String, dynamic> m) => HoaDonGanNhat(
    id: _i(m['id']),
    so: m['so'] as String? ?? '',
    ky: m['ky'] as String? ?? '',
    tong: _d(m['tong']) ?? 0,
    daTra: _d(m['da_tra']) ?? 0,
    trangThai: m['trang_thai'] as String? ?? 'draft',
    hanDong: m['han_dong'] as String? ?? '',
  );
}

class DienNuocPhong {
  const DienNuocPhong({
    required this.thang,
    this.ngayChot,
    this.readingId,
    this.dienCu,
    this.dienMoi,
    this.dienDung,
    this.nuocCu,
    this.nuocMoi,
    this.nuocDung,
    this.giaDien = 0,
    this.giaNuoc = 0,
    this.anhDien,
    this.anhNuoc,
    this.trangThai = 'chua_gui',
  });

  /// `YYYY-MM`.
  final String thang;
  final String? ngayChot;
  final int? readingId;
  final double? dienCu;
  final double? dienMoi;
  final double? dienDung;
  final double? nuocCu;
  final double? nuocMoi;
  final double? nuocDung;
  final double giaDien;
  final double giaNuoc;
  final String? anhDien;
  final String? anhNuoc;

  /// chua_gui | cho_duyet | thieu_anh | can_chup_lai | da_duyet.
  final String trangThai;

  factory DienNuocPhong.fromMap(Map<String, dynamic> m) => DienNuocPhong(
    thang: m['thang'] as String? ?? '',
    ngayChot: _s(m['ngay_chot']),
    readingId: (m['reading_id'] as num?)?.toInt(),
    dienCu: _d(m['dien_cu']),
    dienMoi: _d(m['dien_moi']),
    dienDung: _d(m['dien_dung']),
    nuocCu: _d(m['nuoc_cu']),
    nuocMoi: _d(m['nuoc_moi']),
    nuocDung: _d(m['nuoc_dung']),
    giaDien: _d(m['gia_dien']) ?? 0,
    giaNuoc: _d(m['gia_nuoc']) ?? 0,
    anhDien: _s(m['anh_dien']),
    anhNuoc: _s(m['anh_nuoc']),
    trangThai: m['trang_thai'] as String? ?? 'chua_gui',
  );
}

/// Một món tài sản / nội thất bàn giao cùng phòng.
class TaiSan {
  const TaiSan({
    required this.id,
    required this.ten,
    this.loai,
    this.thongSo,
    this.tinhTrang = 'tot',
    this.ghiChu,
  });

  final int id;
  final String ten;

  /// Key `do_trong_phong` (dieu_hoa, tu_lanh…) để vẽ biểu tượng; `null` = món khác.
  final String? loai;
  final String? thongSo;

  /// tot | hao_mon | hong.
  final String tinhTrang;
  final String? ghiChu;

  static const nhanTinhTrang = <String, String>{
    'tot': 'Tốt',
    'hao_mon': 'Hao mòn',
    'hong': 'Hỏng',
  };

  factory TaiSan.fromMap(Map<String, dynamic> m) => TaiSan(
    id: _i(m['id']),
    ten: m['ten'] as String? ?? '',
    loai: _s(m['loai']),
    thongSo: _s(m['thong_so']),
    tinhTrang: m['tinh_trang'] as String? ?? 'tot',
    ghiChu: _s(m['ghi_chu']),
  );
}

class SuaChua {
  const SuaChua({
    required this.id,
    required this.tieuDe,
    required this.ngay,
    this.moTa,
    this.nguoiThucHien,
    this.chiPhi,
    this.trangThai = 'da_xong',
  });

  final int id;
  final String tieuDe;

  /// `YYYY-MM-DD`.
  final String ngay;
  final String? moTa;
  final String? nguoiThucHien;

  /// `null` với người không xem được tài chính của phòng.
  final double? chiPhi;
  final String trangThai;

  bool get dangXuLy => trangThai == 'dang_xu_ly';

  factory SuaChua.fromMap(Map<String, dynamic> m) => SuaChua(
    id: _i(m['id']),
    tieuDe: m['tieu_de'] as String? ?? '',
    ngay: m['ngay'] as String? ?? '',
    moTa: _s(m['mo_ta']),
    nguoiThucHien: _s(m['nguoi_thuc_hien']),
    chiPhi: _d(m['chi_phi']),
    trangThai: m['trang_thai'] as String? ?? 'da_xong',
  );
}
