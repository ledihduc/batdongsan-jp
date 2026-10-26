import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/models/viewing_appointment_model.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/data/services/management_read_model_api.dart';
import 'package:house_booking/data/services/viewing_v2_api.dart';
import 'package:house_booking/features/host/appointments/host_appointments_screen.dart';

import '../../../helpers/pump_app.dart';

class _JourneyApiGia extends RentalJourneyApi {
  const _JourneyApiGia();

  @override
  Future<List<ViewingAppointmentModel>> workQueue({
    required String view,
    String? date,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async => [
    ViewingAppointmentModel(
      id: 91,
      houseId: 10,
      guestId: 20,
      bookingDate: '2026-09-23',
      bookingTime: '14:30-15:00',
      message: 'Muốn xem phòng',
      status: 'pending',
      houseTitle: 'Căn hộ The Zen Residence',
      houseImage: null,
      guestName: 'Nguyễn Thị Mai',
    ),
  ];

  @override
  Future<List<RentalJourney>> list({
    required String view,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async => const [];
}

class _CapabilitiesGia extends ManagementReadModelApi {
  const _CapabilitiesGia();

  @override
  Future<ManagementCapabilities> capabilities() async =>
      const ManagementCapabilities(
        activeMode: 'owner',
        modes: ['customer', 'owner'],
        managementV2Enabled: true,
        managementV2WritesEnabled: false,
        viewingV2Enabled: true,
        viewingV2WritesEnabled: true,
      );
}

class _ViewingGia extends ViewingV2Api {
  const _ViewingGia();

  @override
  Future<List<CanonicalViewing>> list({
    required ViewingMode mode,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async => const [
    CanonicalViewing(
      id: 92,
      mode: 'owner',
      status: 'WAITING_CUSTOMER',
      legacyStatus: 'doi_gio',
      bookingDate: '2026-09-24',
      bookingTime: '09:00-10:00',
      resultStatus: 'NONE',
      allowedActions: ['PROPOSE_TIME', 'CANCEL'],
      title: 'Phòng P101 · An Cư Home',
      customerName: 'Nguyễn Văn An',
    ),
  ];
}

void main() {
  testWidgets('trung tâm lịch xem Chủ nhà có đủ bốn nhóm và mở danh sách', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const HostAppointmentsScreen(journeyApi: _JourneyApiGia(), now: null),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lịch xem nhà'), findsOneWidget);
    expect(find.text('Cần xử lý'), findsOneWidget);
    expect(find.text('Sắp tới'), findsOneWidget);
    expect(find.text('Sau khi xem'), findsOneWidget);
    expect(find.text('Lịch sử'), findsOneWidget);
    expect(find.byKey(const Key('owner-viewing-action')), findsOneWidget);

    await tester.tap(find.byKey(const Key('owner-viewing-action')));
    await tester.pumpAndSettle();
    expect(find.text('Căn hộ The Zen Residence'), findsOneWidget);
    expect(find.text('Chờ bạn xử lý'), findsOneWidget);
  });

  testWidgets('flag bật dùng projection canonical nhưng vẫn mở hub cũ', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const HostAppointmentsScreen(
        journeyApi: _JourneyApiGia(),
        managementApi: _CapabilitiesGia(),
        viewingV2Api: _ViewingGia(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('owner-viewing-action')));
    await tester.pumpAndSettle();
    expect(find.text('Phòng P101 · An Cư Home'), findsOneWidget);
    expect(find.text('Chờ khách xác nhận'), findsOneWidget);
  });
}
