import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/models/viewing_appointment_model.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/data/services/sale_yeu_cau_api.dart';
import 'package:house_booking/features/sale/bang_dieu_hanh_sale.dart';
import 'package:house_booking/features/sale/khach_hang_sale_screen.dart';
import 'package:house_booking/features/sale/toa_doanh_thu_sale_screen.dart';
import 'package:house_booking/features/sale/yeu_cau_chi_tiet_screen.dart';
import 'package:house_booking/features/sale/yeu_cau_list_screen.dart';

import '../../helpers/pump_app.dart';

/// SALE QUẢN LÝ THEO YÊU CẦU — 5 màn của mockup 23/09/2026.
///
/// Điều phải giữ:
///   * thẻ yêu cầu nói VIỆC TIẾP THEO, không chỉ trạng thái — đó là thứ sale
///     mở app ra để xem;
///   * chip lọc mang số đếm thật của server, bấm là gọi lại đúng nhóm;
///   * màn chi tiết vẽ đủ 7 bước, bước đã qua có mốc giờ, nút chuyển nói rõ
///     chuyển sang bước NÀO; đã chốt thì không còn nút;
///   * tạo yêu cầu / thêm khách gửi đúng dữ liệu, kể cả khi khách chưa có
///     tài khoản (chỉ có tên + SĐT);
///   * tháng không có đơn thì cột biểu đồ tô XÁM, không tô đỏ như tháng có
///     tiền; chưa liên kết toà nào thì nói rõ phải làm gì.
class _ApiGia extends SaleYeuCauApi {
  _ApiGia({this.chiTietMap, this.toaDt});

  final Map<String, dynamic>? chiTietMap;
  final Map<String, dynamic>? toaDt;

  final nhomDaGoi = <String>[];
  final tabDaGoi = <String>[];
  Map<String, dynamic>? daTaoYeuCau;
  Map<String, dynamic>? daThemKhach;
  String? daChuyen;
  String? lyDoDong;
  final daGanCan = <(int?, int?)>[];
  int? daChonCan;

  @override
  Future<TongQuanSale> tongQuan() async => TongQuanSale.fromMap(const {
    'yeu_cau_moi': 12,
    'dang_xu_ly': 28,
    'cho_xem_nha': 16,
    'da_chot': 9,
    'doanh_thu_thang': 320000000,
    'hoa_hong_du_kien': 32500000,
    'phan_tram_hoa_hong': 50,
  });

  @override
  Future<BangYeuCau> danhSach({String nhom = 'tat_ca', String q = ''}) async {
    nhomDaGoi.add(nhom);
    return BangYeuCau.fromMap(_bangMau());
  }

  @override
  Future<YeuCauChiTiet> chiTiet(int id) async =>
      YeuCauChiTiet.fromMap(chiTietMap ?? _chiTietMau());

  @override
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
  }) async {
    daTaoYeuCau = {
      'ho_ten': hoTen,
      'sdt': sdt,
      'loai_can': loaiCan,
      'ngan_sach_min': nganSachMin,
      'ngan_sach_max': nganSachMax,
    };
    return YeuCauChiTiet.fromMap(_chiTietMau());
  }

  @override
  Future<YeuCauChiTiet> chuyenBuoc(int id, String buoc, {String? lyDo}) async {
    daChuyen = buoc;
    if (buoc == 'dong') {
      lyDoDong = lyDo;
      return YeuCauChiTiet.fromMap({
        ...(chiTietMap ?? _chiTietMau()),
        'dong_ly_do': lyDo,
      });
    }
    return YeuCauChiTiet.fromMap(_chiTietMau(trangThai: buoc));
  }

  @override
  Future<SoKhachSale> khach({String tab = 'dang_theo', String q = ''}) async {
    tabDaGoi.add(tab);
    return SoKhachSale.fromMap(_khachMau());
  }

  @override
  Future<KhachSale> themKhach({
    required String hoTen,
    String sdt = '',
    String? khuVuc,
    String? ghiChu,
  }) async {
    daThemKhach = {'ho_ten': hoTen, 'sdt': sdt, 'khu_vuc': khuVuc};
    return KhachSale.fromMap({'id': 9, 'ho_ten': hoTen, 'sdt': sdt});
  }

  @override
  Future<NguonCanSale> nguonCan(int yeuCauId, {String q = ''}) async =>
      NguonCanSale.fromMap(_nguonMau());

  @override
  Future<YeuCauChiTiet> ganCan(int id, {int? houseId, int? roomId}) async {
    daGanCan.add((houseId, roomId));
    return YeuCauChiTiet.fromMap(_chiTietMau());
  }

  @override
  Future<YeuCauChiTiet> chonCan(int yeuCauId, int canId) async {
    daChonCan = canId;
    return YeuCauChiTiet.fromMap(_chiTietMau());
  }

  @override
  Future<ToaVaDoanhThu> toaDoanhThu() async =>
      ToaVaDoanhThu.fromMap(toaDt ?? _toaMau());
}

