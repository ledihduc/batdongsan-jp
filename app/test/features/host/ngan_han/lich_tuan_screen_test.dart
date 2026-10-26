import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/lich_tuan_api.dart';
import 'package:house_booking/features/host/ngan_han/lich_tuan_screen.dart';

import '../../../helpers/pump_app.dart';

/// SƠ ĐỒ PHÒNG × NGÀY BỐN TUẦN.
///
/// Điều phải giữ:
///   * mỗi phòng một hàng, mỗi ngày một cột, ca là thanh bắc đúng số ngày;
///   * cột tên phòng GHIM — cuộn ngang tới ngày 20 vẫn biết hàng nào là phòng
///     nào (đây là lỗi đã thấy khi chạy thật trên bản lịch theo giờ);
///   * ca ngắn (4 tiếng) vẫn bấm được: bề rộng tối thiểu, không mỏng thành sợi;
///   * bấm lùi/tới nhảy đúng một kỳ 4 tuần, không nhảy một tuần.
class _ApiGia extends LichTuanApi {
  _ApiGia(this.du);

  Map<String, dynamic> du;
  final daHoi = <String?>[];

  @override
  Future<LichTuan> lay(int buildingId, {String? tuNgay, int soTuan = 4}) async {
    daHoi.add(tuNgay);
    return LichTuan.fromMap(du);
  }
}

Map<String, dynamic> _ngay(int i, {bool homNay = false}) {
  final d = DateTime(2026, 9, 14).add(Duration(days: i));
  return {
    'ngay': '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
    'thu': d.weekday,
    'hom_nay': homNay,
    'cuoi_tuan': d.weekday >= 6,
    'ban': homNay ? 1 : 0,
    'cong_suat': homNay ? 50.0 : 0.0,
  };
}

Map<String, dynamic> _du() => {
  'tu_ngay': '2026-09-14',
  'den_ngay': '2026-10-11',
  'so_tuan': 4,
  'so_ngay': 28,
  'bay_gio': '2026-09-16T10:00',
  'xem_tai_chinh': true,
  'toa': {'id': 10, 'ten': 'An Cư Garden', 'dia_chi': '25 Hoàng Văn Thụ'},
  'kpi': {
    'luot_dat': 5,
    'dem_ban': 9,
    'so_phong': 2,
    'cong_suat': 16.1,
    'doanh_thu': 4260000,
  },
  'ngay': [for (var i = 0; i < 28; i++) _ngay(i, homNay: i == 2)],
  'phong': [
    {
      'id': 1,
      'ma': 'GARDEN-01',
      'suc_chua': 2,
      'hang': 'Studio VIP',
      'muc': [
        {
          'loai': 'dat',
          'id': 88,
          'cot': 2.625,
          'so_cot': 0.1667,
          'tu_that': '2026-09-16T15:00',
          'den_that': '2026-09-16T19:00',
          'trang_thai': 'checked_in',
          'nhan_kieu': 'Theo giờ',
          'ten': 'Nguyễn Văn An',
          'tong': 280000,
        },
        {
          'loai': 'dat',
          'id': 89,
          'cot': 3.875,
          'so_cot': 0.625,
          'tu_that': '2026-09-17T21:00',
          'den_that': '2026-09-18T12:00',
          'trang_thai': 'approved',
          'nhan_kieu': 'Qua đêm',
          'ten': 'Trần Thị Mai Phương',
          'tong': 580000,
        },
      ],
    },
    {
      'id': 2,
      'ma': 'GARDEN-02',
      'suc_chua': 2,
      'hang': null,
      'muc': [
        {
          'loai': 'chan',
          'id': 5,
          'cot': 2.79,
          'so_cot': 0.04,
          'tu_that': '2026-09-16T19:00',
          'den_that': '2026-09-16T20:00',
          'ghi_chu': 'Dọn phòng',
        },
      ],
    },
  ],
};

