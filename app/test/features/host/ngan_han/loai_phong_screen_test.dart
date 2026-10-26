import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/loai_phong_api.dart';
import 'package:house_booking/features/host/ngan_han/loai_phong_screen.dart';

import '../../../helpers/pump_app.dart';

/// LOẠI PHÒNG (hạng) — quản lý phòng ngắn hạn theo nhóm.
///
/// Điều phải giữ:
///   * trả lời ngay "hạng này còn mấy phòng" — lý do màn này tồn tại;
///   * hạng chưa khai giá phải BÁO ĐỎ: hạng không giá là hạng không bán được;
///   * phòng chưa xếp hạng không được im lặng bỏ qua — đó là hàng mất khỏi chợ;
///   * xếp phòng là THAY THẾ danh sách, bỏ tích phải gửi đi.
class _ApiGia extends LoaiPhongApi {
  _ApiGia(this.bang);

  Map<String, dynamic> bang;
  Map<String, Object?>? daTao;
  ({int id, List<int> phong})? daGan;
  int? daXoa;
  Map<String, Object?>? daSua;

  @override
  Future<BangLoaiPhong> danhSach(int buildingId) async =>
      BangLoaiPhong.fromMap(bang);

  @override
  Future<int> tao(
    int buildingId, {
    required String ten,
    String? moTa,
    int sucChua = 2,
    double? dienTich,
    String? giuong,
    List<String> anh = const [],
    List<String> tienNghi = const [],
    double? giaTheoGio,
    double? giaQuaDem,
    double? giaTheoNgay,
    List<int> roomIds = const [],
  }) async {
    daTao = {
      'toa': buildingId,
      'ten': ten,
      'suc_chua': sucChua,
      'giuong': giuong,
      'gio': giaTheoGio,
      'dem': giaQuaDem,
      'phong': roomIds,
    };
    return 9;
  }

  @override
  Future<int> ganPhong(int loaiId, List<int> roomIds) async {
    daGan = (id: loaiId, phong: roomIds);
    return roomIds.length;
  }

  @override
  Future<void> xoa(int loaiId) async {
    daXoa = loaiId;
  }

  @override
  Future<void> sua(int loaiId, Map<String, Object?> thayDoi) async {
    daSua = {'id': loaiId, ...thayDoi};
  }
}

Map<String, dynamic> _hang({
  int id = 1,
  String ten = 'Studio VIP',
  double? gio = 80000,
  double? dem = 650000,
  List<Map<String, dynamic>> phong = const [
    {'id': 11, 'ma': '201', 'trang_thai': 'vacant', 'co_khach': false},
    {'id': 12, 'ma': '202', 'trang_thai': 'occupied', 'co_khach': true},
    {'id': 13, 'ma': '203', 'trang_thai': 'maintenance', 'co_khach': false},
  ],
}) => {
  'id': id,
  'ten': ten,
  'suc_chua': 2,
  'giuong': 'King 1m8',
  'dien_tich': 28,
  'anh': [],
  'tien_nghi': [],
  'gia_theo_gio': gio,
  'gia_qua_dem': dem,
  'gia_theo_ngay': null,
  'gia_hieu_luc': {
    'gia_theo_gio': gio,
    'gia_qua_dem': dem,
    'gia_theo_ngay': null,
  },
  'thu_tu': 1,
  'dang_ban': true,
  'so_phong': phong.length,
  'dang_co_khach': phong.where((p) => p['co_khach'] == true).length,
  'bao_tri': phong.where((p) => p['trang_thai'] == 'maintenance').length,
  'trong':
      phong.length -
      phong.where((p) => p['co_khach'] == true).length -
      phong.where((p) => p['trang_thai'] == 'maintenance').length,
  'phong': phong,
};

Map<String, dynamic> _bang({
  List<Map<String, dynamic>>? loai,
  List<Map<String, dynamic>> chuaXep = const [],
}) => {
  'building_id': 3,
  'loai_phong': loai ?? [_hang()],
  'chua_xep_hang': chuaXep,
  'tong_phong': (loai ?? [_hang()]).fold<int>(
        0,
        (t, h) => t + (h['so_phong'] as int),
      ) +
      chuaXep.length,
};

