import 'package:flutter/material.dart';
import 'package:house_booking/data/services/so_chu_nha_api.dart';
import 'package:house_booking/features/host/so_chu_nha/trang_chu_chu_nha_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/data/models/building_model.dart';
import 'package:house_booking/data/models/viewing_appointment_model.dart';
import 'package:house_booking/data/services/quan_ly_api.dart';
import 'package:house_booking/data/services/management_read_model_api.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/data/services/tong_quan_chu_nha_api.dart';
import 'package:house_booking/features/guest/quan_ly/quan_ly_theo_vai_tro_screen.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/data/services/sale_yeu_cau_api.dart';
import 'package:house_booking/data/services/hoat_dong_khach_api.dart';
import 'package:house_booking/data/services/chu_nha_api.dart' as cn;
import 'package:house_booking/data/services/sale_van_hanh_api.dart';
import 'package:house_booking/features/host/chu_nha/tong_quan_chu_nha_v2_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/sale_hoat_dong_screen.dart';

import '../../../helpers/pump_app.dart';

class _AuthBaVai extends AuthProvider {
  @override
  UserModel get currentUser => UserModel(
    id: 7,
    name: 'Nguyễn Minh Anh',
    email: 'minhanh@test.local',
    passwordHash: '',
    phone: '',
    avatarPath: '',
    // Tài khoản thường sử dụng đủ ba vai mà không cần đăng ký hoặc duyệt Sale.
    role: 'guest',
    accountType: 'customer',
  );

  @override
  bool get isAuthenticated => true;
}

class _QuanLyGia extends QuanLyApi {
  @override
  Future<TongHopQuanLy> tongHop(GocQuanLy goc) async => TongHopQuanLy(
    dem: const DemQuanLy(daDat: 2, canXuLy: 1, dangO: 1),
    danhSach: [
      MucQuanLy(
        loai: 'thue_dai_han',
        id: 31,
        tieuDe: 'Phòng 305 · Vạn Phúc Residence',
        diaChi: '12 Nguyễn Thị Thập, Quận 7, TP.HCM',
        nhom: NhomQuanLy.dangO,
        kenh: 'dai_han',
        batDau: DateTime(2026, 9, 1),
        ketThuc: DateTime(2027, 8, 31),
      ),
      MucQuanLy(
        loai: 'xem_nha',
        id: 41,
        tieuDe: 'Căn hộ Riverside',
        diaChi: '5 Võ Văn Ngân, TP. Thủ Đức, TP.HCM',
        nhom: NhomQuanLy.daDat,
        batDau: DateTime(2030, 10, 5, 10),
      ),
      MucQuanLy(
        loai: 'xem_nha',
        id: 42,
        tieuDe: 'Phòng 102 · Green Home',
        diaChi: 'Quận 1, TP.HCM',
        nhom: NhomQuanLy.lichSu,
        dong: 'Đã xem · 20/09',
        batDau: DateTime(2026, 9, 20, 9),
      ),
      MucQuanLy(
        loai: 'dat_phong',
        id: 51,
        tieuDe: 'Homestay Đà Lạt',
        diaChi: 'Phường 1, Đà Lạt',
        nhom: NhomQuanLy.dangO,
        kenh: 'ngan_han',
        batDau: DateTime(2026, 10, 3, 14),
        ketThuc: DateTime(2026, 10, 4, 12),
      ),
    ],
  );
}

class _SaleGia extends RentalJourneyApi {
  @override
  Future<List<ViewingAppointmentModel>> workQueue({
    required String view,
    String? date,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async => const [];

  @override
  Future<List<RentalJourney>> list({
    required String view,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async => const [];
}

class _HoatDongGia extends HoatDongKhachApi {
  @override
  Future<HoatDongKhach> lay() async =>
      const HoatDongKhach(lichXemSapToi: 2, hoaDonCanTra: 1, hopDongSapHet: 1);
}

/// Tab "Hoạt động" của sale (mockup 05/10/2026) — số liệu cố định, ghi lại
/// kênh đã hỏi để kiểm công tắc Ngắn hạn | Dài hạn.
class _SaleVanHanhGia extends SaleVanHanhApi {
  final kenhDaGoi = <String>[];

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
          'thoi_gian': '2026-10-08T09:00',
          'nhan': 'Chờ xác nhận',
          'tong': 'cam',
        },
      ],
    });
  }
}

