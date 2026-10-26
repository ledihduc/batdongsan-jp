import 'package:fl_chart/fl_chart.dart' show LineChart;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/dien_nuoc_api.dart';
import 'package:house_booking/data/services/tong_quan_chu_nha_api.dart';
import 'package:house_booking/features/host/tong_quan/tong_quan_chu_nha_screen.dart';

import '../../../helpers/pump_app.dart';

/// Trang chủ chủ nhà — dựng theo mockup "An Cư - Quản lý tòa nhà".
///
/// Dữ liệu giả mang ĐÚNG tên trường của `GET /api/host/tong-quan` đang chạy
/// (`phong_da_thue`, `ty_le_lap_day`, `toa_nha[loai]`, `lap_day_6_thang`).
/// Đã từng vấp: màn đọc một bộ tên, server trả bộ tên khác — test vẫn xanh vì
/// dữ liệu giả cũng dùng bộ tên sai, còn trang live thì trống.
///
/// Điều phải giữ bằng test:
///   * con số KHÔNG tính được thì ẩn, không in "+∞%" hay biểu đồ rỗng
///   * chip lọc khớp đúng nhãn trên thẻ toà
///   * menu ảnh đại diện vẫn có đường tới CÀI ĐẶT (chủ nhà mất lối này là mất
///     đường đăng xuất — đã từng xảy ra)
///   * khổ điện thoại 360px không tràn chữ (4 thẻ số giữ 4 cột như mockup)
class _ApiGia extends TongQuanChuNhaApi {
  _ApiGia(this.so);

  final Map<String, dynamic> so;
  final hoi = <int?>[];

  @override
  Future<TongQuanChuNha> lay({int? buildingId}) async {
    hoi.add(buildingId);
    return TongQuanChuNha.fromMap(so);
  }
}

class _DienNuocGia extends DienNuocApi {
  final hoi = <int>[];

  @override
  Future<BangDienNuoc> bangThang(int buildingId, String thang) async {
    hoi.add(buildingId);
    return BangDienNuoc.fromMap({
      'building_id': buildingId,
      'ten_toa': 'An Cu Garden',
      'thang': thang,
      'tong_phong': 0,
      'da_gui': 0,
      'cho_duyet': 0,
      'thieu_anh': 0,
      'da_duyet': 0,
      'chua_gui': 0,
      'tong_tam_tinh': 0,
      'dong': const [],
    });
  }
}

const _thang = [(4, 55.0), (5, 60.2), (6, 58.4), (7, 64.0), (8, 68.4), (9, 76.6)];

Map<String, dynamic> _so({
  double? tang = 12,
  double? lapDay = 76.6,
  List<Map<String, dynamic>> toa = const [],
}) => {
  'so_toa': 7,
  'so_phong': 128,
  'toa_moi_thang_nay': 1,
  'dai_han_dang_thue': 0,
  'dai_han_tong': 0,
  'ngan_han_hoat_dong': 0,
  'doanh_thu_thang': 125600000,
  'doanh_thu_tang': tang,
  'thang_truoc': 8,
  'dai_han': const [],
  'kinh_doanh': const [],
  'ngan_han': const [],
  'toa': const [
    {'building_id': 1, 'ten': 'An Cu Garden'},
    {'building_id': 2, 'ten': 'An Cu Riverside'},
  ],
  'phong_da_thue': lapDay == null ? 0 : 98,
  'phong_trong': lapDay == null ? 0 : 30,
  'ty_le_lap_day': lapDay,
  'ty_le_trong': lapDay == null ? null : 23.4,
  'lap_day_tang': lapDay == null ? null : 8.2,
  'lap_day_6_thang': [
    for (final (thang, tyLe) in _thang)
      {'nam': 2026, 'thang': thang, 'ty_le': lapDay == null ? null : tyLe},
  ],
  'toa_nha': toa,
};

const _garden = <String, dynamic>{
  'building_id': 1,
  'ten': 'An Cu Garden',
  'dia_chi': '25 Hoàng Văn Thụ · Ba Đình · Hà Nội',
  'tong': 32,
  'da_thue': 28,
  'ty_le': 88,
  'loai': ['ngan_han', 'cho_thue'],
  'hoat_dong': true,
};

const _central = <String, dynamic>{
  'building_id': 3,
  'ten': 'An Cu Central',
  'dia_chi': '88 Nguyễn Huệ · Quận 1 · TP.HCM',
  'tong': 24,
  'da_thue': 20,
  'ty_le': 83,
  'loai': ['kinh_doanh', 'dai_han'],
  'hoat_dong': true,
};

