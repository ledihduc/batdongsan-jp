import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:house_booking/data/services/so_chu_nha_api.dart';
import 'package:house_booking/features/host/so_chu_nha/tai_khoan_nhan_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/dich_vu_phong_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/dien_nuoc_phong_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/hop_dong_phong_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/lich_su_phong_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/nhap_phong_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/phong_theo_tang_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/setup_tang_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/sua_phong_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/tao_hoa_don_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/thong_tin_phong_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/thu_chi_phong_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/thu_chi_tong_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/thu_tien_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/toa_nha_cua_toi_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/trang_chu_chu_nha_screen.dart';

import '../../../helpers/pump_app.dart';

/// Sổ chủ nhà theo mockup 06/10/2026 — 14 màn dựng mới.
/// Số liệu giả lấy đúng ví dụ trong mockup để đối chiếu bằng mắt (golden).
class _Gia extends SoChuNhaApi {
  final kenh = <String>[];
  final thu = <(String, String)>[];
  final hoaDon = <String>[];
  final chiSo = <(double, double)>[];
  final giaHanThang = <int>[];
  final phongMoi = <PhongVaoCN>[];
  final dvMoi = <(String, double)>[];
  final cachTinhMoi = <String>[];
  final soNguoiGoi = <int?>[];
  final suaGoi = <(String, double?, String?)>[];
  final nhap = <bool>[];
  var nhapLoi = true;

  static Map<String, dynamic> _ky(String trangThai) => {
    'ten_phong': 'Phòng 201',
    'thang': '2026-10',
    'ky_chon': ['2026-10', '2026-09'],
    'invoice_id': trangThai == 'chua_lap' ? null : 5,
    'trang_thai': trangThai,
    'han': '2026-10-05',
    'dong': [
      {'loai': 'rent', 'ten': 'Tiền phòng', 'so_tien': 4500000},
      {'loai': 'electricity', 'ten': 'Điện (60 kWh)', 'so_tien': 210000},
      {'loai': 'water', 'ten': 'Nước (8 m³)', 'so_tien': 200000},
      {'loai': 'service', 'ten': 'Internet', 'so_tien': 100000},
      {'loai': 'service', 'ten': 'Vệ sinh', 'so_tien': 50000},
      {'loai': 'service', 'ten': 'Gửi xe', 'so_tien': 100000},
    ],
    'tong': 5160000,
    'da_tra': trangThai == 'da_thu' ? 5160000 : 0,
    'con_lai': trangThai == 'da_thu' ? 0 : 5160000,
  };

  @override
  Future<TrangChuCN> trangChu(String k) async {
    kenh.add(k);
    if (k == 'ngan_han') {
      return TrangChuCN.fromMap({
        'kenh': k, 'ten': 'Nguyễn Văn An', 'thang': 10,
        'doanh_thu': {'tien': 32500000, 'tang': 8.5},
        'so': {'toa_nha': 2, 'phong': 18, 'dang_cho_thue': 12},
        'hom_nay': {'da_dat': 5, 'dang_o': 9, 'sap_tra': 3},
        'viec': [
          {'loai': 'cho_xac_nhan', 'so': 2, 'tieu_de': '2 đơn chờ xác nhận', 'phu': 'Khách đang chờ phản hồi'},
        ],
      });
    }
    return TrangChuCN.fromMap({
      'kenh': k, 'ten': 'Nguyễn Văn An', 'thang': 10,
      'doanh_thu': {'tien': 125600000, 'tang': 12},
      'so': {
        'toa_nha': 3, 'phong': 45, 'dang_thue': 38,
        'sap_thu_tien': 5, 'sap_het_han': 2, 'phong_trong': 7,
      },
      'viec': [
        {'loai': 'sap_thu', 'so': 5, 'tieu_de': '5 phòng sắp thu tiền', 'phu': 'Trong 5 ngày tới'},
        {'loai': 'sap_het_han', 'so': 2, 'tieu_de': '2 hợp đồng sắp hết hạn', 'phu': 'Trong 30 ngày tới'},
        {'loai': 'trong_lau', 'so': 3, 'tieu_de': '3 phòng trống lâu', 'phu': 'Hơn 15 ngày'},
      ],
    });
  }

  @override
  Future<List<ToaCN>> toaNha() async => [
    ToaCN.fromMap({'id': 1, 'ten': 'Sunrise Tower', 'dia_chi': '12 Lê Lợi, Ngô Quyền, Hải Phòng', 'so_phong': 28, 'so_tang': 6, 'dang_thue': 24}),
    ToaCN.fromMap({'id': 2, 'ten': 'Green House', 'dia_chi': '45 Văn Cao, Hải Phòng', 'so_phong': 12, 'dang_thue': 10}),
  ];

  @override
  Future<PhongCuaToaCN> phongCuaToa(int toaId) async => PhongCuaToaCN.fromMap({
    'toa': {'id': toaId, 'ten': 'Sunrise Tower'},
    'tang': [{'ten': '1', 'so': 2, 'dang_thue': 2, 'trong': 0}, {'ten': '2', 'so': 1, 'dang_thue': 1, 'trong': 0}, {'ten': 'Khác', 'so': 1, 'dang_thue': 1, 'trong': 0}],
    'tang_moi': '3',
    'phong': [
      {'id': 101, 'ten': 'Phòng 101', 'tang': '1', 'dien_tich': 25, 'loai_thue': 'dai_han', 'gia': 4500000, 'don_vi': 'thang', 'trang_thai': 'dang_thue',
       'khach': 'Nguyễn Văn Nam', 'hd_lap': '2025-09-28', 'hd_het_han': '2026-09-30', 'hd_con_ngay': 120,
       'thu_tien_ngay': '2026-10-05', 'thu_tien_con_ngay': 12},
      {'id': 102, 'ten': 'Phòng 102', 'tang': '1', 'dien_tich': 20, 'loai_thue': 'dai_han', 'gia': 3800000, 'don_vi': 'thang', 'trang_thai': 'sap_thu', 'ghi_chu': 'Thu tiền 05/10'},
      {'id': 301, 'ten': 'Phòng H01', 'tang': 'Khác', 'dien_tich': 20, 'loai_thue': 'ngan_han', 'gia': 320000, 'don_vi': 'dem', 'trang_thai': 'dang_thue',
       'khach': 'Lê Thu', 'tra_phong_luc': '2026-10-07T12:00:00', 'tra_phong_con_gio': 3},
      {'id': 201, 'ten': 'Phòng 201', 'tang': '2', 'dien_tich': 25, 'loai_thue': 'dai_han', 'gia': 4500000, 'don_vi': 'thang', 'trang_thai': 'sap_het_han', 'ghi_chu': 'Hết hạn 20/10'},
    ],
  });

