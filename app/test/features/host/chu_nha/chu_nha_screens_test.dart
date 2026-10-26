import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/services/chu_nha_api.dart';
import 'package:house_booking/data/services/ho_so_phong_api.dart';
import 'package:house_booking/features/host/chu_nha/chi_tiet_phong_chu_nha_screen.dart';
import 'package:house_booking/features/host/chu_nha/nha_va_phong_screen.dart';
import 'package:house_booking/features/host/chu_nha/quyet_dinh_sau_xem_screen.dart';
import 'package:house_booking/features/host/chu_nha/tao_hop_dong_screen.dart';
import 'package:house_booking/features/host/chu_nha/tong_quan_chu_nha_v2_screen.dart';
import 'package:house_booking/features/host/chu_nha/yeu_cau_tu_sale_screen.dart';

import '../../../helpers/pump_app.dart';

/// Bộ màn "Góc nhìn Chủ nhà" (mockup 04/10/2026): Tổng quan · Nhà & phòng ·
/// Chi tiết phòng · Yêu cầu từ Sale · Quyết định sau khi xem · Tạo hợp đồng.

Map<String, dynamic> _sale(String ten) => {
  'id': 3,
  'ten': ten,
  'sdt': '0901111002',
  'so_lan_xem_xong': 120,
  'danh_gia': 4.9,
};

Map<String, dynamic> _lich(
  int id,
  String kieu, {
  String tt = 'pending',
  String ngay = '2099-10-10',
  String? ketQua,
  bool quaGio = false,
}) => {
  'id': id,
  'kieu': kieu,
  'loai': 'xem',
  'trang_thai': tt,
  'ngay': ngay,
  'gio': '10:00-10:30',
  'qua_gio': quaGio,
  'phong': {'id': 305, 'ten': 'Phòng 305 - Tòa A', 'anh': null},
  'sale': _sale(kieu == 'chot' ? 'Lê Minh' : 'Nguyễn Thảo'),
  'ghi_chu': 'Khách đi xem cuối tuần, rất quan tâm',
  'ket_qua': ketQua,
  'ghi_chu_ket_qua': '',
  'gia_thue': 5000000,
};

class _ApiGia extends ChuNhaApi {
  final goi = <String>[];

  @override
  Future<TongQuanChuNha> tongQuan() async => TongQuanChuNha.fromMap({
    'ten': 'Anh Minh',
    'so_toa': 3,
    'dang_thue': 12,
    'phong_trong': 4,
    'co_lich_xem': 3,
    'sap_tra': 2,
    'doanh_thu_thang': 25500000,
    'doanh_thu_tang': 12,
    'thang': 10,
    'can_xac_nhan': [_lich(1, 'lich_xem'), _lich(2, 'chot', tt: 'completed')],
  });

  @override
  Future<YeuCauChuNha> yeuCau() async => YeuCauChuNha.fromMap({
    'lich_xem': [_lich(1, 'lich_xem'), _lich(4, 'lich_xem')],
    'chot': [_lich(2, 'chot', tt: 'completed')],
    'khac': <Map>[],
    'giao_dich': <Map>[],
  });

  @override
  Future<PhongCuaToa> phong({int? buildingId}) async => PhongCuaToa.fromMap({
    'toa': [
      {'id': 1, 'ten': 'Tòa A', 'dia_chi': '123 Đường X'},
    ],
    'toa_chon': 1,
    'phong': [
      for (final (id, tang, tt) in const [
        (101, '1', 'dang_thue'),
        (102, '1', 'trong'),
        (103, '1', 'co_lich_xem'),
        (201, '2', 'dang_thue'),
      ])
        {
          'id': id,
          'code': 'P$id',
          'tang': tang,
          'dien_tich': 25,
          'gia': 4500000,
          'trang_thai': tt,
        },
    ],
    'dem': {'tat_ca': 4, 'dang_thue': 2, 'trong': 1, 'co_lich_xem': 1},
  });

  @override
  Future<({List<LichChuNha> sapToi, List<LichChuNha> daQua})> lichXemPhong(
    int roomId,
  ) async => (
    sapToi: [
      LichChuNha.fromMap(_lich(1, 'lich_xem')),
      LichChuNha.fromMap(_lich(5, 'lich_xem', tt: 'approved')),
    ],
    daQua: [
      LichChuNha.fromMap(
        _lich(
          6,
          'lich_xem',
          tt: 'completed',
          ngay: '2024-10-05',
          ketQua: 'khong_chot',
          quaGio: true,
        ),
      ),
    ],
  );