Future<_ApiGia> _mo(WidgetTester t, Map<String, dynamic> bang) async {
  t.view.physicalSize = const Size(1000, 2400);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  final api = _ApiGia(bang);
  await pumpApp(
    t,
    LoaiPhongScreen(buildingId: 3, tenToa: 'An Cư Central', api: api),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
  return api;
}

void main() {
  testWidgets('thẻ hạng: giá, số phòng và số phòng còn trống', (t) async {
    await _mo(t, _bang());
    expect(find.text('Studio VIP'), findsOneWidget);
    expect(find.text('King 1m8 • 2 khách • 28 m²'), findsOneWidget);
    expect(find.text('80.000đ/giờ'), findsOneWidget);
    expect(find.text('650.000đ/đêm'), findsOneWidget);
    // 3 phòng: 1 có khách, 1 bảo trì → còn 1 trống.
    expect(find.text('trống'), findsOneWidget);
    expect(find.text('có khách'), findsOneWidget);
    expect(find.text('bảo trì'), findsOneWidget);
    for (final ma in ['201', '202', '203']) {
      expect(find.text(ma), findsOneWidget, reason: ma);
    }
  });

  testWidgets('hạng chưa khai giá thì báo đỏ là chưa bán được', (t) async {
    await _mo(t, _bang(loai: [_hang(gio: null, dem: null)]));
    expect(find.text('Chưa khai giá — hạng chưa bán được'), findsOneWidget);
  });

  testWidgets('phòng chưa xếp hạng: nhắc rõ là khách không đặt được', (t) async {
    await _mo(t, _bang(chuaXep: const [
      {'id': 21, 'ma': '301', 'trang_thai': 'vacant', 'co_khach': false},
      {'id': 22, 'ma': '302', 'trang_thai': 'vacant', 'co_khach': false},
    ]));
    expect(find.text('2 phòng chưa xếp hạng'), findsOneWidget);
    expect(find.text('301'), findsOneWidget);
  });

  testWidgets('thêm hạng: gửi đúng tên, giá và phòng vừa tích', (t) async {
    final api = await _mo(t, _bang(loai: const [], chuaXep: const [
      {'id': 21, 'ma': '301', 'trang_thai': 'vacant', 'co_khach': false},
    ]));
    expect(find.text('Chưa có hạng phòng nào'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('them-hang')));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Tên hạng'), 'Phòng đôi');
    await t.enterText(find.widgetWithText(TextField, 'đ/giờ'), '70000');
    await t.tap(find.byKey(const ValueKey('chon-phong-21')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('luu-hang')));
    await t.pumpAndSettle();

    expect(api.daTao!['ten'], 'Phòng đôi');
    expect(api.daTao!['gio'], 70000);
    expect(api.daTao!['phong'], [21]);
  });

  testWidgets('xếp phòng: bỏ tích một phòng thì gửi danh sách còn lại', (t) async {
    final api = await _mo(t, _bang(chuaXep: const [
      {'id': 21, 'ma': '301', 'trang_thai': 'vacant', 'co_khach': false},
    ]));
    await t.tap(find.byKey(const ValueKey('gan-phong-1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('chon-phong-13'))); // bỏ 203
    await t.tap(find.byKey(const ValueKey('chon-phong-21'))); // thêm 301
    await t.pump();
    await t.tap(find.byKey(const ValueKey('luu-gan-phong')));
    await t.pumpAndSettle();

    expect(api.daGan!.id, 1);
    expect(api.daGan!.phong.toSet(), {11, 12, 21});
  });

  testWidgets('xoá hạng: nói rõ phòng không bị xoá rồi mới gọi server', (t) async {
    final api = await _mo(t, _bang());
    await t.tap(find.byKey(const ValueKey('xoa-hang-1')));
    await t.pumpAndSettle();
    expect(find.textContaining('trở về "chưa xếp hạng"'), findsOneWidget);
    expect(api.daXoa, isNull);
    await t.tap(find.byKey(const ValueKey('xac-nhan-xoa-hang')));
    await t.pumpAndSettle();
    expect(api.daXoa, 1);
  });

  testWidgets('tắt hạng = ngừng bán cả nhóm phòng', (t) async {
    final api = await _mo(t, _bang());
    await t.tap(find.byKey(const ValueKey('bat-hang-1')));
    await t.pumpAndSettle();
    expect(api.daSua, {'id': 1, 'dang_ban': false});
  });
}
