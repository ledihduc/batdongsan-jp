import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/models/viewing_appointment_model.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/features/host/journey/tong_quan_xem_nha_screen.dart';

import '../../../helpers/pump_app.dart';

/// TỔNG QUAN XEM NHÀ (chủ nhà) — màn 1 của mockup CHỦ NHÀ.
///
/// Điều phải giữ bằng test:
///   * ba con số đầu màn đếm đúng ba việc khác nhau (chờ xác nhận · lịch hôm
///     nay · chờ xác nhận cọc);
///   * nhãn trạng thái nói đúng việc đã xong: lịch ĐÃ CHỐT THUÊ từng bị gắn
///     "Chờ xác nhận" vì màn chỉ biết mỗi `approved` — tức là giục chủ nhà làm
///     lại việc đã xong.
class _OwnerGia extends RentalJourneyApi {
  _OwnerGia(this.hang, {this.hoSo = const []});

  final List<ViewingAppointmentModel> hang;
  final List<RentalJourney> hoSo;

  @override
  Future<List<ViewingAppointmentModel>> workQueue({
    required String view,
    String? date,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async => hang;

  @override
  Future<List<RentalJourney>> list({
    required String view,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async => hoSo;
}

ViewingAppointmentModel _hen({
  required int id,
  required String ngay,
  required String trangThai,
  String gio = '09:00-10:00',
}) => ViewingAppointmentModel(
  id: id,
  guestId: 52,
  bookingDate: ngay,
  bookingTime: gio,
  message: '',
  status: trangThai,
  createdAt: DateTime(2026, 9, 20, 8),
  guestName: 'Ngô Bảo Anh',
  houseTitle: 'Phòng trọ khép kín 30m²',
);

RentalJourney _hoSoChoCoc() => RentalJourney.fromMap({
  'id': 4,
  'appointment_id': 33,
  'status': 'CUSTOMER_CONFIRMATION_PENDING',
  'viewer_role': 'owner',
  'subject': {'title': 'Phòng P301', 'image': null},
  'participants': {
    'customer': {'id': 66, 'name': 'Phạm Minh Tuấn'},
    'sale': {'id': 65, 'name': 'Nguyễn Thị Lan'},
    'owner': {'id': 64, 'name': 'Trần Văn Hùng'},
  },
  'appointment': {'date': '2026-09-20', 'time': '09:00-10:00', 'status': 'locked'},
  'contract': {'urls': [], 'note': null, 'submitted_at': null},
  'total_deposit': 3200000,
  'payments': [],
  'available_actions': ['ACKNOWLEDGE_OWNER_DEPOSIT'],
  'created_at': '2026-09-20T09:00:00',
  'updated_at': '2026-09-20T09:00:00',
});

void main() {
  final bayGio = DateTime(2026, 9, 20, 19);

  Future<void> mo(WidgetTester t, _OwnerGia api) async {
    t.view.physicalSize = const Size(430, 2600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await pumpApp(
      t,
      TongQuanXemNhaScreen(
        api: api,
        tenChuNha: 'Trần Văn Hùng',
        bayGio: bayGio,
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
  }

  testWidgets('ba con số: chờ xác nhận · hôm nay · chờ cọc', (t) async {
    await mo(
      t,
      _OwnerGia(
        [
          _hen(id: 43, ngay: '2026-09-21', trangThai: 'pending'),
          _hen(id: 45, ngay: '2026-09-20', trangThai: 'approved'),
          _hen(id: 33, ngay: '2026-09-20', trangThai: 'locked'),
        ],
        hoSo: [_hoSoChoCoc()],
      ),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('chu-dem-yeu-cau-cho')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('chu-dem-lich-hom-nay')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('chu-dem-cho-coc')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('lịch đã chốt thuê KHÔNG bị gắn "Chờ xác nhận"', (t) async {
    await mo(
      t,
      _OwnerGia([_hen(id: 33, ngay: '2026-09-20', trangThai: 'locked')]),
    );
    expect(find.text('Đã chốt thuê'), findsOneWidget);
    expect(find.text('Chờ xác nhận'), findsNothing);
  });

  testWidgets('không có việc thì nói rõ từng mục', (t) async {
    await mo(t, _OwnerGia(const []));
    expect(find.text('Không có yêu cầu nào đang chờ bạn.'), findsOneWidget);
    expect(find.text('Hôm nay không có lịch xem nào.'), findsOneWidget);
    expect(find.text('Chưa có khoản cọc nào chờ bạn xác nhận.'), findsOneWidget);
  });
}
