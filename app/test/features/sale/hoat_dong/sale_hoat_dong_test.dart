import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:house_booking/data/services/sale_van_hanh_api.dart';
import 'package:house_booking/features/sale/hoat_dong/bai_dang_cua_toi_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/bao_cao_sale_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/don_lich_xem_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/hop_dong_sale_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/khach_hang_sale_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/quan_ly_sale_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/sale_hoat_dong_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/toa_nha_phong_sale_screen.dart';

import '../../../helpers/pump_app.dart';

/// Tab "Hoạt động" của SALE theo mockup 05/10/2026 — 9 màn dựng mới.
/// Số liệu giả lấy đúng ví dụ trong mockup để đối chiếu bằng mắt (golden).
class _Gia extends SaleVanHanhApi {
  final kenhDaGoi = <String>[];
  final kyDaGoi = <String>[];
  final xacNhan = <int>[];
  final tuChoi = <(int, String)>[];
  final ketQua = <(int, bool, String)>[];

  @override
  Future<TongQuanVanHanh> tongQuan(String kenh) async {
    kenhDaGoi.add(kenh);
    return TongQuanVanHanh.fromMap({
      'kenh': kenh,
      'so': {'bai_dang': 24, 'khach_moi': 18, 'lich_xem': 8, 'cho_chot': 3},
      'can_xu_ly': [
        {
          'loai': 'xac_nhan_lich',
          'id': 1,
          'khach': {'id': 9, 'ten': 'Trần Minh'},
          'tieu_de': 'Khách Trần Minh',
          'mo_ta': 'Yêu cầu xem phòng 305 - Vạn Phúc',
          'thoi_gian': '2030-10-08T09:00',
          'nhan': 'Chờ xác nhận',
          'tong': 'cam',
        },
        {
          'loai': 'cap_nhat_ket_qua',
          'id': 2,
          'khach': {'id': 10, 'ten': 'Lê Thu'},
          'tieu_de': 'Khách Lê Thu',
          'mo_ta': 'Đã xem phòng 201 - Cozy Home',
          'thoi_gian': '2026-09-08T14:00',
          'nhan': 'Cập nhật kết quả',
          'tong': 'lam',
        },
        {
          'loai': 'cho_chu_xac_nhan',
          'id': 3,
          'khach': {'id': 11, 'ten': 'Phạm Nam'},
          'tieu_de': 'Khách Phạm Nam',
          'mo_ta': 'Đã chốt - chờ chủ xác nhận',
          'thoi_gian': '2026-09-07T10:00',
          'nhan': 'Chờ xác nhận',
          'tong': 'cam',
        },
      ],
    });
  }

  @override
  Future<DanhSachSale<BaiDangSale>> baiDang(String kenh) async => DanhSachSale.fromMap({
    'chip': [
      {'khoa': 'tat_ca', 'nhan': 'Tất cả', 'so': 3},
      {'khoa': 'dang_dang', 'nhan': 'Đang đăng', 'so': 3},
      {'khoa': 'co_lich_xem', 'nhan': 'Có lịch xem', 'so': 1},
      {'khoa': 'cho_chot', 'nhan': 'Chờ chốt', 'so': 1},
    ],
    'ds': [
      {
        'id': 305, 'tieu_de': 'Phòng 305 - Vạn Phúc Residence', 'gia': 4500000,
        'don_vi': 'tháng', 'dien_tich': 28, 'loai': 'Studio', 'khu_vuc': 'Quận 7',
        'trang_thai': 'dang_dang', 'nhom': ['dang_dang'],
        'so_khach': 12, 'so_lich_xem': 5, 'so_cho_chot': 1,
      },
      {
        'id': 201, 'tieu_de': 'Phòng 201 - Cozy Home', 'gia': 5000000,
        'don_vi': 'tháng', 'dien_tich': 30, 'loai': '1PN', 'khu_vuc': 'Bình Thạnh',
        'trang_thai': 'co_lich_xem', 'nhom': ['dang_dang', 'co_lich_xem'],
        'so_khach': 8, 'so_lich_xem': 3, 'so_cho_chot': 0,
      },
      {
        'id': 102, 'tieu_de': 'Phòng 102 - Green Home', 'gia': 4800000,
        'don_vi': 'tháng', 'dien_tich': 25, 'loai': 'Studio', 'khu_vuc': 'Thủ Đức',
        'trang_thai': 'cho_chot', 'nhom': ['dang_dang', 'cho_chot'],
        'so_khach': 6, 'so_lich_xem': 4, 'so_cho_chot': 2,
      },
    ],
  }, BaiDangSale.fromMap);

