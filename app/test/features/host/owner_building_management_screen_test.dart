import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/models/room_model.dart';
import 'package:house_booking/data/services/tong_quan_chu_nha_api.dart';
import 'package:house_booking/features/host/property/providers/room_provider.dart';
import 'package:house_booking/features/host/property/screens/owner_building_management_screen.dart';

import '../../helpers/pump_app.dart';

class _RoomsFake extends RoomProvider {
  _RoomsFake(this.values);
  final List<RoomModel> values;

  @override
  List<RoomModel> get rooms => values;

  @override
  bool get isLoading => false;

  @override
  String? get error => null;
}

class _OverviewFake extends TongQuanChuNhaApi {
  const _OverviewFake();

  @override
  Future<TongQuanChuNha> lay({int? buildingId}) async => TongQuanChuNha(
    soToa: 1,
    soPhong: 4,
    toaMoiThangNay: 0,
    daiHanDangThue: 1,
    daiHanTong: 2,
    daiHanLapDay: 50,
    nganHanHoatDong: 1,
    nganHanCongSuat: 50,
    doanhThuThang: 12500000,
    doanhThuTang: null,
    thangTruoc: 0,
    daiHan: const [
      KhoiThue(
        buildingId: 5,
        ten: 'An Cư Home',
        tong: 2,
        dangThue: 1,
        phongNo: 1,
        hoaDonNo: 3,
        tienNo: 4800000,
      ),
    ],
    kinhDoanh: const [],
    nganHan: const [
      KhoiNganHan(
        buildingId: 5,
        ten: 'An Cư Home',
        tong: 2,
        dangSuDung: 1,
        trong: 1,
        tyLe: 50,
      ),
    ],
    toa: const [(id: 5, ten: 'An Cư Home')],
  );
}

RoomModel _room(
  int id,
  String code,
  String type, {
  String state = 'trong',
  String? tenant,
  String? contractEnd,
  String? contractStart,
  String? payDay,
}) => RoomModel(
  id: id,
  buildingId: 5,
  code: code,
  capacity: 2,
  basePrice: 5000000,
  status: state == 'trong' ? 'vacant' : 'occupied',
  images: const [],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  tinhTrang: state,
  loai: [type],
  khachThue: tenant,
  hopDongTu: contractStart,
  hopDongDen: contractEnd,
  dongTienNgay: payDay,
);

RoomModel _hybridRoom() => RoomModel(
  id: 5,
  buildingId: 5,
  code: 'P201',
  areaM2: 25,
  capacity: 2,
  basePrice: 5000000,
  status: 'vacant',
  images: const [],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  tinhTrang: 'trong',
  loai: const ['dai_han', 'ngan_han'],
  loaiPhong: 'Deluxe',
);

Future<void> _pump(WidgetTester tester, {double width = 430}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await pumpApp(
    tester,
    OwnerBuildingManagementScreen(
      buildingId: 5,
      buildingName: 'Tòa nhà An Cư Home',
      address: '123 Nguyễn Văn Linh, Hải Châu, Đà Nẵng',
      api: const _OverviewFake(),
      roomProvider: _RoomsFake([
        _room(1, 'P101', 'dai_han', state: 'dang_o'),
        _room(2, 'P102', 'dai_han'),
        _room(3, 'S101', 'ngan_han', state: 'dang_o'),
        _room(4, 'S102', 'ngan_han'),
        _hybridRoom(),
      ]),
    ),
  );
  await tester.pumpAndSettle();
}

String _iso(int daysFromNow) {
  final d = DateTime.now().add(Duration(days: daysFromNow));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

String _ngayNgan(int daysFromNow) {
  final d = DateTime.now().add(Duration(days: daysFromNow));
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}';
}