  @override
  Future<PhongCN> phong(int id) async => PhongCN.fromMap({
    'id': id, 'ten': 'Phòng 201', 'building_id': 1, 'ten_toa': 'Sunrise Tower',
    'anh': <String>[], 'trang_thai': 'dang_thue', 'tang': '2', 'dien_tich': 25,
    'loai_thue': 'dai_han', 'gia': 4500000, 'don_vi': 'thang', 'thu_tien_ngay': '2026-10-05',
    'khach': {'ten': 'Nguyễn Văn Nam', 'sdt': '0912345678'},
    'dai_dien': {'ten': 'Trần Minh', 'vai': 'Sale'},
    'hop_dong': {'bat_dau': '2025-10-01', 'ket_thuc': '2026-09-30', 'con_thang': 12, 'coc_da_thu': 4500000},
    'dich_vu': [
      {'ma': 'dien', 'ten': 'Điện', 'gia': 3500, 'don_vi': 'kWh', 'ap_dung': true},
      {'ma': 'nuoc', 'ten': 'Nước', 'gia': 25000, 'don_vi': 'm³', 'ap_dung': true},
      {'ma': '7', 'ten': 'Internet', 'gia': 100000, 'don_vi': 'tháng', 'ap_dung': true},
    ],
  });

  HopDongCN? _hd(String ketThuc) => HopDongCN.tuGoi({
    'ten_phong': 'Phòng 201',
    'hop_dong': {
      'so': 'HD-2024-201', 'trang_thai': 'dang_hieu_luc', 'bat_dau': '2024-10-01',
      'ket_thuc': ketThuc, 'ngay_lap': '2024-09-28', 'du_kien_roi_di': ketThuc,
      'chu_ky': 'Hàng tháng (ngày 05)', 'gia_thue': 4500000, 'tien_coc': 4500000,
      'coc_da_thu': 4500000, 'con_thang': 12,
      'khach': {'ten': 'Nguyễn Văn Nam', 'sdt': '0912345678'},
      'dai_dien': {'ten': 'Trần Minh', 'vai': 'Sale'},
      'gia_han_duoc': true,
    },
  });

  @override
  Future<HopDongCN?> hopDong(int roomId) async => _hd('2025-09-30');

  @override
  Future<HopDongCN?> giaHan(int roomId, int soThang) async {
    giaHanThang.add(soThang);
    return _hd('2026-03-30');
  }

  /// Khách đã gửi chỉ số + ảnh tháng này, đang chờ chủ nhà.
  var khachGui = false;
  var lichSuCho = false;
  final anhLuu = <String?>[];
  final duyetGoi = <int>[];
  final traVeGoi = <(int, String)>[];

  DienNuocCN _dn({double? dien, double? nuoc, String? anhDien}) => DienNuocCN.fromMap({
    'ten_phong': 'Phòng 201', 'thang': '2026-10', 'gia_dien': 3500, 'gia_nuoc': 25000,
    'trang_thai': khachGui ? 'cho_duyet' : (dien == null ? 'chua_gui' : 'da_duyet'),
    if (khachGui) ...{
      'reading_id': 77, 'nguoi_ghi': 'khach', 'ten_nguoi_gui': 'Nguyễn Văn Nam',
      'anh_dien': 'https://x.test/dien.jpg', 'anh_nuoc': 'https://x.test/nuoc.jpg',
    } else if (dien != null) ...{
      'reading_id': 78, 'nguoi_ghi': 'chu_nha', 'anh_dien': ?anhDien,
    },
    'dien': {'cu': 1200, 'moi': dien, 'tieu_thu': dien == null ? null : dien - 1200},
    'nuoc': {'cu': 50, 'moi': nuoc, 'tieu_thu': nuoc == null ? null : nuoc - 50},
    'lich_su': [
      {'thang': '2026-09', 'dien_dung': 55, 'nuoc_dung': 7, 'thanh_tien': 367500,
       'trang_thai': lichSuCho ? 'cho_duyet' : 'da_duyet',
       if (lichSuCho) ...{'reading_id': 23, 'nguoi_ghi': 'khach', 'anh_dien': 'https://x.test/d.jpg'}},
      {'thang': '2026-08', 'dien_dung': 62, 'nuoc_dung': 8, 'thanh_tien': 417000, 'trang_thai': 'da_duyet'},
    ],
  });

  @override
  Future<DienNuocCN> dienNuoc(int roomId) async => _dn();

  @override
  Future<DienNuocCN> luuChiSo(
    int roomId, {
    required double dien,
    double nuoc = 0,
    String? anhDien,
    String? anhNuoc,
  }) async {
    chiSo.add((dien, nuoc));
    anhLuu.add(anhDien);
    khachGui = false;
    return _dn(dien: dien, nuoc: nuoc, anhDien: anhDien);
  }

  @override
  Future<void> duyetChiSo(int readingId) async {
    duyetGoi.add(readingId);
    khachGui = false;
  }