final _saleVanHanh = _SaleVanHanhGia();

/// Tab "Hoạt động" của chủ nhà = Tổng quan chủ nhà (06/10/2026).
class _ChuNhaV2Gia extends cn.ChuNhaApi {
  @override
  Future<cn.TongQuanChuNha> tongQuan() async => cn.TongQuanChuNha.fromMap({
    'ten': 'Anh Minh',
    'so_toa': 3,
    'dang_thue': 12,
    'phong_trong': 4,
    'co_lich_xem': 3,
    'sap_tra': 2,
    'doanh_thu_thang': 25500000,
    'doanh_thu_tang': 12,
    'thang': 10,
    'can_xac_nhan': [],
  });
}

final _chuNhaV2 = _ChuNhaV2Gia();

/// Tab "Hoạt động" của chủ nhà = Sổ chủ nhà (06/10/2026).
class _SoChuNhaGia extends SoChuNhaApi {
  @override
  Future<TrangChuCN> trangChu(String kenh) async => TrangChuCN.fromMap({
    'kenh': kenh, 'ten': 'Anh Minh', 'thang': 10,
    'doanh_thu': {'tien': 25500000, 'tang': 12},
    'so': {'toa_nha': 3, 'phong': 16, 'dang_thue': 12, 'sap_thu_tien': 2, 'sap_het_han': 1, 'phong_trong': 4},
    'viec': [],
  });
}

final _soChuNha = _SoChuNhaGia();

class _SaleYeuCauGia extends SaleYeuCauApi {
  @override
  Future<TongQuanSale> tongQuan() async => TongQuanSale.fromMap(const {
    'yeu_cau_moi': 0,
    'dang_xu_ly': 0,
    'cho_xem_nha': 0,
    'da_chot': 0,
    'doanh_thu_thang': 0,
    'hoa_hong_du_kien': 0,
    'phan_tram_hoa_hong': 50,
  });
}

class _ChuNhaGia extends TongQuanChuNhaApi {
  @override
  Future<TongQuanChuNha> lay({int? buildingId}) async => const TongQuanChuNha(
    soToa: 2,
    soPhong: 11,
    toaMoiThangNay: 0,
    daiHanDangThue: 2,
    daiHanTong: 11,
    daiHanLapDay: 18,
    nganHanHoatDong: 0,
    nganHanCongSuat: null,
    doanhThuThang: 28500000,
    doanhThuTang: null,
    thangTruoc: 8,
    daiHan: [],
    kinhDoanh: [],
    nganHan: [],
    toa: [],
    phongDaThue: 2,
    phongTrong: 9,
  );
}

class _BuildingsGia extends BuildingProvider {
  final _values = [
    BuildingModel(
      id: 5,
      hostId: 7,
      name: 'Tòa nhà An Cư Home',
      address: '123 Nguyễn Văn Linh',
      city: 'Đà Nẵng',
      district: 'Hải Châu',
      ward: '',
      soPhong: 11,
      soPhongTrong: 9,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];

  @override
  List<BuildingModel> get buildings => _values;

  @override
  bool get isLoading => false;

  @override
  String? get error => null;

  @override
  Future<void> fetchBuildings() async {}
}

class _ManagementV2Gia extends ManagementReadModelApi {
  _ManagementV2Gia({
    required this.enabled,
    this.shortStayEnabled = false,
    this.modes = const ['customer'],
  });

  final bool enabled;
  final bool shortStayEnabled;
  final List<String> modes;
  int capabilityCalls = 0;
  int summaryCalls = 0;
  final List<ManagementMode> summaryModes = [];

  @override
  Future<ManagementCapabilities> capabilities() async {
    capabilityCalls++;
    return ManagementCapabilities(
      activeMode: 'customer',
      modes: modes,
      managementV2Enabled: enabled,
      managementV2WritesEnabled: false,
      shortStayInventoryV2Enabled: shortStayEnabled,
    );
  }

