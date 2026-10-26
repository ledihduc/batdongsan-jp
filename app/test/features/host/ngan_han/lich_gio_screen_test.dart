import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/lich_gio_api.dart';
import 'package:house_booking/features/host/ngan_han/lich_gio_screen.dart';

import '../../../helpers/pump_app.dart';

/// SƠ ĐỒ GIỜ CỦA MỘT PHÒNG — hàng = ngày, cột = giờ, 4 tuần liền.
///
/// Điều phải giữ:
///   * mỗi ngày một hàng, khối nằm đúng mốc giờ trong hàng đó;
///   * ca qua đêm thành HAI khúc ở hai hàng, có cờ tràn — không vẽ tràn lưới;
///   * cột ngày GHIM khi cuộn ngang tới tối;
///   * ca 1 tiếng vẫn bấm được (bề rộng tối thiểu);
///   * đổi phòng bằng chip, lùi/tới nhảy nguyên một kỳ 4 tuần.
class _ApiGia extends LichGioApi {
  _ApiGia(this.du);

  Map<String, dynamic> du;
  final daHoi = <String>[];

  @override
  Future<LichGio> lay(
    int roomId, {
    String? tuNgay,
    int soTuan = 4,
    String moc = 'tuan',
  }) async {
    daHoi.add('$roomId|${tuNgay ?? ''}');
    return LichGio.fromMap(du);
  }
}

Map<String, dynamic> _hang(
  int i, {
  List<Map<String, dynamic>> muc = const [],
  int soCa = 0,
  double gioBan = 0,
  bool homNay = false,
}) {
  final d = DateTime(2026, 9, 14).add(Duration(days: i));
  return {
    'ngay': '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
    'thu': d.weekday,
    'hom_nay': homNay,
    'cuoi_tuan': d.weekday >= 6,
    'so_ca': soCa,
    'gio_ban': gioBan,
    'ty_le': gioBan / 24 * 100,
    'doanh_thu': 0,
    'muc': muc,
  };
}

Map<String, dynamic> _du() => {
  'tu_ngay': '2026-09-14',
  'den_ngay': '2026-10-11',
  'so_tuan': 4,
  'so_ngay': 28,
  'bay_gio': '2026-09-16T20:00',
  'xem_tai_chinh': true,
  'phong': {'id': 33, 'ma': 'GARDEN-01', 'suc_chua': 2, 'building_id': 10},
  'toa': {'id': 10, 'ten': 'An Cư Garden', 'dia_chi': ''},
  'cac_phong': [
    {'id': 33, 'ma': 'GARDEN-01'},
    {'id': 34, 'ma': 'GARDEN-02'},
  ],
  'kpi': {
    'luot_dat': 2,
    'gio_ban': 19.0,
    'so_ngay': 28,
    'cong_suat': 2.8,
    'doanh_thu': 860000,
  },
  'ngay': [
    for (var i = 0; i < 28; i++)
      if (i == 2)
        _hang(
          2,
          homNay: true,
          soCa: 2,
          gioBan: 7,
          muc: [
            {
              'loai': 'dat',
              'id': 88,
              'gio': 15.0,
              'so_gio': 4.0,
              'trang_thai': 'checked_in',
              'nhan_kieu': 'Theo giờ',
              'ten': 'Nguyễn Văn An',
              'tong': 280000,
            },
            {
              'loai': 'chan',
              'id': 5,
              'gio': 19.0,
              'so_gio': 1.0,
              'ghi_chu': 'Dọn phòng',
            },
            {
              'loai': 'dat',
              'id': 89,
              'gio': 21.0,
              'so_gio': 3.0,
              'tran_sau': true,
              'trang_thai': 'approved',
              'nhan_kieu': 'Qua đêm',
              'ten': 'Trần Thị Mai Phương',
              'tong': 580000,
            },
          ],
        )
      else if (i == 3)
        _hang(
          3,
          gioBan: 12,
          muc: [
            {
              'loai': 'dat',
              'id': 89,
              'gio': 0.0,
              'so_gio': 12.0,
              'tran_truoc': true,
              'trang_thai': 'approved',
              'nhan_kieu': 'Qua đêm',
              'ten': 'Trần Thị Mai Phương',
            },
          ],
        )
      else
        _hang(i),
  ],
};

