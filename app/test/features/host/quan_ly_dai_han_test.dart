import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/services/quan_ly_dai_han_api.dart';
import 'package:house_booking/features/host/quan_ly_dai_han/doanh_thu_screen.dart';
import 'package:house_booking/features/host/quan_ly_dai_han/hoa_don_screen.dart';
import 'package:house_booking/features/host/quan_ly_dai_han/hop_dong_screen.dart';
import 'package:house_booking/features/host/quan_ly_dai_han/khach_hang_screen.dart';

import '../../helpers/pump_app.dart';

/// BỐN MÀN "Quản lý cho thuê dài hạn": Khách hàng · Hợp đồng · Hóa đơn · Doanh thu.
///
/// Điều phải giữ bằng test:
///   * màn hiện đúng con số SERVER đếm, không tự cộng lại (hai chỗ đếm là hai
///     số khác nhau ở cùng một toà);
///   * đổi chip lọc / tab thì GỌI LẠI server kèm đúng tham số, không lọc cục bộ
///     trên trang đang có — lọc cục bộ thì trang 2 trở đi mất dữ liệu;
///   * hoá đơn hiện đủ bốn khoản tiền phòng · điện · nước · dịch vụ và hạn thu;
///   * nút "Tạo hóa đơn" chỉ hiện khi CÒN hợp đồng chưa lập, và báo lại số vừa
///     lập — kể cả phần lập không được;
///   * toà chưa có số liệu thì nói rõ, không vẽ biểu đồ rỗng không chú thích.
class _Gia extends QuanLyDaiHanApi {
  _Gia({
    this.khach,
    this.hd,
    this.hoaDonData,
    this.doanhThuData,
    this.taoKq,
  });

  final KhachHangToa? khach;
  final HopDongToa? hd;
  final HoaDonToa? hoaDonData;
  final DoanhThuToa? doanhThuData;
  final TaoHoaDonKetQua? taoKq;

  final List<({String tim, String loc})> goiKhach = [];
  final List<String> goiHopDong = [];
  final List<String> goiHoaDon = [];
  final List<String?> goiDoanhThu = [];
  int soLanTao = 0;

  @override
  Future<KhachHangToa> khachHang(
    int buildingId, {
    String tim = '',
    String loc = 'tat_ca',
  }) async {
    goiKhach.add((tim: tim, loc: loc));
    return khach ?? const KhachHangToa();
  }

  @override
  Future<HopDongToa> hopDong(int buildingId, {String tab = 'hieu_luc'}) async {
    goiHopDong.add(tab);
    return hd ?? const HopDongToa();
  }

  @override
  Future<HoaDonToa> hoaDon(
    int buildingId, {
    String? thang,
    String tab = 'chua_thu',
  }) async {
    goiHoaDon.add(tab);
    return hoaDonData ?? const HoaDonToa();
  }

  @override
  Future<DoanhThuToa> doanhThu(int buildingId, {String? thang}) async {
    goiDoanhThu.add(thang);
    return doanhThuData ?? const DoanhThuToa(thang: '2026-09');
  }

  @override
  Future<TaoHoaDonKetQua> taoHoaDonThang(
    int buildingId, {
    String? thang,
  }) async {
    soLanTao++;
    return taoKq ?? const TaoHoaDonKetQua(thang: '2026-09', vuaLap: 2);
  }
}

KhachHangToa _khachMau() => KhachHangToa.fromMap({
  'tom_tat': {'dang_o': 12, 'sap_het_hd': 2, 'co_cong_no': 1},
  'danh_sach': [
    {
      'contract_id': 1,
      'ten': 'Nguyễn Văn An',
      'phong': 'P101',
      'sdt': '0987654321',
      'trang_thai': 'dang_o',
      'so_thang_da_o': 8,
      'no': null,
    },
    {
      'contract_id': 2,
      'ten': 'Trần Thị Bình',
      'phong': 'P203',
      'sdt': '0902345678',
      'trang_thai': 'sap_het_hd',
      'so_thang_da_o': 11,
      'no': 2500000,
    },
  ],
});

