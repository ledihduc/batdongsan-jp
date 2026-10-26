import 'dart:convert';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/data/services/api_client.dart';

/// SỔ CHỦ NHÀ — 14 màn quản lý của chủ nhà (mockup 06/10/2026).
///
///     GET    /api/host/so-chu-nha/trang-chu?kenh=          màn 1, 14
///     GET    /api/host/so-chu-nha/toa-nha                  màn 2
///     GET    /api/host/so-chu-nha/toa-nha/{id}/phong       màn 3
///     GET    /api/host/so-chu-nha/toa-nha/{id}/form-phong  màn 12 (dữ liệu form)
///     POST   /api/host/so-chu-nha/toa-nha/{id}/phong       màn 12 thêm
///     PUT    /api/host/so-chu-nha/phong/{id}               màn 12 sửa
///     GET    /api/host/so-chu-nha/mau-nhap-phong.xlsx      màn 13 tệp mẫu
///     POST   /api/host/so-chu-nha/toa-nha/{id}/nhap-phong  màn 13
///     GET    /api/host/so-chu-nha/phong/{id}               màn 4
///     GET    /api/host/so-chu-nha/phong/{id}/hop-dong      màn 5 (+ gia-han)
///     GET    /api/host/so-chu-nha/phong/{id}/dien-nuoc     màn 6 (+ POST lưu)
///     GET    /api/host/so-chu-nha/thu-chi?thang=           tab Thu chi
///     GET    /api/host/so-chu-nha/phong/{id}/thu-chi       màn 7
///     GET    /api/host/so-chu-nha/phong/{id}/thu-tien      màn 8, 9 (+ POST thu)
///     POST   /api/host/so-chu-nha/phong/{id}/hoa-don       màn 9 Tạo hoá đơn
///     GET    /api/host/so-chu-nha/phong/{id}/dich-vu       màn 10 (+ PATCH/POST)
///     GET    /api/host/so-chu-nha/phong/{id}/lich-su       màn 11
class SoChuNhaApi {
  const SoChuNhaApi({ApiClient client = const ApiClient()}) : _c = client;

  final ApiClient _c;

  static const _goc = '/api/host/so-chu-nha';

  /// Link tải tệp Excel mẫu — công khai, mở thẳng bằng trình duyệt.
  static String get linkMauNhap => '${ApiConfig.baseUrl}$_goc/mau-nhap-phong.xlsx';

  Future<TrangChuCN> trangChu(String kenh) async => TrangChuCN.fromMap(
    await _c.get('$_goc/trang-chu', queryParameters: {'kenh': kenh}),
  );

  Future<List<ToaCN>> toaNha() async {
    final m = await _c.get('$_goc/toa-nha');
    return [for (final x in _ds(m['toa_nha'])) ToaCN.fromMap(x)];
  }

  /// Thêm toà — endpoint toà nhà sẵn có của chủ nhà.
  Future<int> themToa({
    required String ten,
    required String diaChi,
    String phuong = '',
    String thanhPho = '',
  }) async {
    final m = await _c.post(
      '/api/host/buildings',
      body: {'name': ten, 'address': diaChi, 'ward': phuong, 'city': thanhPho},
    );
    return (m['id'] as num).toInt();
  }

  Future<PhongCuaToaCN> phongCuaToa(int toaId) async =>
      PhongCuaToaCN.fromMap(await _c.get('$_goc/toa-nha/$toaId/phong'));

  /// Setup tầng: gán tầng cho nhiều phòng một lượt. `tang` null = bỏ tầng.
  Future<PhongCuaToaCN> datTang(int toaId, Map<int, String?> tangTheoPhong) async =>
      PhongCuaToaCN.fromMap(
        await _c.put(
          '$_goc/toa-nha/$toaId/tang',
          body: {
            'phong': [
              for (final e in tangTheoPhong.entries) {'id': e.key, 'tang': e.value},
            ],
          },
        ),
      );

  Future<FormPhongCN> formPhong(int toaId, {int? roomId}) async =>
      FormPhongCN.fromMap(
        await _c.get(
          '$_goc/toa-nha/$toaId/form-phong',
          queryParameters: {if (roomId != null) 'room_id': '$roomId'},
        ),
      );

  Future<int> themPhong(int toaId, PhongVaoCN p) async {
    final m = await _c.post('$_goc/toa-nha/$toaId/phong', body: p.toMap());
    return (m['id'] as num).toInt();
  }

  Future<void> suaPhong(int roomId, PhongVaoCN p) =>
      _c.put('$_goc/phong/$roomId', body: p.toMap());

  Future<String> taiAnh(List<int> bytes, String ten) => _c.uploadImage(bytes, ten);

  Future<KetQuaNhapCN> nhapPhong(
    int toaId,
    List<int> bytes,
    String tenTep, {
    required bool ghi,
  }) async => KetQuaNhapCN.fromMap(
    await _c.post(
      '$_goc/toa-nha/$toaId/nhap-phong?ghi=$ghi',
      body: {'ten_tep': tenTep, 'du_lieu': base64Encode(bytes)},
    ),
  );

  Future<PhongCN> phong(int id) async => PhongCN.fromMap(await _c.get('$_goc/phong/$id'));

  Future<HopDongCN?> hopDong(int roomId) async =>
      HopDongCN.tuGoi(await _c.get('$_goc/phong/$roomId/hop-dong'));