Future<_ApiGia> _mo(WidgetTester t, [Map<String, dynamic>? du]) async {
  t.view.physicalSize = const Size(1100, 2400);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  final api = _ApiGia(du ?? _du());
  await pumpApp(
    t,
    LichGioScreen(roomId: 33, api: api, tuNgayBanDau: '2026-09-14'),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
  return api;
}

void main() {
  testWidgets('mỗi ngày một hàng, có mốc giờ bên trên', (t) async {
    await _mo(t);
    expect(find.text('Lịch giờ · Phòng GARDEN-01'), findsOneWidget);
    expect(find.text('4 tuần liền · mỗi hàng một ngày'), findsOneWidget);
    expect(find.text('Ngày'), findsOneWidget);
    expect(find.text('T2 14/9'), findsOneWidget);
    expect(find.text('T4 16/9'), findsOneWidget);
    // Nhãn giờ 2 tiếng một lần: 00,02,...,22 = 12 nhãn.
    expect(find.text('08'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
  });

  testWidgets('khối nằm đúng mốc giờ của hàng ngày đó', (t) async {
    await _mo(t);
    final o = find.byKey(const ValueKey('g-dat-88'));
    expect(o, findsOneWidget);
    expect(find.text('15:00 – 19:00'), findsOneWidget);
    // 15:00 × 30px/giờ = 450 kể từ mép trái lưới giờ.
    final hang = find.byKey(const ValueKey('g-chan-5'));
    expect(t.getTopLeft(hang).dx - t.getTopLeft(o).dx, closeTo(4 * 30, 1));
  });

  testWidgets('ca qua đêm thành hai khúc ở hai hàng', (t) async {
    await _mo(t);
    expect(find.byKey(const ValueKey('g-dat-89')), findsNWidgets(2));
    expect(find.text('21:00 – 00:00'), findsOneWidget);
    expect(find.text('00:00 – 12:00'), findsOneWidget);
  });

  testWidgets('ca ngắn vẫn đủ rộng để bấm', (t) async {
    await _mo(t);
    final w = t.getSize(find.byKey(const ValueKey('g-chan-5'))).width;
    expect(w, greaterThanOrEqualTo(22.0));
  });

  testWidgets('cột ngày GHIM: cuộn ngang không làm mất nhãn ngày', (t) async {
    await _mo(t);
    final x = t.getTopLeft(find.text('T4 16/9')).dx;
    await t.drag(find.byKey(const ValueKey('g-dat-88')), const Offset(-260, 0));
    await t.pump();
    expect(find.text('T4 16/9'), findsOneWidget);
    expect(t.getTopLeft(find.text('T4 16/9')).dx, x);
  });

  testWidgets('đổi phòng bằng chip thì hỏi lại đúng phòng', (t) async {
    final api = await _mo(t);
    await t.tap(find.byKey(const Key('lich-gio-phong-34')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(api.daHoi.last.split('|').first, '34');
  });

  testWidgets('lùi/tới nhảy nguyên kỳ 4 tuần', (t) async {
    final api = await _mo(t);
    await t.tap(find.byKey(const Key('lich-gio-lui')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(api.daHoi.last, endsWith('2026-08-17'));

    await t.tap(find.byKey(const Key('lich-gio-toi')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(api.daHoi.last, endsWith('2026-10-12'));
  });

  testWidgets('ngày trống nói là trống, ngày có ca ghi số ca và số giờ', (t) async {
    await _mo(t);
    expect(find.text('2 ca · 7h'), findsOneWidget);
    expect(find.text('trống'), findsWidgets);
  });

  testWidgets('ngày chỉ có đuôi ca hôm trước KHÔNG được ghi là trống', (t) async {
    await _mo(t);
    // 13/9 chỉ có khúc 00:00–12:00 của ca qua đêm bắt đầu tối 12/9.
    expect(find.text('ca hôm trước · 12h'), findsOneWidget);
  });

  testWidgets('sale không xem tiền: không có ô doanh thu', (t) async {
    final du = _du();
    du['xem_tai_chinh'] = false;
    await _mo(t, du);
    expect(find.text('Doanh thu'), findsNothing);
    expect(find.text('Giờ bán'), findsOneWidget);
  });
}
