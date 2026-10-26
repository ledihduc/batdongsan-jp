/// Hồ sơ phòng thuê tháng — dựng theo mockup "Hồ sơ phòng P101" (11/09/2026).
///
/// Điều phải giữ:
/// * Chủ phòng xem phòng có hợp đồng: đủ khối như mockup, số là số server trả.
/// * Sale / người không xem được tài chính: không có tên khách, SĐT, tiền, nút
///   lập hoá đơn hay trả phòng — và không vẽ ô trống thế chỗ.
/// * Nút làm việc thật: lập hoá đơn gọi đúng hợp đồng, ghi sửa chữa / tài sản /
///   kỳ thanh toán gửi đúng dữ liệu rồi nạp lại, đánh dấu xong gọi đúng mục.
/// * Không tràn chữ trên điện thoại 360px.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/room_model.dart';
import 'package:house_booking/data/services/cho_thue_ngoai_api.dart';
import 'package:house_booking/data/services/ho_so_phong_api.dart';
import 'package:house_booking/data/services/kenh_khai_thac_api.dart';
import 'package:house_booking/features/host/property/providers/contract_provider.dart';
import 'package:house_booking/features/host/property/screens/ho_so_phong_screen.dart';
import 'package:house_booking/features/host/property/screens/room_detail_screen.dart';

import '../../helpers/pump_app.dart';

class _CtnGia extends ChoThueNgoaiApi {
  _CtnGia();

  Map<String, Object?>? daDanhDau;
  int? daGo;

  @override
  Future<ChoThueNgoai> danhDau(
    int roomId, {
    String tenKhach = '',
    String sdt = '',
    String? ngayBatDau,
    int soThang = 12,
    double? giaThue,
    double? cocDaThu,
    int? ngayThanhToan,
    String? ghiChu,
  }) async {
    daDanhDau = {
      'room': roomId,
      'ten': tenKhach,
      'sdt': sdt,
      'so_thang': soThang,
      'gia': giaThue,
      'ngay_thu': ngayThanhToan,
    };
    return ChoThueNgoai(contractId: 77, roomId: roomId, trangThaiPhong: 'occupied');
  }

  @override
  Future<void> boDanhDau(int roomId) async {
    daGo = roomId;
  }
}

class _ApiGia extends HoSoPhongApi {
  _ApiGia(this.hs);

  HoSoPhong hs;
  int soLanNap = 0;
  int? hopDongLapHoaDon;
  final ghi = <Map<String, Object?>>[];
  final xong = <int>[];
  final taiSanMoi = <Map<String, Object?>>[];
  ({int? ngay, String? hinhThuc, double? coc})? thanhToan;

  @override
  Future<HoSoPhong> lay(int roomId) async {
    soLanNap++;
    return hs;
  }

  @override
  Future<({int invoiceId, bool daCo})> lapHoaDonThangNay(int contractId) async {
    hopDongLapHoaDon = contractId;
    // Dừng ở đây: màn hoá đơn gọi mạng thật, không cần cho điều test này giữ.
    throw Exception('mạng');
  }

  @override
  Future<SuaChua> ghiSuaChua(
    int roomId, {
    required String tieuDe,
    required String ngay,
    String? moTa,
    String? nguoiThucHien,
    double? chiPhi,
    bool dangXuLy = false,
  }) async {
    ghi.add({'room': roomId, 'tieu_de': tieuDe, 'chi_phi': chiPhi, 'dang_xu_ly': dangXuLy});
    return SuaChua(id: 99, tieuDe: tieuDe, ngay: ngay);
  }

  @override
  Future<SuaChua> danhDauXong(int id) async {
    xong.add(id);
    return SuaChua(id: id, tieuDe: 'x', ngay: '2026-09-01');
  }