Map<String, dynamic> _bangMau() => {
  'dem': {
    'tat_ca': 68,
    'lead_moi': 12,
    'lich_xem': 14,
    'sau_xem': 8,
    'cho_coc': 6,
    'da_chot': 28,
  },
  'danh_sach': [
    {
      'id': 245,
      'ma': 'YC-0245',
      'khach': 'Nguyễn Thị Lan',
      'sdt': '0908123456',
      'khach_id': 5,
      'loai_can': 'Căn 2PN',
      'khu_vuc': 'The Sun Avenue',
      'ngan_sach': '10 - 15 triệu',
      'trang_thai': 'lead_moi',
      'nhan': 'Lead mới',
      'viec_tiep': 'Liên hệ khách',
      'cap_nhat': '2026-09-23T10:00:00',
    },
  ],
};

Map<String, dynamic> _chiTietMau({
  String trangThai = 'da_xac_nhan_lich',
  bool coCanChot = true,
}) {
  // Pipeline 7 bước — bước "Gửi căn phù hợp" đã bỏ (23/09/2026): hệ thống
  // không gửi gì cho khách, vẽ nó thành một bước là hứa thứ mình không làm.
  const buoc = [
    'lead_moi',
    'da_lien_he',
    'da_xac_nhan_lich',
    'sau_xem',
    'muon_thue',
    'cho_coc',
    'da_chot',
  ];
  const nhan = [
    'Lead mới',
    'Đã liên hệ khách',
    'Đã xác nhận lịch xem',
    'Sau khi xem',
    'Muốn thuê',
    'Chờ cọc',
    'Đã chốt',
  ];
  final iHt = buoc.indexOf(trangThai);
  return {
    'id': 245,
    'ma': 'YC-0245',
    'khach': {
      'id': 5,
      'ho_ten': 'Nguyễn Thị Lan',
      'sdt': '0908123456',
      'khu_vuc': 'Thảo Điền, Quận 2',
      'co_tai_khoan': false,
    },
    'trang_thai': trangThai,
    'nhan': nhan[iHt],
    'viec_tiep': 'Dẫn khách xem',
    'ngan_sach': '10 - 15 triệu',
    'vao_o_tu': '2026-10-01T00:00:00',
    'loai_can': 'Căn hộ 2 phòng ngủ',
    'khu_vuc': 'Thảo Điền, Quận 2',
    'ghi_chu': 'Gia đình 2 vợ chồng, có 1 bé nhỏ.',
    'can_lien_quan': [
      {
        'id': 1,
        'house_id': 11,
        'ten': 'Masteri Thảo Điền',
        'dia_chi': '2PN · 70m²',
        'gia': 15000000,
        'khach_thich': coCanChot,
      },
    ],
    'pipeline': [
      for (var i = 0; i < buoc.length; i++)
        {
          'buoc': buoc[i],
          'nhan': nhan[i],
          'xong': i <= iHt,
          'dang_o': i == iHt,
          'luc': i <= iHt ? '2026-09-1${i + 1}T09:12:00' : null,
        },
    ],
  };
}