  Map<String, dynamic> _lich(int id, String nhan, List<String> nut, String batDau,
      String gio, String phong, String khach) => {
    'id': id,
    'loai': 'lich_xem',
    'phong': {'ten': phong},
    'khach': {'id': 20 + id, 'ten': khach},
    'bat_dau': batDau,
    'gio': gio,
    'trang_thai': 'x',
    'nhan': nhan,
    'nhom': [nhan == 'cho_xac_nhan' ? 'cho_xac_nhan' : nhan == 'da_xac_nhan' ? 'da_xac_nhan' : 'da_xem'],
    'hanh_dong': nut,
  };

  @override
  Future<DanhSachSale<LichSale>> lich(String kenh) async => DanhSachSale.fromMap({
    'chip': [
      {'khoa': 'tat_ca', 'nhan': 'Tất cả', 'so': 3},
      {'khoa': 'cho_xac_nhan', 'nhan': 'Chờ xác nhận', 'so': 1},
      {'khoa': 'da_xac_nhan', 'nhan': 'Đã xác nhận', 'so': 1},
      {'khoa': 'da_xem', 'nhan': 'Đã xem', 'so': 1},
    ],
    'ds': [
      _lich(1, 'cho_xac_nhan', ['tu_choi', 'xac_nhan'], '2030-10-08T09:00',
          '09:00-09:30', 'Phòng 305 - Vạn Phúc', 'Trần Minh'),
      _lich(2, 'da_xac_nhan', ['doi_lich', 'cap_nhat_ket_qua'], '2026-09-08T14:00',
          '14:00-15:00', 'Phòng 201 - Cozy Home', 'Lê Thu'),
      _lich(3, 'da_xem', ['xem_chi_tiet'], '2026-09-07T10:00', '10:00-10:30',
          'Phòng 102 - Green Home', 'Phạm Nam'),
    ],
  }, LichSale.fromMap);

  @override
  Future<void> xacNhanLich(int id) async => xacNhan.add(id);

  @override
  Future<void> tuChoiLich(int id, {String lyDo = ''}) async => tuChoi.add((id, lyDo));

  @override
  Future<void> ghiKetQua(int id, {required bool muonThue, String ghiChu = ''}) async =>
      ketQua.add((id, muonThue, ghiChu));

  @override
  Future<DanhSachSale<KhachCuaSale>> khachHang(String kenh) async => DanhSachSale.fromMap({
    'chip': [
      {'khoa': 'tat_ca', 'nhan': 'Tất cả', 'so': 3},
      {'khoa': 'moi', 'nhan': 'Mới', 'so': 0},
      {'khoa': 'dang_tu_van', 'nhan': 'Đang tư vấn', 'so': 1},
      {'khoa': 'da_xem', 'nhan': 'Đã xem', 'so': 1},
      {'khoa': 'cho_chot', 'nhan': 'Chờ chốt', 'so': 1},
    ],
    'ds': [
      {'id': 1, 'user_id': 31, 'ten': 'Trần Minh', 'sdt': '0901', 'trang_thai': 'dang_tu_van', 'so_lich_xem': 3},
      {'id': 2, 'user_id': 32, 'ten': 'Lê Thu', 'sdt': '0902', 'trang_thai': 'da_xem', 'so_lich_xem': 2},
      {'id': 3, 'user_id': 33, 'ten': 'Phạm Nam', 'sdt': '0903', 'trang_thai': 'cho_chot', 'so_lich_xem': 1},
    ],
  }, KhachCuaSale.fromMap);