const _riverside = <String, dynamic>{
  'building_id': 2,
  'ten': 'An Cu Riverside',
  'dia_chi': '12 Đường Ven Sông · Hải Châu · Đà Nẵng',
  'tong': 48,
  'da_thue': 36,
  'ty_le': 75,
  'loai': ['khach_san', 'ngan_han'],
  'hoat_dong': true,
};

const _toaMoi = <String, dynamic>{
  'building_id': 4,
  'ten': 'Toà Mới',
  'tong': 0,
  'da_thue': 0,
  'ty_le': 0,
  'loai': <String>[],
  'hoat_dong': false,
};

Future<_ApiGia> _dung(
  WidgetTester t,
  Map<String, dynamic> so, {
  VoidCallback? onMoCaiDat,
  DienNuocApi? dienNuoc,
  int soChuaDoc = 0,
  double rong = 1200,
}) async {
  t.view.physicalSize = Size(rong, 2800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final api = _ApiGia(so);
  await pumpApp(
    t,
    TongQuanChuNhaScreen(
      api: api,
      dienNuocApi: dienNuoc ?? _DienNuocGia(),
      ten: 'Vũ Đình Văn',
      soChuaDoc: soChuaDoc,
      onMoCaiDat: onMoCaiDat,
    ),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
  return api;
}

Finder _trongThe(int id, String chu) => find.descendant(
  of: find.byKey(ValueKey('toa-$id')),
  matching: find.text(chu),
);

void main() {
  testWidgets('đầu trang + bốn thẻ số như mockup, số lấy từ server', (t) async {
    await _dung(t, _so());
    expect(find.text('Vũ Đình Văn'), findsOneWidget);
    expect(find.text('Chủ nhà'), findsOneWidget);
    expect(find.text('7 tòa nhà · 128 phòng'), findsOneWidget);
    expect(find.text('▲ +1 so với tháng trước'), findsOneWidget);
    expect(find.text('Phòng đã thuê'), findsOneWidget);
    expect(find.text('98'), findsOneWidget);
    expect(find.text('76.6% lấp đầy'), findsOneWidget);
    expect(find.text('Phòng trống'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('23.4%'), findsOneWidget);
    expect(find.text('125,6 triệu'), findsOneWidget);
    expect(find.text('▲ +12% so với T8'), findsOneWidget);
  });

  testWidgets('tháng trước không có doanh thu → KHÔNG in % tăng bịa', (
    t,
  ) async {
    await _dung(t, _so(tang: null));
    expect(find.text('125,6 triệu'), findsOneWidget);
    expect(find.textContaining('so với T'), findsNothing);
  });

  testWidgets('chấm đỏ trên chuông chỉ khi có thông báo chưa đọc', (t) async {
    await _dung(t, _so(), soChuaDoc: 3);
    expect(find.byKey(const ValueKey('cham-thong-bao')), findsOneWidget);
  });

  testWidgets('không có thông báo chưa đọc → không vẽ chấm đỏ', (t) async {
    await _dung(t, _so());
    expect(find.byKey(const ValueKey('cham-thong-bao')), findsNothing);
  });

  testWidgets('Tòa nhà của bạn: nhãn, số phòng, Hoạt động', (t) async {
    await _dung(t, _so(toa: [_garden, _central, _riverside, _toaMoi]));
    expect(find.text('Tòa nhà của bạn'), findsOneWidget);
    expect(_trongThe(1, 'Cho thuê'), findsOneWidget);
    expect(_trongThe(1, 'Ngắn hạn'), findsOneWidget);
    expect(_trongThe(1, '28/32 phòng'), findsOneWidget);
    expect(_trongThe(1, '88%'), findsOneWidget);
    expect(_trongThe(3, 'Kinh doanh'), findsOneWidget);
    expect(_trongThe(3, 'Dài hạn'), findsOneWidget);
    expect(_trongThe(2, 'Khách sạn'), findsOneWidget);
    // Mockup chỉ bày 3 toà; phần còn lại nằm sau "Xem tất cả".
    expect(find.text('Hoạt động'), findsNWidgets(3));
    expect(find.byKey(const ValueKey('toa-4')), findsNothing);
    expect(find.text('Xem tất cả'), findsOneWidget);
  });

  testWidgets('lọc Khách sạn chỉ còn toà mang nhãn Khách sạn', (t) async {
    await _dung(t, _so(toa: [_garden, _central, _riverside]));
    await t.tap(find.byKey(const ValueKey('loc-khach_san')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('toa-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('toa-1')), findsNothing);
    expect(find.byKey(const ValueKey('toa-3')), findsNothing);
  });

  testWidgets('lọc Kinh doanh chỉ còn toà mang nhãn Kinh doanh', (t) async {
    await _dung(t, _so(toa: [_garden, _central, _riverside]));
    await t.tap(find.byKey(const ValueKey('loc-kinh_doanh')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('toa-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('toa-1')), findsNothing);
  });

  testWidgets('lọc không ra toà nào → nói rõ, không để trống trơn', (t) async {
    await _dung(t, _so(toa: [_garden]));
    await t.tap(find.byKey(const ValueKey('loc-dai_han')));
    await t.pumpAndSettle();
    expect(find.text('Không có tòa nhà nào thuộc loại này.'), findsOneWidget);
  });

  testWidgets('toà chưa khai thác → không nói dối là Hoạt động', (t) async {
    await _dung(t, _so(toa: [_toaMoi]));
    expect(find.text('Chưa khai thác'), findsOneWidget);
    expect(find.text('Hoạt động'), findsNothing);
  });

  testWidgets('chưa có toà nào → nói rõ và chỉ đường thêm toà', (t) async {
    await _dung(t, _so());
    expect(find.text('Chưa có tòa nhà nào.'), findsOneWidget);
    expect(find.text('Thêm tòa nhà'), findsOneWidget);
  });

  testWidgets('chọn một toà → hỏi lại server đúng toà đó', (t) async {
    final api = await _dung(t, _so());
    await t.tap(find.text('Tất cả tòa nhà'));
    await t.pumpAndSettle();
    await t.tap(find.text('An Cu Riverside'));
    await t.pumpAndSettle();
    expect(api.hoi, [null, 2]);
  });

  testWidgets('menu ảnh đại diện vẫn có đường tới cài đặt', (t) async {
    var daMo = false;
    await _dung(t, _so(), onMoCaiDat: () => daMo = true);
    await t.tap(find.byTooltip('Tài khoản'));
    await t.pumpAndSettle();
    await t.tap(find.text('Tài khoản & cài đặt'));
    await t.pumpAndSettle();
    expect(daMo, isTrue);
  });

  testWidgets('đủ năm thao tác nhanh như mockup', (t) async {
    await _dung(t, _so());
    for (final nhan in const [
      'Quản lí phòng',
      'Điện nước',
      'Dịch vụ',
      'Khách thuê',
      'Báo cáo',
    ]) {
      expect(find.text(nhan), findsOneWidget, reason: nhan);
    }
  });

  testWidgets('Điện nước mở màn duyệt, chọn sẵn toà đầu tiên', (t) async {
    final dn = _DienNuocGia();
    await _dung(t, _so(), dienNuoc: dn);
    await t.tap(find.text('Điện nước'));
    await t.pumpAndSettle();
    // Tiêu đề màn là "Điện nước" — trùng nhãn thao tác nhanh vừa bấm, nên nhận
    // diện bằng câu phụ của màn.
    expect(find.text('Quản lý chỉ số và chi phí hàng tháng'), findsOneWidget);
    expect(dn.hoi, [1]);
  });

  testWidgets('biểu đồ lưu trú: tháng này, % và chênh lệch so tháng trước', (
    t,
  ) async {
    await _dung(t, _so());
    expect(find.text('Tình hình lưu trú tháng 9'), findsOneWidget);
    // Số in to + nhãn tròn bên phải.
    expect(find.text('76.6%'), findsNWidgets(2));
    expect(find.text('▲ +8.2% so với tháng trước'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('Th4'), findsOneWidget);
    expect(find.text('Th9'), findsOneWidget);
  });

  testWidgets('chưa có phòng nào → không vẽ biểu đồ rỗng', (t) async {
    await _dung(t, _so(lapDay: null));
    expect(find.textContaining('Tình hình lưu trú'), findsNothing);
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('76.6% lấp đầy'), findsNothing);
  });

  testWidgets('điện thoại 360px: đủ mọi khối, không tràn chữ', (t) async {
    await _dung(t, _so(toa: [_garden, _central, _riverside]), rong: 360);
    expect(find.text('Tòa nhà của bạn'), findsOneWidget);
    expect(find.text('Thao tác nhanh'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
  });
}
