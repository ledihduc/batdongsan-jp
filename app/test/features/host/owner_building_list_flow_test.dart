import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/data/models/building_model.dart';
import 'package:house_booking/data/services/tong_quan_chu_nha_api.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';
import 'package:house_booking/features/host/property/screens/building_list_screen.dart';

import '../../helpers/pump_app.dart';

class _BuildingsFake extends BuildingProvider {
  _BuildingsFake(this.values);

  final List<BuildingModel> values;

  @override
  List<BuildingModel> get buildings => values;

  @override
  bool get isLoading => false;

  @override
  String? get error => null;

  @override
  Future<void> fetchBuildings() async {}
}

class _OverviewFake extends TongQuanChuNhaApi {
  const _OverviewFake();

  @override
  Future<TongQuanChuNha> lay({int? buildingId}) async => TongQuanChuNha(
    soToa: 1,
    soPhong: 24,
    toaMoiThangNay: 0,
    daiHanDangThue: 10,
    daiHanTong: 12,
    daiHanLapDay: 83,
    nganHanHoatDong: 8,
    nganHanCongSuat: 75,
    doanhThuThang: 125600000,
    doanhThuTang: null,
    thangTruoc: 0,
    phongDaThue: 20,
    phongTrong: 4,
    daiHan: const [
      KhoiThue(
        buildingId: 5,
        ten: 'An Cư Home',
        tong: 12,
        dangThue: 10,
        phongNo: 2,
        yeuCauDienNuoc: 1,
      ),
    ],
    kinhDoanh: const [],
    nganHan: const [
      KhoiNganHan(
        buildingId: 5,
        ten: 'An Cư Home',
        tong: 8,
        dangSuDung: 6,
        trong: 2,
        tyLe: 75,
      ),
    ],
    toa: const [(id: 5, ten: 'An Cư Home')],
    toaNha: const [
      ToaNha(
        buildingId: 5,
        ten: 'An Cư Home',
        tong: 24,
        daThue: 20,
        tyLe: 83,
        hoatDong: true,
      ),
    ],
  );
}

BuildingModel _building() => BuildingModel(
  id: 5,
  hostId: 62,
  name: 'An Cư Home',
  address: '123 Nguyễn Văn Linh',
  district: 'Hải Châu',
  city: 'Đà Nẵng',
  ward: '',
  soPhong: 24,
  soPhongTrong: 4,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<void> _pump(WidgetTester tester, {double width = 430}) async {
  tester.view.physicalSize = Size(width, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await pumpApp(
    tester,
    ChangeNotifierProvider<BuildingProvider>.value(
      value: _BuildingsFake([_building()]),
      child: const Scaffold(
        body: BuildingListScreen(overviewApi: _OverviewFake()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hiển thị vỏ danh sách và số liệu thật theo tòa', (tester) async {
    await _pump(tester);

    expect(find.text('Quản lý tòa nhà của bạn'), findsOneWidget);
    expect(find.text('Tòa nhà của bạn'), findsOneWidget);
    expect(find.text('An Cư Home'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('83%'), findsOneWidget);
    expect(find.text('125.6 tr'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bấm tòa mở tổng quan tòa, không mở màn chi tiết cũ', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('owner-building-5')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tổng quan tòa nhà'), findsOneWidget);
    expect(find.text('Quản lý dài hạn'), findsOneWidget);
    expect(find.text('Quản lý ngắn hạn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('màn 360px không tràn giao diện', (tester) async {
    await _pump(tester, width: 360);
    expect(find.text('Quản lý tòa nhà của bạn'), findsOneWidget);
    expect(find.byKey(const Key('owner-building-5')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