  @override
  Future<DanhSachSale<ChuNhaSale>> chuNha() async => DanhSachSale.fromMap({
    'chip': [
      {'khoa': 'tat_ca', 'nhan': 'Tất cả', 'so': 3},
      {'khoa': 'dang_hop_tac', 'nhan': 'Đang hợp tác', 'so': 2},
      {'khoa': 'moi', 'nhan': 'Mới', 'so': 1},
    ],
    'ds': [
      {'id': 41, 'ten': 'Anh Hoàng', 'sdt': '0911', 'so_toa': 3, 'so_phong': 28, 'trang_thai': 'dang_hop_tac'},
      {'id': 42, 'ten': 'Chị Mai', 'sdt': '0912', 'so_toa': 1, 'so_phong': 12, 'trang_thai': 'moi'},
      {'id': 43, 'ten': 'Công ty Vạn Phúc', 'sdt': '0913', 'so_toa': 2, 'so_phong': 45, 'trang_thai': 'dang_hop_tac'},
    ],
  }, ChuNhaSale.fromMap);

  @override
  Future<List<ToaSale>> toaNha() async => [
    ToaSale.fromMap({'id': 7, 'ten': 'Vạn Phúc Residence', 'dia_chi': 'Quận 7, TP.HCM', 'so_phong': 20}),
    ToaSale.fromMap({'id': 8, 'ten': 'Cozy Home', 'dia_chi': 'Bình Thạnh, TP.HCM', 'so_phong': 12}),
  ];

  @override
  Future<ChiTietToaSale> chiTietToa(int id, String kenh) async => ChiTietToaSale.fromMap({
    'toa': {
      'id': id, 'ten': 'Vạn Phúc Residence', 'dia_chi': 'Quận 7, TP.HCM',
      'dia_chi_day_du': '12 Nguyễn Thị Thập, Quận 7, TP.HCM',
      'chu_nha': {'id': 41, 'ten': 'Anh Hoàng', 'sdt': '0911'},
      'gia_dien': 3500, 'gia_nuoc': 25000, 'phi_dich_vu': 150000, 'tong_phong': 3,
    },
    'chip': [
      {'khoa': 'tat_ca', 'nhan': 'Tất cả', 'so': 3},
      {'khoa': 'trong', 'nhan': 'Trống', 'so': 1},
      {'khoa': 'co_lich_xem', 'nhan': 'Có lịch xem', 'so': 1},
      {'khoa': 'dang_thue', 'nhan': 'Đang thuê', 'so': 1},
    ],
    'phong': [
      {'id': 305, 'ten': 'Phòng 305', 'dien_tich': 28, 'loai': 'Studio', 'gia': 4500000, 'don_vi': 'tháng', 'trang_thai': 'trong'},
      {'id': 306, 'ten': 'Phòng 306', 'dien_tich': 28, 'loai': 'Studio', 'gia': 4500000, 'don_vi': 'tháng', 'trang_thai': 'co_lich_xem'},
      {'id': 307, 'ten': 'Phòng 307', 'dien_tich': 28, 'loai': 'Studio', 'gia': 4500000, 'don_vi': 'tháng', 'trang_thai': 'dang_thue'},
    ],
    'anh': ['https://example.test/a.jpg'],
  });