  @override
  Future<void> duyetLich(int id) async => goi.add('duyet $id');

  @override
  Future<void> ghiKetQua(
    int id, {
    required bool muonThue,
    String ghiChu = '',
  }) async => goi.add('ket-qua $id $muonThue $ghiChu');

  @override
  Future<int> taoHopDong(
    int appointmentId, {
    required double giaThue,
    required int soThang,
    required DateTime ngayBatDau,
    required double tienCoc,
    required int ngayThanhToan,
    String? hinhThuc,
  }) async {
    goi.add(
      'hop-dong $appointmentId ${giaThue.toInt()} $soThang '
      '${ngayBatDau.toIso8601String().substring(0, 10)} ${tienCoc.toInt()} '
      '$ngayThanhToan $hinhThuc',
    );
    return 77;
  }
}

class _HoSoGia extends HoSoPhongApi {
  @override
  Future<HoSoPhong> lay(int roomId) async => HoSoPhong.fromMap({
    'room': {
      'id': 305,
      'building_id': 1,
      'code': 'P305',
      'area_m2': 25,
      'base_price': 4500000,
      'loai_phong': 'Studio',
      'tang': '3',
      'images': <String>[],
      'created_at': '2026-01-01T00:00:00',
      'updated_at': '2026-01-01T00:00:00',
    },
    'toa': {'id': 1, 'ten': 'Tòa A', 'dia_chi': '123 Đường X'},
    'hop_dong': {
      'id': 9,
      'bat_dau': '2026-09-01',
      'ket_thuc': '2027-08-31',
      'tien_thue': 4500000,
      'tien_coc': 9000000,
      'con_lai_ngay': 300,
    },
    'hoa_don': <Map>[],
  });
}

