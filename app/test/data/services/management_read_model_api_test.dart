import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/management_read_model_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'parses feature flag and summary without touching legacy management',
    () async {
      final requested = <String>[];
      final api = ManagementReadModelApi(
        client: ApiClient(
          client: MockClient((request) async {
            requested.add(request.url.path);
            final body = switch (request.url.path) {
              '/api/v2/me/capabilities' => {
                'active_mode': 'customer',
                'modes': ['customer'],
                'feature_flags': {'management_v2_enabled': true},
              },
              '/api/v2/manage/summary' => {
                'contract_version': 'manage-v2.1',
                'mode': 'customer',
                'counters': {'ACTION_REQUIRED': 2, 'UPCOMING': 1},
                'long_term': {
                  'total': 10,
                  'counters': {'ACTION_REQUIRED': 1, 'UPCOMING': 1},
                },
                'short_stay': {
                  'total': 4,
                  'pending': 1,
                  'confirmed': 1,
                  'checked_in': 1,
                  'history': 1,
                },
                'totals': {
                  'viewings': 3,
                  'rental_journeys': 1,
                  'contracts': 2,
                  'invoices': 4,
                },
              },
              _ => <String, dynamic>{},
            };
            return http.Response(jsonEncode(body), 200);
          }),
        ),
      );

      final capabilities = await api.capabilities();
      final summary = await api.summary(mode: ManagementMode.customer);

      expect(capabilities.managementV2Enabled, isTrue);
      expect(summary.count(ManagementBucket.actionRequired), 2);
      expect(summary.count(ManagementBucket.history), 0);
      expect(summary.longTerm.total, 10);
      expect(summary.longTerm.count(ManagementBucket.actionRequired), 1);
      expect(summary.shortStay.total, 4);
      expect(summary.shortStay.pending, 1);
      expect(summary.shortStay.confirmed, 1);
      expect(summary.shortStay.checkedIn, 1);
      expect(summary.shortStay.history, 1);
      expect(summary.viewings, 3);
      expect(summary.reservations, 0);
      expect(summary.contracts, 2);
      expect(summary.invoices, 4);
      expect(requested, ['/api/v2/me/capabilities', '/api/v2/manage/summary']);
    },
  );

  test('keeps server-owned work item routes and actions intact', () async {
    final api = ManagementReadModelApi(
      client: ApiClient(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v2/manage/work-items');
          expect(request.url.queryParameters['bucket'], 'AFTER_VIEWING');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'data': [
                  {
                    'id': 'rental_journey:9',
                    'kind': 'RENTAL_JOURNEY',
                    'title': 'Hồ sơ thuê dài hạn',
                    'subtitle': 'Hồ sơ #9',
                    'bucket': 'AFTER_VIEWING',
                    'needs_action': true,
                    'allowed_actions': ['SUBMIT_CONTRACT'],
                    'detail_route': '/rental-journeys/9',
                  },
                ],
                'pagination': {'page': 1, 'total_pages': 1, 'total_items': 1},
              }),
            ),
            200,
          );
        }),
      ),
    );

    final result = await api.workItems(
      mode: ManagementMode.sale,
      bucket: ManagementBucket.afterViewing,
    );

    expect(result.items.single.detailRoute, '/rental-journeys/9');
    expect(result.items.single.allowedActions, ['SUBMIT_CONTRACT']);
    expect(result.totalItems, 1);
  });
}