  @override
  Future<DanhSachSale<HopDongSale>> hopDong(String kenh) async => DanhSachSale.fromMap({
    'chip': [
      {'khoa': 'dang_xu_ly', 'nhan': 'Đang xử lý', 'so': 2},
      {'khoa': 'hieu_luc', 'nhan': 'Hiệu lực', 'so': 1},
      {'khoa': 'da_ket_thuc', 'nhan': 'Đã kết thúc', 'so': 0},
    ],
    'ds': [
      {'khoa': 'lich-1', 'appointment_id': 1, 'phong': {'ten': 'Phòng 201 - Cozy Home'}, 'khach': {'ten': 'Phạm Nam'}, 'ngay_tao': '2026-10-07T10:00', 'nhan': 'cho_chu_xac_nhan', 'nhom': 'dang_xu_ly'},
      {'khoa': 'lich-2', 'appointment_id': 2, 'phong': {'ten': 'Phòng 305 - Vạn Phúc'}, 'khach': {'ten': 'Lê Thu'}, 'ngay_tao': '2026-10-05T10:00', 'nhan': 'dang_ky_hop_dong', 'nhom': 'dang_xu_ly'},
      {'khoa': 'hd-9', 'contract_id': 9, 'phong': {'ten': 'Phòng 102 - Green Home'}, 'khach': {'ten': 'Trần Minh'}, 'ngay_tao': '2026-10-01T10:00', 'nhan': 'hoan_tat', 'nhom': 'hieu_luc'},
    ],
  }, HopDongSale.fromMap);

