import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/data/services/quan_ly_api.dart';
import 'package:house_booking/data/services/management_read_model_api.dart';
import 'package:house_booking/data/services/viewing_v2_api.dart';
import 'package:house_booking/features/guest/customer/customer_journey_store.dart';
import 'package:house_booking/features/guest/customer/customer_screens.dart';
import 'package:house_booking/providers/auth_provider.dart';

class _Auth extends AuthProvider {
  @override
  UserModel? get currentUser => UserModel(
    id: 42,
    name: 'Nguyễn Thị Lan',
    email: 'lan@example.com',
    passwordHash: '',
    phone: '',
    avatarPath: '',
    role: 'guest',
    accountType: 'customer',
    createdAt: DateTime(2025, 1, 1),
  );

  @override
  bool get isAuthenticated => true;
}

class _Api extends QuanLyApi {
  _Api(this.data);
  final TongHopQuanLy data;

  @override
  Future<TongHopQuanLy> tongHop(GocQuanLy goc) async => data;
}

class _Store extends CustomerJourneyStore {
  final Map<int, CustomerJourneyEntry> entries = {};

  @override
  Future<Map<int, CustomerJourneyEntry>> read(int userId) async => entries;

  @override
  Future<void> save(
    int userId,
    int appointmentId,
    CustomerJourneyEntry entry,
  ) async {
    entries[appointmentId] = entry;
  }

  @override
  Future<void> remove(int userId, int appointmentId) async {
    entries.remove(appointmentId);
  }
}

class _Capabilities extends ManagementReadModelApi {
  @override
  Future<ManagementCapabilities> capabilities() async =>
      const ManagementCapabilities(
        activeMode: 'customer',
        modes: ['customer'],
        managementV2Enabled: true,
        managementV2WritesEnabled: true,
        viewingV2Enabled: true,
        viewingV2WritesEnabled: true,
      );
}

class _CanonicalApi extends ViewingV2Api {
  String? submittedStatus;

  @override
  Future<CanonicalViewing> submitResult(
    int id, {
    required String status,
    String? reasonCode,
    String? reasonNote,
  }) async {
    submittedStatus = status;
    return _viewing(status);
  }

  @override
  Future<List<CanonicalViewing>> list({
    required ViewingMode mode,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async => [if (submittedStatus != null) _viewing(submittedStatus!)];

  CanonicalViewing _viewing(String status) => CanonicalViewing(
    id: 25,
    mode: 'customer',
    status: 'COMPLETED',
    legacyStatus: 'completed',
    bookingDate: '2026-09-20',
    bookingTime: '09:00-10:00',
    resultStatus: status,
    allowedActions: const ['UPDATE_RESULT'],
    title: 'Căn hộ 3PN 82m² tầng trung',
    customerName: 'Nguyễn Thị Lan',
  );
}

MucQuanLy _appointment({DateTime? date}) => MucQuanLy(
  loai: 'xem_nha',
  id: 25,
  tieuDe: 'Căn hộ 3PN 82m² tầng trung',
  diaChi: 'Thượng Lý, Hồng Bàng, Hải Phòng',
  nhom: NhomQuanLy.daDat,
  nhan: 'Đã xác nhận',
  anh: null,
  batDau: date ?? DateTime.now().subtract(const Duration(days: 1)),
  ketThuc: date ?? DateTime.now().subtract(const Duration(days: 1)),
);

Widget _app(Widget child) => ChangeNotifierProvider<AuthProvider>.value(
  value: _Auth(),
  child: MaterialApp(home: Scaffold(body: child)),
);

void _usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('customer profile exposes the reference quick actions', (
    tester,
  ) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(
      _app(
        CustomerProfileScreen(
          onOpenManage: () {},
          api: _Api(const TongHopQuanLy()),
          store: _Store(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nguyễn Thị Lan'), findsOneWidget);
    expect(find.text('Quản lý của tôi'), findsOneWidget);
    expect(find.text('Bài đã lưu'), findsOneWidget);
    expect(find.text('Nhu cầu đã đăng'), findsOneWidget);
    expect(find.text('Thông tin cá nhân'), findsOneWidget);
    expect(find.text('Chính sách & điều khoản'), findsOneWidget);
  });

  testWidgets('a completed viewing can be filed into customer journey tabs', (
    tester,
  ) async {
    _usePhoneSize(tester);
    final store = _Store();
    final api = _Api(TongHopQuanLy(danhSach: [_appointment()]));
    await tester.pumpWidget(
      _app(CustomerManagementScreen(api: api, store: store)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quản lý của tôi'), findsOneWidget);
    expect(find.text('Căn hộ 3PN 82m² tầng trung'), findsOneWidget);
    await tester.tap(find.text('Cập nhật kết quả sau xem'));
    await tester.pumpAndSettle();
    expect(find.text('Kết quả sau xem'), findsOneWidget);

    await tester.tap(find.text('Muốn thuê'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Lưu kết quả'),
      350,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Lưu kết quả'));
    await tester.pumpAndSettle();

    expect(store.entries[25]?.decision, CustomerDecision.wantToRent);
  });

  testWidgets(
    'journey tabs remain scrollable and expose rental and history states',
    (tester) async {
      _usePhoneSize(tester);
      await tester.pumpWidget(
        _app(
          CustomerManagementScreen(
            api: _Api(const TongHopQuanLy()),
            store: _Store(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Lịch xem ('), findsOneWidget);
      expect(find.textContaining('Đang cân nhắc ('), findsOneWidget);
      expect(find.textContaining('Muốn thuê ('), findsOneWidget);

      await tester.drag(find.byType(TabBar), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.textContaining('Lịch sử ('), findsOneWidget);
    },
  );

  testWidgets('migrates readable local decisions then uses server truth', (
    tester,
  ) async {
    _usePhoneSize(tester);
    final store = _Store();
    store.entries[25] = CustomerJourneyEntry(
      decision: CustomerDecision.wantToRent,
      updatedAt: DateTime(2026, 9, 20),
    );
    final canonical = _CanonicalApi();
    await tester.pumpWidget(
      _app(
        CustomerManagementScreen(
          api: _Api(TongHopQuanLy(danhSach: [_appointment()])),
          store: store,
          managementApi: _Capabilities(),
          viewingV2Api: canonical,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(canonical.submittedStatus, 'INTERESTED');
    expect(store.entries, isEmpty);
    expect(find.textContaining('Muốn thuê ('), findsOneWidget);
  });
}