  @override
  Future<TaiSan> themTaiSan(
    int roomId, {
    required String ten,
    String? loai,
    String? thongSo,
    String tinhTrang = 'tot',
    String? ghiChu,
  }) async {
    taiSanMoi.add({
      'room': roomId,
      'ten': ten,
      'loai': loai,
      'thong_so': thongSo,
      'tinh_trang': tinhTrang,
    });
    return TaiSan(id: 50, ten: ten);
  }

  @override
  Future<void> capNhatThanhToan(
    int contractId, {
    required int? ngayThanhToan,
    required String? hinhThuc,
    required double? cocDaThu,
  }) async {
    thanhToan = (ngay: ngayThanhToan, hinhThuc: hinhThuc, coc: cocDaThu);
  }
}

class _KenhGia extends KenhKhaiThacApi {
  const _KenhGia();

  @override
  Future<List<KenhKhaiThac>> cuaPhong(int roomId) async => const [];
}

final _luc = DateTime(2026, 9, 1);

RoomModel _phong({
  String tinhTrang = 'dang_o',
  String status = 'occupied',
  List<String> loai = const ['dai_han'],
}) => RoomModel(
  id: 5,
  buildingId: 1,
  code: 'P101',
  areaM2: 32,
  capacity: 2,
  basePrice: 5000000,
  status: status,
  images: const [],
  createdAt: _luc,
  updatedAt: _luc,
  tinhTrang: tinhTrang,
  loai: loai,
  giaKenh: 5000000,
  donVi: 'thang',
  tang: '1',
  huong: 'southeast',
  loaiPhong: 'Studio 1PN',
  doTrongPhong: const ['dieu_hoa', 'nong_lanh', 'tu_lanh', 'giuong', 'ban_cong'],
);

const _toa = (id: 1, ten: 'An Cư Garden', diaChi: '25 Hoàng Văn Thụ · Ba Đình');

HopDongHienTai _hopDong({bool daKhai = true}) => HopDongHienTai(
  id: 9,
  batDau: '2025-10-01',
  ketThuc: '2026-11-10',
  tienThue: 5000000,
  tienCoc: 5000000,
  tongThang: 13,
  daOThang: 11,
  conLaiNgay: 60,
  tyLe: 80,
  soNguoi: 2,
  khach: const KhachChinh(
    tenantId: 3,
    ten: 'Nguyễn Văn An',
    sdt: '0982345678',
    coCccd: true,
    cccdDuoi: '029',
  ),
  ngayThanhToan: daKhai ? 5 : null,
  hinhThucThanhToan: daKhai ? 'ca_hai' : null,
  cocDaThu: daKhai ? 5000000 : null,
);

HoSoPhong _hoSoChu({
  List<SuaChua> suaChua = const [
    SuaChua(
      id: 1,
      tieuDe: 'Vệ sinh bảo dưỡng điều hoà',
      ngay: '2026-06-15',
      moTa: 'Bơm gas, làm sạch lưới lọc.',
      nguoiThucHien: 'KTV Tuấn',
      chiPhi: 150000,
    ),
  ],
  int ton = 0,
  bool daKhai = true,
}) => HoSoPhong(
  room: _phong(),
  toa: _toa,
  xemTaiChinh: true,
  suaDuoc: true,
  hopDong: _hopDong(daKhai: daKhai),
  hoaDonGanNhat: const HoaDonGanNhat(
    id: 21,
    so: 'INV-202608-C9',
    ky: '2026-08',
    tong: 2650000,
    daTra: 2650000,
    trangThai: 'paid',
    hanDong: '2026-08-12',
  ),
  dienNuoc: const DienNuocPhong(
    thang: '2026-09',
    ngayChot: '2026-09-10',
    readingId: 4,
    dienCu: 732,
    dienMoi: 852,
    dienDung: 120,
    nuocCu: 110,
    nuocMoi: 125,
    nuocDung: 15,
    giaDien: 3000,
    giaNuoc: 12000,
    trangThai: 'da_duyet',
  ),
  taiSan: const [
    TaiSan(id: 1, loai: 'dieu_hoa', ten: 'Điều hòa Daikin', thongSo: '12000 BTU • Inverter'),
    TaiSan(id: 2, loai: 'nong_lanh', ten: 'Bình nóng lạnh', thongSo: 'Ariston 20L'),
  ],
  suaChua: suaChua,
  suaChuaTon: ton,
);