Future<_ApiGia> _mo(WidgetTester t, [Map<String, dynamic>? du]) async {
  t.view.physicalSize = const Size(1100, 2200);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  final api = _ApiGia(du ?? _du());
  await pumpApp(
    t,
    LichTuanScreen(buildingId: 10, api: api, tuNgayBanDau: '2026-09-14'),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
  return api;
}

void main() {
  testWidgets('vẽ đủ 4 tuần, mỗi phòng một hàng', (t) async {
    await _mo(t);
    expect(find.text('Sơ đồ phòng 4 tuần'), findsOneWidget);
    expect(find.text('14/9 – 11/10'), findsOneWidget);
    expect(find.text('GARDEN-01'), findsOneWidget);
    expect(find.text('GARDEN-02'), findsOneWidget);
    // 4 tuần × 7 cột: nhãn thứ Hai xuất hiện 4 lần ở hàng đầu + 4 lần trong ô.
    expect(find.text('T2'), findsNWidgets(4));
  });

  testWidgets('khối ca nằm đúng phòng và bấm được', (t) async {
    await _mo(t);
    expect(find.byKey(const ValueKey('o-dat-88')), findsOneWidget);
    expect(find.byKey(const ValueKey('o-dat-89')), findsOneWidget);
    expect(find.byKey(const ValueKey('o-chan-5')), findsOneWidget);
  });

  testWidgets('ca 4 tiếng vẫn đủ rộng để bấm, không mỏng thành sợi', (t) async {
    await _mo(t);
    final w = t.getSize(find.byKey(const ValueKey('o-dat-88'))).width;
    expect(w, greaterThanOrEqualTo(22.0));
  });

  testWidgets('ca qua đêm rộng hơn ca theo giờ (bắc cầu 2 ngày)', (t) async {
    await _mo(t);
    final gio = t.getSize(find.byKey(const ValueKey('o-dat-88'))).width;
    final dem = t.getSize(find.byKey(const ValueKey('o-dat-89'))).width;
    expect(dem, greaterThan(gio));
  });

  testWidgets('cột tên phòng GHIM: không nằm trong vùng cuộn ngang', (t) async {
    await _mo(t);
    final tenX = t.getTopLeft(find.text('GARDEN-01')).dx;
    await t.drag(find.byKey(const ValueKey('o-dat-89')), const Offset(-400, 0));
    await t.pump();
    expect(find.text('GARDEN-01'), findsOneWidget);
    expect(t.getTopLeft(find.text('GARDEN-01')).dx, tenX);
  });

  testWidgets('KPI cả kỳ hiện đủ bốn ô', (t) async {
    await _mo(t);
    expect(find.text('5'), findsWidgets);
    expect(find.text('Đêm bán'), findsOneWidget);
    expect(find.text('16%'), findsOneWidget);
    expect(find.text('Doanh thu'), findsOneWidget);
  });

  testWidgets('lùi một kỳ hỏi server đúng 4 tuần trước', (t) async {
    final api = await _mo(t);
    await t.tap(find.byKey(const Key('lich-tuan-lui')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(api.daHoi.last, '2026-08-17');
  });

  testWidgets('tới một kỳ hỏi server đúng 4 tuần sau', (t) async {
    final api = await _mo(t);
    await t.tap(find.byKey(const Key('lich-tuan-toi')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(api.daHoi.last, '2026-10-12');
  });

  testWidgets('ba khối cùng ngày xếp LÀN, không đè lên nhau', (t) async {
    await _mo(t, _duChongCho());
    final a = t.getRect(find.byKey(const ValueKey('o-dat-88')));
    final b = t.getRect(find.byKey(const ValueKey('o-chan-7')));
    final c = t.getRect(find.byKey(const ValueKey('o-dat-89')));
    for (final (x, y) in [(a, b), (b, c), (a, c)]) {
      final chongNgang = x.right > y.left + 0.5 && y.right > x.left + 0.5;
      final chongDoc = x.bottom > y.top + 0.5 && y.bottom > x.top + 0.5;
      expect(chongNgang && chongDoc, isFalse,
          reason: 'hai khối $x và $y đè lên nhau');
    }
    // Cùng hàng phòng: cả ba vẫn nằm trong chiều cao một hàng.
    expect(c.bottom - a.top, lessThanOrEqualTo(54.0));
  });

  testWidgets('sale không xem tiền: không có ô doanh thu', (t) async {
    final du = _du();
    du['xem_tai_chinh'] = false;
    await _mo(t, du);
    expect(find.text('Doanh thu'), findsNothing);
    expect(find.text('Đêm bán'), findsOneWidget);
  });
}

// Ba khối trong CÙNG một ngày (ca giờ → dọn phòng → ca qua đêm) là cảnh thật
// của một phòng ngắn hạn. Vẽ đè lên nhau thì thành một cục không đọc được.
Map<String, dynamic> _duChongCho() {
  final du = _du();
  (du['phong'] as List)[0]['muc'] = [
    {
      'loai': 'dat', 'id': 88, 'cot': 2.625, 'so_cot': 0.1667,
      'tu_that': '2026-09-16T15:00', 'den_that': '2026-09-16T19:00',
      'trang_thai': 'checked_in', 'nhan_kieu': 'Theo giờ', 'ten': 'A',
    },
    {
      'loai': 'chan', 'id': 7, 'cot': 2.79, 'so_cot': 0.0417,
      'tu_that': '2026-09-16T19:00', 'den_that': '2026-09-16T20:00',
      'ghi_chu': 'Dọn phòng',
    },
    {
      'loai': 'dat', 'id': 89, 'cot': 2.875, 'so_cot': 0.625,
      'tu_that': '2026-09-16T21:00', 'den_that': '2026-09-17T12:00',
      'trang_thai': 'approved', 'nhan_kieu': 'Qua đêm', 'ten': 'B',
    },
  ];
  return du;
}