HopDongToa _hopDongMau() => HopDongToa.fromMap({
  'tom_tat': {
    'hieu_luc': 12,
    'sap_het_han': 2,
    'cho_gia_han': 0,
    'da_ket_thuc': 3,
  },
  'danh_sach': [
    {
      'id': 9,
      'phong': 'P101',
      'khach': 'Nguyễn Văn An',
      'tu': '2026-01-01',
      'den': '2027-01-10',
      'gia_thue': 4800000,
      'tien_coc': 9600000,
      'nhom': 'hieu_luc',
      'nhan': 'Còn 3 tháng',
      'tong_thang': 12,
      'da_qua_thang': 9,
      'con_thang': 3,
      'phan_tram': 75,
    },
  ],
});

HoaDonToa _hoaDonMau({bool conPhaiTao = true}) => HoaDonToa.fromMap({
  'thang': '2026-09',
  'tom_tat': {
    'chua_tao': conPhaiTao ? 1 : 0,
    'chua_thu': 3,
    'qua_han': 1,
    'da_thu': 1,
    'tong_can_thu': 4800000,
  },
  'danh_sach': [
    {
      'id': 31,
      'phong': 'P101',
      'khach': 'Nguyễn Văn An',
      'ky': 'Tháng 9/2026',
      'trang_thai': 'qua_han',
      'nhan': 'Quá hạn 4 ngày',
      'tien_phong': 4800000,
      'dien': 320000,
      'nuoc': 120000,
      'dich_vu': 100000,
      'tong': 5340000,
      'da_thu': 0,
      'con_lai': 5340000,
      'han': '2026-10-05',
      'da_gui': true,
    },
  ],
  'chua_tao': conPhaiTao
      ? [
          {
            'contract_id': 7,
            'phong': 'P305',
            'khach': 'Lê Minh Đức',
            'gia_thue': 4200000,
            'ngay_thanh_toan': 5,
          },
        ]
      : [],
});

DoanhThuToa _doanhThuMau() => DoanhThuToa.fromMap({
  'thang': '2026-09',
  'doanh_thu': 48500000,
  'da_thu': 42700000,
  'da_thu_phan_tram': 88,
  'chua_thu': 5800000,
  'chua_thu_phan_tram': 12,
  'qua_han': 1200000,
  'sau_thang': [
    {'thang': '2026-04', 'nhan': 'T4', 'tien': 32100000},
    {'thang': '2026-05', 'nhan': 'T5', 'tien': 36800000},
    {'thang': '2026-06', 'nhan': 'T6', 'tien': 41200000},
    {'thang': '2026-07', 'nhan': 'T7', 'tien': 45000000},
    {'thang': '2026-08', 'nhan': 'T8', 'tien': 47600000},
    {'thang': '2026-09', 'nhan': 'T9', 'tien': 48500000},
  ],
  'co_cau': [
    {'ma': 'tien_phong', 'nhan': 'Tiền phòng', 'tien': 38400000, 'phan_tram': 79},
    {'ma': 'dien_nuoc', 'nhan': 'Điện nước', 'tien': 6800000, 'phan_tram': 14},
    {'ma': 'dich_vu', 'nhan': 'Dịch vụ', 'tien': 3300000, 'phan_tram': 7},
  ],
  'top_phong': [
    {'phong': 'P101', 'tien': 5300000},
    {'phong': 'P203', 'tien': 5100000},
  ],
  'cong_no': [
    {'phong': 'P203', 'tien': 2500000},
  ],
});

