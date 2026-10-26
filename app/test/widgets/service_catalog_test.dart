import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/service_api.dart';
import 'package:house_booking/features/admin/admin_service_requests_screen.dart';
import 'package:house_booking/features/guest/service/service_catalog_screen.dart';

import '../helpers/pump_app.dart';

/// Đặt dịch vụ kiểu Vua Thợ — danh mục nghề (khách) + màn xử lý (admin).
///
/// Sau khi mảng thi công bị gỡ, mọi nghề đều đi CÙNG một luồng: chạm là mở form
/// đặt, không còn nhánh nào dẫn sang danh bạ nhà thầu.
ServiceApi _api(Object body) => ServiceApi(
      client: ApiClient(
        client: MockClient((req) async => http.Response(
              jsonEncode(body),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            )),
      ),
    );

final _services = [
  {'slug': 'electric', 'name': 'Sửa điện', 'icon': 'bolt'},
  {'slug': 'unclog', 'name': 'Thông tắc', 'icon': 'plumbing'},
];

Map<String, dynamic> _yeuCau({
  int id = 1,
  String status = 'new',
  String? scheduledAt,
  String? adminNote,
}) =>
    {
      'id': id,
      'service_slug': 'electric',
      'service_name': 'Sửa điện',
      'name': 'Chị Lan',
      'phone': '0912345678',
      'description': 'Aptomat nhảy liên tục',
      'location_text': 'Quận 7, TP.HCM',
      'status': status,
      'scheduled_at': scheduledAt,
      'admin_note': adminNote,
      'created_at': DateTime.now().toIso8601String(),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ApiClient đính token vào header → mọi lời gọi chờ flutter_secure_storage.
  // Không giả lập thì `await` treo và màn mãi ở trạng thái đang tải.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  group('Danh mục dịch vụ (khách)', () {
    testWidgets('hiện danh mục nghề', (tester) async {
      await pumpApp(tester, ServiceCatalogScreen(api: _api(_services)));
      await tester.pump();
      await tester.pump();

      expect(find.text('Sửa điện'), findsOneWidget);
      expect(find.text('Thông tắc'), findsOneWidget);
    });

    testWidgets('chạm một nghề mở form đặt dịch vụ', (tester) async {
      await pumpApp(tester, ServiceCatalogScreen(api: _api(_services)));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Sửa điện'));
      await tester.pumpAndSettle();

      // Bottom-sheet đặt dịch vụ dùng tiêu đề "Đặt dịch vụ · <tên>".
      expect(find.textContaining('Đặt dịch vụ'), findsOneWidget);
    });

    testWidgets('API lỗi → không vỡ màn', (tester) async {
      final hong = ServiceApi(
        client: ApiClient(
          client: MockClient((_) async => http.Response('boom', 500)),
        ),
      );
      await pumpApp(tester, ServiceCatalogScreen(api: hong));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('Màn admin xử lý yêu cầu', () {
    testWidgets('hiện SĐT khách để gọi lại', (tester) async {
      await pumpApp(
        tester,
        AdminServiceRequestsScreen(api: _api({'requests': [_yeuCau()]})),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('0912345678'), findsOneWidget);
      expect(find.textContaining('Sửa điện'), findsWidgets);
      expect(find.text('Aptomat nhảy liên tục'), findsOneWidget);
    });

    testWidgets('danh sách rỗng hiện trạng thái rỗng', (tester) async {
      await pumpApp(
        tester,
        AdminServiceRequestsScreen(api: _api({'requests': []})),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Chưa có yêu cầu nào.'), findsOneWidget);
    });

    testWidgets('hiện lịch hẹn và ghi chú khi đã có', (tester) async {
      await pumpApp(
        tester,
        AdminServiceRequestsScreen(
          api: _api({
            'requests': [
              _yeuCau(
                status: 'scheduled',
                scheduledAt: '2026-09-02T09:30:00',
                adminNote: 'Khách hẹn sáng thứ 3',
              )
            ]
          }),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('02/09 09:30'), findsOneWidget);
      expect(find.textContaining('Khách hẹn sáng thứ 3'), findsOneWidget);
      expect(find.text('Đã xếp lịch'), findsWidgets);
    });
  });
}