Map<String, dynamic> _nguonMau() => {
  'toa_lien_ket': [
    {
      'room_id': 77,
      'house_id': null,
      'ten': 'Phòng A12',
      'dia_chi': 'Masteri Thảo Điền · 12 Thảo Điền',
      'gia': 15000000,
      'trang_thai': 'vacant',
      'da_gan': false,
    },
    {
      'room_id': 78,
      'house_id': null,
      'ten': 'Phòng A13',
      'dia_chi': 'Masteri Thảo Điền · 12 Thảo Điền',
      'gia': 14000000,
      'trang_thai': 'vacant',
      'da_gan': true,
    },
  ],
  'bai_dang': [
    {
      'room_id': null,
      'house_id': 24,
      'ten': 'Căn hộ 3PN 82m² tầng trung',
      'dia_chi': 'Lê Chân · Hải Phòng',
      'gia': 12000000,
      'trang_thai': 'published',
      'da_gan': false,
    },
  ],
};

Map<String, dynamic> _khachMau() => {
  'tong_khach': 128,
  'dang_tu_van': 86,
  'da_thue': 42,
  'danh_sach': [
    {
      'id': 5,
      'ho_ten': 'Nguyễn Thị Lan',
      'sdt': '0908123456',
      'khu_vuc': 'Thảo Điền, Quận 2',
      'trang_thai': 'dang_tu_van',
      'nhan': 'Đang tư vấn',
      'co_tai_khoan': false,
      'so_yeu_cau': 3,
      'gan_nhat': 'Đã xác nhận lịch xem',
    },
  ],
};

Map<String, dynamic> _toaMau() => {
  'toa': [
    {
      'id': 1,
      'ten': 'Masteri Thảo Điền',
      'dia_chi': '12 Thảo Điền · Quận 2',
      'so_phong': 24,
      'phong_trong': 8,
    },
  ],
  'so_chu_lien_ket': 12,
  'don_da_chot': 9,
  'doanh_thu_thang': 320000000,
  'hoa_hong_du_kien': 32500000,
  'hoa_hong_da_nhan': 18000000,
  'theo_thang': [
    {
      'thang': '2026-04-01',
      'don_da_chot': 0,
      'doanh_thu': 0,
      'hoa_hong_du_kien': 0,
    },
    {
      'thang': '2026-05-01',
      'don_da_chot': 4,
      'doanh_thu': 180000000,
      'hoa_hong_du_kien': 9000000,
    },
    {
      'thang': '2026-06-01',
      'don_da_chot': 5,
      'doanh_thu': 220000000,
      'hoa_hong_du_kien': 11000000,
    },
    {
      'thang': '2026-07-01',
      'don_da_chot': 6,
      'doanh_thu': 260000000,
      'hoa_hong_du_kien': 13000000,
    },
    {
      'thang': '2026-08-01',
      'don_da_chot': 7,
      'doanh_thu': 310000000,
      'hoa_hong_du_kien': 15500000,
    },
    {
      'thang': '2026-09-01',
      'don_da_chot': 9,
      'doanh_thu': 320000000,
      'hoa_hong_du_kien': 32500000,
    },
  ],
  'gan_day': [
    {
      'yeu_cau_id': 245,
      'ma': 'YC-0245',
      'khach': 'Lê Thảo Vy',
      'gia_thue': 15000000,
      'chot_luc': '2026-09-22T09:00:00',
    },
  ],
};

void _manRong(WidgetTester t, {double cao = 2600}) {
  t.view.physicalSize = Size(430, cao);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}

Future<void> _cho(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 60));
}

/// Hàng lịch xem của sale: [soCho] lịch khách vừa đặt, đang chờ xác nhận.
class _LichGia extends RentalJourneyApi {
  _LichGia(this.soCho);

  final int soCho;
  final trangThaiDaHoi = <String?>[];

