import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:house_booking/data/models/reservation_model.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/models/su_kien_lich_su.dart';
import 'package:house_booking/data/services/dat_phong_api.dart';
import 'package:house_booking/data/services/short_stay_api.dart';
import 'package:house_booking/features/guest/booking/room_booking_screen.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_booking_detail_screen.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_bookings_screen.dart';
import 'package:house_booking/features/guest/booking/phieu_dat_phong_screen.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/chi_tiet_ca_thue_screen.dart';
import '../host/ngan_han/ca_thue/ca_thue_gia.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_operations_role.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_rooms_screen.dart';
import 'package:house_booking/features/guest/short_stay/short_stay_search_screen.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> quote(String mode) => {
  'room_id': 1,
  'room_type': 'Phòng đôi',
  'booking_mode': mode,
  'quote_token': 'server-price-v1',
  'check_in_at': '2030-01-01T14:00:00+07:00',
  'check_out_at': '2030-01-01T16:00:00+07:00',
  'unit_price': 80000,
  'quantity': 2,
  'unit': 'giờ',
  'fees': 0,
  'total_amount': 160000,
  'free_cancel_until': '2030-01-01T13:00:00+07:00',
  'cancellation_policy': 'Huỷ trước 1 giờ. Thanh toán tại nơi lưu trú.',
  'payment_policy': 'Thanh toán tại nơi lưu trú',
};
Map<String, dynamic> record({
  bool canCancel = true,
  String status = 'pending',
}) => {
  'id': 1,
  'room_id': 1,
  'guest_user_id': 3,
  'guest_name': 'Khách',
  'guest_phone': '0901234567',
  'check_in_date': '2030-01-01',
  'check_out_date': '2030-01-02',
  'nights': 1,
  'total_amount': 160000,
  'status': status,
  'status_label': status == 'cancelled' ? 'Đã huỷ' : 'Chờ duyệt',
  'created_at': '2029-01-01T00:00:00',
  'updated_at': '2029-01-01T00:00:00',
  'booking_mode': 'theo_gio',
  'booking_code': 'AC-300101-AABBCCDDEE',
  'can_cancel': canCancel,
  'check_in_at': quote('theo_gio')['check_in_at'],
  'check_out_at': quote('theo_gio')['check_out_at'],
  'price_breakdown': quote('theo_gio'),
  'room_code': 'P101',
  'room_type': 'Phòng đôi',
  'building_name': 'Nhà bên sông',
};
Map<String, dynamic> room() => {
  'room_id': 1,
  'room_code': 'P101',
  'room_type': 'Phòng đôi',
  'building_name': 'Nhà bên sông',
  'address': '1 Trần Phú',
  'district': 'Hải Châu',
  'city': 'Đà Nẵng',
  'capacity': 2,
  'products': shortStayModes.entries
      .map(
        (m) => {
          'booking_mode': m.key,
          'label': m.value,
          'unit': 'giờ',
          'unit_price': 80000,
          'stay_rule': 'Chọn thời gian lưu trú',
          'cancellation_policy': 'Huỷ trước 1 giờ.',
        },
      )
      .toList(),
};

/// Màn đặt phòng mở từ tìm kiếm — chỉ cần đủ dữ liệu để dựng.
class _DatPhongGia extends DatPhongApi {
  @override
  Future<ThongTinDatPhong> thongTinDat(int roomId, {int? houseId}) async =>
      ThongTinDatPhong.fromMap({
        'phong': {'room_id': roomId, 'ma': 'P101', 'hang': 'Phòng đôi'},
        'goi': room()['products'],
        'nhan_dat': true,
      });

  @override
  Future<List<KhoangBan>> lichBan(
    int roomId,
    DateTime tuNgay, {
    int soNgay = 14,
  }) async => const [];

  @override
  Future<BaoGiaPhong> baoGia(
    int roomId,
    String hinhThuc,
    DateTime nhan,
    DateTime tra,
  ) async => BaoGiaPhong.fromMap(quote(hinhThuc));
}

/// Phiếu đặt phòng mở từ danh sách "Đặt phòng ngắn hạn của tôi".
class _PhieuGia extends DatPhongApi {
  @override
  Future<PhieuDatPhong> phieu(int id) async => PhieuDatPhong.fromMap({
    'id': id,
    'ma': 'AC-300101-AABBCCDDEE',
    'trang_thai': 'pending',
    'hinh_thuc': 'theo_gio',
    'nhan_luc': '2030-01-01T14:00:00+07:00',
    'tra_luc': '2030-01-01T16:00:00+07:00',
    'so_luong': 2,
    'don_vi': 'giờ',
    'don_gia': 80000,
    'tong': 160000,
    'so_khach': 2,
    'ten_khach': 'Khách',
    'sdt_khach': '0901234567',
    'phong': const {'room_id': 1, 'ma': 'P101', 'hang': 'Phòng đôi', 'toa': 'Nhà bên sông'},
    'diem_den': const {'dia_chi': '1 Trần Phú'},
    'chinh_sach': const <String>[],
  });