  Future<HopDongCN?> giaHan(int roomId, int soThang) async => HopDongCN.tuGoi(
    await _c.post('$_goc/phong/$roomId/hop-dong/gia-han', body: {'so_thang': soThang}),
  );

  Future<DienNuocCN> dienNuoc(int roomId) async =>
      DienNuocCN.fromMap(await _c.get('$_goc/phong/$roomId/dien-nuoc'));

  Future<DienNuocCN> luuChiSo(
    int roomId, {
    required double dien,
    double nuoc = 0,
    String? anhDien,
    String? anhNuoc,
  }) async => DienNuocCN.fromMap(
    await _c.post(
      '$_goc/phong/$roomId/dien-nuoc',
      body: {
        'dien_moi': dien,
        'nuoc_moi': nuoc,
        'anh_dien': ?anhDien,
        'anh_nuoc': ?anhNuoc,
      },
    ),
  );

  /// Duyệt chỉ số KHÁCH gửi — cùng endpoint với bảng duyệt tháng.
  Future<void> duyetChiSo(int readingId) async {
    await _c.post('/api/host/dien-nuoc/$readingId/duyet');
  }

  /// Trả về cho khách chụp lại, kèm lý do (khách nhận thông báo).
  Future<void> yeuCauChupLai(int readingId, String lyDo) async {
    await _c.post('/api/host/dien-nuoc/$readingId/chup-lai', body: {'ly_do': lyDo});
  }

  Future<ThuChiTongCN> thuChiTong({String? thang}) async => ThuChiTongCN.fromMap(
    await _c.get(
      '$_goc/thu-chi',
      queryParameters: {'thang': ?thang},
    ),
  );

  Future<ThuChiPhongCN> thuChi(int roomId) async =>
      ThuChiPhongCN.fromMap(await _c.get('$_goc/phong/$roomId/thu-chi'));

  Future<KyThuCN> kyThu(int roomId, {String? thang}) async => KyThuCN.fromMap(
    await _c.get(
      '$_goc/phong/$roomId/thu-tien',
      queryParameters: {'thang': ?thang},
    ),
  );

  Future<KyThuCN> xacNhanThu(int roomId, String thang, String hinhThuc) async =>
      KyThuCN.fromMap(
        await _c.post(
          '$_goc/phong/$roomId/thu-tien',
          body: {'thang': thang, 'hinh_thuc': hinhThuc},
        ),
      );

  Future<KyThuCN> taoHoaDon(int roomId, String thang) async => KyThuCN.fromMap(
    await _c.post('$_goc/phong/$roomId/hoa-don', body: {'thang': thang}),
  );

  Future<DichVuPhongCN> dichVu(int roomId) async =>
      DichVuPhongCN.fromMap(await _c.get('$_goc/phong/$roomId/dich-vu'));

  Future<DichVuPhongCN> suaDichVu(
    int roomId,
    String ma, {
    double? gia,
    bool? apDung,
    String? cachTinh,
  }) async => DichVuPhongCN.fromMap(
    await _c.patch(
      '$_goc/phong/$roomId/dich-vu/$ma',
      body: {'gia': ?gia, 'ap_dung': ?apDung, 'cach_tinh': ?cachTinh},
    ),
  );

  /// Số người ở thực tế; `null` = đếm theo người trên hợp đồng.
  Future<DichVuPhongCN> datSoNguoi(int roomId, int? soNguoi) async => DichVuPhongCN.fromMap(
    await _c.put('$_goc/phong/$roomId/so-nguoi', body: {'so_nguoi': soNguoi}),
  );

  Future<DichVuPhongCN> themDichVu(
    int roomId, {
    required String ten,
    required double gia,
    String cachTinh = 'don_gia',
  }) async => DichVuPhongCN.fromMap(
    await _c.post(
      '$_goc/phong/$roomId/dich-vu',
      body: {'ten': ten, 'gia': gia, 'cach_tinh': cachTinh},
    ),
  );

  Future<LichSuPhongCN> lichSu(int roomId) async =>
      LichSuPhongCN.fromMap(await _c.get('$_goc/phong/$roomId/lich-su'));

  // ── Tài khoản nhận tiền (mig 0139) ─────────────────────────────────────────
  // Khai ở TOÀ, phòng ghi đè được; bỏ trống ở phòng = dùng của toà.

  Future<TaiKhoanNhanCN> taiKhoanToa(int toaId) async =>
      TaiKhoanNhanCN.fromMap(await _c.get('$_goc/toa-nha/$toaId/tai-khoan'));

  Future<TaiKhoanNhanCN> suaTaiKhoanToa(int toaId, {String bin = '', String so = '', String chu = ''}) async =>
      TaiKhoanNhanCN.fromMap(
        await _c.put(
          '$_goc/toa-nha/$toaId/tai-khoan',
          body: {'ngan_hang_bin': bin, 'so_tai_khoan': so, 'chu_tai_khoan': chu},
        ),
      );

  Future<TaiKhoanNhanCN> taiKhoanPhong(int roomId) async =>
      TaiKhoanNhanCN.fromMap(await _c.get('$_goc/phong/$roomId/tai-khoan'));

  Future<TaiKhoanNhanCN> suaTaiKhoanPhong(int roomId, {String bin = '', String so = '', String chu = ''}) async =>
      TaiKhoanNhanCN.fromMap(
        await _c.put(
          '$_goc/phong/$roomId/tai-khoan',
          body: {'ngan_hang_bin': bin, 'so_tai_khoan': so, 'chu_tai_khoan': chu},
        ),
      );
}

