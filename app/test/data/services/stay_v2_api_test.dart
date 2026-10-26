import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/stay_v2_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('parses role-safe stay records', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v2/stays');
      expect(request.url.queryParameters['mode'], 'sale');
      return http.Response(
        jsonEncode({
          'items': [
            {
              'contract_id': 31,
              'status': 'active',
              'role_projection': 'sale',
              'room': {
                'id': 9,
                'code': 'P101',
                'building_name': 'An Cư Home',
                'address': 'Hải Phòng',
                'images': ['/p.jpg'],
              },
              'contract': {
                'monthly_rent': 5000000,
                'start_date': '2026-09-01',
                'end_date': '2027-08-31',
              },
              'open_support_count': 2,
              'allowed_actions': ['VIEW_INVOICES', 'COORDINATE_SUPPORT'],
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final rows = await StayV2Api(client: ApiClient(client: client)).list(StayRole.sale);
    expect(rows.single.contractId, 31);
    expect(rows.single.openSupportCount, 2);
    expect(rows.single.allowedActions, contains('COORDINATE_SUPPORT'));
  });
}