Future<void> _dung(
  WidgetTester t,
  Widget man, {
  Size co = const Size(400, 1300),
}) async {
  t.view.physicalSize = co;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await pumpApp(t, man);
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('1. Tổng quan: 4 ô số, doanh thu, cần xác nhận', (t) async {
    final api = _ApiGia();
    await _dung(t, TongQuanChuNhaV2Screen(api: api));
    expect(find.text('Xin chào, Anh Minh'), findsOneWidget);
    expect(find.text('Chủ nhà · 3 tòa nhà'), findsOneWidget);
    for (final s in ['Đang thuê', 'Phòng trống', 'Có lịch xem', 'Sắp trả']) {
      expect(find.text(s), findsOneWidget);
    }
    expect(find.text('25.500.000đ'), findsOneWidget);
    expect(find.text('+12%'), findsOneWidget);
    expect(find.text('Cần xác nhận (2)'), findsOneWidget);
    expect(find.text('Xác nhận lịch xem'), findsOneWidget);
    expect(find.text('Xác nhận chốt phòng'), findsOneWidget);
    await t.tap(find.byKey(const Key('xac-nhan-1')));
    await t.pump();
    expect(api.goi, ['duyet 1']);
  });

  testWidgets('2. Nhà & phòng: gom theo tầng, lọc chip', (t) async {
    await _dung(t, NhaVaPhongScreen(api: _ApiGia()));
    expect(find.text('Tầng 1'), findsOneWidget);
    expect(find.text('Tầng 2'), findsOneWidget);
    expect(find.text('Phòng 101'), findsOneWidget);
    expect(find.text('25 m² • 4.500.000đ'), findsNWidgets(4));
    await t.tap(find.byKey(const Key('loc-trong')));
    await t.pump();
    expect(find.text('Phòng 101'), findsNothing);
    expect(find.text('Phòng 102'), findsOneWidget);
  });

  testWidgets('3. Chi tiết phòng: tab Lịch xem sắp tới / đã qua', (t) async {
    await _dung(
      t,
      ChiTietPhongChuNhaScreen(
        roomId: 305,
        api: _ApiGia(),
        hoSoApi: _HoSoGia(),
      ),
    );
    expect(find.text('Phòng 305 - Tòa A'), findsOneWidget);
    expect(find.text('Lịch xem (2)'), findsOneWidget);
    expect(find.text('Chờ xác nhận'), findsOneWidget);
    expect(find.text('Đã xác nhận'), findsOneWidget);
    expect(find.text('Lịch xem đã qua'), findsOneWidget);
    expect(find.text('Khách: [ẩn thông tin]'), findsNWidgets(3));
    await t.tap(find.byKey(const Key('tab-phong-2')));
    await t.pump();
    expect(find.text('4.500.000đ/tháng'), findsWidgets);
  });

  testWidgets('4. Yêu cầu từ Sale: ba tab và thẻ sale', (t) async {
    await _dung(t, YeuCauTuSaleScreen(api: _ApiGia()));
    expect(find.text('Lịch xem (2)'), findsOneWidget);
    expect(find.text('Yêu cầu chốt (1)'), findsOneWidget);
    expect(find.text('Yêu cầu xác nhận lịch xem'), findsNWidgets(2));
    expect(find.text('Nguyễn Thảo'), findsNWidgets(2));
    expect(find.text('(120 lượt)'), findsNWidgets(2));
    await t.tap(find.byKey(const Key('tab-yeu-cau-1')));
    await t.pump();
    expect(find.text('Yêu cầu xác nhận chốt phòng'), findsOneWidget);
    expect(find.text('Giá thuê: 5.000.000đ/tháng'), findsOneWidget);
    expect(find.text('Xem chi tiết'), findsOneWidget);
  });

  testWidgets('5→6. Khách muốn thuê → tạo hợp đồng 3 bước → gửi', (t) async {
    final api = _ApiGia();
    final lich = LichChuNha.fromMap(
      _lich(2, 'ghi_ket_qua', tt: 'approved', quaGio: true),
    );
    await _dung(t, QuyetDinhSauXemScreen(lich: lich, api: api));
    expect(find.text('Khách đã xem phòng'), findsOneWidget);
    await t.tap(find.byKey(const Key('khach-muon-thue')));
    await t.pump();
    await t.tap(find.byKey(const Key('xac-nhan-ket-qua')));
    await t.pumpAndSettle();
    expect(api.goi, ['ket-qua 2 true ']);
    expect(find.byType(TaoHopDongScreen), findsOneWidget);
    expect(
      find.text('Thông tin được Sale cung cấp', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('[ẩn thông tin]'), findsNWidgets(3));
    await t.enterText(find.byKey(const Key('o-gia-thue')), '4500000');
    await t.pump();
    expect(find.text('4.500.000'), findsOneWidget);
    await t.tap(find.byKey(const Key('tiep-tuc')));
    await t.pump();
    expect(find.text('Hình thức thanh toán'), findsOneWidget);
    await t.tap(find.byKey(const Key('tiep-tuc')));
    await t.pump();
    expect(find.text('Xác nhận hợp đồng'), findsOneWidget);
    await t.tap(find.byKey(const Key('tiep-tuc')));
    await t.pumpAndSettle();
    expect(api.goi.last, startsWith('hop-dong 2 4500000 12 '));
    expect(find.text('Đã gửi hợp đồng cho khách'), findsOneWidget);
  });

  testWidgets('golden 360px: sáu màn chủ nhà', (t) async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final api = _ApiGia();
    final lich = LichChuNha.fromMap(_lich(2, 'chot', tt: 'completed'));
    for (final (ten, man) in <(String, Widget)>[
      ('tong_quan', TongQuanChuNhaV2Screen(api: api, onXemTatCa: () {})),
      ('nha_va_phong', NhaVaPhongScreen(api: api)),
      (
        'chi_tiet_phong',
        ChiTietPhongChuNhaScreen(roomId: 305, api: api, hoSoApi: _HoSoGia()),
      ),
      ('yeu_cau_tu_sale', YeuCauTuSaleScreen(api: api)),
      ('quyet_dinh', QuyetDinhSauXemScreen(lich: lich, api: api)),
      (
        'tao_hop_dong',
        TaoHopDongScreen(
          lich: lich,
          api: api,
          dienTich: 25,
          homNay: DateTime(2024, 10, 8),
        ),
      ),
    ]) {
      t.view.physicalSize = const Size(360, 760);
      t.view.devicePixelRatio = 1;
      await pumpApp(t, KeyedSubtree(key: ValueKey(ten), child: man));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull, reason: ten);
      await expectLater(
        find.byKey(ValueKey(ten)),
        matchesGoldenFile('goldens/chu_nha_$ten.png'),
      );
    }
    t.view.reset();
  });
}