/// Một tài khoản ngân hàng: BIN (null = không vẽ được VietQR) · tên NH · số · chủ.
class TaiKhoanCN {
  const TaiKhoanCN({
    required this.bin,
    required this.nganHang,
    required this.so,
    required this.chu,
    required this.nguon,
  });

  final String? bin;
  final String nganHang;
  final String so;
  final String chu;

  /// 'phong' · 'toa' · 'ho_so'
  final String nguon;

  static TaiKhoanCN? tu(Object? v) {
    final m = _m(v);
    if (m == null) return null;
    return TaiKhoanCN(
      bin: _chuNull(m['bin']),
      nganHang: _chu(m['ngan_hang']),
      so: _chu(m['so_tai_khoan']),
      chu: _chu(m['chu_tai_khoan']),
      nguon: _chu(m['nguon']),
    );
  }
}

/// Tài khoản nhận tiền của toà (`taiKhoan`) hoặc của phòng (`rieng` · `cuaToa`
/// · `hieuLuc` = thứ khách thấy khi bấm "Thanh toán ngay").
class TaiKhoanNhanCN {
  const TaiKhoanNhanCN({this.ten = '', this.taiKhoan, this.rieng, this.cuaToa, this.hieuLuc});

  final String ten;
  final TaiKhoanCN? taiKhoan;
  final TaiKhoanCN? rieng;
  final TaiKhoanCN? cuaToa;
  final TaiKhoanCN? hieuLuc;

  factory TaiKhoanNhanCN.fromMap(Map<String, dynamic> m) => TaiKhoanNhanCN(
    ten: _chu(m['ten_toa'] ?? m['ten_phong']),
    taiKhoan: TaiKhoanCN.tu(m['tai_khoan']),
    rieng: TaiKhoanCN.tu(m['rieng']),
    cuaToa: TaiKhoanCN.tu(m['cua_toa']),
    hieuLuc: TaiKhoanCN.tu(m['hieu_luc']),
  );
}

// ── đọc map an toàn ─────────────────────────────────────────────────────────

List<Map<String, dynamic>> _ds(Object? v) => [
  for (final x in (v as List? ?? const [])) (x as Map).cast<String, dynamic>(),
];

Map<String, dynamic>? _m(Object? v) => v is Map ? v.cast<String, dynamic>() : null;

double? _so(Object? v) => v is num ? v.toDouble() : null;

int _nguyen(Object? v) => v is num ? v.toInt() : 0;

String _chu(Object? v) => v?.toString() ?? '';

String? _chuNull(Object? v) {
  final s = v?.toString();
  return s == null || s.isEmpty ? null : s;
}

// ── màn 1, 14 ───────────────────────────────────────────────────────────────

class ViecCN {
  const ViecCN({required this.loai, required this.so, required this.tieuDe, required this.phu});

  final String loai;
  final int so;
  final String tieuDe;
  final String phu;

  factory ViecCN.fromMap(Map<String, dynamic> m) => ViecCN(
    loai: _chu(m['loai']),
    so: _nguyen(m['so']),
    tieuDe: _chu(m['tieu_de']),
    phu: _chu(m['phu']),
  );
}

class TrangChuCN {
  const TrangChuCN({
    required this.kenh,
    required this.ten,
    required this.thang,
    required this.doanhThu,
    required this.tangPhanTram,
    required this.so,
    required this.homNay,
    required this.viec,
  });

  final String kenh;
  final String ten;
  final int thang;
  final double doanhThu;

  /// `null` = tháng trước bằng 0, không so được.
  final double? tangPhanTram;

  /// Dài hạn: toa_nha, phong, dang_thue, sap_thu_tien, sap_het_han, phong_trong.
  /// Ngắn hạn: toa_nha, phong, dang_cho_thue.
  final Map<String, int> so;

  /// Chỉ ngắn hạn: da_dat, dang_o, sap_tra.
  final Map<String, int> homNay;
  final List<ViecCN> viec;

  factory TrangChuCN.fromMap(Map<String, dynamic> m) {
    final dt = _m(m['doanh_thu']) ?? const {};
    Map<String, int> dem(Object? v) => {
      for (final e in (_m(v) ?? const {}).entries) e.key: _nguyen(e.value),
    };
    return TrangChuCN(
      kenh: _chu(m['kenh']),
      ten: _chu(m['ten']),
      thang: _nguyen(m['thang']),
      doanhThu: _so(dt['tien']) ?? 0,
      tangPhanTram: _so(dt['tang']),
      so: dem(m['so']),
      homNay: dem(m['hom_nay']),
      viec: [for (final x in _ds(m['viec'])) ViecCN.fromMap(x)],
    );
  }
}

// ── màn 2, 3 ────────────────────────────────────────────────────────────────

class ToaCN {
  const ToaCN({
    required this.id,
    required this.ten,
    required this.diaChi,
    required this.anh,
    required this.soPhong,
    required this.dangThue,
    this.soTang = 0,
  });

  final int id;
  final String ten;
  final String diaChi;
  final String? anh;
  final int soPhong;
  final int dangThue;
  final int soTang;

  factory ToaCN.fromMap(Map<String, dynamic> m) => ToaCN(
    id: _nguyen(m['id']),
    ten: _chu(m['ten']),
    diaChi: _chu(m['dia_chi']),
    anh: _chuNull(m['anh']),
    soPhong: _nguyen(m['so_phong']),
    dangThue: _nguyen(m['dang_thue']),
    soTang: _nguyen(m['so_tang']),
  );
}