  @override
  Future<ManagementSummary> summary({required ManagementMode mode}) async {
    summaryCalls++;
    summaryModes.add(mode);
    return ManagementSummary(
      contractVersion: 'manage-v2.1',
      mode: mode,
      counters: const {
        ManagementBucket.actionRequired: 2,
        ManagementBucket.waitingExternal: 1,
        ManagementBucket.upcoming: 3,
        ManagementBucket.afterViewing: 4,
        ManagementBucket.history: 5,
      },
      viewings: 9,
      rentalJourneys: 2,
      reservations: 1,
      contracts: 2,
      invoices: 4,
      longTerm: const LongTermCounters(
        total: 22,
        counters: {
          ManagementBucket.actionRequired: 2,
          ManagementBucket.waitingExternal: 1,
          ManagementBucket.upcoming: 3,
          ManagementBucket.afterViewing: 4,
          ManagementBucket.history: 5,
        },
      ),
      shortStay: const ShortStayCounters(
        total: 7,
        pending: 2,
        confirmed: 3,
        checkedIn: 1,
        history: 1,
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Chỉ nạp các biến thể đã đóng gói, trước mọi widget trong file này.
    await GoogleFonts.pendingFonts([
      for (final weight in [
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w600,
        FontWeight.w700,
      ])
        GoogleFonts.hankenGrotesk(fontWeight: weight),
      GoogleFonts.hankenGrotesk(fontStyle: FontStyle.italic),
      GoogleFonts.hankenGrotesk(
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
      ),
    ]);
  });
  testWidgets(
    'vai cố định theo đăng nhập: không còn công tắc, mỗi vai một sảnh',
    (t) async {
      // 360px là chiều ngang Android nhỏ phổ biến; dựng đủ ba vai để bắt cả lỗi
      // tràn ở banner và thẻ số. Đổi vai CHỈ xảy ra khi đăng nhập lại bằng vai
      // khác — ở đây mô phỏng bằng cách đổi giá trị cheDo từ shell.
      t.view.physicalSize = const Size(360, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);

      final mode = ValueNotifier<String>('customer');
      addTearDown(mode.dispose);

      await pumpApp(
        t,
        QuanLyTheoVaiTroScreen(
          cheDo: mode,
          coCheDoSale: true,
          coCheDoChuNha: true,
          quanLyApi: _QuanLyGia(),
          hoatDongKhachApi: _HoatDongGia(),
          saleApi: _SaleGia(),
          saleYeuCauApi: _SaleYeuCauGia(),
          saleVanHanhApi: _saleVanHanh,
          chuNhaV2Api: _chuNhaV2,
        soChuNhaApi: _soChuNha,
          chuNhaApi: _ChuNhaGia(),
          buildingProvider: _BuildingsGia(),
        ),
        auth: _AuthBaVai(),
      );
      await t.pump();
      await t.pump();

      // Khách hàng: trang "Hoạt động" theo mockup 03/10.
      expect(find.text('Hoạt động'), findsOneWidget);
      expect(find.byKey(const Key('chon-vai-tro-quan-ly')), findsNothing);
      expect(find.byKey(const Key('vai-tro-sale')), findsNothing);
      expect(find.byKey(const Key('vai-tro-owner')), findsNothing);
      expect(find.text('Đang thuê (1)'), findsOneWidget);
      expect(find.text('Phòng 305 – Vạn Phúc Residence'), findsOneWidget);
      expect(find.text('Quận 7, TP.HCM'), findsOneWidget);
      expect(find.text('Lịch xem phòng sắp tới (1)'), findsOneWidget);
      expect(find.text('Đã xác nhận'), findsOneWidget);
      expect(find.text('Lịch sử'), findsOneWidget);
      expect(find.text('Đã xem · 20/09/2026'), findsOneWidget);
      // Đơn lưu trú ngắn hạn không lẫn vào tab Dài hạn.
      expect(find.text('Homestay Đà Lạt'), findsNothing);
      await t.tap(find.byKey(const Key('khach-kenh-ngan')));
      await t.pump();
      expect(find.text('Đang ở (1)'), findsOneWidget);
      expect(find.text('Homestay Đà Lạt'), findsOneWidget);
      expect(find.text('Phòng 305 – Vạn Phúc Residence'), findsNothing);
      expect(find.byKey(const Key('banner-quan-ly-customer')), findsNothing);
      expect(find.text('Đăng ký Sale'), findsNothing);
      expect(find.byKey(const Key('banner-quan-ly-sale')), findsNothing);
      expect(find.byKey(const Key('owner-building-5')), findsNothing);

      mode.value = 'sale';
      await t.pump();
      await t.pump();
      // Sale: tab "Hoạt động" theo mockup 05/10/2026 — bộ màn riêng thay
      // bảng điều hành cũ (không còn banner / thẻ vai).
      expect(find.byType(SaleHoatDongScreen), findsOneWidget);
      expect(find.byKey(const Key('banner-quan-ly-sale')), findsNothing);
      expect(find.byKey(const Key('chon-vai-tro-quan-ly')), findsNothing);
      expect(find.text('Tổng quan (Dài hạn)', findRichText: true), findsOneWidget);
      expect(find.text('Cần xử lý hôm nay (1)', findRichText: true), findsOneWidget);
      expect(find.text('Khách Trần Minh'), findsOneWidget);
      expect(find.text('Thuê ở'), findsNothing);
      expect(find.byKey(const Key('owner-building-5')), findsNothing);

      mode.value = 'owner';
      await t.pump();
      await t.pump();
      // Chủ nhà: chung bộ tab, tab Hoạt động = Sổ chủ nhà + lối tắt.
      expect(find.byType(TrangChuChuNhaScreen), findsOneWidget);
      expect(find.byKey(const Key('chon-vai-tro-quan-ly')), findsNothing);
      expect(find.text('Xin chào, Minh 👋'), findsOneWidget);
      for (final s in ['Thu chi', 'Tổng quan dài hạn']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      expect(find.byKey(const Key('banner-quan-ly-sale')), findsNothing);
      expect(find.text('Thuê ở'), findsNothing);
    },
  );

  testWidgets('đăng nhập vai chưa được cấp thì rơi về sảnh Khách', (t) async {
    t.view.physicalSize = const Size(430, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final mode = ValueNotifier<String>('owner');
    addTearDown(mode.dispose);
    await pumpApp(
      t,
      QuanLyTheoVaiTroScreen(
        cheDo: mode,
        coCheDoSale: false,
        coCheDoChuNha: false,
        quanLyApi: _QuanLyGia(),
        hoatDongKhachApi: _HoatDongGia(),
      ),
      auth: _AuthBaVai(),
    );
    await t.pump();
    await t.pump();

    expect(find.text('Lịch xem phòng sắp tới (1)'), findsOneWidget);
    expect(find.text('Quản lý tòa nhà của bạn'), findsNothing);
    expect(find.byKey(const Key('chon-vai-tro-quan-ly')), findsNothing);
  });

  testWidgets('Management V2 chỉ hiện khi server bật feature flag', (t) async {
    // Panel nằm dưới bảng điều hành Sale — màn phải đủ cao để nó được dựng.
    t.view.physicalSize = const Size(430, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    // Khách hàng không còn panel này (mockup 24/09) — kiểm ở vai Sale.
    final mode = ValueNotifier<String>('sale');
    addTearDown(mode.dispose);

    final disabled = _ManagementV2Gia(
      enabled: false,
      modes: const ['customer', 'sale'],
    );
    await pumpApp(
      t,
      QuanLyTheoVaiTroScreen(
        key: const ValueKey('management-v2-off'),
        cheDo: mode,
        coCheDoSale: true,
        coCheDoChuNha: false,
        quanLyApi: _QuanLyGia(),
        hoatDongKhachApi: _HoatDongGia(),
        saleApi: _SaleGia(),
        saleYeuCauApi: _SaleYeuCauGia(),
        saleVanHanhApi: _saleVanHanh,
        chuNhaV2Api: _chuNhaV2,
        soChuNhaApi: _soChuNha,
        managementReadModelApi: disabled,
      ),
      auth: _AuthBaVai(),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const Key('management-v2-summary')), findsNothing);
    expect(disabled.capabilityCalls, 1);
    expect(disabled.summaryCalls, 0);

    final enabled = _ManagementV2Gia(
      enabled: true,
      modes: const ['customer', 'sale'],
    );
    await pumpApp(
      t,
      QuanLyTheoVaiTroScreen(
        key: const ValueKey('management-v2-on'),
        cheDo: mode,
        coCheDoSale: true,
        coCheDoChuNha: false,
        quanLyApi: _QuanLyGia(),
        hoatDongKhachApi: _HoatDongGia(),
        saleApi: _SaleGia(),
        saleYeuCauApi: _SaleYeuCauGia(),
        saleVanHanhApi: _saleVanHanh,
        chuNhaV2Api: _chuNhaV2,
        soChuNhaApi: _soChuNha,
        managementReadModelApi: enabled,
      ),
      auth: _AuthBaVai(),
    );
    await t.pumpAndSettle();

    expect(enabled.capabilityCalls, 1);
    expect(enabled.summaryCalls, 1);
    expect(find.byKey(const Key('management-v2-summary')), findsNothing);
    expect(find.text('Tình trạng hành trình'), findsNothing);
    expect(
      find.byKey(const Key('management-v2-open-work-items')),
      findsNothing,
    );
  });

  testWidgets('capability server khóa vai trò dù client legacy đang cho phép', (
    t,
  ) async {
    final mode = ValueNotifier<String>('owner');
    addTearDown(mode.dispose);
    await pumpApp(
      t,
      QuanLyTheoVaiTroScreen(
        cheDo: mode,
        coCheDoSale: true,
        coCheDoChuNha: true,
        quanLyApi: _QuanLyGia(),
        hoatDongKhachApi: _HoatDongGia(),
        chuNhaApi: _ChuNhaGia(),
        buildingProvider: _BuildingsGia(),
        managementReadModelApi: _ManagementV2Gia(enabled: true),
      ),
      auth: _AuthBaVai(),
    );
    await t.pumpAndSettle();

    // Server chỉ cấp vai customer → dù đăng nhập bằng vai Chủ nhà, sảnh mở ra
    // vẫn là của Khách.
    expect(find.text('Lịch xem phòng sắp tới (1)'), findsOneWidget);
    expect(find.text('Quản lý tòa nhà của bạn'), findsNothing);
  });

  testWidgets('ba dashboard V2 đều mở bằng mode server đã cấp', (t) async {
    final mode = ValueNotifier<String>('customer');
    addTearDown(mode.dispose);
    final api = _ManagementV2Gia(
      enabled: true,
      modes: const ['customer', 'sale', 'owner'],
    );
    await pumpApp(
      t,
      QuanLyTheoVaiTroScreen(
        cheDo: mode,
        coCheDoSale: true,
        coCheDoChuNha: true,
        quanLyApi: _QuanLyGia(),
        hoatDongKhachApi: _HoatDongGia(),
        saleApi: _SaleGia(),
        saleYeuCauApi: _SaleYeuCauGia(),
        saleVanHanhApi: _saleVanHanh,
        chuNhaV2Api: _chuNhaV2,
        soChuNhaApi: _soChuNha,
        chuNhaApi: _ChuNhaGia(),
        managementReadModelApi: api,
        buildingProvider: _BuildingsGia(),
      ),
      auth: _AuthBaVai(),
    );
    await t.pumpAndSettle();

    mode.value = 'sale';
    await t.pumpAndSettle();
    mode.value = 'owner';
    await t.pumpAndSettle();

    expect(api.capabilityCalls, 1);
    expect(api.summaryModes, [
      ManagementMode.customer,
      ManagementMode.sale,
      ManagementMode.owner,
    ]);
    expect(find.byType(TrangChuChuNhaScreen), findsOneWidget);
    expect(find.text('Xin chào, Minh 👋'), findsOneWidget);
  });

  testWidgets('ngắn hạn có lối vào và counter riêng cho đủ ba vai', (t) async {
    t.view.physicalSize = const Size(430, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final mode = ValueNotifier<String>('customer');
    addTearDown(mode.dispose);
    final api = _ManagementV2Gia(
      enabled: true,
      shortStayEnabled: true,
      modes: const ['customer', 'sale', 'owner'],
    );
    await pumpApp(
      t,
      QuanLyTheoVaiTroScreen(
        cheDo: mode,
        coCheDoSale: true,
        coCheDoChuNha: true,
        quanLyApi: _QuanLyGia(),
        hoatDongKhachApi: _HoatDongGia(),
        saleApi: _SaleGia(),
        saleYeuCauApi: _SaleYeuCauGia(),
        saleVanHanhApi: _saleVanHanh,
        chuNhaV2Api: _chuNhaV2,
        soChuNhaApi: _soChuNha,
        chuNhaApi: _ChuNhaGia(),
        managementReadModelApi: api,
        buildingProvider: _BuildingsGia(),
      ),
      auth: _AuthBaVai(),
    );
    await t.pumpAndSettle();

    // Khách hàng: Ngắn hạn | Dài hạn là dải chọn của trang Hoạt động.
    expect(find.byKey(const Key('chon-loai-van-hanh')), findsNothing);
    expect(find.byKey(const Key('khach-kenh-ngan')), findsOneWidget);

    mode.value = 'sale';
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('kenh-ngan-han')));
    await t.pumpAndSettle();
    expect(find.text('Tổng quan (Ngắn hạn)', findRichText: true), findsOneWidget);
    expect(_saleVanHanh.kenhDaGoi.last, 'ngan_han');

    mode.value = 'owner';
    await t.pumpAndSettle();
    expect(find.byKey(const Key('cn-mo-toa-nha')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('panel Management V2 không tràn ở mobile, tablet và desktop', (
    t,
  ) async {
    for (final size in const [
      Size(360, 900),
      Size(768, 1024),
      Size(1366, 900),
    ]) {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      final mode = ValueNotifier<String>('sale');
      addTearDown(mode.dispose);
      await pumpApp(
        t,
        QuanLyTheoVaiTroScreen(
          key: ValueKey('management-v2-responsive-${size.width}'),
          cheDo: mode,
          coCheDoSale: true,
          coCheDoChuNha: false,
          quanLyApi: _QuanLyGia(),
          hoatDongKhachApi: _HoatDongGia(),
          saleApi: _SaleGia(),
          saleYeuCauApi: _SaleYeuCauGia(),
          saleVanHanhApi: _saleVanHanh,
          chuNhaV2Api: _chuNhaV2,
        soChuNhaApi: _soChuNha,
          managementReadModelApi: _ManagementV2Gia(
            enabled: true,
            modes: const ['customer', 'sale'],
          ),
        ),
        auth: _AuthBaVai(),
      );
      await t.pumpAndSettle();

      expect(find.byKey(const Key('management-v2-summary')), findsNothing);
      expect(t.takeException(), isNull);
    }
    t.view.reset();
  });

  testWidgets('golden dashboard Management V2 trên ba breakpoint', (t) async {
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await materialIcons.load();
    const cases = <(String, Size)>[
      ('mobile', Size(360, 900)),
      ('tablet', Size(768, 1024)),
      ('desktop', Size(1366, 900)),
    ];

    for (final goldenCase in cases) {
      t.view.physicalSize = goldenCase.$2;
      t.view.devicePixelRatio = 1;
      final mode = ValueNotifier<String>('customer');
      await pumpApp(
        t,
        QuanLyTheoVaiTroScreen(
          key: ValueKey('management-v2-golden-${goldenCase.$1}'),
          cheDo: mode,
          coCheDoSale: false,
          coCheDoChuNha: false,
          quanLyApi: _QuanLyGia(),
          hoatDongKhachApi: _HoatDongGia(),
          managementReadModelApi: _ManagementV2Gia(enabled: true),
        ),
        auth: _AuthBaVai(),
      );
      await t.pumpAndSettle();

      await expectLater(
        find.byType(QuanLyTheoVaiTroScreen),
        matchesGoldenFile(
          'goldens/management_v2_dashboard_${goldenCase.$1}.png',
        ),
      );
      mode.dispose();
    }
    t.view.reset();
  });
}