  @override
  Future<List<SuKienLichSu>> lichSu(int id) async => const [];
}

class FakeApi extends ShortStayApi {
  int books = 0, cancels = 0, searches = 0, actions = 0;
  String bookingStatus = 'pending';
  bool eligible = true;
  bool owner = false;
  Map<String, dynamic>? savedRates;
  int blockCount = 0;
  bool failQuote = false;
  String? mode;
  @override
  Future<Map<String, dynamic>> detail(int id) async => room();
  @override
  Future<Map<String, dynamic>> quote(
    int id,
    String mode,
    DateTime start,
    DateTime end,
  ) async {
    this.mode = mode;
    if (failQuote) throw ApiException(409, 'Phòng vừa được giữ chỗ');
    return _quote(mode);
  }

  Map<String, dynamic> _quote(String mode) => {
    ...record()['price_breakdown'] as Map<String, dynamic>,
    'booking_mode': mode,
  };
  @override
  Future<ReservationModel> book(
    Map<String, dynamic> quote,
    String name,
    String phone,
    String note, {
    int? houseId,
  }) async {
    books++;
    return ReservationModel.fromJson(record());
  }

  @override
  Future<List<ReservationModel>> bookings({
    bool operations = false,
    bool today = true,
  }) async => [
    ReservationModel.fromJson(
      record(
        canCancel: eligible,
        status: cancels > 0 ? 'cancelled' : bookingStatus,
      ),
    ),
  ];
  @override
  Future<ReservationModel> cancel(int id) async {
    cancels++;
    eligible = false;
    return ReservationModel.fromJson(
      record(canCancel: false, status: 'cancelled'),
    );
  }