class ThePhongCN {
  const ThePhongCN({
    required this.id,
    required this.ten,
    required this.tang,
    required this.dienTich,
    required this.loaiThue,
    required this.gia,
    required this.donVi,
    required this.anh,
    required this.trangThai,
    required this.ghiChu,
    this.khach,
    this.hdLap,
    this.hdHetHan,
    this.hdConNgay,
    this.thuTienNgay,
    this.thuTienConNgay,
    this.traPhongLuc,
    this.traPhongConGio,
    this.thieuGiayTo = const [],
  });

  /// Hợp đồng đang ở còn thiếu: 'hop_dong' · 'minh_chung_coc' (thuê trước,
  /// bổ sung sau — chỉ là cảnh báo).
  final List<String> thieuGiayTo;

  /// Người đang ở (HĐ dài hạn hoặc khách lưu trú ngắn hạn).
  final String? khach;
  final String? hdLap;
  final String? hdHetHan;
  final int? hdConNgay;
  final String? thuTienNgay;
  final int? thuTienConNgay;
  final String? traPhongLuc;
  final int? traPhongConGio;

  final int id;
  final String ten;
  final String tang;
  final double? dienTich;
  final String loaiThue;
  final double gia;
  final String donVi;
  final String? anh;

  /// dang_thue · sap_thu · sap_het_han · sap_vao · bao_tri · trong
  final String trangThai;
  final String? ghiChu;

  factory ThePhongCN.fromMap(Map<String, dynamic> m) => ThePhongCN(
    id: _nguyen(m['id']),
    ten: _chu(m['ten']),
    tang: _chu(m['tang']),
    dienTich: _so(m['dien_tich']),
    loaiThue: _chu(m['loai_thue']),
    gia: _so(m['gia']) ?? 0,
    donVi: _chu(m['don_vi']),
    anh: _chuNull(m['anh']),
    trangThai: _chu(m['trang_thai']),
    ghiChu: _chuNull(m['ghi_chu']),
    khach: _chuNull(m['khach']),
    hdLap: _chuNull(m['hd_lap']),
    hdHetHan: _chuNull(m['hd_het_han']),
    hdConNgay: m['hd_con_ngay'] == null ? null : _nguyen(m['hd_con_ngay']),
    thuTienNgay: _chuNull(m['thu_tien_ngay']),
    thuTienConNgay: m['thu_tien_con_ngay'] == null ? null : _nguyen(m['thu_tien_con_ngay']),
    traPhongLuc: _chuNull(m['tra_phong_luc']),
    traPhongConGio: m['tra_phong_con_gio'] == null ? null : _nguyen(m['tra_phong_con_gio']),
    thieuGiayTo: [for (final x in (m['thieu_giay_to'] as List? ?? const [])) '$x'],
  );
}

/// Một tầng của toà: tên + số phòng / đang thuê / trống.
class TangCN {
  const TangCN({required this.ten, required this.so, this.dangThue = 0, this.trong = 0});

  final String ten;
  final int so;
  final int dangThue;
  final int trong;

  /// "1" → "Tầng 1"; "Trệt" giữ nguyên.
  String get nhan => ten == 'Khác'
      ? 'Chưa xếp tầng'
      : (RegExp(r'^\d+$').hasMatch(ten) ? 'Tầng $ten' : ten);

  factory TangCN.fromMap(Map<String, dynamic> m) => TangCN(
    ten: _chu(m['ten']),
    so: _nguyen(m['so']),
    dangThue: _nguyen(m['dang_thue']),
    trong: _nguyen(m['trong']),
  );
}

class PhongCuaToaCN {
  const PhongCuaToaCN({
    required this.toaId,
    required this.tenToa,
    required this.tang,
    required this.phong,
    this.tangMoi = '1',
  });

  final int toaId;
  final String tenToa;
  final List<TangCN> tang;
  final List<ThePhongCN> phong;

  /// Tầng kế tiếp cho nút "Thêm tầng mới".
  final String tangMoi;

  factory PhongCuaToaCN.fromMap(Map<String, dynamic> m) {
    final t = _m(m['toa']) ?? const {};
    return PhongCuaToaCN(
      toaId: _nguyen(t['id']),
      tenToa: _chu(t['ten']),
      tang: [for (final x in _ds(m['tang'])) TangCN.fromMap(x)],
      phong: [for (final x in _ds(m['phong'])) ThePhongCN.fromMap(x)],
      tangMoi: _chuNull(m['tang_moi']) ?? '1',
    );
  }
}

// ── màn 12, 13 ──────────────────────────────────────────────────────────────

class PhongVaoCN {
  const PhongVaoCN({
    required this.ten,
    required this.tang,
    required this.dienTich,
    required this.gia,
    required this.loaiThue,
    required this.anh,
  });

  final String ten;
  final String? tang;
  final double? dienTich;
  final double gia;
  final String loaiThue;
  final List<String> anh;

  Map<String, dynamic> toMap() => {
    'ten': ten,
    'tang': tang,
    'dien_tich': dienTich,
    'gia': gia,
    'loai_thue': loaiThue,
    'anh': anh,
  };
}

class FormPhongCN {
  const FormPhongCN({required this.tenToa, required this.tang, required this.phong});

  final String tenToa;
  final List<String> tang;
  final PhongVaoCN? phong;