  @override
  Future<BaoCaoSale> baoCao(String kenh, String ky) async {
    kyDaGoi.add(ky);
    return BaoCaoSale.fromMap({
      'ky': {'khoa': ky, 'nhan': ky == 'thang_truoc' ? 'Tháng trước' : 'Tháng này'},
      'cac_ky': [
        {'khoa': 'thang_nay', 'nhan': 'Tháng này'},
        {'khoa': 'thang_truoc', 'nhan': 'Tháng trước'},
      ],
      'so': {'bai_dang': 24, 'khach_moi': 18, 'lich_xem': 8, 'da_chot': 3},
      'bieu_do': [
        for (var i = 1; i <= 28; i++)
          {
            'ngay': '2026-10-${i.toString().padLeft(2, '0')}',
            'luot_xem': (i * 7) % 40,
            'yeu_cau': (i * 3) % 9,
          },
      ],
      'hoa_hong': {'du_kien': 2250000, 'da_nhan': 1500000, 'doanh_thu': 4500000, 'phan_tram': 50},
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
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
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

  testWidgets('màn 2: lối tắt · tổng quan · cần xử lý hôm nay', (t) async {
    await dung(t, SaleHoatDongScreen(api: api));
    for (final s in ['Hoạt động', 'Quản lý', 'Lịch xem', 'Khách hàng', 'Hợp đồng']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    expect(find.text('Tổng quan (Dài hạn)', findRichText: true), findsOneWidget);
    for (final s in ['24', '18', '8', '3', 'Bài đăng', 'Khách mới', 'Chờ chốt']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    expect(find.text('Cần xử lý hôm nay (3)', findRichText: true), findsOneWidget);
    expect(find.text('Khách Trần Minh'), findsOneWidget);
    expect(find.text('Ngày 08/10 • 09:00'), findsOneWidget);
    expect(find.text('Cập nhật kết quả'), findsOneWidget);
    expect(find.text('Chờ xác nhận'), findsNWidgets(2));
    expect(api.kenhDaGoi, ['dai_han']);

    await t.tap(find.byKey(const Key('kenh-ngan-han')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(api.kenhDaGoi.last, 'ngan_han');
    expect(find.text('Tổng quan (Ngắn hạn)', findRichText: true), findsOneWidget);
    expect(find.text('Đơn đặt'), findsWidgets);
    expect(t.takeException(), isNull);
  });

  testWidgets('màn 3: menu Quản lý đủ bảy lối và mở đúng màn', (t) async {
    await dung(t, QuanLySaleScreen(api: api));
    for (final s in [
      'Bài đăng của tôi', 'Đơn & lịch xem', 'Khách hàng', 'Chủ nhà',
      'Tòa nhà & phòng', 'Hợp đồng', 'Báo cáo',
    ]) {
      expect(find.byKey(Key('muc-$s')), findsOneWidget, reason: s);
    }
    expect(find.text('Tòa nhà & phòng (chỉ xem)', findRichText: true), findsOneWidget);
    await t.tap(find.byKey(const Key('muc-Báo cáo')));
    await t.pumpAndSettle();
    expect(find.byType(BaoCaoSaleScreen), findsOneWidget);
  });

  testWidgets('màn 4: bài đăng — ba con số, chip lọc, đăng tin mới', (t) async {
    var daMo = 0;
    await dung(
      t,
      BaiDangCuaToiScreen(
        api: api,
        moDangTin: (_) async => daMo++,
        moTin: (_, _) {},
      ),
    );
    expect(find.text('Tất cả (3)'), findsOneWidget);
    expect(find.text('Phòng 305 - Vạn Phúc Residence'), findsOneWidget);
    expect(find.text('4.500.000đ/tháng'), findsOneWidget);
    expect(find.text('28 m²'), findsOneWidget);
    expect(find.text('12 khách'), findsOneWidget);
    expect(find.text('5 lịch xem'), findsOneWidget);
    expect(find.text('1 chờ chốt'), findsOneWidget);
    expect(find.text('Đang đăng'), findsOneWidget);
    expect(find.text('Có lịch xem'), findsOneWidget);

    // Chip thứ tư nằm ngoài mép phải dải chip — cuộn ngang tới như người dùng.
    await t.ensureVisible(find.byKey(const Key('chip-cho_chot')));
    await t.pump();
    await t.tap(find.byKey(const Key('chip-cho_chot')));
    await t.pump();
    expect(find.text('Phòng 305 - Vạn Phúc Residence'), findsNothing);
    expect(find.text('Phòng 102 - Green Home'), findsOneWidget);

    await t.tap(find.byKey(const Key('dang-tin-moi')));
    await t.pump();
    expect(daMo, 1);
  });

  testWidgets('màn 5: nút theo trạng thái — xác nhận, từ chối, cập nhật kết quả', (t) async {
    await dung(t, DonLichXemScreen(api: api));
    expect(find.text('Từ chối'), findsOneWidget);
    expect(find.text('Đổi lịch'), findsOneWidget);
    expect(find.text('Xem chi tiết'), findsOneWidget);
    expect(find.text('08/10 • 09:00 - 09:30'), findsOneWidget);

    await t.tap(find.byKey(const Key('xac-nhan-1')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(api.xacNhan, [1]);

    await t.tap(find.byKey(const Key('tu-choi-1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('xac-nhan-tu-choi')));
    await t.pumpAndSettle();
    expect(api.tuChoi, [(1, 'Phòng đã có khách')]);

    await t.tap(find.byKey(const Key('cap-nhat-2')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('kq-muon-thue')));
    await t.pump();
    await t.enterText(find.byKey(const Key('kq-ghi-chu')), 'Khách ưng phòng');
    await t.tap(find.byKey(const Key('kq-luu')));
    await t.pumpAndSettle();
    expect(api.ketQua, [(2, true, 'Khách ưng phòng')]);
    expect(t.takeException(), isNull);
  });

  testWidgets('màn 6–7: khách hàng tìm + lọc, tab chủ nhà', (t) async {
    await dung(t, KhachHangSaleScreen(api: api));
    expect(find.text('Khách hàng (Dài hạn)', findRichText: true), findsOneWidget);
    expect(find.text('Trần Minh'), findsOneWidget);
    expect(find.text('Đang tư vấn  •  3 lịch xem', findRichText: true), findsOneWidget);

    await t.enterText(find.byKey(const Key('o-tim')), 'thu');
    await t.pump();
    expect(find.text('Trần Minh'), findsNothing);
    expect(find.text('Lê Thu'), findsOneWidget);

    await t.tap(find.byKey(const Key('tab-chu-nha')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Anh Hoàng'), findsOneWidget);
    expect(find.text('3 tòa nhà • 28 phòng'), findsOneWidget);
    await t.tap(find.byKey(const Key('chip-moi')));
    await t.pump();
    expect(find.text('Anh Hoàng'), findsNothing);
    expect(find.text('Chị Mai'), findsOneWidget);
  });

  testWidgets('màn 8: tòa nhà & phòng — chip, ba tab', (t) async {
    await dung(t, ToaNhaPhongSaleScreen(api: api));
    expect(find.text('Vạn Phúc Residence'), findsOneWidget);
    expect(find.text('Phòng 305'), findsOneWidget);
    expect(find.text('28 m² • Studio'), findsNWidgets(3));
    expect(find.text('Trống'), findsOneWidget);
    expect(find.text('Đang thuê'), findsOneWidget);

    await t.tap(find.byKey(const Key('chip-trong')));
    await t.pump();
    expect(find.text('Phòng 306'), findsNothing);

    await t.tap(find.byKey(const Key('tab-toa-0')));
    await t.pump();
    expect(find.text('Tổng phòng'), findsOneWidget);
    expect(find.text('12 Nguyễn Thị Thập, Quận 7, TP.HCM'), findsOneWidget);

    await t.tap(find.byKey(const Key('dau-toa')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('chon-toa-8')));
    await t.pumpAndSettle();
    expect(find.text('Cozy Home'), findsOneWidget);
  });

  testWidgets('màn 9: hợp đồng theo nhóm', (t) async {
    await dung(t, HopDongSaleScreen(api: api));
    expect(find.text('Đang xử lý (2)'), findsOneWidget);
    expect(find.text('Chờ chủ xác nhận'), findsOneWidget);
    expect(find.text('Đang ký hợp đồng'), findsOneWidget);
    expect(find.text('Ngày tạo: 07/10/2026'), findsOneWidget);
    await t.tap(find.byKey(const Key('chip-hieu_luc')));
    await t.pump();
    expect(find.text('Hoàn tất'), findsOneWidget);
    expect(find.text('Chờ chủ xác nhận'), findsNothing);
  });

  testWidgets('màn 10: báo cáo — số liệu, biểu đồ, đổi kỳ', (t) async {
    await dung(t, BaoCaoSaleScreen(api: api));
    expect(find.text('Báo cáo (Dài hạn)', findRichText: true), findsOneWidget);
    expect(find.text('Tháng này'), findsOneWidget);
    expect(find.text('Đã chốt'), findsOneWidget);
    expect(find.text('Hiệu quả bài đăng'), findsOneWidget);
    expect(find.byKey(const Key('bieu-do-sale')), findsOneWidget);
    expect(find.text('2.250.000đ'), findsOneWidget);

    await t.tap(find.byKey(const Key('chon-ky')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('ky-thang_truoc')));
    await t.pumpAndSettle();
    expect(api.kyDaGoi, ['thang_nay', 'thang_truoc']);
    expect(find.text('Tháng trước'), findsOneWidget);
  });

  testWidgets('golden 390px: tám màn theo mockup', (t) async {
    for (final (ten, man) in <(String, Widget)>[
      ('hoat_dong', SaleHoatDongScreen(api: api)),
      ('quan_ly', QuanLySaleScreen(api: api)),
      ('bai_dang', BaiDangCuaToiScreen(api: api, moDangTin: (_) async {}, moTin: (_, _) {})),
      ('don_lich_xem', DonLichXemScreen(api: api)),
      ('khach_hang', KhachHangSaleScreen(api: api)),
      ('toa_nha', ToaNhaPhongSaleScreen(api: api)),
      ('hop_dong', HopDongSaleScreen(api: api)),
      ('bao_cao', BaoCaoSaleScreen(api: api)),
    ]) {
      await dung(t, KeyedSubtree(key: ValueKey(ten), child: man), co: const Size(390, 844));
      expect(t.takeException(), isNull, reason: ten);
      await expectLater(
        find.byKey(ValueKey(ten)),
        matchesGoldenFile('goldens/sale_$ten.png'),
      );
    }
  });
}