  @override
  Future<void> yeuCauChupLai(int readingId, String lyDo) async => traVeGoi.add((readingId, lyDo));

  /// Tài khoản nhận tiền: toà đã khai VCB, phòng chưa khai riêng.
  final tkLuu = <(String, int, String, String, String)>[];
  Map<String, dynamic>? tkPhongRieng;
  static const _tkToa = {
    'bin': '970436', 'ngan_hang': 'Vietcombank', 'so_tai_khoan': '0011001234567',
    'chu_tai_khoan': 'NGUYEN VAN AN', 'nguon': 'toa',
  };

  @override
  Future<TaiKhoanNhanCN> taiKhoanToa(int toaId) async =>
      TaiKhoanNhanCN.fromMap({'ten_toa': 'Sunrise', 'tai_khoan': null});

  @override
  Future<TaiKhoanNhanCN> suaTaiKhoanToa(int toaId, {String bin = '', String so = '', String chu = ''}) async {
    tkLuu.add(('toa', toaId, bin, so, chu));
    return TaiKhoanNhanCN.fromMap({'ten_toa': 'Sunrise', 'tai_khoan': {..._tkToa, 'so_tai_khoan': so}});
  }

  @override
  Future<TaiKhoanNhanCN> taiKhoanPhong(int roomId) async => TaiKhoanNhanCN.fromMap({
    'ten_phong': 'Phòng 201', 'rieng': tkPhongRieng, 'cua_toa': _tkToa, 'hieu_luc': tkPhongRieng ?? _tkToa,
  });

  @override
  Future<TaiKhoanNhanCN> suaTaiKhoanPhong(int roomId, {String bin = '', String so = '', String chu = ''}) async {
    tkLuu.add(('phong', roomId, bin, so, chu));
    tkPhongRieng = so.isEmpty ? null : {'bin': bin, 'ngan_hang': 'MBBank', 'so_tai_khoan': so, 'chu_tai_khoan': chu, 'nguon': 'phong'};
    return taiKhoanPhong(roomId);
  }

  @override
  Future<ThuChiPhongCN> thuChi(int roomId) async => ThuChiPhongCN.fromMap({
    'ten_phong': 'Phòng 201', 'co_hop_dong': true, 'da_thu': 9000000, 'con_phai_thu': 5160000,
    'lich_thu': [
      {'invoice_id': null, 'ky': '2026-10', 'han': '2026-10-05', 'tong': 5160000, 'da_tra': 0, 'trang_thai': 'chua_thu'},
      {'invoice_id': 4, 'ky': '2026-09', 'han': '2026-09-05', 'tong': 4500000, 'da_tra': 4500000, 'trang_thai': 'da_thu'},
      {'invoice_id': 3, 'ky': '2026-08', 'han': '2026-08-05', 'tong': 4500000, 'da_tra': 4500000, 'trang_thai': 'da_thu'},
    ],
    'chi_phi': [
      {'ngay': '2026-09-12', 'tieu_de': 'Sửa vòi nước', 'so_tien': 350000},
    ],
    'tong_chi': 350000,
  });

  @override
  Future<ThuChiTongCN> thuChiTong({String? thang}) async => ThuChiTongCN.fromMap({
    'thang': thang ?? '2026-10', 'ky_chon': ['2026-10', '2026-09'],
    'da_thu': 98500000, 'con_phai_thu': 27100000, 'tong_chi': 1250000,
    'thu': [
      {'room_id': 201, 'ten_phong': 'Phòng 201', 'ten_toa': 'Sunrise Tower', 'khach': 'Nguyễn Văn Nam', 'han': '2026-10-05', 'tong': 5160000, 'da_tra': 0, 'trang_thai': 'chua_thu'},
      {'room_id': 101, 'ten_phong': 'Phòng 101', 'ten_toa': 'Sunrise Tower', 'khach': 'Lê Thu', 'han': '2026-10-03', 'tong': 4800000, 'da_tra': 4800000, 'trang_thai': 'da_thu'},
    ],
    'chi_phi': [
      {'room_id': 201, 'ten_phong': 'Phòng 201', 'ngay': '2026-10-02', 'tieu_de': 'Thay bóng đèn', 'so_tien': 150000},
    ],
  });

  @override
  Future<KyThuCN> kyThu(int roomId, {String? thang}) async => KyThuCN.fromMap(_ky('chua_lap'));

  @override
  Future<KyThuCN> xacNhanThu(int roomId, String thang, String hinhThuc) async {
    thu.add((thang, hinhThuc));
    return KyThuCN.fromMap(_ky('da_thu'));
  }

  @override
  Future<KyThuCN> taoHoaDon(int roomId, String thang) async {
    hoaDon.add(thang);
    return KyThuCN.fromMap(_ky('chua_thu'));
  }

  int _soNguoi = 2;

  @override
  Future<DichVuPhongCN> datSoNguoi(int roomId, int? soNguoi) async {
    soNguoiGoi.add(soNguoi);
    _soNguoi = soNguoi ?? 1;
    return _dv();
  }

  @override
  Future<DichVuPhongCN> suaDichVu(int roomId, String ma, {double? gia, bool? apDung, String? cachTinh}) async {
    suaGoi.add((ma, gia, cachTinh));
    return _dv();
  }