  factory FormPhongCN.fromMap(Map<String, dynamic> m) {
    final p = _m(m['phong']);
    return FormPhongCN(
      tenToa: _chu((_m(m['toa']) ?? const {})['ten']),
      tang: [for (final x in (m['tang'] as List? ?? const [])) x.toString()],
      phong: p == null
          ? null
          : PhongVaoCN(
              ten: _chu(p['ten']),
              tang: _chuNull(p['tang']),
              dienTich: _so(p['dien_tich']),
              gia: _so(p['gia']) ?? 0,
              loaiThue: _chu(p['loai_thue']),
              anh: [for (final x in (p['anh'] as List? ?? const [])) x.toString()],
            ),
    );
  }
}

class DongNhapCN {
  const DongNhapCN({required this.dong, required this.ten, required this.loi});

  final int dong;
  final String ten;
  final List<String> loi;

  factory DongNhapCN.fromMap(Map<String, dynamic> m) => DongNhapCN(
    dong: _nguyen(m['dong']),
    ten: _chu(m['ten']),
    loi: [for (final x in (m['loi'] as List? ?? const [])) x.toString()],
  );
}

class KetQuaNhapCN {
  const KetQuaNhapCN({
    required this.tong,
    required this.hopLe,
    required this.soLoi,
    required this.daNhap,
    required this.dong,
  });

  final int tong;
  final int hopLe;
  final int soLoi;
  final int daNhap;
  final List<DongNhapCN> dong;

  factory KetQuaNhapCN.fromMap(Map<String, dynamic> m) => KetQuaNhapCN(
    tong: _nguyen(m['tong']),
    hopLe: _nguyen(m['hop_le']),
    soLoi: _nguyen(m['so_loi']),
    daNhap: _nguyen(m['da_nhap']),
    dong: [for (final x in _ds(m['dong'])) DongNhapCN.fromMap(x)],
  );
}

// ── màn 4, 5 ────────────────────────────────────────────────────────────────

class NguoiCN {
  const NguoiCN({required this.ten, this.sdt, this.vai});

  final String ten;
  final String? sdt;
  final String? vai;

  static NguoiCN? tu(Object? v) {
    final m = _m(v);
    if (m == null) return null;
    return NguoiCN(ten: _chu(m['ten']), sdt: _chuNull(m['sdt']), vai: _chuNull(m['vai']));
  }
}

class DichVuCN {
  const DichVuCN({
    required this.ma,
    required this.ten,
    required this.gia,
    required this.donVi,
    required this.apDung,
    required this.xoaDuoc,
    this.cachTinh = 'don_gia',
    this.doiCachTinh = false,
  });

  /// 'don_gia' | 'theo_nguoi'.
  final String cachTinh;

  /// Đổi được cách tính (điện / phí phòng thì không).
  final bool doiCachTinh;

  bool get theoNguoi => cachTinh == 'theo_nguoi';

  final String ma;
  final String ten;
  final double gia;
  final String donVi;
  final bool apDung;
  final bool xoaDuoc;

  factory DichVuCN.fromMap(Map<String, dynamic> m) => DichVuCN(
    ma: _chu(m['ma']),
    ten: _chu(m['ten']),
    gia: _so(m['gia']) ?? 0,
    donVi: _chu(m['don_vi']),
    apDung: m['ap_dung'] == true,
    xoaDuoc: m['xoa_duoc'] == true,
    cachTinh: _chuNull(m['cach_tinh']) ?? 'don_gia',
    doiCachTinh: m['doi_cach_tinh'] == true,
  );
}

class PhongCN {
  const PhongCN({
    required this.id,
    required this.ten,
    required this.toaId,
    required this.tenToa,
    required this.anh,
    required this.trangThai,
    required this.tang,
    required this.dienTich,
    required this.loaiThue,
    required this.gia,
    required this.donVi,
    required this.thuTienNgay,
    required this.khach,
    required this.daiDien,
    required this.hdBatDau,
    required this.hdKetThuc,
    required this.conThang,
    required this.cocDaThu,
    required this.dichVu,
  });

  final int id;
  final String ten;
  final int toaId;
  final String tenToa;
  final List<String> anh;
  final String trangThai;
  final String tang;
  final double? dienTich;
  final String loaiThue;
  final double gia;
  final String donVi;
  final String? thuTienNgay;
  final NguoiCN? khach;
  final NguoiCN? daiDien;
  final String? hdBatDau;
  final String? hdKetThuc;
  final int? conThang;
  final double? cocDaThu;
  final List<DichVuCN> dichVu;

  bool get coHopDong => hdBatDau != null;

  factory PhongCN.fromMap(Map<String, dynamic> m) {
    final hd = _m(m['hop_dong']);
    return PhongCN(
      id: _nguyen(m['id']),
      ten: _chu(m['ten']),
      toaId: _nguyen(m['building_id']),
      tenToa: _chu(m['ten_toa']),
      anh: [for (final x in (m['anh'] as List? ?? const [])) x.toString()],
      trangThai: _chu(m['trang_thai']),
      tang: _chu(m['tang']),
      dienTich: _so(m['dien_tich']),
      loaiThue: _chu(m['loai_thue']),
      gia: _so(m['gia']) ?? 0,
      donVi: _chu(m['don_vi']),
      thuTienNgay: _chuNull(m['thu_tien_ngay']),
      khach: NguoiCN.tu(m['khach']),
      daiDien: NguoiCN.tu(m['dai_dien']),
      hdBatDau: hd == null ? null : _chuNull(hd['bat_dau']),
      hdKetThuc: hd == null ? null : _chuNull(hd['ket_thuc']),
      conThang: hd == null || hd['con_thang'] == null ? null : _nguyen(hd['con_thang']),
      cocDaThu: hd == null ? null : _so(hd['coc_da_thu']),
      dichVu: [for (final x in _ds(m['dich_vu'])) DichVuCN.fromMap(x)],
    );
  }
}