Future<_ApiGia> _mo(
  WidgetTester t,
  HoSoPhong hs, {
  double rong = 390,
  ChoThueNgoaiApi? ctn,
  bool taoHopDongDuoc = true,
}) async {
  t.view.physicalSize = Size(rong, 3200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  final api = _ApiGia(hs);
  await pumpApp(
    t,
    HoSoPhongScreen(
      room: hs.room,
      contractProvider: ContractProvider(),
      api: api,
      kenhApi: const _KenhGia(),
      onSua: () async {},
      onXoa: () async {},
      onNhanBan: () async {},
      onBaoTri: () async {},
      onKetThucBaoTri: () async {},
      onChiSo: () async {},
      onTaoHopDong: taoHopDongDuoc ? () async {} : null,
      choThueNgoaiApi: ctn ?? const ChoThueNgoaiApi(),
    ),
    auth: SignedInAuthProvider(id: 62),
  );
  await t.pump();
  await t.pump();
  return api;
}

void main() {
  testWidgets('chủ phòng có hợp đồng: đủ khối như mockup', (t) async {
    await _mo(t, _hoSoChu());
    for (final s in [
      'Hồ sơ phòng P101',
      'An Cư Garden • Tầng 1',
      'Giá thuê niêm yết',
      'Studio 1PN • 32 m²',
      'Có ban công',
      'Sửa tin',
      'Diện tích',
      '32 m²',
      'Vị trí',
      'Tầng 1',
      'Hướng',
      'Đông Nam',
      'Số người ở',
      '2 người',
      'KHÁCH THUÊ HIỆN TẠI',
      'Nguyễn Văn An',
      'Hợp đồng dài hạn',
      '0982 345 678 • CCCD: xxxxxxxxx029',
      'Xem HĐ',
      'Lập HĐơn',
      'Gọi điện',
      'TÀI CHÍNH & TIỀN CỌC PHÒNG',
      'Tiền cọc giữ chỗ (Cọc 1T)',
      'Đã đóng đủ',
      'Kỳ thanh toán',
      'Ngày 05 hàng tháng',
      'Chuyển khoản / Tiền mặt',
      'ĐỒNG HỒ ĐIỆN & NƯỚC P101',
      'Kỳ chốt: 10/09/2026',
      '120 kWh',
      '15 m³',
      'Chi tiết',
      'TÀI SẢN & NỘI THẤT BÀN GIAO',
      // 2 món đã ghi + tủ lạnh, giường tờ khai nói có mà chưa ghi chi tiết;
      // ban công là đặc điểm căn phòng, không phải đồ bàn giao.
      '4 thiết bị đã bàn giao biên bản',
      'Điều hòa Daikin',
      '12000 BTU • Inverter',
      'Tủ lạnh',
      'Chưa ghi thông số',
      'Xem tất cả 4 tài sản & tình trạng hao mòn',
      'LỊCH SỬ SỬA CHỮA & SỰ CỐ',
      'Không có lỗi tồn',
      'Vệ sinh bảo dưỡng điều hoà',
      'Trả phòng & Chốt sổ',
      'Lập hóa đơn tháng này',
    ]) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    expect(find.textContaining('Còn 2 tháng (Hạn 10/11)'), findsOneWidget);
    expect(find.textContaining('2.650.000đ'), findsOneWidget);
    expect(find.text('Đã thanh toán'), findsOneWidget);
    expect(find.text('Chi phí: 150.000đ'), findsOneWidget);
    // Kênh khai thác không có trong mockup — ở menu ⋮, không chiếm chỗ trên màn.
    expect(find.text('KÊNH KHAI THÁC'), findsNothing);
    expect(find.byTooltip('Chia sẻ phòng'), findsOneWidget);
  });

  testWidgets('sale xem: không thấy người, tiền, điện nước — không vẽ ô trống', (t) async {
    await _mo(
      t,
      HoSoPhong(room: _phong(), toa: _toa, xemTaiChinh: false, suaDuoc: true),
    );
    expect(find.text('Đang có khách thuê'), findsOneWidget);
    expect(find.text('Thông tin người thuê do chủ nhà quản lý'), findsOneWidget);
    for (final s in [
      'TÀI CHÍNH & TIỀN CỌC PHÒNG',
      'Lập hóa đơn tháng này',
      'Trả phòng & Chốt sổ',
      'Gọi điện',
      'Xem HĐ',
      'Kỳ thanh toán',
    ]) {
      expect(find.text(s), findsNothing, reason: s);
    }
    expect(find.textContaining('ĐỒNG HỒ ĐIỆN'), findsNothing);
  });

  testWidgets('phòng trống: mời tạo hợp đồng, cho chuyển bảo trì', (t) async {
    await _mo(
      t,
      HoSoPhong(
        room: _phong(tinhTrang: 'trong', status: 'vacant'),
        toa: _toa,
        xemTaiChinh: true,
        suaDuoc: true,
      ),
    );
    expect(find.text('Chưa có khách thuê'), findsOneWidget);
    expect(find.text('Sẵn sàng cho thuê'), findsOneWidget);
    expect(find.text('Tạo hợp đồng'), findsOneWidget);
    expect(find.text('Chuyển bảo trì'), findsOneWidget);
    expect(find.text('Lập hóa đơn tháng này'), findsNothing);
    // Hai khối tiền / điện nước VẪN có mặt, nói rõ bắt đầu từ đâu — ẩn hẳn thì
    // chủ nhà tưởng dài hạn không có quản lý hoá đơn và ảnh công tơ.
    expect(find.text('TÀI CHÍNH & TIỀN CỌC PHÒNG'), findsOneWidget);
    expect(find.text('Chưa có hợp đồng thuê'), findsOneWidget);
    expect(find.text('ĐỒNG HỒ ĐIỆN & NƯỚC P101'), findsOneWidget);
    expect(find.text('Chưa có người thuê gửi ảnh công tơ'), findsOneWidget);
    expect(find.text('Ghi số công tơ lúc bàn giao'), findsOneWidget);
    // Chưa có hợp đồng thì chưa "bàn giao biên bản". Ban công là đặc điểm căn
    // phòng, không đếm là thiết bị.
    expect(find.text('4 thiết bị trong phòng'), findsOneWidget);
  });

  testWidgets('phòng trống: đánh dấu ĐÃ CHO THUÊ NGOÀI APP gửi đúng dữ liệu', (t) async {
    final ctn = _CtnGia();
    final api = await _mo(
      t,
      HoSoPhong(
        room: _phong(tinhTrang: 'trong', status: 'vacant'),
        toa: _toa,
        xemTaiChinh: true,
        suaDuoc: true,
      ),
      ctn: ctn,
    );
    final napTruoc = api.soLanNap;
    await t.tap(find.byKey(const ValueKey('cho-thue-ngoai')));
    await t.pumpAndSettle();
    expect(find.text('Đã cho thuê ngoài app · P101'), findsOneWidget);

    await t.enterText(find.widgetWithText(TextField, 'Tên khách thuê'), 'Chị Lan');
    await t.tap(find.byKey(const ValueKey('ctn-luu')));
    await t.pumpAndSettle();

    expect(ctn.daDanhDau!['room'], 5);
    expect(ctn.daDanhDau!['ten'], 'Chị Lan');
    // Giá điền sẵn từ giá phòng đang rao — chủ nhà khỏi gõ lại con số app đã biết.
    expect(ctn.daDanhDau!['gia'], 5000000);
    expect(api.soLanNap, greaterThan(napTruoc), reason: 'phải nạp lại hồ sơ');
  });

  testWidgets('hợp đồng ngoài luồng: nói rõ trên thẻ và gỡ được', (t) async {
    final ctn = _CtnGia();
    await _mo(
      t,
      HoSoPhong(
        room: _phong(),
        toa: _toa,
        xemTaiChinh: true,
        suaDuoc: true,
        hopDong: HopDongHienTai(
          id: 9,
          batDau: '2026-01-10',
          ketThuc: '2027-01-09',
          tienThue: 5000000,
          tienCoc: 5000000,
          soNguoi: 1,
          ngoaiLuong: true,
          ghiChu: 'Thuê qua Facebook, chưa làm giấy tờ',
          khach: const KhachChinh(tenantId: 1, ten: 'Chị Lan', sdt: '0900000101'),
        ),
      ),
      ctn: ctn,
    );
    expect(find.text('Cho thuê ngoài app'), findsOneWidget);
    expect(find.text('Hợp đồng dài hạn'), findsNothing);
    expect(find.text('Thuê qua Facebook, chưa làm giấy tờ'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('menu-ho-so')));
    await t.pumpAndSettle();
    await t.tap(find.text('Bỏ đánh dấu cho thuê ngoài'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('xac-nhan-bo-ctn')));
    await t.pumpAndSettle();
    expect(ctn.daGo, 5);
  });

  testWidgets('hoá đơn: liệt kê các kỳ và đếm kỳ chưa thu xong', (t) async {
    await _mo(
      t,
      HoSoPhong(
        room: _phong(),
        toa: _toa,
        xemTaiChinh: true,
        suaDuoc: true,
        hopDong: _hopDong(),
        hoaDon: const [
          HoaDonGanNhat(id: 31, so: 'HD-9', ky: '2026-09', tong: 2700000,
              daTra: 0, trangThai: 'sent', hanDong: '2026-10-05'),
          HoaDonGanNhat(id: 21, so: 'HD-8', ky: '2026-08', tong: 2650000,
              daTra: 2650000, trangThai: 'paid', hanDong: '2026-09-05'),
        ],
      ),
    );
    expect(find.text('Hoá đơn gần đây · 1 kỳ chưa thu xong'), findsOneWidget);
    expect(find.textContaining('Hóa đơn T9/2026'), findsOneWidget);
    expect(find.textContaining('Hóa đơn T8/2026'), findsOneWidget);
    expect(find.text('Đã thanh toán'), findsOneWidget);
    expect(find.text('Chưa thanh toán'), findsOneWidget);
    expect(find.text('Xem tất cả'), findsOneWidget);
  });

  testWidgets('Lập hóa đơn tháng này mở bước chốt chỉ số điện nước', (t) async {
    final api = await _mo(t, _hoSoChu());
    await t.tap(find.byKey(const ValueKey('lap-hoa-don')));
    // pumpAndSettle treo ở đây: màn Điện nước gọi mạng thật rồi quay vòng tải,
    // nên chỉ pump đủ số nhịp cho route mở ra.
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    // Không tạo hoá đơn nháp ngay nữa: chỉ số điện nước phải chốt trước, nếu
    // không hoá đơn gửi đi thiếu tiền điện mà không ai kịp thấy.
    expect(api.hopDongLapHoaDon, isNull);
    expect(find.text('Bước 1 · Chốt chỉ số'), findsOneWidget);
    expect(find.byKey(const ValueKey('tiep-tuc-hoa-don')), findsOneWidget);
  });

  testWidgets('cọc chưa ghi nhận: bấm ô cọc → "Đã đóng đủ" → gửi đúng số', (t) async {
    final api = await _mo(t, _hoSoChu(daKhai: false));
    expect(find.text('Chưa ghi nhận — bấm để ghi'), findsOneWidget);
    expect(find.text('Chưa đặt ngày thu'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('o-tien-coc')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('tt-ht-chuyen_khoan')));
    await t.tap(find.byKey(const ValueKey('tt-coc-du')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('luu-thanh-toan')));
    await t.pumpAndSettle();
    expect(api.thanhToan, (ngay: null, hinhThuc: 'chuyen_khoan', coc: 5000000.0));
    expect(api.soLanNap, greaterThanOrEqualTo(2));
  });

  testWidgets('+ Thêm tài sản: chọn loại tự điền tên, gửi thông số + tình trạng', (t) async {
    final api = await _mo(t, _hoSoChu());
    await t.tap(find.byKey(const ValueKey('them-tai-san')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('ts-loai-may_giat')));
    await t.pump();
    final ten = t.widget<TextField>(find.byKey(const ValueKey('ts-ten')));
    expect(ten.controller!.text, 'Máy giặt');
    await t.enterText(find.byKey(const ValueKey('ts-ten')), 'Máy giặt LG');
    await t.enterText(find.byKey(const ValueKey('ts-thong-so')), '8kg Inverter');
    await t.tap(find.byKey(const ValueKey('ts-tt-hao_mon')));
    await t.tap(find.byKey(const ValueKey('luu-tai-san')));
    await t.pumpAndSettle();
    expect(api.taiSanMoi.single, {
      'room': 5,
      'ten': 'Máy giặt LG',
      'loai': 'may_giat',
      'thong_so': '8kg Inverter',
      'tinh_trang': 'hao_mon',
    });
    expect(api.soLanNap, greaterThanOrEqualTo(2));
  });

  testWidgets('Ghi sửa chữa: gửi đúng dữ liệu rồi nạp lại hồ sơ', (t) async {
    final api = await _mo(t, _hoSoChu());
    await t.tap(find.byKey(const ValueKey('ghi-sua-chua')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('sc-tieu-de')), 'Hỏng khoá cửa');
    await t.enterText(find.byKey(const ValueKey('sc-chi-phi')), '200000');
    await t.tap(find.byKey(const ValueKey('luu-sua-chua')));
    await t.pumpAndSettle();
    expect(api.ghi.single['tieu_de'], 'Hỏng khoá cửa');
    expect(api.ghi.single['chi_phi'], 200000);
    expect(api.soLanNap, greaterThanOrEqualTo(2));
  });

  testWidgets('việc đang xử lý: đếm ở nhãn và "Đánh dấu xong" gọi đúng mục', (t) async {
    final api = await _mo(
      t,
      _hoSoChu(
        suaChua: const [
          SuaChua(
            id: 7,
            tieuDe: 'Điều hoà chảy nước',
            ngay: '2026-09-01',
            trangThai: 'dang_xu_ly',
          ),
        ],
        ton: 1,
      ),
    );
    expect(find.text('1 việc đang xử lý'), findsOneWidget);
    await t.tap(find.text('Đánh dấu xong'));
    await t.pump();
    expect(api.xong, [7]);
  });

  test('chỉ phòng NGẮN HẠN thuần giữ màn chi tiết cũ', () {
    expect(laPhongThueThang(_phong()), isTrue);
    expect(laPhongThueThang(_phong(loai: const [])), isTrue);
    expect(laPhongThueThang(_phong(loai: const ['kinh_doanh'])), isTrue);
    expect(laPhongThueThang(_phong(loai: const ['ngan_han', 'dai_han'])), isTrue);
    expect(laPhongThueThang(_phong(loai: const ['ngan_han', 'khach_san'])), isFalse);
  });

  for (final rong in [360.0, 390.0]) {
    testWidgets('điện thoại ${rong.toInt()}px: không tràn chữ', (t) async {
      await _mo(t, _hoSoChu(), rong: rong);
      expect(t.takeException(), isNull);
      expect(find.text('Lập hóa đơn tháng này'), findsOneWidget);
    });
  }
}