  DichVuPhongCN _dv({bool them = false}) => DichVuPhongCN.fromMap({
    'ten_phong': 'Phòng 201', 'co_hop_dong': true, 'so_nguoi': _soNguoi,
    'dich_vu': [
      {'ma': 'dien', 'ten': 'Điện', 'gia': 3500, 'don_vi': 'kWh', 'ap_dung': true},
      {'ma': 'nuoc', 'ten': 'Nước', 'gia': 100000, 'don_vi': 'người/tháng', 'ap_dung': true, 'cach_tinh': 'theo_nguoi', 'doi_cach_tinh': true},
      {'ma': '7', 'ten': 'Internet', 'gia': 100000, 'don_vi': 'tháng', 'ap_dung': true, 'xoa_duoc': true},
      {'ma': '8', 'ten': 'Vệ sinh', 'gia': 50000, 'don_vi': 'tháng', 'ap_dung': true, 'xoa_duoc': true},
      {'ma': '9', 'ten': 'Gửi xe', 'gia': 100000, 'don_vi': 'tháng', 'ap_dung': true, 'xoa_duoc': true},
      if (them) {'ma': '10', 'ten': 'Giặt sấy', 'gia': 40000, 'don_vi': 'tháng', 'ap_dung': true, 'xoa_duoc': true},
    ],
  });

  @override
  Future<DichVuPhongCN> dichVu(int roomId) async => _dv();

  @override
  Future<DichVuPhongCN> themDichVu(int roomId, {required String ten, required double gia, String cachTinh = 'don_gia'}) async {
    dvMoi.add((ten, gia));
    cachTinhMoi.add(cachTinh);
    return _dv(them: true);
  }

  @override
  Future<LichSuPhongCN> lichSu(int roomId) async {
    final hd = {'luc': '2025-10-01', 'loai': 'hop_dong', 'tieu_de': 'Ký hợp đồng với Nguyễn Văn Nam', 'mo_ta': '01/10/2025 – 30/09/2026', 'so_tien': 4500000};
    final tt = {'luc': '2026-09-04T13:00:00', 'loai': 'thu_tien', 'tieu_de': 'Thu tiền tháng 09/2026', 'mo_ta': 'Chuyển khoản', 'so_tien': 4500000};
    final dn = {'luc': '2026-09-28', 'loai': 'dien_nuoc', 'tieu_de': 'Chốt chỉ số điện nước', 'mo_ta': 'Điện 1200 kWh · Nước 50 m³'};
    return LichSuPhongCN.fromMap({
      'ten_phong': 'Phòng 201',
      'bien_dong': [dn, tt, hd], 'hop_dong': [hd], 'hoa_don': [tt], 'dien_nuoc': [dn],
    });
  }

  final datTangGoi = <Map<int, String?>>[];

  @override
  Future<PhongCuaToaCN> datTang(int toaId, Map<int, String?> tangTheoPhong) async {
    datTangGoi.add(Map.of(tangTheoPhong));
    return phongCuaToa(toaId);
  }

  @override
  Future<FormPhongCN> formPhong(int toaId, {int? roomId}) async => FormPhongCN.fromMap({
    'toa': {'id': toaId, 'ten': 'Sunrise Tower'},
    'tang': ['1', '2', '3'],
    'phong': roomId == null
        ? null
        : {'ten': 'Phòng 201', 'tang': '2', 'dien_tich': 25, 'gia': 4500000, 'loai_thue': 'dai_han', 'anh': <String>[]},
  });

  @override
  Future<int> themPhong(int toaId, PhongVaoCN p) async {
    phongMoi.add(p);
    return 999;
  }

  @override
  Future<KetQuaNhapCN> nhapPhong(int toaId, List<int> bytes, String tenTep, {required bool ghi}) async {
    nhap.add(ghi);
    if (nhapLoi) {
      return KetQuaNhapCN.fromMap({
        'tong': 3, 'hop_le': 2, 'so_loi': 1, 'da_nhap': 0,
        'dong': [
          {'dong': 2, 'ten': '301', 'loi': <String>[]},
          {'dong': 3, 'ten': '302', 'loi': <String>[]},
          {'dong': 4, 'ten': '101', 'loi': ['Tòa đã có phòng này']},
        ],
      });
    }
    return KetQuaNhapCN.fromMap({
      'tong': 2, 'hop_le': 2, 'so_loi': 0, 'da_nhap': ghi ? 2 : 0,
      'dong': [
        {'dong': 2, 'ten': '301', 'loi': <String>[]},
        {'dong': 3, 'ten': '302', 'loi': <String>[]},
      ],
    });
  }
}