Future<void> _mo(WidgetTester t, Widget man, {double cao = 2200}) async {
  t.view.physicalSize = Size(430, cao);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await pumpApp(t, man);
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  // ── MÀN 1 — Khách hàng ────────────────────────────────────────────────────
  testWidgets('khách hàng: ba con số + danh sách kèm công nợ', (t) async {
    final api = _Gia(khach: _khachMau());
    await _mo(
      t,
      KhachHangToaScreen(
        buildingId: 5,
        buildingName: 'Vua Nhà Demo Residence',
        api: api,
      ),
    );

    expect(find.text('Vua Nhà Demo Residence'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('khách đang ở'), findsOneWidget);
    expect(find.text('sắp hết HĐ'), findsOneWidget);
    expect(find.text('có công nợ'), findsOneWidget);
    expect(find.text('Nguyễn Văn An'), findsOneWidget);
    expect(find.text('P101  •  0987654321'), findsOneWidget);
    expect(find.text('Đã ở 8 tháng'), findsOneWidget);
    expect(find.text('Sắp hết hạn'), findsOneWidget);
    expect(find.text('Còn nợ 2,5tr'), findsOneWidget);
  });

  testWidgets('khách hàng: đổi chip lọc thì hỏi lại server', (t) async {
    final api = _Gia(khach: _khachMau());
    await _mo(
      t,
      KhachHangToaScreen(buildingId: 5, buildingName: 'Toà A', api: api),
    );
    await t.tap(find.byKey(const Key('ql-chip-co_cong_no')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));

    expect(api.goiKhach.map((e) => e.loc).toList(), ['tat_ca', 'co_cong_no']);
  });

  testWidgets('khách hàng: gõ tìm kiếm rồi enter thì gửi từ khoá', (t) async {
    final api = _Gia(khach: _khachMau());
    await _mo(
      t,
      KhachHangToaScreen(buildingId: 5, buildingName: 'Toà A', api: api),
    );
    await t.enterText(find.byKey(const Key('khach-tim')), 'bình');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));

    expect(api.goiKhach.last.tim, 'bình');
  });

  // ── MÀN 2 — Hợp đồng ──────────────────────────────────────────────────────
  testWidgets('hợp đồng: thẻ có giá thuê, cọc và tiến độ', (t) async {
    final api = _Gia(hd: _hopDongMau());
    await _mo(
      t,
      HopDongToaScreen(buildingId: 5, buildingName: 'Toà A', api: api),
    );

    expect(find.text('HĐ hiệu lực'), findsOneWidget);
    expect(find.text('HĐ sắp hết hạn'), findsOneWidget);
    expect(find.text('P101'), findsOneWidget);
    expect(find.text('Còn 3 tháng'), findsNWidgets(2)); // chip + dòng tiến độ
    expect(find.text('01/01/2026 - 10/01/2027'), findsOneWidget);
    expect(find.text('4.800.000đ/tháng'), findsOneWidget);
    expect(find.text('9.600.000đ'), findsOneWidget);
    expect(find.text('Đã qua 9 tháng'), findsOneWidget);
  });

  testWidgets('hợp đồng: bốn tab, đổi tab là hỏi lại server', (t) async {
    final api = _Gia(hd: _hopDongMau());
    await _mo(
      t,
      HopDongToaScreen(buildingId: 5, buildingName: 'Toà A', api: api),
    );
    for (final tab in ['sap_het_han', 'cho_gia_han', 'da_ket_thuc']) {
      await t.tap(find.byKey(Key('ql-chip-$tab')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(api.goiHopDong, [
      'hieu_luc',
      'sap_het_han',
      'cho_gia_han',
      'da_ket_thuc',
    ]);
  });

  // ── MÀN 3 — Hóa đơn ───────────────────────────────────────────────────────
  testWidgets('hóa đơn: đủ bốn khoản, tổng cộng và hạn thu', (t) async {
    final api = _Gia(hoaDonData: _hoaDonMau());
    await _mo(
      t,
      HoaDonToaScreen(buildingId: 5, buildingName: 'Toà A', api: api),
    );

    expect(find.text('chưa thu'), findsOneWidget);
    expect(find.text('quá hạn'), findsOneWidget);
    expect(find.text('Tổng cần thu'), findsOneWidget);
    expect(find.text('Quá hạn 4 ngày'), findsOneWidget);
    expect(find.text('Tháng 9/2026'), findsOneWidget);
    for (final nhan in ['Tiền phòng', 'Điện', 'Nước', 'Dịch vụ']) {
      expect(find.text(nhan), findsOneWidget, reason: nhan);
    }
    expect(find.text('5.340.000đ'), findsOneWidget);
    expect(find.text('05/10/2026'), findsOneWidget);
  });

  testWidgets('hóa đơn: nháp chưa gửi thì nói "Chưa gửi khách"', (t) async {
    // Nháp vẫn tính vào tiền phải thu, nhưng khách chưa nhận được gì — gắn
    // "Chưa thanh toán" là đổ lỗi cho người chưa thấy hoá đơn.
    final api = _Gia(
      hoaDonData: HoaDonToa.fromMap({
        'thang': '2026-09',
        'tom_tat': {'chua_thu': 1, 'qua_han': 0, 'tong_can_thu': 3300000},
        'danh_sach': [
          {
            'id': 44,
            'phong': 'P101',
            'khach': 'Phạm Minh Tuấn',
            'ky': 'Tháng 9/2026',
            'trang_thai': 'chua_thanh_toan',
            'nhan': 'Chưa thanh toán',
            'tien_phong': 3200000,
            'dich_vu': 100000,
            'tong': 3300000,
            'han': '2026-10-05',
            'da_gui': false,
          },
        ],
        'chua_tao': [],
      }),
    );
    await _mo(
      t,
      HoaDonToaScreen(buildingId: 5, buildingName: 'Toà A', api: api),
    );
    expect(find.text('Chưa gửi khách'), findsOneWidget);
    expect(find.text('Chưa thanh toán'), findsNothing);
  });

  testWidgets('hóa đơn: lập đủ rồi thì KHÔNG còn nút tạo', (t) async {
    await _mo(
      t,
      HoaDonToaScreen(
        buildingId: 5,
        buildingName: 'Toà A',
        api: _Gia(hoaDonData: _hoaDonMau(conPhaiTao: false)),
      ),
    );
    expect(find.byKey(const Key('hd-tao-thang-nay')), findsNothing);
  });

  testWidgets('hóa đơn: còn phòng chưa lập thì có nút tạo kèm tên kỳ', (
    t,
  ) async {
    await _mo(
      t,
      HoaDonToaScreen(
        buildingId: 5,
        buildingName: 'Toà A',
        api: _Gia(hoaDonData: _hoaDonMau()),
      ),
    );
    expect(find.byKey(const Key('hd-tao-thang-nay')), findsOneWidget);
    expect(find.text('Tạo hóa đơn tháng 9/2026'), findsOneWidget);
  });

  testWidgets('hóa đơn: bấm tạo thì gọi server và báo lại kết quả', (t) async {
    final api = _Gia(
      hoaDonData: _hoaDonMau(),
      taoKq: const TaoHoaDonKetQua(thang: '2026-09', vuaLap: 2),
    );
    await _mo(
      t,
      HoaDonToaScreen(buildingId: 5, buildingName: 'Toà A', api: api),
    );
    await t.tap(find.byKey(const Key('hd-tao-thang-nay')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));

    expect(api.soLanTao, 1);
    expect(find.text('Đã lập 2 hóa đơn cho tháng 9/2026.'), findsOneWidget);
  });

  testWidgets('hóa đơn: phòng lập không được phải được nói ra', (t) async {
    final api = _Gia(
      hoaDonData: _hoaDonMau(),
      taoKq: const TaoHoaDonKetQua(
        thang: '2026-09',
        vuaLap: 1,
        khongLapDuoc: [(phong: 'P305', viSao: 'Chưa chốt chỉ số điện')],
      ),
    );
    await _mo(
      t,
      HoaDonToaScreen(buildingId: 5, buildingName: 'Toà A', api: api),
    );
    await t.tap(find.byKey(const Key('hd-tao-thang-nay')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));

    expect(
      find.textContaining('1 phòng chưa lập được: P305'),
      findsOneWidget,
    );
  });

  testWidgets('hóa đơn: tab "Chưa tạo" liệt kê hợp đồng, không phải hoá đơn', (
    t,
  ) async {
    final api = _Gia(hoaDonData: _hoaDonMau());
    await _mo(
      t,
      HoaDonToaScreen(buildingId: 5, buildingName: 'Toà A', api: api),
    );
    await t.tap(find.byKey(const Key('ql-chip-chua_tao')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('hd-chua-tao-7')), findsOneWidget);
    expect(find.text('P305'), findsOneWidget);
    expect(find.text('Thu ngày 5'), findsOneWidget);
    expect(api.goiHoaDon.last, 'chua_tao');
  });

  // ── MÀN 4 — Doanh thu ─────────────────────────────────────────────────────
  testWidgets('doanh thu: bốn con số, biểu đồ 6 tháng, cơ cấu và hai bảng', (
    t,
  ) async {
    final api = _Gia(doanhThuData: _doanhThuMau());
    await _mo(
      t,
      DoanhThuToaScreen(
        buildingId: 5,
        buildingName: 'Toà A',
        api: api,
        thang: '2026-09',
      ),
      cao: 2600,
    );

    expect(find.text('Tháng 9/2026'), findsOneWidget);
    expect(find.text('48,5tr'), findsOneWidget);
    expect(find.text('Đã thu (88%)'), findsOneWidget);
    expect(find.text('Chưa thu (12%)'), findsOneWidget);
    expect(find.text('1,2tr'), findsOneWidget);
    expect(find.text('Doanh thu 6 tháng gần nhất'), findsOneWidget);
    for (final t9 in ['T4', 'T5', 'T6', 'T7', 'T8', 'T9']) {
      expect(find.text(t9), findsOneWidget, reason: t9);
    }
    expect(find.text('Cơ cấu doanh thu tháng 9/2026'), findsOneWidget);
    expect(find.text('Tiền phòng'), findsOneWidget);
    expect(find.text('79%'), findsOneWidget);
    expect(find.text('Top phòng doanh thu cao'), findsOneWidget);
    expect(find.text('Công nợ cần chú ý'), findsOneWidget);
    expect(find.text('2,5tr'), findsOneWidget);
  });

  testWidgets('doanh thu: đổi tháng thì hỏi lại đúng kỳ', (t) async {
    final api = _Gia(doanhThuData: _doanhThuMau());
    await _mo(
      t,
      DoanhThuToaScreen(
        buildingId: 5,
        buildingName: 'Toà A',
        api: api,
        thang: '2026-09',
      ),
      cao: 2600,
    );
    await t.tap(find.byKey(const Key('dt-thang-truoc')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));

    expect(api.goiDoanhThu, ['2026-09', '2026-08']);
  });

  testWidgets('doanh thu: toà chưa có số liệu vẫn vẽ đủ 6 cột, không treo', (
    t,
  ) async {
    final api = _Gia(
      doanhThuData: DoanhThuToa.fromMap({
        'thang': '2026-09',
        'doanh_thu': 0,
        'sau_thang': [
          for (var m = 4; m <= 9; m++)
            {'thang': '2026-0$m', 'nhan': 'T$m', 'tien': 0},
        ],
        'co_cau': [
          {'ma': 'tien_phong', 'nhan': 'Tiền phòng', 'tien': 0, 'phan_tram': 0},
        ],
        'top_phong': [],
        'cong_no': [],
      }),
    );
    await _mo(
      t,
      DoanhThuToaScreen(
        buildingId: 5,
        buildingName: 'Toà A',
        api: api,
        thang: '2026-09',
      ),
      cao: 2600,
    );

    expect(find.text('Chưa có doanh thu'), findsOneWidget);
    expect(find.text('Không có công nợ'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
