/// Màn "Quản lí phòng" (sổ phòng của một toà) — dựng theo mockup 11/09/2026.
///
/// Điều phải giữ:
/// * Mọi nút mockup vẽ đều LÀM việc — chip loại hình, ô tìm, Bộ lọc, Sắp xếp,
///   Dạng lưới / Dạng danh sách, ⋮ của phòng. Không vẽ nút rỗng.
/// * Bốn thẻ số đếm đúng danh sách SAU chip loại hình.
/// * Không tràn chữ trên điện thoại 360px.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/data/models/room_model.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';
import 'package:house_booking/features/host/property/providers/room_provider.dart';
import 'package:house_booking/features/host/property/screens/building_detail_screen.dart';

import '../../helpers/pump_app.dart';

/// Sổ phòng có sẵn dữ liệu — màn không tự nạp khi provider được bơm vào.
class _SoPhongGia extends RoomProvider {
  _SoPhongGia(this._ds);

  final List<RoomModel> _ds;

  @override
  List<RoomModel> get rooms => _ds;

  @override
  bool get isLoading => false;

  @override
  String? get error => null;
}

final _luc = DateTime(2026, 9, 1);

RoomModel _phong(
  int id,
  String ma, {
  String tinhTrang = 'trong',
  List<String> loai = const ['dai_han'],
  double gia = 5000000,
  String donVi = 'thang',
  String? khach,
  String? den,
  String? baoTriDen,
}) => RoomModel(
  id: id,
  buildingId: 5,
  code: ma,
  capacity: 2,
  basePrice: gia,
  status: switch (tinhTrang) {
    'trong' => 'vacant',
    'bao_tri' => 'maintenance',
    _ => 'occupied',
  },
  maintenanceEnd: baoTriDen,
  images: const [],
  createdAt: _luc,
  updatedAt: _luc,
  tinhTrang: tinhTrang,
  loai: loai,
  giaKenh: gia,
  donVi: donVi,
  khachThue: khach,
  hopDongDen: den,
);

List<RoomModel> _mau() => [
  _phong(1, 'P101', tinhTrang: 'dang_o', khach: 'Nguyễn Văn An', den: '2025-09-30'),
  _phong(2, 'P102', tinhTrang: 'sap_tra', gia: 5500000, khach: 'Trần Thị Mai', den: '2025-08-15'),
  _phong(3, 'P103'),
  _phong(4, 'P104', tinhTrang: 'bao_tri', gia: 6000000, baoTriDen: '2026-08-20'),
  _phong(5, 'P201', tinhTrang: 'dang_o', gia: 5500000, khach: 'Lê Minh Hoàng', den: '2026-01-12'),
  _phong(6, 'S1', tinhTrang: 'dang_o', loai: ['ngan_han', 'khach_san'], gia: 400000, donVi: 'dem', khach: 'Phạm Thu Hà'),
  _phong(7, 'P10'),
];