class HopDongCN {
  const HopDongCN({
    this.id = 0,
    this.giayToThieu = const [],
    required this.tenPhong,
    required this.so,
    required this.trangThai,
    required this.batDau,
    required this.ketThuc,
    required this.ngayLap,
    required this.duKienRoiDi,
    required this.chuKy,
    required this.hinhThuc,
    required this.giaThue,
    required this.tienCoc,
    required this.cocDaThu,
    required this.conThang,
    required this.khach,
    required this.daiDien,
    required this.ghiChu,
    required this.giaHanDuoc,
  });

  /// id hợp đồng — khối Giấy tờ (`/api/hop-dong/{id}/giay-to`).
  final int id;

  /// Loại giấy tờ còn thiếu: 'hop_dong' · 'minh_chung_coc'.
  final List<String> giayToThieu;
  final String tenPhong;
  final String so;

  /// dang_hieu_luc · het_han · da_cham_dut
  final String trangThai;
  final String batDau;
  final String ketThuc;
  final String? ngayLap;
  final String? duKienRoiDi;
  final String chuKy;
  final String? hinhThuc;
  final double giaThue;
  final double tienCoc;
  final double? cocDaThu;
  final int? conThang;
  final NguoiCN? khach;
  final NguoiCN? daiDien;
  final String? ghiChu;
  final bool giaHanDuoc;

  /// `null` = phòng chưa từng có hợp đồng.
  static HopDongCN? tuGoi(Map<String, dynamic> goi) {
    final m = _m(goi['hop_dong']);
    if (m == null) return null;
    return HopDongCN(
      id: _nguyen(m['id']),
      giayToThieu: [for (final x in (m['giay_to_thieu'] as List? ?? const [])) '$x'],
      tenPhong: _chu(goi['ten_phong']),
      so: _chu(m['so']),
      trangThai: _chu(m['trang_thai']),
      batDau: _chu(m['bat_dau']),
      ketThuc: _chu(m['ket_thuc']),
      ngayLap: _chuNull(m['ngay_lap']),
      duKienRoiDi: _chuNull(m['du_kien_roi_di']),
      chuKy: _chu(m['chu_ky']),
      hinhThuc: _chuNull(m['hinh_thuc']),
      giaThue: _so(m['gia_thue']) ?? 0,
      tienCoc: _so(m['tien_coc']) ?? 0,
      cocDaThu: _so(m['coc_da_thu']),
      conThang: m['con_thang'] == null ? null : _nguyen(m['con_thang']),
      khach: NguoiCN.tu(m['khach']),
      daiDien: NguoiCN.tu(m['dai_dien']),
      ghiChu: _chuNull(m['ghi_chu']),
      giaHanDuoc: m['gia_han_duoc'] == true,
    );
  }
}

// ── màn 6 ───────────────────────────────────────────────────────────────────

class ChiSoCN {
  const ChiSoCN({required this.cu, required this.moi, required this.tieuThu});

  final double? cu;
  final double? moi;
  final double? tieuThu;

  factory ChiSoCN.fromMap(Map<String, dynamic>? m) => ChiSoCN(
    cu: _so(m?['cu']),
    moi: _so(m?['moi']),
    tieuThu: _so(m?['tieu_thu']),
  );
}

class ThangDienNuocCN {
  const ThangDienNuocCN({
    required this.thang,
    required this.dienDung,
    required this.nuocDung,
    required this.thanhTien,
    required this.trangThai,
    this.anhDien,
    this.anhNuoc,
    this.nguoiGhi,
    this.readingId,
  });

  final int? readingId;
  final String thang;
  final double? dienDung;
  final double? nuocDung;
  final double? thanhTien;
  final String trangThai;
  final String? anhDien;
  final String? anhNuoc;

  /// 'khach' | 'chu_nha' | null — ai đưa ra số của kỳ.
  final String? nguoiGhi;

  factory ThangDienNuocCN.fromMap(Map<String, dynamic> m) => ThangDienNuocCN(
    thang: _chu(m['thang']),
    dienDung: _so(m['dien_dung']),
    nuocDung: _so(m['nuoc_dung']),
    thanhTien: _so(m['thanh_tien']),
    trangThai: _chu(m['trang_thai']),
    anhDien: _chuNull(m['anh_dien']),
    anhNuoc: _chuNull(m['anh_nuoc']),
    nguoiGhi: _chuNull(m['nguoi_ghi']),
    readingId: (m['reading_id'] as num?)?.toInt(),
  );

  /// Kỳ khách gửi còn chờ — kể cả tháng TRƯỚC (vd gửi cuối tháng, chủ nhà
  /// chưa kịp xem) — vẫn phải duyệt được, không thì treo mãi.
  bool get khachChoDuyet =>
      nguoiGhi == 'khach' && (trangThai == 'cho_duyet' || trangThai == 'thieu_anh');
}