void main() {
  late _Gia api;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await GoogleFonts.pendingFonts([
      for (final w in [FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700])
        GoogleFonts.hankenGrotesk(fontWeight: w),
    ]);
    final icons = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  setUp(() => api = _Gia());

  Future<void> dung(WidgetTester t, Widget man, {Size co = const Size(390, 1100)}) async {
    t.view.physicalSize = co;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpApp(t, man);
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
  }

  Future<void> cho(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  testWidgets('màn 1 + 14: trang chủ dài hạn → ngắn hạn', (t) async {
    var moThuChi = 0;
    await dung(t, TrangChuChuNhaScreen(api: api, onMoThuChi: () => moThuChi++));
    expect(find.text('Xin chào, An 👋'), findsOneWidget);
    expect(find.text('Tổng quan dài hạn'), findsOneWidget);
    for (final s in ['Tòa nhà', 'Phòng', 'Đang thuê', 'Sắp thu tiền', 'Sắp hết hạn', 'Phòng trống', '45', '38', '7']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    expect(find.text('Doanh thu tháng 10'), findsOneWidget);
    expect(find.text('125.600.000đ'), findsOneWidget);
    expect(find.text('12%'), findsOneWidget);
    expect(find.text('5 phòng sắp thu tiền'), findsOneWidget);
    expect(find.text('Trong 30 ngày tới'), findsOneWidget);
    expect(find.text('3 phòng trống lâu'), findsOneWidget);
    await t.tap(find.byKey(const Key('cn-viec-sap_thu')));
    expect(moThuChi, 1);

    await t.tap(find.byKey(const Key('cn-ngan-han')));
    await cho(t);
    expect(api.kenh, ['dai_han', 'ngan_han']);
    expect(find.text('Tổng quan ngắn hạn'), findsOneWidget);
    expect(find.text('Đang cho thuê'), findsOneWidget);
    expect(find.text('Hôm nay'), findsOneWidget);
    for (final s in ['Đã đặt', 'Đang ở', 'Sắp trả']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.text('8.5%'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('ngắn hạn: ô Hôm nay và việc chờ duyệt mở hộp đơn đã lọc', (t) async {
    final mo = <String>[];
    await dung(
      t,
      TrangChuChuNhaScreen(
        api: api,
        moDonNganHan: (_, {required loc, required homNay}) async =>
            mo.add('$loc:$homNay'),
      ),
    );
    await t.tap(find.byKey(const Key('cn-ngan-han')));
    await cho(t);
    for (var i = 0; i < 3; i++) {
      await t.tap(find.byKey(Key('cn-hom-nay-$i')));
      await t.pump();
    }
    await t.ensureVisible(find.byKey(const Key('cn-viec-cho_xac_nhan')));
    await t.tap(find.byKey(const Key('cn-viec-cho_xac_nhan')));
    await t.pump();
    expect(mo, ['all:true', 'staying:false', 'staying:true', 'pending:false']);
  });

  testWidgets('màn 2 → 3: tòa nhà, chip tầng, nhãn trạng thái', (t) async {
    await dung(t, ToaNhaCuaToiScreen(api: api));
    expect(find.text('Tòa nhà của tôi'), findsOneWidget);
    expect(find.text('Sunrise Tower'), findsOneWidget);
    expect(find.text('28 phòng'), findsOneWidget);
    expect(find.text('24 đang thuê'), findsOneWidget);
    expect(find.text('6 tầng'), findsOneWidget);
    expect(find.byKey(const Key('cn-them-toa')), findsOneWidget);

    await t.tap(find.byKey(const Key('cn-toa-1')));
    await t.pumpAndSettle();
    expect(find.byType(PhongTheoTangScreen), findsOneWidget);
    expect(find.text('Tất cả (4)'), findsOneWidget);
    expect(find.text('Nguyễn Văn Nam'), findsOneWidget);
    expect(find.text('Lập HĐ'), findsOneWidget);
    expect(find.text('28/09/2025'), findsOneWidget);
    expect(find.text('còn 120 ngày'), findsOneWidget);
    expect(find.text('Trả tiền phòng'), findsOneWidget);
    expect(find.text('còn 12 ngày'), findsOneWidget);
    expect(find.text('1 phòng chưa xếp tầng'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Lê Thu'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('còn 3 giờ'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('cn-tang-1')), -200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Tầng 1 (2)'), findsOneWidget);
    expect(find.text('25 m² · Dài hạn'), findsNWidgets(2));
    expect(find.text('4.500.000đ/tháng'), findsNWidgets(2));
    expect(find.text('Sắp thu'), findsOneWidget);
    expect(find.text('Thu tiền 05/10'), findsOneWidget);
    expect(find.text('Hết hạn 20/10'), findsOneWidget);
    expect(find.text('6 tầng'), findsNothing);
    expect(find.byKey(const Key('cn-tang-1')), findsOneWidget);
    expect(find.byKey(const Key('cn-tang-2')), findsOneWidget);
    expect(find.text('2 phòng · 2 đang thuê', findRichText: true), findsOneWidget);
    await t.scrollUntilVisible(find.text('Thêm tầng mới (Tầng 3)'), 200, scrollable: find.byType(Scrollable).last);

    await t.scrollUntilVisible(find.byKey(const Key('cn-them-phong-tang-2')), -200, scrollable: find.byType(Scrollable).last);
    await t.tap(find.byKey(const Key('cn-them-phong-tang-2')));
    await t.pumpAndSettle();
    expect(find.byType(SuaPhongScreen), findsOneWidget);
    expect(find.text('Tầng 2'), findsWidgets);
    await t.tap(find.byKey(const Key('cn-lui')));
    await t.pumpAndSettle();

    await t.tap(find.text('Tầng 2 (1)'));
    await t.pump();
    expect(find.text('Phòng 101'), findsNothing);
    expect(find.text('Phòng 201'), findsOneWidget);
    expect(find.byKey(const Key('cn-tang-1')), findsNothing);
    expect(find.byKey(const Key('cn-them-tang')), findsNothing);
  });

  testWidgets('setup tầng: chọn phòng chưa xếp tầng → chuyển vào tầng mới', (t) async {
    await dung(t, SetupTangScreen(toaId: 1, api: api));
    await cho(t);
    expect(find.text('Chưa xếp tầng'), findsOneWidget);
    await t.tap(find.byKey(const Key('cn-chon-phong-301')));
    await t.pump();
    expect(find.text('Chuyển 1 phòng vào tầng…'), findsOneWidget);
    await t.tap(find.byKey(const Key('cn-chuyen-tang')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('cn-tang-moi')), 'Tầng 4');
    await t.tap(find.byKey(const Key('cn-tang-moi-luu')));
    await t.pumpAndSettle();
    expect(api.datTangGoi, [{301: '4'}]);

    await t.tap(find.byKey(const Key('cn-chon-ca-tang-1')));
    await t.pump();
    await t.tap(find.byKey(const Key('cn-chuyen-tang')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('cn-tang-dich-2')));
    await t.pumpAndSettle();
    expect(api.datTangGoi.last, {101: '2', 102: '2'});
  });

  testWidgets('màn 4: thông tin phòng + lối tắt sang hợp đồng', (t) async {
    await dung(t, ThongTinPhongScreen(roomId: 201, api: api));
    expect(find.text('Phòng 201'), findsOneWidget);
    expect(find.text('Đang thuê'), findsOneWidget);
    expect(find.text('Tầng 2 · 25 m² · Dài hạn'), findsOneWidget);
    expect(find.text('Thu tiền 05/10'), findsOneWidget);
    expect(find.text('Nguyễn Văn Nam'), findsOneWidget);
    expect(find.text('Trần Minh (Sale)'), findsOneWidget);
    expect(find.text('Còn 12 tháng'), findsOneWidget);
    expect(find.text('4.500.000đ'), findsOneWidget);
    expect(find.text('Dịch vụ đang áp dụng'), findsOneWidget);
    expect(find.text('3.500đ/kWh'), findsOneWidget);
    expect(find.text('Thu tiền'), findsOneWidget);
    expect(find.text('Tạo hóa đơn'), findsOneWidget);

    await t.tap(find.byKey(const Key('cn-loi-tat-Hợp đồng')));
    await t.pumpAndSettle();
    expect(find.byType(HopDongPhongScreen), findsOneWidget);
  });

  testWidgets('màn 5: hợp đồng + gia hạn 6 tháng', (t) async {
    await dung(t, HopDongPhongScreen(roomId: 201, api: api));
    await cho(t);
    expect(find.text('Hợp đồng – Phòng 201'), findsOneWidget);
    expect(find.text('Đang hiệu lực'), findsOneWidget);
    expect(find.text('HD-2024-201'), findsOneWidget);
    for (final s in ['Ngày lập HĐ', 'Ngày dự kiến rời đi', 'Chu kỳ thu tiền', 'Giá thuê', 'Cọc đã thu', 'Đại diện/Sale']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.text('Hàng tháng (ngày 05)'), findsOneWidget);
    await t.tap(find.byKey(const Key('cn-gia-han')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('cn-gia-han-6')));
    await t.pumpAndSettle();
    expect(api.giaHanThang, [6]);
    expect(find.text('30/03/2026'), findsWidgets);

    await t.tap(find.byKey(const Key('cn-xem-hop-dong')));
    await t.pumpAndSettle();
    expect(find.text('HỢP ĐỒNG THUÊ PHÒNG'), findsOneWidget);
  });

  testWidgets('màn 6: nhập chỉ số → tiêu thụ tự tính → lưu; tab lịch sử', (t) async {
    await dung(t, DienNuocPhongScreen(roomId: 201, api: api));
    await cho(t);
    expect(find.text('Điện nước – Phòng 201'), findsOneWidget);
    expect(find.text('Chỉ số tháng 10/2026'), findsOneWidget);
    await t.enterText(find.byKey(const Key('cn-dien-moi')), '1260');
    await t.enterText(find.byKey(const Key('cn-nuoc-moi')), '58');
    await t.pump();
    expect(find.text('60 kWh'), findsOneWidget);
    expect(find.text('8 m³'), findsOneWidget);
    await t.tap(find.byKey(const Key('cn-luu-chi-so')));
    await cho(t);
    expect(api.chiSo, [(1260.0, 58.0)]);
    expect(find.text('Đã chốt'), findsOneWidget);

    await t.tap(find.byKey(const Key('tab-1')));
    await t.pump();
    expect(find.text('Tháng 09/2026'), findsOneWidget);
    expect(find.text('Điện 55 kWh · Nước 7 m³'), findsOneWidget);
  });

  testWidgets('màn 6: khách đã gửi → chủ nhà thấy ảnh, duyệt tại chỗ', (t) async {
    api.khachGui = true;
    await dung(t, DienNuocPhongScreen(roomId: 201, api: api));
    await cho(t);
    expect(find.byKey(const Key('cn-dn-khach-gui')), findsOneWidget);
    expect(find.textContaining('Nguyễn Văn Nam đã gửi'), findsOneWidget);
    expect(find.text('Ảnh khách gửi'), findsWidgets);
    await t.tap(find.byKey(const Key('cn-dn-duyet')));
    await cho(t);
    expect(api.duyetGoi, [77]);
    expect(find.byKey(const Key('cn-dn-khach-gui')), findsNothing);
  });

  testWidgets('màn 6: kỳ THÁNG TRƯỚC khách gửi còn chờ vẫn duyệt được ở Lịch sử', (t) async {
    api.lichSuCho = true;
    await dung(t, DienNuocPhongScreen(roomId: 201, api: api));
    await cho(t);
    await t.tap(find.byKey(const Key('tab-1')));
    await t.pump();
    await t.tap(find.byKey(const Key('cn-dn-duyet-2026-09')));
    await cho(t);
    expect(api.duyetGoi, [23]);
  });

  testWidgets('màn 6: yêu cầu khách chụp lại kèm lý do', (t) async {
    api.khachGui = true;
    await dung(t, DienNuocPhongScreen(roomId: 201, api: api));
    await cho(t);
    await t.tap(find.byKey(const Key('cn-dn-chup-lai')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('cn-dn-ly-do-o')), 'Ảnh mờ');
    await t.tap(find.byKey(const Key('cn-dn-gui-ly-do')));
    await cho(t);
    expect(api.traVeGoi, [(77, 'Ảnh mờ')]);
  });

  testWidgets('màn 6: chủ nhà nhập số không ảnh vẫn lưu được (ảnh tuỳ chọn)', (t) async {
    await dung(t, DienNuocPhongScreen(roomId: 201, api: api));
    await cho(t);
    expect(find.text('Chụp ảnh công tơ'), findsWidgets);
    await t.enterText(find.byKey(const Key('cn-dien-moi')), '1260');
    await t.enterText(find.byKey(const Key('cn-nuoc-moi')), '58');
    await t.tap(find.byKey(const Key('cn-luu-chi-so')));
    await cho(t);
    expect(api.anhLuu, [null]);
  });

  testWidgets('tài khoản tòa: chọn ngân hàng, nhập số → thấy mã VietQR → lưu', (t) async {
    await dung(t, TaiKhoanNhanScreen.toa(toaId: 9, api: api));
    await cho(t);
    await t.tap(find.byKey(const Key('tk-ngan-hang')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('tk-tim-ngan-hang')), 'vietcom');
    await t.pump();
    await t.tap(find.byKey(const Key('tk-nh-970436')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('tk-so')), '0011001234567');
    await t.enterText(find.byKey(const Key('tk-chu')), 'Nguyễn Văn An');
    await t.pump();
    expect(find.byKey(const Key('tk-qr')), findsOneWidget);
    await t.tap(find.byKey(const Key('tk-luu')));
    await cho(t);
    expect(api.tkLuu, [('toa', 9, '970436', '0011001234567', 'Nguyễn Văn An')]);
  });

  testWidgets('tài khoản phòng: mặc định dùng của tòa; chuyển sang riêng rồi lưu', (t) async {
    await dung(t, TaiKhoanNhanScreen.phong(roomId: 201, api: api));
    await cho(t);
    expect(find.textContaining('Khách đang thấy tài khoản của tòa'), findsOneWidget);
    expect(find.byKey(const Key('tk-so')), findsNothing);
    await t.tap(find.byKey(const Key('tk-rieng')));
    await t.pump();
    await t.tap(find.byKey(const Key('tk-ngan-hang')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('tk-tim-ngan-hang')), 'mbbank');
    await t.pump();
    await t.tap(find.byKey(const Key('tk-nh-970422')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('tk-so')), '999888777');
    await t.enterText(find.byKey(const Key('tk-chu')), 'TRAN B');
    await t.tap(find.byKey(const Key('tk-luu')));
    await cho(t);
    expect(api.tkLuu.single.$3, '970422');
    expect(find.textContaining('Khách đang thấy tài khoản riêng của phòng'), findsOneWidget);
  });

  testWidgets('màn 7 → 8: thu chi phòng, thu tiền chuyển khoản', (t) async {
    await dung(t, ThuChiPhongScreen(roomId: 201, api: api));
    await cho(t);
    expect(find.text('Thu chi – Phòng 201'), findsOneWidget);
    expect(find.text('Đã thu'), findsWidgets);
    expect(find.text('Còn phải thu'), findsOneWidget);
    expect(find.text('Lịch thu tiền'), findsOneWidget);
    expect(find.text('Chưa thu'), findsOneWidget);
    expect(find.text('Tháng 09/2026'), findsOneWidget);
    await t.tap(find.byKey(const Key('tab-1')));
    await t.pump();
    expect(find.text('Sửa vòi nước'), findsOneWidget);

    await t.tap(find.byKey(const Key('cn-nut-thu-tien')));
    await t.pumpAndSettle();
    expect(find.byType(ThuTienScreen), findsOneWidget);
    for (final s in ['Kỳ thu', 'Tiền phòng', 'Điện (60 kWh)', 'Nước (8 m³)', 'Internet', 'Vệ sinh', 'Gửi xe', 'Tổng tiền', 'Hình thức thu']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.text('5.160.000đ'), findsOneWidget);
    await t.tap(find.byKey(const Key('cn-hinh-thuc-chuyen_khoan')));
    await t.pump();
    await t.tap(find.byKey(const Key('cn-xac-nhan-thu')));
    await cho(t);
    expect(api.thu, [('2026-10', 'chuyen_khoan')]);
    expect(find.text('Đã thu đủ'), findsOneWidget);
  });

  testWidgets('màn 9: tạo hóa đơn + xem trước', (t) async {
    await dung(t, TaoHoaDonScreen(roomId: 201, api: api));
    await cho(t);
    expect(find.text('Kỳ tháng'), findsOneWidget);
    expect(find.text('Tháng 10/2026'), findsOneWidget);
    await t.tap(find.byKey(const Key('cn-xem-truoc')));
    await t.pumpAndSettle();
    expect(find.text('HÓA ĐƠN TIỀN PHÒNG'), findsOneWidget);
    await t.tapAt(const Offset(195, 40));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('cn-tao-hoa-don')));
    await cho(t);
    expect(api.hoaDon, ['2026-10']);
    expect(find.text('Đã tạo'), findsOneWidget);
  });

  testWidgets('màn 10: dịch vụ phòng + thêm dịch vụ', (t) async {
    await dung(t, DichVuPhongScreen(roomId: 201, api: api));
    await cho(t);
    for (final s in ['Điện', 'Nước', 'Internet', 'Vệ sinh', 'Gửi xe']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.text('3.500đ/kWh'), findsOneWidget);
    expect(find.text('2 người'), findsOneWidget);
    expect(find.text('Theo người'), findsOneWidget);
    expect(find.text('100.000đ/người/tháng · × 2 = 200.000đ'), findsOneWidget);
    expect(find.text('Theo lượt'), findsNothing);

    await t.tap(find.byKey(const Key('cn-so-nguoi')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('cn-so-nguoi-cong')));
    await t.pump();
    await t.tap(find.byKey(const Key('cn-so-nguoi-luu')));
    await t.pumpAndSettle();
    expect(api.soNguoiGoi, [3]);
    expect(find.text('3 người'), findsOneWidget);

    await t.tap(find.byKey(const Key('cn-sua-dv-nuoc')));
    await t.pumpAndSettle();
    expect(find.text('Theo chỉ số'), findsOneWidget);
    await t.tap(find.byKey(const Key('cn-dv-don-gia')));
    await t.pump();
    expect(find.text('đ/m³'), findsOneWidget);
    await t.tap(find.byKey(const Key('cn-dv-luu')));
    await t.pumpAndSettle();
    expect(api.suaGoi.single.$3, 'don_gia');

    await t.tap(find.byKey(const Key('cn-them-dich-vu')));
    await t.pumpAndSettle();
    expect(find.text('Theo lượt'), findsNothing);
    await t.tap(find.byKey(const Key('cn-dv-moi-theo-nguoi')));
    await t.pump();
    await t.enterText(find.byKey(const Key('cn-dv-ten')), 'Giặt sấy');
    await t.enterText(find.byKey(const Key('cn-dv-gia-moi')), '40.000');
    await t.tap(find.byKey(const Key('cn-dv-them-luu')));
    await t.pumpAndSettle();
    expect(api.dvMoi, [('Giặt sấy', 40000.0)]);
    expect(api.cachTinhMoi, ['theo_nguoi']);
    expect(find.text('Giặt sấy'), findsOneWidget);
  });

  testWidgets('màn 11: lịch sử bốn tab', (t) async {
    await dung(t, LichSuPhongScreen(roomId: 201, api: api));
    await cho(t);
    for (final s in ['Biến động', 'Hợp đồng', 'Hóa đơn', 'Điện nước']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.text('Thu tiền tháng 09/2026'), findsOneWidget);
    expect(find.text('Ký hợp đồng với Nguyễn Văn Nam'), findsOneWidget);
    await t.tap(find.byKey(const Key('tab-1')));
    await t.pump();
    expect(find.text('Thu tiền tháng 09/2026'), findsNothing);
    expect(find.text('Ký hợp đồng với Nguyễn Văn Nam'), findsOneWidget);
  });

  testWidgets('màn 12: thêm phòng — tầng, loại thuê ngắn hạn', (t) async {
    await dung(t, SuaPhongScreen(toaId: 1, api: api));
    await cho(t);
    expect(find.text('Thêm phòng'), findsOneWidget);
    expect(find.text('Thêm ảnh'), findsOneWidget);
    await t.enterText(find.byKey(const Key('cn-ten-phong')), 'Phòng 301');
    await t.tap(find.byKey(const Key('cn-tang')));
    await t.pumpAndSettle();
    await t.tap(find.text('Tầng 3').last);
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('cn-dien-tich')), '25');
    await t.enterText(find.byKey(const Key('cn-gia-thue')), '450.000');
    await t.tap(find.byKey(const Key('cn-loai-ngan_han')));
    await t.pump();
    expect(find.text('đ/đêm'), findsOneWidget);
    await t.tap(find.byKey(const Key('cn-luu-phong')));
    await cho(t);
    final p = api.phongMoi.single;
    expect((p.ten, p.tang, p.dienTich, p.gia, p.loaiThue), ('Phòng 301', '3', 25.0, 450000.0, 'ngan_han'));
  });

  testWidgets('màn 13: import — lỗi thì chọn lại, hợp lệ thì nhập', (t) async {
    await dung(
      t,
      NhapPhongScreen(toaId: 1, tenToa: 'Sunrise Tower', api: api, chonTep: () async => ('phong.xlsx', [1, 2, 3])),
    );
    for (final s in ['Tải file mẫu', 'Điền thông tin theo mẫu', 'Tải file lên', 'Kiểm tra & nhập dữ liệu', 'Chọn file Excel', 'Tiếp tục']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    await t.tap(find.byKey(const Key('cn-tiep-tuc')));
    await cho(t);
    expect(api.nhap, [false]);
    expect(find.text('2 hợp lệ'), findsOneWidget);
    expect(find.text('Dòng 4 (101): Tòa đã có phòng này'), findsOneWidget);
    expect(find.text('Chọn file khác'), findsWidgets);

    api.nhapLoi = false;
    await t.tap(find.byKey(const Key('cn-chon-file')));
    await cho(t);
    expect(find.text('Nhập 2 phòng'), findsOneWidget);
    await t.tap(find.byKey(const Key('cn-tiep-tuc')));
    await cho(t);
    expect(api.nhap, [false, false, true]);
  });

  testWidgets('tab Thu chi: chưa thu lên trước, mở phòng', (t) async {
    await dung(t, ThuChiTongScreen(api: api));
    await cho(t);
    expect(find.text('98.500.000đ'), findsOneWidget);
    expect(find.text('Thu tiền (2)'), findsOneWidget);
    expect(find.text('Nguyễn Văn Nam · Hạn 05/10'), findsOneWidget);
    await t.tap(find.byKey(const Key('cn-thu-201')));
    await t.pumpAndSettle();
    expect(find.byType(ThuChiPhongScreen), findsOneWidget);
  });

  testWidgets('golden 390px: các màn theo mockup', (t) async {
    for (final (ten, man) in <(String, Widget)>[
      ('trang_chu', TrangChuChuNhaScreen(api: api)),
      ('toa_nha', ToaNhaCuaToiScreen(api: api)),
      ('phong_theo_tang', PhongTheoTangScreen(toaId: 1, tenToa: 'Sunrise Tower', api: api)),
      ('thong_tin_phong', ThongTinPhongScreen(roomId: 201, api: api)),
      ('hop_dong', HopDongPhongScreen(roomId: 201, api: api)),
      ('dien_nuoc', DienNuocPhongScreen(roomId: 201, api: api)),
      ('thu_chi', ThuChiPhongScreen(roomId: 201, api: api)),
      ('thu_tien', ThuTienScreen(roomId: 201, api: api)),
      ('tao_hoa_don', TaoHoaDonScreen(roomId: 201, api: api)),
      ('dich_vu', DichVuPhongScreen(roomId: 201, api: api)),
      ('lich_su', LichSuPhongScreen(roomId: 201, api: api)),
      ('sua_phong', SuaPhongScreen(toaId: 1, roomId: 201, api: api)),
      ('setup_tang', SetupTangScreen(toaId: 1, api: api)),
      ('nhap_phong', NhapPhongScreen(toaId: 1, tenToa: 'Sunrise Tower', api: api)),
      ('thu_chi_tong', ThuChiTongScreen(api: api)),
    ]) {
      await dung(t, KeyedSubtree(key: ValueKey(ten), child: man), co: const Size(390, 844));
      await cho(t);
      expect(t.takeException(), isNull, reason: ten);
      await expectLater(find.byKey(ValueKey(ten)), matchesGoldenFile('goldens/chu_nha_$ten.png'));
    }
  });
}