  @override
  Future<ReservationModel> action(int id, String action, String? reason) async {
    actions++;
    bookingStatus = switch (action) {
      'approve' => 'approved',
      'reject' => 'rejected',
      'check_in' => 'checked_in',
      'check_out' => 'checked_out',
      'cancel' => 'cancelled',
      _ => bookingStatus,
    };
    return ReservationModel.fromJson(
      record(canCancel: bookingStatus == 'approved', status: bookingStatus),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> search({
    String query = '',
    String? mode,
    DateTime? start,
    DateTime? end,
  }) async {
    searches++;
    this.mode = mode;
    return [
      {...room(), 'quote': _quote(mode!)},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> rooms() async => [
    {
      ...room(),
      'dang_bat': true,
      'can_set_rates': owner,
      'rates': {
        'gia_theo_gio': 80000,
        'gia_qua_dem': null,
        'gia_theo_ngay': null,
        'huy_truoc_gio': 1,
        'huy_truoc_dem': 2,
        'huy_truoc_ngay': 12,
      },
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> blocks(int id) async => blockCount > 0
      ? [
          {
            'id': 1,
            'check_in_at': '2030-01-01T14:00:00+07:00',
            'check_out_at': '2030-01-01T16:00:00+07:00',
            'note': 'Bảo trì',
          },
        ]
      : [];
  @override
  Future<void> rates(int id, Map<String, dynamic> rates) async {
    savedRates = rates;
  }

  @override
  Future<void> block(int id, DateTime start, DateTime end, String note) async {
    blockCount++;
  }

  @override
  Future<void> unblock(int roomId, int blockId) async {
    blockCount--;
  }
}

Future<void> large(WidgetTester t, Widget child) async {
  t.view.physicalSize = const Size(500, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await pumpApp(t, child, auth: SignedInAuthProvider(id: 3));
  await t.pumpAndSettle();
}

void main() {
  test(
    'API quote/book sends exact zoned time and quote token, no owner or price input',
    () async {
      final requests = <http.Request>[];
      final api = ShortStayApi(
        client: ApiClient(
          client: MockClient((r) async {
            requests.add(r);
            return http.Response(
              jsonEncode(
                r.url.path.endsWith('quote') ? quote('theo_gio') : record(),
              ),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      final q = await api.quote(
        1,
        'theo_gio',
        DateTime(2030, 1, 1, 14),
        DateTime(2030, 1, 1, 16),
      );
      final res = await api.book(q, 'Khách', '0901234567', '');
      final body = jsonDecode(requests.last.body) as Map;
      expect(body['quote_token'], 'server-price-v1');
      expect(body['check_in_at'], '2030-01-01T14:00:00+07:00');
      expect(body.containsKey('host_id'), false);
      expect(body.containsKey('total_amount'), false);
      expect(res.hostId, 0);
      expect(res.bookingCode, 'AC-300101-AABBCCDDEE');
    },
  );
  test('legacy reservation remains readable without new fields', () {
    final data = record()
      ..remove('booking_mode')
      ..remove('booking_code')
      ..remove('can_cancel');
    final r = ReservationModel.fromJson(data);
    expect(r.bookingMode, isNull);
    expect(r.nights, 1);
    expect(r.canCancel, false);
  });
  test('Vietnam time display is independent of device timezone', () {
    expect(stayTime('2030-01-01T07:00:00Z'), '1/1/2030 14:00');
  });
  testWidgets(
    'guest cancellation requires confirmation and refreshes eligibility',
    (t) async {
      final api = FakeApi();
      await large(t, ShortStayBookingsScreen(api: api));
      await t.tap(find.text('Huỷ đặt phòng'));
      await t.pumpAndSettle();
      expect(api.cancels, 0);
      await t.tap(find.widgetWithText(FilledButton, 'Huỷ đặt phòng'));
      await t.pumpAndSettle();
      expect(api.cancels, 1);
      expect(find.text('Đã huỷ'), findsOneWidget);
      expect(find.text('Huỷ đặt phòng'), findsNothing);
    },
  );
  testWidgets('guest taps a mode booking and gets the booking slip', (
    t,
  ) async {
    final api = FakeApi();
    await large(
      t,
      ShortStayBookingsScreen(api: api, datPhongApi: _PhieuGia()),
    );

    expect(
      find.byKey(const Key('customer-short-stay-bookings')),
      findsOneWidget,
    );
    expect(find.text('Tất cả (1)'), findsOneWidget);
    expect(find.text('Chờ xác nhận'), findsOneWidget);
    await t.tap(find.byKey(const Key('customer-short-stay-booking-1')));
    await t.pumpAndSettle();

    // Một màn đơn duy nhất cho khách: phiếu (mã, QR, đổi giờ, huỷ).
    expect(find.byType(PhieuDatPhongScreen), findsOneWidget);
    expect(find.byType(ShortStayBookingDetailScreen), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('customer short-stay list and detail do not overflow on mobile', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final api = FakeApi();
    await pumpApp(
      t,
      ShortStayBookingsScreen(api: api, datPhongApi: _PhieuGia()),
      auth: SignedInAuthProvider(id: 3),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);

    await t.tap(find.byKey(const Key('customer-short-stay-booking-1')));
    await t.pumpAndSettle();
    expect(find.byType(PhieuDatPhongScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('expired booking has no guest cancel button', (t) async {
    await large(t, ShortStayBookingsScreen(api: FakeApi()..eligible = false));
    expect(find.text('Huỷ đặt phòng'), findsNothing);
  });
  testWidgets('search includes mode and opens the selected room', (t) async {
    final api = FakeApi();
    await large(
      t,
      ShortStaySearchScreen(api: api, datPhongApi: _DatPhongGia()),
    );
    await t.tap(find.text('Theo ngày'));
    await t.pumpAndSettle();
    await t.tap(find.text('Tìm phòng trống'));
    await t.pumpAndSettle();
    expect(api.mode, 'theo_ngay');
    await t.tap(find.text('Nhà bên sông · Phòng P101'));
    await t.pumpAndSettle();
    expect(find.byType(RoomBookingScreen), findsOneWidget);
    expect(find.text('Phòng đôi · P101'), findsOneWidget);
  });
  testWidgets('sale sees operational controls and cannot edit rates', (
    t,
  ) async {
    final api = FakeApi();
    // Sale: không có quyền tiền → màn quầy ẩn phần tiền.
    final ca = CaThueGia(mauCa(trangThai: 'pending', xemTaiChinh: false));
    await large(
      t,
      ShortStayBookingsScreen(api: api, operations: true, caThueApi: ca),
    );
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Điều phối ngắn hạn'), findsOneWidget);
    expect(find.byKey(const Key('short-stay-sale-operations')), findsOneWidget);
    await t.tap(find.byKey(const Key('short-stay-operation-booking-1')));
    await t.pumpAndSettle();
    expect(find.byType(ChiTietCaThueScreen), findsOneWidget);
    await t.tap(find.byKey(const Key('ca-thue-duyet')));
    await t.pumpAndSettle();
    expect(api.actions, 1);
    await t.tap(find.byTooltip('Quay lại'));
    await t.pumpAndSettle();
    await t.tap(find.text('Giá & khóa phòng'));
    await t.pumpAndSettle();
    await t.tap(find.text('Nhà bên sông · P101'));
    await t.pumpAndSettle();
    expect(
      find.text('Giá và chính sách do chủ phòng quyết định.'),
      findsOneWidget,
    );
    expect(find.text('Lưu giá & chính sách'), findsNothing);
    expect(find.text('Khoá khoảng thời gian'), findsOneWidget);
  });
  testWidgets('owner gets a dedicated short-stay operations workspace', (
    t,
  ) async {
    final api = FakeApi();
    final ca = CaThueGia(mauCa(trangThai: 'pending'));
    t.view.physicalSize = const Size(360, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpApp(
      t,
      ShortStayBookingsScreen(
        api: api,
        caThueApi: ca,
        operations: true,
        operationsRole: ShortStayOperationsRole.owner,
      ),
      auth: SignedInAuthProvider(id: 3),
    );
    await t.pumpAndSettle();

    expect(find.text('Vận hành ngắn hạn'), findsOneWidget);
    expect(find.text('Chờ duyệt'), findsOneWidget);
    expect(
      find.byKey(const Key('short-stay-owner-operations')),
      findsOneWidget,
    );
    await t.tap(find.byKey(const Key('short-stay-operation-booking-1')));
    await t.pumpAndSettle();
    // Chủ nhà đi thẳng vào quầy lễ tân (có quyết toán), không còn màn
    // vận hành cũ — trả phòng ở đó từng bỏ qua tiền và khoá dọn.
    expect(find.byType(ChiTietCaThueScreen), findsOneWidget);
    expect(find.byKey(const Key('ca-thue-duyet')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('sale confirms check-in and check-out without the money screens', (
    t,
  ) async {
    final api = FakeApi()..bookingStatus = 'approved';
    final ca = CaThueGia(mauCa(trangThai: 'approved', xemTaiChinh: false));
    await large(
      t,
      ShortStayBookingsScreen(api: api, operations: true, caThueApi: ca),
    );
    await t.tap(find.byKey(const Key('short-stay-operation-booking-1')));
    await t.pumpAndSettle();

    // Gia hạn ghi tiền → sale không bấm được.
    final giaHan = t.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Gia hạn giờ'),
        matching: find.byWidgetPredicate((w) => w is OutlinedButton),
      ),
    );
    expect(giaHan.onPressed, isNull);

    await t.tap(find.byKey(const Key('ca-thue-xac-nhan-sale')));
    await t.pumpAndSettle();
    expect(find.text('Xác nhận khách đã nhận phòng?'), findsOneWidget);
    ca.du = mauCa(trangThai: 'checked_in', xemTaiChinh: false);
    await t.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
    await t.pumpAndSettle();
    expect(api.bookingStatus, 'checked_in');
    expect(ca.ghi.where((g) => g.startsWith('nhan')), isEmpty);

    await t.tap(find.byKey(const Key('ca-thue-xac-nhan-sale')));
    await t.pumpAndSettle();
    expect(find.text('Xác nhận trả phòng?'), findsOneWidget);
  });
  testWidgets('owner saves room type and prices, blocks and reopens a room', (
    t,
  ) async {
    final api = FakeApi()..owner = true;
    await large(t, ShortStayRoomsScreen(api: api));
    await t.tap(find.text('Nhà bên sông · P101'));
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(TextField, 'Loại phòng *'),
      'Phòng hai giường',
    );
    await t.enterText(
      find.widgetWithText(TextField, 'Giá mỗi giờ (đ)'),
      '95000',
    );
    await t.tap(find.text('Lưu giá & chính sách'));
    await t.pumpAndSettle();
    expect(api.savedRates?['loai_phong'], 'Phòng hai giường');
    expect(api.savedRates?['gia_theo_gio'], 95000);
    await t.ensureVisible(find.text('Khoá khoảng thời gian'));
    await t.tap(find.text('Khoá khoảng thời gian'));
    await t.pumpAndSettle();
    expect(api.blockCount, 1);
    await t.ensureVisible(find.text('Mở lại'));
    await t.tap(find.text('Mở lại'));
    await t.pumpAndSettle();
    expect(api.blockCount, 0);
  });
}