class DienNuocCN {
  const DienNuocCN({
    required this.tenPhong,
    required this.thang,
    required this.giaDien,
    required this.giaNuoc,
    required this.trangThai,
    required this.dien,
    required this.nuoc,
    required this.lichSu,
    this.nuocTheoNguoi = false,
    this.soNguoi = 0,
    this.readingId,
    this.anhDien,
    this.anhNuoc,
    this.nguoiGhi,
    this.tenNguoiGui = '',
    this.lyDoTraVe,
  });

  /// Dòng chỉ số tháng này (null = chưa ai gửi) — để Duyệt / Yêu cầu chụp lại.
  final int? readingId;
  final String? anhDien;
  final String? anhNuoc;

  /// 'khach' | 'chu_nha' | null — ai đưa ra số tháng này.
  final String? nguoiGhi;
  final String tenNguoiGui;
  final String? lyDoTraVe;

  /// Khách đã gửi và đang chờ chủ nhà xem.
  bool get khachChoDuyet =>
      nguoiGhi == 'khach' && (trangThai == 'cho_duyet' || trangThai == 'thieu_anh');

  /// Nước tính theo người — không có công tơ nước để ghi.
  final bool nuocTheoNguoi;
  final int soNguoi;

  final String tenPhong;
  final String thang;
  final double giaDien;
  final double giaNuoc;
  final String trangThai;
  final ChiSoCN dien;
  final ChiSoCN nuoc;
  final List<ThangDienNuocCN> lichSu;

  factory DienNuocCN.fromMap(Map<String, dynamic> m) => DienNuocCN(
    tenPhong: _chu(m['ten_phong']),
    thang: _chu(m['thang']),
    giaDien: _so(m['gia_dien']) ?? 0,
    giaNuoc: _so(m['gia_nuoc']) ?? 0,
    trangThai: _chu(m['trang_thai']),
    dien: ChiSoCN.fromMap(_m(m['dien'])),
    nuoc: ChiSoCN.fromMap(_m(m['nuoc'])),
    lichSu: [for (final x in _ds(m['lich_su'])) ThangDienNuocCN.fromMap(x)],
    nuocTheoNguoi: m['nuoc_theo_nguoi'] == true,
    soNguoi: _nguyen(m['so_nguoi']),
    readingId: (m['reading_id'] as num?)?.toInt(),
    anhDien: _chuNull(m['anh_dien']),
    anhNuoc: _chuNull(m['anh_nuoc']),
    nguoiGhi: _chuNull(m['nguoi_ghi']),
    tenNguoiGui: _chu(m['ten_nguoi_gui']),
    lyDoTraVe: _chuNull(m['ly_do_tra_ve']),
  );
}

// ── màn 7, 8, 9 + tab Thu chi ───────────────────────────────────────────────

class KhoanThuCN {
  const KhoanThuCN({
    required this.invoiceId,
    required this.ky,
    required this.han,
    required this.tong,
    required this.daTra,
    required this.trangThai,
    this.roomId,
    this.tenPhong,
    this.tenToa,
    this.khach,
  });

  final int? invoiceId;
  final String ky;
  final String? han;
  final double tong;
  final double daTra;

  /// chua_thu · thu_mot_phan · da_thu
  final String trangThai;
  final int? roomId;
  final String? tenPhong;
  final String? tenToa;
  final String? khach;

  factory KhoanThuCN.fromMap(Map<String, dynamic> m) => KhoanThuCN(
    invoiceId: m['invoice_id'] == null ? null : _nguyen(m['invoice_id']),
    ky: _chu(m['ky']),
    han: _chuNull(m['han']),
    tong: _so(m['tong']) ?? 0,
    daTra: _so(m['da_tra']) ?? 0,
    trangThai: _chu(m['trang_thai']),
    roomId: m['room_id'] == null ? null : _nguyen(m['room_id']),
    tenPhong: _chuNull(m['ten_phong']),
    tenToa: _chuNull(m['ten_toa']),
    khach: _chuNull(m['khach']),
  );
}

class ChiPhiCN {
  const ChiPhiCN({required this.ngay, required this.tieuDe, required this.soTien, this.tenPhong});

  final String ngay;
  final String tieuDe;
  final double soTien;
  final String? tenPhong;

  factory ChiPhiCN.fromMap(Map<String, dynamic> m) => ChiPhiCN(
    ngay: _chu(m['ngay']),
    tieuDe: _chu(m['tieu_de']),
    soTien: _so(m['so_tien']) ?? 0,
    tenPhong: _chuNull(m['ten_phong']),
  );
}

class ThuChiPhongCN {
  const ThuChiPhongCN({
    required this.tenPhong,
    required this.coHopDong,
    required this.daThu,
    required this.conPhaiThu,
    required this.lichThu,
    required this.chiPhi,
    required this.tongChi,
  });

  final String tenPhong;
  final bool coHopDong;
  final double daThu;
  final double conPhaiThu;
  final List<KhoanThuCN> lichThu;
  final List<ChiPhiCN> chiPhi;
  final double tongChi;

  factory ThuChiPhongCN.fromMap(Map<String, dynamic> m) => ThuChiPhongCN(
    tenPhong: _chu(m['ten_phong']),
    coHopDong: m['co_hop_dong'] == true,
    daThu: _so(m['da_thu']) ?? 0,
    conPhaiThu: _so(m['con_phai_thu']) ?? 0,
    lichThu: [for (final x in _ds(m['lich_thu'])) KhoanThuCN.fromMap(x)],
    chiPhi: [for (final x in _ds(m['chi_phi'])) ChiPhiCN.fromMap(x)],
    tongChi: _so(m['tong_chi']) ?? 0,
  );
}

