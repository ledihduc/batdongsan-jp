import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/data/models/building_model.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/data/services/tong_quan_chu_nha_api.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';
import 'package:house_booking/features/host/property/screens/building_list_screen.dart';

import '../../../helpers/pump_app.dart';

/// ĐƯỜNG VÀO hồ sơ chờ chốt của chủ nhà (23/09/2026).
///
/// Nút "Nhận khách vào ở" nằm trong màn Xác nhận cọc, mà màn đó trước giờ chỉ
/// tới được từ work-queue hoặc màn kết quả buổi xem — chủ nhà mở app lên gần
/// như không tìm ra. Nay tab Chủ nhà hiện thẳng danh sách hồ sơ đang chờ
/// chính mình bấm, và KHÔNG vẽ thẻ khi không có hồ sơ nào.
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
  Future<TongQuanChuNha> lay({int? buildingId}) async => const TongQuanChuNha(
    soToa: 1,
    soPhong: 10,
    toaMoiThangNay: 0,
    daiHanDangThue: 3,
    daiHanTong: 5,
    daiHanLapDay: 60,
    nganHanHoatDong: 0,
    nganHanCongSuat: 0,
    doanhThuThang: 0,
    doanhThuTang: null,
    thangTruoc: 0,
    phongDaThue: 3,
    phongTrong: 7,
    daiHan: [],
    kinhDoanh: [],
    nganHan: [],
    toa: [],
    toaNha: [],
  );
}

class _JourneyFake extends RentalJourneyApi {
  _JourneyFake(this.actions);
  final List<String> actions;

  @override
  Future<List<RentalJourney>> list({
    required String view,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async => [
    RentalJourney.fromMap({
      'id': 4,
      'appointment_id': 33,
      'status': 'CUSTOMER_CONFIRMATION_PENDING',
      'viewer_role': 'owner',
      'subject': {'title': 'Phòng P203 · An Cư Home', 'image': null},
      'participants': {
        'customer': {'id': 1, 'name': 'Phạm Minh Tuấn'},
        'sale': {'id': 2, 'name': 'Nguyễn Thị Mai'},
        'owner': {'id': 3, 'name': 'Trần Văn Hùng'},
      },
      'appointment': {
        'date': '2026-09-20',
        'time': '09:00',
        'status': 'completed',
      },
      'contract': {
        'urls': ['/uploads/hd.pdf'],
        'note': null,
        'submitted_at': null,
      },
      'total_deposit': 10000000,
      'payments': [],
      'available_actions': actions,
      'created_at': '2026-09-20T09:00:00',
      'updated_at': '2026-09-23T09:00:00',
    }),
  ];
}

BuildingModel _toa() => BuildingModel(
  id: 5,
  hostId: 62,
  name: 'An Cư Home',
  address: '123 Nguyễn Văn Linh',
  district: 'Hải Châu',
  city: 'Đà Nẵng',
  ward: '',
  soPhong: 10,
  soPhongTrong: 7,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<void> _pump(WidgetTester t, List<String> actions) async {
  t.view.physicalSize = const Size(430, 2200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await pumpApp(
    t,
    ChangeNotifierProvider<BuildingProvider>.value(
      value: _BuildingsFake([_toa()]),
      child: Scaffold(
        body: BuildingListScreen(
          overviewApi: const _OverviewFake(),
          journeyApi: _JourneyFake(actions),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('có hồ sơ chờ chốt: hiện thẻ kèm tên khách và phòng', (t) async {
    await _pump(t, const ['CONFIRM_RENTAL', 'CANCEL_JOURNEY']);
    expect(find.text('Hồ sơ chờ bạn chốt · 1'), findsOneWidget);
    expect(find.text('Phòng P203 · An Cư Home'), findsOneWidget);
    expect(find.text('Khách Phạm Minh Tuấn'), findsOneWidget);
    expect(find.byKey(const Key('owner-ho-so-cho-chot-4')), findsOneWidget);
  });

  testWidgets('chưa tới lượt mình: không vẽ thẻ rỗng', (t) async {
    await _pump(t, const ['CANCEL_JOURNEY', 'REPORT_PARTICIPANT']);
    expect(find.textContaining('Hồ sơ chờ bạn chốt'), findsNothing);
  });

  testWidgets('bấm hồ sơ mở màn xác nhận của chủ nhà', (t) async {
    await _pump(t, const ['CONFIRM_RENTAL']);
    await t.tap(find.byKey(const Key('owner-ho-so-cho-chot-4')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Cọc & nhận khách'), findsOneWidget);
  });
}
