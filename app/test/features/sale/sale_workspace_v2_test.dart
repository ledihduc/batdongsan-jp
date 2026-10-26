import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/data/services/management_read_model_api.dart';
import 'package:house_booking/data/services/sale_crm_v2_api.dart';
import 'package:house_booking/features/sale/sale_workspace_screen.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/notification_provider.dart';

import '../../helpers/pump_app.dart';

class _SaleAuth extends AuthProvider {
  @override
  bool get isAuthenticated => true;

  @override
  UserModel get currentUser => UserModel(
    id: 71,
    name: 'Nguyễn Thị Mai',
    email: 'sale@test.vn',
    passwordHash: '',
    phone: '',
    avatarPath: '',
    role: 'guest',
    accountType: 'sale',
  );
}

class _Capabilities extends ManagementReadModelApi {
  @override
  Future<ManagementCapabilities> capabilities() async =>
      const ManagementCapabilities(
        activeMode: 'sale',
        modes: ['customer', 'sale'],
        managementV2Enabled: true,
        managementV2WritesEnabled: true,
        saleCrmV2Enabled: true,
        saleCrmV2WritesEnabled: true,
      );
}

class _Crm extends SaleCrmV2Api {
  @override
  Future<SaleCrmDashboard> dashboard() async => const SaleCrmDashboard(
    contacts: 2,
    openTasks: 1,
    overdueTasks: 1,
    activeDeals: 1,
    propertyCount: 1,
  );

  @override
  Future<List<SaleCrmContact>> contacts({String? type}) async => const [
    SaleCrmContact(
      id: 1,
      type: 'CUSTOMER',
      name: 'Nguyễn Văn An',
      phone: '0900000001',
      email: '',
      openTasks: 1,
      deepLink: '/activity/sale/contacts/1',
    ),
  ];

  @override
  Future<List<SaleCrmTask>> tasks({String? status}) async => [
    SaleCrmTask(
      id: 2,
      title: 'Nhắc khách xác nhận lịch',
      dueAt: DateTime(2026, 9, 22, 10),
      status: 'OPEN',
      deepLink: '/activity/viewings/2',
    ),
  ];

  @override
  Future<List<SaleCrmProperty>> properties() async => const [
    SaleCrmProperty(
      id: 3,
      name: 'An Cư Home',
      address: 'Hải Phòng',
      roomCount: 10,
      occupiedCount: 8,
      listedCount: 2,
    ),
  ];

  @override
  Future<List<SaleCrmDeal>> deals() async => const [
    SaleCrmDeal(
      id: 4,
      amount: 5000000,
      transactionStatus: 'pending',
      pipelineStage: 'PAPERWORK',
      customerId: 5,
    ),
  ];

  @override
  Future<List<SaleStaySupport>> staySupport() async => const [];
}

void main() {
  testWidgets(
    'workspace P07 dùng server truth và giữ quyền xác nhận cho các bên',
    (tester) async {
      tester.view.physicalSize = const Size(430, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        SaleWorkspaceScreen(managementApi: _Capabilities(), crmApi: _Crm()),
        auth: _SaleAuth(),
        extraProviders: [
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Nhịp làm việc hôm nay'), findsOneWidget);
      expect(find.text('Nhắc khách xác nhận lịch'), findsOneWidget);
      expect(
        find.textContaining('Sale theo dõi · các bên xác nhận'),
        findsOneWidget,
      );
      expect(find.text('Giao dịch'), findsWidgets);
      expect(find.text('Hậu mãi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
