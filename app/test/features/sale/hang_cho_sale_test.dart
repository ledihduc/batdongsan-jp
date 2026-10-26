import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/models/viewing_appointment_model.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/features/sale/viec_can_xu_ly_screen.dart';

import '../../helpers/pump_app.dart';

/// HÀNG CHỜ CỦA SALE — màn 1 "Việc cần xử lý".
///
/// Điều phải giữ bằng test: bốn con số đầu màn và danh sách việc phải nói đúng
/// trạng thái THẬT mà `work-queue` trả về. Bản đầu chỉ biết `pending` và
/// `approved`, nên một hàng chờ đầy `locked`/`doi_gio` hiện ra thành "0 việc" —
/// sale mở app thấy trống trong khi khách đang đợi.
class _QueueGia extends RentalJourneyApi {
  _QueueGia(this.hang, {this.hoSo = const []});

  final List<ViewingAppointmentModel> hang;
  final List<RentalJourney> hoSo;

  @override
  Future<List<ViewingAppointmentModel>> workQueue({
    required String view,
    String? date,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async => date == null
      ? hang
      : [
          for (final a in hang)
            if (a.bookingDate == date) a,
        ];

  @override
  Future<List<RentalJourney>> list({
    required String view,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async => hoSo;
}

RentalJourney _hoSo({
  required int id,
  String trangThai = RentalJourneyStatus.customerInterested,
  List<String> hanhDong = const [],
}) => RentalJourney.fromMap({
  'id': id,
  'appointment_id': 33,
  'status': trangThai,
  'viewer_role': 'sale',
  'subject': {'title': 'Phòng P301 · Nhà trọ An Cư Văn Cao', 'image': null},
  'participants': {
    'customer': {'id': 66, 'name': 'Phạm Minh Tuấn'},
    'sale': {'id': 65, 'name': 'Nguyễn Thị Lan'},
    'owner': {'id': 64, 'name': 'Trần Văn Hùng'},
  },
  'appointment': {
    'date': '2026-09-20',
    'time': '09:00-10:00',
    'status': 'locked',
  },
  'contract': {'urls': [], 'note': null, 'submitted_at': null},
  'total_deposit': 0,
  'payments': [],
  'available_actions': hanhDong,
  'created_at': '2026-09-20T09:00:00',
  'updated_at': '2026-09-20T09:00:00',
});

ViewingAppointmentModel _hen({
  required int id,
  required String ngay,
  required String trangThai,
  String gio = '09:00-10:00',
  String khach = 'Ngô Bảo Anh',
}) => ViewingAppointmentModel(
  id: id,
  guestId: 52,
  bookingDate: ngay,
  bookingTime: gio,
  message: '',
  status: trangThai,
  createdAt: DateTime(2026, 9, 20, 8),
  guestName: khach,
  houseTitle: 'Phòng trọ khép kín 30m²',
);

void main() {
  final bayGio = DateTime(2026, 9, 20, 19);

  Future<void> mo(WidgetTester t, _QueueGia api) async {
    t.view.physicalSize = const Size(430, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await pumpApp(
      t,
      ViecCanXuLyScreen(api: api, tenSale: 'Nguyễn Thị Lan', bayGio: bayGio),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
  }

  testWidgets('đếm đúng: mới · quá hạn · lịch hôm nay', (t) async {
    await mo(
      t,
      _QueueGia([
        _hen(id: 43, ngay: '2026-09-21', trangThai: 'pending'),
        _hen(id: 44, ngay: '2026-09-19', trangThai: 'pending'),
        _hen(id: 45, ngay: '2026-09-20', trangThai: 'approved'),
        _hen(id: 33, ngay: '2026-09-20', trangThai: 'locked'),
        _hen(id: 32, ngay: '2026-06-27', trangThai: 'completed'),
      ]),
    );

    for (final khoa in ['yeu-cau-moi', 'qua-han', 'lich-hom-nay']) {
      expect(
        find.descendant(
          of: find.byKey(Key('sale-dem-$khoa')),
          matching: find.text('1'),
        ),
        findsOneWidget,
        reason: 'ô $khoa phải đếm đúng 1',
      );
    }
    // Lịch đã chốt thuê và buổi xem cũ KHÔNG phải việc đang chờ.
    expect(find.byKey(const Key('sale-viec-33')), findsNothing);
    expect(find.byKey(const Key('sale-viec-32')), findsNothing);
  });

  testWidgets('quá hạn đứng trước việc mới, đúng nhãn', (t) async {
    await mo(
      t,
      _QueueGia([
        _hen(id: 43, ngay: '2026-09-21', trangThai: 'pending'),
        _hen(id: 44, ngay: '2026-09-19', trangThai: 'pending'),
      ]),
    );
    final tre = t.getTopLeft(find.byKey(const Key('sale-viec-44')));
    final moi = t.getTopLeft(find.byKey(const Key('sale-viec-43')));
    expect(tre.dy, lessThan(moi.dy));
    expect(find.text('Quá hạn'), findsOneWidget);
    expect(find.text('Mới'), findsOneWidget);
  });

  testWidgets('sale đã đổi giờ: là việc "Chờ khách", không phải yêu cầu mới', (
    t,
  ) async {
    await mo(
      t,
      _QueueGia([_hen(id: 36, ngay: '2026-09-19', trangThai: 'doi_gio')]),
    );
    expect(find.byKey(const Key('sale-viec-36')), findsOneWidget);
    expect(find.text('Chờ khách'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('sale-dem-yeu-cau-moi')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('hồ sơ chờ gửi hợp đồng hiện ngay ở bảng việc', (t) async {
    // Trước đây màn "Gửi hồ sơ chốt thuê" chỉ mở được từ dòng lịch trong đúng
    // ngày diễn ra buổi xem — hôm sau sale hết đường vào.
    await mo(
      t,
      _QueueGia(
        const [],
        hoSo: [
          _hoSo(id: 7, hanhDong: [RentalJourneyAction.uploadContract]),
        ],
      ),
    );
    expect(find.text('Hồ sơ chốt thuê'), findsOneWidget);
    expect(find.byKey(const Key('sale-ho-so-7')), findsOneWidget);
    expect(find.text('Phạm Minh Tuấn'), findsOneWidget);
  });

  testWidgets('hồ sơ tranh chấp đếm riêng, không nằm ở mục hợp đồng', (
    t,
  ) async {
    await mo(
      t,
      _QueueGia(
        const [],
        hoSo: [
          _hoSo(
            id: 8,
            trangThai: RentalJourneyStatus.disputed,
            hanhDong: [RentalJourneyAction.reportParticipant],
          ),
        ],
      ),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('sale-dem-tranh-chap')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(find.text('Hồ sơ chốt thuê'), findsNothing);
  });

  testWidgets('hàng chờ rỗng thì nói rõ, không để màn trắng', (t) async {
    await mo(t, _QueueGia(const []));
    expect(find.text('Không có việc nào đang chờ'), findsOneWidget);
  });
}