class ThuChiTongCN {
  const ThuChiTongCN({
    required this.thang,
    required this.kyChon,
    required this.daThu,
    required this.conPhaiThu,
    required this.tongChi,
    required this.thu,
    required this.chiPhi,
  });

  final String thang;
  final List<String> kyChon;
  final double daThu;
  final double conPhaiThu;
  final double tongChi;
  final List<KhoanThuCN> thu;
  final List<ChiPhiCN> chiPhi;

  factory ThuChiTongCN.fromMap(Map<String, dynamic> m) => ThuChiTongCN(
    thang: _chu(m['thang']),
    kyChon: [for (final x in (m['ky_chon'] as List? ?? const [])) x.toString()],
    daThu: _so(m['da_thu']) ?? 0,
    conPhaiThu: _so(m['con_phai_thu']) ?? 0,
    tongChi: _so(m['tong_chi']) ?? 0,
    thu: [for (final x in _ds(m['thu'])) KhoanThuCN.fromMap(x)],
    chiPhi: [for (final x in _ds(m['chi_phi'])) ChiPhiCN.fromMap(x)],
  );
}

class DongTienCN {
  const DongTienCN({required this.loai, required this.ten, required this.soTien});

  final String loai;
  final String ten;
  final double soTien;

  factory DongTienCN.fromMap(Map<String, dynamic> m) => DongTienCN(
    loai: _chu(m['loai']),
    ten: _chu(m['ten']),
    soTien: _so(m['so_tien']) ?? 0,
  );
}

class KyThuCN {
  const KyThuCN({
    required this.tenPhong,
    required this.thang,
    required this.kyChon,
    required this.invoiceId,
    required this.trangThai,
    required this.han,
    required this.dong,
    required this.tong,
    required this.daTra,
    required this.conLai,
  });

  final String tenPhong;
  final String thang;
  final List<String> kyChon;
  final int? invoiceId;

  /// chua_lap · nhap · chua_thu · thu_mot_phan · da_thu
  final String trangThai;
  final String? han;
  final List<DongTienCN> dong;
  final double tong;
  final double daTra;
  final double conLai;

  bool get daCoHoaDon => trangThai != 'chua_lap' && trangThai != 'nhap';

  factory KyThuCN.fromMap(Map<String, dynamic> m) => KyThuCN(
    tenPhong: _chu(m['ten_phong']),
    thang: _chu(m['thang']),
    kyChon: [for (final x in (m['ky_chon'] as List? ?? const [])) x.toString()],
    invoiceId: m['invoice_id'] == null ? null : _nguyen(m['invoice_id']),
    trangThai: _chu(m['trang_thai']),
    han: _chuNull(m['han']),
    dong: [for (final x in _ds(m['dong'])) DongTienCN.fromMap(x)],
    tong: _so(m['tong']) ?? 0,
    daTra: _so(m['da_tra']) ?? 0,
    conLai: _so(m['con_lai']) ?? 0,
  );
}

// ── màn 10, 11 ──────────────────────────────────────────────────────────────

class DichVuPhongCN {
  const DichVuPhongCN({
    required this.tenPhong,
    required this.coHopDong,
    required this.dichVu,
    this.soNguoi = 0,
    this.soNguoiTuKhai = false,
  });

  final String tenPhong;
  final bool coHopDong;
  final List<DichVuCN> dichVu;

  /// Số người ở — nhân với khoản tính theo người.
  final int soNguoi;
  final bool soNguoiTuKhai;

  factory DichVuPhongCN.fromMap(Map<String, dynamic> m) => DichVuPhongCN(
    tenPhong: _chu(m['ten_phong']),
    coHopDong: m['co_hop_dong'] == true,
    soNguoi: _nguyen(m['so_nguoi']),
    soNguoiTuKhai: m['so_nguoi_tu_khai'] == true,
    dichVu: [for (final x in _ds(m['dich_vu'])) DichVuCN.fromMap(x)],
  );
}

class SuKienCN {
  const SuKienCN({
    required this.luc,
    required this.loai,
    required this.tieuDe,
    required this.moTa,
    required this.soTien,
  });

  final String? luc;
  final String loai;
  final String tieuDe;
  final String moTa;
  final double? soTien;

  factory SuKienCN.fromMap(Map<String, dynamic> m) => SuKienCN(
    luc: _chuNull(m['luc']),
    loai: _chu(m['loai']),
    tieuDe: _chu(m['tieu_de']),
    moTa: _chu(m['mo_ta']),
    soTien: _so(m['so_tien']),
  );
}

class LichSuPhongCN {
  const LichSuPhongCN({
    required this.tenPhong,
    required this.bienDong,
    required this.hopDong,
    required this.hoaDon,
    required this.dienNuoc,
  });

  final String tenPhong;
  final List<SuKienCN> bienDong;
  final List<SuKienCN> hopDong;
  final List<SuKienCN> hoaDon;
  final List<SuKienCN> dienNuoc;

  factory LichSuPhongCN.fromMap(Map<String, dynamic> m) {
    List<SuKienCN> d(String k) => [for (final x in _ds(m[k])) SuKienCN.fromMap(x)];
    return LichSuPhongCN(
      tenPhong: _chu(m['ten_phong']),
      bienDong: d('bien_dong'),
      hopDong: d('hop_dong'),
      hoaDon: d('hoa_don'),
      dienNuoc: d('dien_nuoc'),
    );
  }
}