/// Mở thẳng workspace dài hạn với dữ liệu có đủ ba loại mốc.
Future<void> _pumpLongTerm(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await pumpApp(
    tester,
    OwnerBuildingManagementScreen(
      buildingId: 5,
      buildingName: 'Tòa nhà An Cư Home',
      api: const _OverviewFake(),
      roomProvider: _RoomsFake([
        _room(
          1,
          'P101',
          'dai_han',
          state: 'dang_o',
          tenant: 'Phạm Minh Tuấn',
          contractEnd: _iso(200),
          payDay: _iso(5),
        ),
        _room(
          2,
          'P102',
          'dai_han',
          state: 'sap_tra',
          tenant: 'Lê Thị Hoa',
          contractEnd: _iso(3),
        ),
        _room(
          3,
          'P103',
          'dai_han',
          state: 'sap_vao',
          tenant: 'Đỗ Quang Huy',
          contractStart: _iso(15),
          contractEnd: _iso(380),
        ),
        _room(4, 'P104', 'dai_han'),
      ]),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('owner-building-long-term')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tổng quan tòa có hai lối quản lý rõ ràng', (tester) async {
    await _pump(tester);

    expect(find.text('Tòa nhà An Cư Home'), findsOneWidget);
    expect(find.text('Tổng quan tòa nhà'), findsOneWidget);
    expect(find.text('Quản lý dài hạn'), findsOneWidget);
    expect(find.text('Quản lý ngắn hạn'), findsOneWidget);
    expect(find.text('Quản lý linh hoạt'), findsOneWidget);
    expect(find.text('12.5 tr'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thẻ "Chưa thu" nói TIỀN, không nói số phòng', (tester) async {
    // Chủ nhà hỏi "còn bao nhiêu tiền chưa thu", không hỏi "mấy phòng nợ";
    // bản đầu chuyển giao diện in số phòng vào chỗ đáng lẽ là tiền.
    await _pumpLongTerm(tester);
    expect(find.text('4.8 tr'), findsOneWidget);
    expect(find.text('Chưa thu'), findsOneWidget);
    expect(find.text('3 hóa đơn chưa thanh toán'), findsOneWidget);
    expect(find.text('Tổng tiền 4.8 tr · 1 phòng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"khách sắp trả phòng" hẹp hơn "HĐ sắp hết hạn"', (tester) async {
    await _pumpLongTerm(tester);
    // P102 hết hạn sau 3 ngày → vừa là HĐ sắp hết hạn (30 ngày) vừa là khách
    // sắp trả (7 ngày). P103 hết hạn sau hơn một năm → không tính vào đâu cả.
    expect(find.text('1 HĐ sắp hết hạn'), findsOneWidget);
    expect(find.text('1 khách sắp trả phòng'), findsOneWidget);
    expect(find.text('Dự kiến trong 7 ngày tới'), findsOneWidget);
  });

  testWidgets('"Sắp tới" trộn đủ ba loại mốc và xếp theo ngày', (tester) async {
    await _pumpLongTerm(tester);
    expect(find.text('Thu tiền P101'), findsOneWidget);
    expect(find.text('HĐ P102 hết hạn'), findsOneWidget);
    expect(find.text('Khách mới vào P103'), findsOneWidget);
    expect(find.text(_ngayNgan(3)), findsOneWidget);
    expect(find.text(_ngayNgan(5)), findsOneWidget);

    // Xếp theo ngày: 3 ngày nữa đứng trên 5 ngày nữa.
    final tra = tester.getTopLeft(find.text('HĐ P102 hết hạn'));
    final thu = tester.getTopLeft(find.text('Thu tiền P101'));
    expect(tra.dy, lessThan(thu.dy));
  });

  testWidgets('phòng linh hoạt vẫn dùng đúng một Room Unit', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('owner-building-flexible')));
    await tester.pumpAndSettle();
    expect(find.text('1 phòng linh hoạt'), findsOneWidget);
    expect(find.text('P201'), findsOneWidget);

    await tester.tap(find.text('P201'));
    await tester.pumpAndSettle();
    expect(find.text('Dài hạn + Ngắn hạn'), findsOneWidget);
    expect(find.text('Lịch khai thác phòng'), findsOneWidget);
    expect(find.text('Quy tắc vận hành linh hoạt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mở workspace dài hạn và ngắn hạn', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('owner-building-long-term')));
    await tester.pumpAndSettle();
    expect(find.text('Quản lý cho thuê dài hạn'), findsOneWidget);
    expect(find.text('Quản lý'), findsOneWidget);
    expect(find.text('Cần chú ý'), findsOneWidget);
    expect(find.text('Sắp tới'), findsOneWidget);
    expect(find.text('Khách hàng'), findsOneWidget);
    expect(find.text('Phòng'), findsOneWidget);
    expect(find.text('Hợp đồng'), findsOneWidget);
    expect(find.text('Hóa đơn'), findsOneWidget);
    expect(find.text('Doanh thu'), findsOneWidget);
    expect(find.text('Cài đặt'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('owner-building-short-term')));
    await tester.pumpAndSettle();
    expect(find.text('Quản lý cho thuê ngắn hạn'), findsOneWidget);
    expect(find.text('Lịch phòng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('điện thoại 360px không tràn giao diện', (tester) async {
    await _pump(tester, width: 360);
    expect(find.text('Tổng quan tòa nhà'), findsOneWidget);
    expect(find.byKey(const Key('owner-building-long-term')), findsOneWidget);
    expect(find.byKey(const Key('owner-building-short-term')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('danh sách phòng dài hạn dùng lưới hai cột như thiết kế', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final rooms = [
      _room(1, 'DH-101', 'dai_han'),
      _room(
        2,
        'DH-102',
        'dai_han',
        state: 'dang_o',
        tenant: 'Nguyễn Văn An',
        contractEnd: '2026-12-20',
      ),
      _room(3, 'DH-201', 'dai_han'),
    ];
    final provider = _RoomsFake(rooms);

    await pumpApp(
      tester,
      OwnerLongTermRoomsScreen(
        buildingName: 'Vua Nhà Demo Residence',
        rooms: rooms,
        roomProvider: provider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('owner-long-term-room-grid')), findsOneWidget);
    expect(find.byKey(const Key('owner-long-room-1')), findsOneWidget);
    expect(find.byKey(const Key('owner-long-room-2')), findsOneWidget);
    expect(find.text('DH-101'), findsOneWidget);
    expect(find.text('Nguyễn Văn An'), findsOneWidget);
    expect(find.text('HĐ đến: 20/12/2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
