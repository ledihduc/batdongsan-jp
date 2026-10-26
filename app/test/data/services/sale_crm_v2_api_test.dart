import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/sale_crm_v2_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('parses scoped Sale CRM read models', () async {
    final api = SaleCrmV2Api(
      client: ApiClient(
        client: MockClient((request) async {
          final Object payload = switch (request.url.path) {
            '/api/v2/sale-crm/dashboard' => {
              'contacts': 4,
              'open_tasks': 3,
              'overdue_tasks': 1,
              'active_deals': 2,
              'property_count': 5,
            },
            '/api/v2/sale-crm/contacts' => {
              'items': [
                {
                  'id': 8,
                  'type': 'OWNER',
                  'user': {
                    'name': 'Vũ Đình Văn',
                    'phone': '0900000000',
                    'email': 'owner@test.vn',
                  },
                  'open_tasks': 2,
                  'deep_link': '/activity/sale/contacts/8',
                },
              ],
            },
            '/api/v2/sale-crm/tasks' => {
              'items': [
                {
                  'id': 9,
                  'title': 'Nhắc khách xác nhận',
                  'due_at': '2026-09-22T10:00:00',
                  'status': 'OPEN',
                  'deep_link': '/activity/viewings/12',
                },
              ],
            },
            _ => <String, Object>{'items': const []},
          };
          return http.Response.bytes(utf8.encode(jsonEncode(payload)), 200);
        }),
      ),
    );

    final dashboard = await api.dashboard();
    final contacts = await api.contacts(type: 'OWNER');
    final tasks = await api.tasks(status: 'OPEN');
    expect(dashboard.overdueTasks, 1);
    expect(contacts.single.name, 'Vũ Đình Văn');
    expect(contacts.single.type, 'OWNER');
    expect(tasks.single.deepLink, '/activity/viewings/12');
  });

  test(
    'CRM commands send idempotency and never claim transaction authority',
    () async {
      final requests = <http.Request>[];
      final api = SaleCrmV2Api(
        client: ApiClient(
          client: MockClient((request) async {
            requests.add(request);
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'id': 20,
                  'amount': 5000000,
                  'transaction_status': 'pending',
                  'pipeline_stage': 'LOST',
                  'customer_id': 3,
                }),
              ),
              200,
            );
          }),
        ),
      );

      final deal = await api.updateDealStage(
        20,
        'LOST',
        lossReasonCode: 'PRICE',
      );
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(requests.single.url.path, '/api/v2/sale-crm/deals/20/stage');
      expect(
        requests.single.headers['idempotency-key']!.length,
        greaterThan(8),
      );
      expect(body, isNot(contains('status')));
      expect(body['stage'], 'LOST');
      expect(deal.transactionStatus, 'pending');
    },
  );
}