Future<void> _mo(
  WidgetTester t, {
  double rong = 440,
  List<RoomModel>? ds,
  bool coToa = false,
}) async {
  t.view.physicalSize = Size(rong, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await pumpApp(
    t,
    BuildingDetailScreen(
      buildingId: 5,
      buildingName: 'An Cư Garden',
      hostId: 62,
      roomProvider: _SoPhongGia(ds ?? _mau()),
    ),
    auth: SignedInAuthProvider(id: 62),
    extraProviders: [
      if (coToa) ChangeNotifierProvider(create: (_) => BuildingProvider()),
    ],
  );
  await t.pump();
}

Finder _trong(String the, String chu) =>
    find.descendant(of: find.byKey(ValueKey(the)), matching: find.text(chu));

void main() {
  testWidgets('đủ khối như mockup', (t) async {
    await _mo(t);
    expect(find.text('Quản lí phòng'), findsOneWidget);
    expect(find.text('Quản lý chi tiết các phòng trong tòa nhà'), findsOneWidget);
    expect(find.text('An Cư Garden'), findsOneWidget);
    for (final c in ['Tất cả', 'Ngắn hạn', 'Dài hạn', 'Kinh doanh', 'Khách sạn']) {
      expect(find.text(c), findsOneWidget, reason: c);
    }
    for (final c in ['Tổng phòng', 'Đang thuê', 'Phòng trống', 'Danh sách phòng', 'Dạng lưới', 'Dạng danh sách', 'Bộ lọc', 'Sắp xếp']) {
      expect(find.text(c), findsOneWidget, reason: c);
    }
    expect(find.byTooltip('Thêm phòng'), findsOneWidget);
  });

  testWidgets('bốn thẻ số: đang thuê gồm cả sắp trả, phần trăm như mockup', (t) async {
    await _mo(t);
    expect(_trong('the-tong', '7'), findsOneWidget);
    expect(_trong('the-thue', '4'), findsOneWidget);
    expect(_trong('the-thue', '57.1%'), findsOneWidget);
    expect(_trong('the-trong', '2'), findsOneWidget);
    expect(_trong('the-trong', '28.6%'), findsOneWidget);
    expect(_trong('the-bao-tri', '1'), findsOneWidget);
    expect(_trong('the-bao-tri', '14.3%'), findsOneWidget);
  });

  testWidgets('chip loại hình lọc cả danh sách lẫn bốn thẻ số', (t) async {
    await _mo(t);
    // Hàng chip cuộn ngang như mockup — "Khách sạn" nằm ngoài mép màn 440px.
    await t.ensureVisible(find.byKey(const ValueKey('loai-khach_san')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('loai-khach_san')));
    await t.pump();
    expect(find.text('S1'), findsOneWidget);
    expect(find.text('P101'), findsNothing);
    expect(_trong('the-tong', '1'), findsOneWidget);
    expect(_trong('the-thue', '100%'), findsOneWidget);
  });

  testWidgets('tìm theo tên khách không cần dấu, và theo mã phòng', (t) async {
    await _mo(t);
    await t.enterText(find.byKey(const ValueKey('tim-phong')), 'nguyen');
    await t.pump();
    expect(find.text('P101'), findsOneWidget);
    expect(find.text('P102'), findsNothing);

    await t.enterText(find.byKey(const ValueKey('tim-phong')), 'p10');
    await t.pump();
    expect(find.text('P104'), findsOneWidget);
    expect(find.text('P201'), findsNothing);
    expect(find.text('S1'), findsNothing);
  });

  testWidgets('Bộ lọc chọn tình trạng "Sắp trả"', (t) async {
    await _mo(t);
    await t.tap(find.byKey(const ValueKey('bo-loc')));
    await t.pumpAndSettle();
    await t.tap(find.text('Sắp trả').last);
    await t.pumpAndSettle();
    expect(find.text('P102'), findsOneWidget);
    expect(find.text('P101'), findsNothing);
    expect(find.text('P103'), findsNothing);
  });

  testWidgets('mã phòng xếp theo số (P10 trước P101); Sắp xếp giá cao → thấp', (t) async {
    await _mo(t);
    expect(t.getTopLeft(find.text('P10')).dx, lessThan(t.getTopLeft(find.text('P101')).dx));

    await t.tap(find.byKey(const ValueKey('sap-xep')));
    await t.pumpAndSettle();
    await t.tap(find.text('Giá cao → thấp'));
    await t.pumpAndSettle();
    final dau = t.getTopLeft(find.text('P104'));
    for (final ma in ['P101', 'P103', 'P10', 'S1']) {
      expect(dau.dy, lessThan(t.getTopLeft(find.text(ma)).dy), reason: ma);
    }
  });

  testWidgets('Dạng danh sách xếp phòng thành một cột', (t) async {
    await _mo(t);
    expect(t.getTopLeft(find.text('P10')).dy, t.getTopLeft(find.text('P101')).dy);

    await t.tap(find.byKey(const ValueKey('che-do-danh-sach')));
    await t.pump();
    expect(t.getTopLeft(find.text('P10')).dy, lessThan(t.getTopLeft(find.text('P101')).dy));
    expect(t.getTopLeft(find.text('P10')).dx, t.getTopLeft(find.text('P101')).dx);
  });

  testWidgets('thẻ phòng: người ở + hạn hợp đồng, phòng trống, bảo trì, giá theo đêm', (t) async {
    await _mo(t);
    expect(find.text('Nguyễn Văn An'), findsOneWidget);
    expect(find.text('Hợp đồng đến 30/09/2025'), findsOneWidget);
    expect(find.text('Chưa có khách thuê'), findsNWidgets(2));
    expect(find.text('Sẵn sàng cho thuê'), findsNWidgets(2));
    expect(find.text('Đang bảo trì'), findsOneWidget);
    expect(find.text('Dự kiến hoàn thành 20/08'), findsOneWidget);
    expect(find.textContaining('5.500.000đ'), findsNWidgets(2));
    // Phòng ngắn hạn tính theo đêm — in "/tháng" cho mọi phòng là sai.
    expect(find.textContaining('400.000đ/đêm'), findsOneWidget);
  });

  testWidgets('không có tên khách (sale xem) vẫn nói phòng có người', (t) async {
    await _mo(t, ds: [_phong(9, 'P202', tinhTrang: 'dang_o')]);
    expect(find.text('Đang có khách thuê'), findsOneWidget);
  });

  testWidgets('menu tên toà giữ lối Giá điện nước + Mời sale; ⋮ phòng có Sửa/Xoá', (t) async {
    await _mo(t, coToa: true);
    await t.tap(find.byKey(const ValueKey('menu-toa')));
    await t.pumpAndSettle();
    expect(find.text('Giá điện nước mặc định'), findsOneWidget);
    expect(find.text('Mời sale phụ trách'), findsOneWidget);
    expect(find.text('Tải lại danh sách phòng'), findsOneWidget);
    await t.tap(find.text('Tải lại danh sách phòng'));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('menu-phong-1')));
    await t.pumpAndSettle();
    expect(find.text('Xem chi tiết'), findsOneWidget);
    expect(find.text('Sửa phòng'), findsOneWidget);
    expect(find.text('Xoá phòng'), findsOneWidget);
  });

  testWidgets('toà chưa có phòng: mời thêm phòng đầu tiên', (t) async {
    await _mo(t, ds: const []);
    expect(find.byKey(const ValueKey('so-phong-trong')), findsOneWidget);
    expect(find.text('Thêm phòng đầu tiên'), findsOneWidget);
  });

  for (final rong in [360.0, 390.0]) {
    testWidgets('điện thoại ${rong.toInt()}px: đủ khối, không tràn chữ', (t) async {
      await _mo(t, rong: rong);
      expect(t.takeException(), isNull);
      expect(find.text('Danh sách phòng'), findsOneWidget);
      expect(find.text('P101'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('che-do-danh-sach')));
      await t.pump();
      expect(t.takeException(), isNull);
    });
  }
}