  @override
  Future<List<RentalJourney>> list({
    required String view,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async => const [];

  @override
  Future<List<ViewingAppointmentModel>> workQueue({
    required String view,
    String? date,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async {
    trangThaiDaHoi.add(status);
    return [
      for (var i = 0; i < soCho; i++)
        ViewingAppointmentModel(
          id: 50 + i,
          guestId: 73,
          bookingDate: '2026-09-25',
          bookingTime: '09:00-10:00',
          message: '',
          status: 'pending',
          createdAt: DateTime(2026, 9, 24, 7),
        ),
    ];
  }
}

void main() {
  group('Màn 1 — bảng điều hành', () {
    testWidgets('bốn ô phễu + tiền tháng + lưới chức năng', (t) async {
      _manRong(t);
      await pumpApp(
        t,
        Scaffold(
          body: BangDieuHanhSale(api: _ApiGia(), lichApi: _LichGia(0)),
        ),
      );
      await _cho(t);

      expect(find.text('Công việc Sale hôm nay'), findsOneWidget);
      expect(find.byKey(const Key('sale-lich-cho-xac-nhan')), findsNothing);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Yêu cầu mới'), findsOneWidget);
      expect(find.text('28'), findsOneWidget);
      expect(find.text('16'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('320 triệu'), findsOneWidget);
      expect(find.text('32,5 triệu'), findsOneWidget);
      expect(find.text('Hoa hồng dự kiến (50%)'), findsOneWidget);
      expect(find.byKey(const Key('sale-chuc-nang-yêu-cầu')), findsOneWidget);
    });

    testWidgets('khách vừa đặt lịch xem → thẻ nhắc xác nhận nằm đầu bảng', (
      t,
    ) async {
      _manRong(t);
      final lich = _LichGia(2);
      final api = _ApiGia();
      await pumpApp(
        t,
        Scaffold(
          body: BangDieuHanhSale(api: api, lichApi: lich),
        ),
      );
      await _cho(t);
      expect(lich.trangThaiDaHoi, ['pending']);
      expect(find.text('2 lịch xem chờ bạn xác nhận'), findsOneWidget);
      await t.tap(find.byKey(const Key('sale-lich-cho-xac-nhan')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.widgetWithText(AppBar, 'Yêu cầu'), findsOneWidget);
      expect(find.text('Lịch xem cần xử lý'), findsNothing);
      expect(api.nhomDaGoi.last, 'lich_xem');
    });
  });

  group('Màn 2 — danh sách yêu cầu', () {
    testWidgets('thẻ nói việc tiếp theo; chip mang số đếm thật', (t) async {
      _manRong(t);
      final api = _ApiGia();
      await pumpApp(t, YeuCauListScreen(api: api));
      await _cho(t);

      expect(find.text('YC-0245'), findsOneWidget);
      expect(find.text('Nguyễn Thị Lan'), findsOneWidget);
      expect(find.text('Việc tiếp theo: Liên hệ khách'), findsOneWidget);
      expect(find.text('Tất cả (68)'), findsOneWidget);
      expect(find.text('Lead mới (12)'), findsOneWidget);

      // Chip nằm trong dải cuộn ngang — phải kéo tới rồi mới bấm được.
      await t.dragUntilVisible(
        find.text('Lịch xem (14)'),
        find.byType(SingleChildScrollView).first,
        const Offset(-120, 0),
      );
      await t.tap(find.text('Lịch xem (14)'));
      await _cho(t);
      expect(api.nhomDaGoi.last, 'lich_xem');
    });

    testWidgets('tạo yêu cầu gửi tên, SĐT và ngân sách quy ra đồng', (t) async {
      _manRong(t, cao: 3000);
      final api = _ApiGia();
      await pumpApp(t, YeuCauListScreen(api: api));
      await _cho(t);

      await t.tap(find.byKey(const Key('sale-tao-yeu-cau')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('sale-yc-ten')), 'Trần Minh Quân');
      await t.enterText(find.byKey(const Key('sale-yc-sdt')), '0903222888');
      await t.enterText(find.byKey(const Key('sale-yc-min')), '8');
      await t.tap(find.byKey(const Key('sale-yc-luu')));
      await _cho(t);

      expect(api.daTaoYeuCau!['ho_ten'], 'Trần Minh Quân');
      expect(api.daTaoYeuCau!['sdt'], '0903222888');
      expect(api.daTaoYeuCau!['ngan_sach_min'], 8000000);
    });
  });

  group('Màn 3 — chi tiết yêu cầu', () {
    testWidgets('đủ 7 bước, bước đã qua có mốc giờ, nút nói bước kế', (
      t,
    ) async {
      _manRong(t, cao: 3200);
      final api = _ApiGia();
      await pumpApp(
        t,
        YeuCauChiTietScreen(yeuCauId: 245, api: api, moLink: (_) async {}),
      );
      await _cho(t);

      expect(find.text('Lead mới'), findsOneWidget);
      expect(find.text('Đã xác nhận lịch xem'), findsWidgets);
      expect(find.text('Đã chốt'), findsOneWidget);
      // Bước đã bỏ không được xuất hiện lại ở bất kỳ đâu trên màn.
      expect(find.text('Gửi căn phù hợp'), findsNothing);
      expect(find.textContaining('Gia đình 2 vợ chồng'), findsOneWidget);
      expect(find.text('Masteri Thảo Điền'), findsOneWidget);
      expect(find.text('15 triệu/tháng'), findsOneWidget);
      expect(find.text('Tháng 10/2026'), findsOneWidget);

      await t.tap(find.byKey(const Key('sale-chuyen-trang-thai')));
      await _cho(t);
      expect(api.daChuyen, 'sau_xem');
    });

    testWidgets('đã chốt thì không vẽ nút chuyển trạng thái', (t) async {
      _manRong(t, cao: 3200);
      await pumpApp(
        t,
        YeuCauChiTietScreen(
          yeuCauId: 245,
          api: _ApiGia(chiTietMap: _chiTietMau(trangThai: 'da_chot')),
          moLink: (_) async {},
        ),
      );
      await _cho(t);

      expect(find.byKey(const Key('sale-chuyen-trang-thai')), findsNothing);
      expect(find.textContaining('hoa hồng được ghi nhận'), findsOneWidget);
    });

    testWidgets('cả 7 bước đều cho Sale hủy yêu cầu', (t) async {
      _manRong(t, cao: 3200);
      const cacBuoc = [
        'lead_moi',
        'da_lien_he',
        'da_xac_nhan_lich',
        'sau_xem',
        'muon_thue',
        'cho_coc',
        'da_chot',
      ];

      for (final buoc in cacBuoc) {
        await pumpApp(
          t,
          YeuCauChiTietScreen(
            key: ValueKey(buoc),
            yeuCauId: 245,
            api: _ApiGia(chiTietMap: _chiTietMau(trangThai: buoc)),
            moLink: (_) async {},
          ),
        );
        await _cho(t);
        expect(
          find.byKey(const Key('sale-huy-yeu-cau')),
          findsOneWidget,
          reason: 'Thiếu nút hủy tại bước $buoc',
        );
      }
    });

    testWidgets('hủy bắt buộc lý do và khóa các thao tác của yêu cầu', (
      t,
    ) async {
      _manRong(t, cao: 3200);
      final api = _ApiGia(chiTietMap: _chiTietMau(trangThai: 'cho_coc'));
      await pumpApp(
        t,
        YeuCauChiTietScreen(yeuCauId: 245, api: api, moLink: (_) async {}),
      );
      await _cho(t);

      await t.tap(find.byKey(const Key('sale-huy-yeu-cau')));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const Key('sale-huy-yeu-cau-ly-do')),
        'Khách đổi nhu cầu',
      );
      await t.tap(find.byKey(const Key('sale-xac-nhan-huy-yeu-cau')));
      await t.pumpAndSettle();

      expect(api.daChuyen, 'dong');
      expect(api.lyDoDong, 'Khách đổi nhu cầu');
      expect(find.byKey(const Key('sale-yeu-cau-da-huy')), findsOneWidget);
      expect(find.text('Đã hủy · Khách đổi nhu cầu'), findsOneWidget);
      expect(find.byKey(const Key('sale-huy-yeu-cau')), findsNothing);
      expect(find.byKey(const Key('sale-chuyen-trang-thai')), findsNothing);
    });
  });

  group('Màn 4 — khách hàng', () {
    testWidgets('ba con số + thẻ khách chưa có tài khoản', (t) async {
      _manRong(t);
      final api = _ApiGia();
      await pumpApp(t, KhachHangSaleScreen(api: api));
      await _cho(t);

      expect(find.text('128'), findsOneWidget);
      expect(find.text('86'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(
        find.text(
          '3 yêu cầu · Gần nhất: Đã xác nhận lịch xem · Chưa có tài khoản',
        ),
        findsOneWidget,
      );

      await t.tap(find.text('Đã thuê (42)'));
      await _cho(t);
      expect(api.tabDaGoi.last, 'da_thue');
    });

    testWidgets('thêm khách gửi đúng tên và SĐT', (t) async {
      _manRong(t, cao: 3000);
      final api = _ApiGia();
      await pumpApp(t, KhachHangSaleScreen(api: api));
      await _cho(t);

      await t.tap(find.byKey(const Key('sale-them-khach')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('sale-kh-ten')), 'Lê Thảo Vy');
      await t.enterText(find.byKey(const Key('sale-kh-sdt')), '0936333222');
      await t.tap(find.byKey(const Key('sale-kh-luu')));
      await _cho(t);

      expect(api.daThemKhach!['ho_ten'], 'Lê Thảo Vy');
      expect(api.daThemKhach!['sdt'], '0936333222');
    });
  });

  group('Yêu cầu sinh từ lịch xem khách tự đặt', () {
    testWidgets(
      'lịch còn chờ → nút chính là xác nhận lịch, không tự chuyển bước',
      (t) async {
        _manRong(t, cao: 3200);
        await pumpApp(
          t,
          YeuCauChiTietScreen(
            yeuCauId: 245,
            api: _ApiGia(
              chiTietMap: {
                ..._chiTietMau(trangThai: 'lead_moi'),
                'appointment_id': 50,
              },
            ),
            moLink: (_) async {},
          ),
        );
        await _cho(t);
        expect(find.byKey(const Key('sale-xac-nhan-lich')), findsOneWidget);
        expect(find.text('Xem & xác nhận lịch xem'), findsOneWidget);
        expect(find.byKey(const Key('sale-chuyen-trang-thai')), findsNothing);
      },
    );

    testWidgets(
      'lịch đã xác nhận → vẫn chuyển bước bình thường, có lối về lịch',
      (t) async {
        _manRong(t, cao: 3200);
        await pumpApp(
          t,
          YeuCauChiTietScreen(
            yeuCauId: 245,
            api: _ApiGia(chiTietMap: {..._chiTietMau(), 'appointment_id': 50}),
            moLink: (_) async {},
          ),
        );
        await _cho(t);
        expect(find.byKey(const Key('sale-xac-nhan-lich')), findsNothing);
        expect(find.byKey(const Key('sale-mo-lich-xem')), findsOneWidget);
        expect(find.byKey(const Key('sale-chuyen-trang-thai')), findsOneWidget);
      },
    );
  });

  testWidgets('muốn thuê → Sale có lối gửi hợp đồng và ảnh cọc', (t) async {
    _manRong(t, cao: 3200);
    await pumpApp(
      t,
      YeuCauChiTietScreen(
        yeuCauId: 245,
        api: _ApiGia(
          chiTietMap: {
            ..._chiTietMau(trangThai: 'muon_thue'),
            'appointment_id': 50,
            'journey_id': 6,
          },
        ),
        moLink: (_) async {},
      ),
    );
    await _cho(t);
    expect(find.byKey(const Key('sale-gui-ho-so-chot')), findsOneWidget);
    expect(find.text('Hợp đồng & ảnh cọc'), findsOneWidget);
  });

  group('Chọn căn cho khách', () {
    testWidgets('khay chọn căn có hai nguồn, căn đã gắn không bấm lại', (
      t,
    ) async {
      _manRong(t, cao: 3000);
      final api = _ApiGia();
      await pumpApp(
        t,
        YeuCauChiTietScreen(yeuCauId: 245, api: api, moLink: (_) async {}),
      );
      await _cho(t);

      await t.tap(find.byKey(const Key('sale-them-can')));
      await t.pumpAndSettle();

      expect(find.text('Toà liên kết (2)'), findsOneWidget);
      expect(find.text('Bài đăng của tôi (1)'), findsOneWidget);
      expect(find.text('Phòng A12'), findsOneWidget);
      // Căn đã gắn rồi thì hiện nhãn, không mời bấm lần nữa.
      expect(find.text('Đã thêm'), findsOneWidget);

      await t.tap(find.byKey(const Key('sale-can-phong-77')));
      await _cho(t);
      expect(api.daGanCan, [(null, 77)]);
    });

    testWidgets('đổi sang tab bài đăng thấy tin của chính sale', (t) async {
      _manRong(t, cao: 3000);
      await pumpApp(
        t,
        YeuCauChiTietScreen(
          yeuCauId: 245,
          api: _ApiGia(),
          moLink: (_) async {},
        ),
      );
      await _cho(t);
      await t.tap(find.byKey(const Key('sale-them-can')));
      await t.pumpAndSettle();

      await t.tap(find.text('Bài đăng của tôi (1)'));
      await t.pumpAndSettle();
      expect(find.text('Căn hộ 3PN 82m² tầng trung'), findsOneWidget);
      expect(find.text('Phòng A12'), findsNothing);
    });

    testWidgets('chưa chọn căn khách thuê thì nút chốt nói rõ và bị tắt', (
      t,
    ) async {
      _manRong(t, cao: 3200);
      await pumpApp(
        t,
        YeuCauChiTietScreen(
          yeuCauId: 245,
          api: _ApiGia(
            chiTietMap: _chiTietMau(trangThai: 'cho_coc', coCanChot: false),
          ),
          moLink: (_) async {},
        ),
      );
      await _cho(t);

      expect(find.text('Chọn căn khách thuê trước'), findsOneWidget);
      final nut = t.widget<ButtonStyleButton>(
        find.byKey(const Key('sale-chuyen-trang-thai')),
      );
      expect(nut.onPressed, isNull);
    });
  });

  group('Màn 5 — toà liên kết & doanh thu', () {
    testWidgets('toà, bốn ô tiền và giao dịch gần đây', (t) async {
      _manRong(t, cao: 3200);
      await pumpApp(t, ToaDoanhThuSaleScreen(api: _ApiGia()));
      await _cho(t);

      expect(find.text('Masteri Thảo Điền'), findsOneWidget);
      expect(find.text('24 phòng · 8 phòng trống'), findsOneWidget);
      expect(find.text('1 toà · 12 chủ nhà'), findsOneWidget);
      expect(find.text('320 triệu'), findsWidgets);
      expect(find.text('18 triệu'), findsWidgets);
      expect(find.text('YC-0245 · Lê Thảo Vy'), findsOneWidget);
    });

    testWidgets('chưa liên kết toà nào thì chỉ đường, không để màn trống', (
      t,
    ) async {
      _manRong(t, cao: 3000);
      final rong = Map<String, dynamic>.from(_toaMau())
        ..['toa'] = []
        ..['so_chu_lien_ket'] = 0;
      await pumpApp(t, ToaDoanhThuSaleScreen(api: _ApiGia(toaDt: rong)));
      await _cho(t);

      expect(find.text('Chưa liên kết toà nào'), findsOneWidget);
      expect(find.textContaining('Nhận mã mời từ chủ nhà'), findsOneWidget);
    });
  });
}
