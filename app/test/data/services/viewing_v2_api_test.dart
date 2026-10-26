import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/viewing_v2_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const payload = {
    'contract_version': 'viewing-v2.1',
    'id': 42,
    'mode': 'owner',
    'status': 'CONFIRMED',
    'legacy_status': 'approved',
    'booking_date': '2026-09-25',
    'booking_time': '09:00-10:00',
    'subject': {
      'title': 'Phòng P101 · An Cư Home',
      'image': '/uploads/p101.jpg',
      'price': 5000000,
    },
    'participants': {
      'customer': {'id': 7, 'name': 'Nguyễn Văn An'},
    },
    'result': {'status': 'WAITING_RESULT'},
    'cancellation': {},
    'proposals': [],
    'issues': [],
    'allowed_actions': ['MARK_COMPLETED', 'CANCEL'],
  };

  test('parses canonical server state and keeps allowed actions', () async {
    final api = ViewingV2Api(
      client: ApiClient(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v2/viewings');
          expect(request.url.queryParameters['mode'], 'owner');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'data': [payload],
              }),
            ),
            200,
          );
        }),
      ),
    );

    final item = (await api.list(mode: ViewingMode.owner)).single;
    expect(item.status, 'CONFIRMED');
    expect(item.legacyStatus, 'approved');
    expect(item.title, 'Phòng P101 · An Cư Home');
    expect(item.customerName, 'Nguyễn Văn An');
    expect(item.can('MARK_COMPLETED'), isTrue);
  });

  test('commands always send a unique idempotency key', () async {
    final keys = <String>[];
    final api = ViewingV2Api(
      client: ApiClient(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v2/viewings/42/confirm');
          keys.add(request.headers['idempotency-key'] ?? '');
          return http.Response.bytes(utf8.encode(jsonEncode(payload)), 200);
        }),
      ),
    );

    await api.confirm(42);
    await api.confirm(42);
    expect(keys.every((value) => value.length >= 8), isTrue);
    expect(keys.toSet(), hasLength(2));
  });

  test(
    'result taxonomy is sent without creating client-side journey state',
    () async {
      final api = ViewingV2Api(
        client: ApiClient(
          client: MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['status'], 'DECLINED');
            expect(body['reason_code'], 'PRICE_MISMATCH');
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  ...payload,
                  'status': 'COMPLETED',
                  'legacy_status': 'completed',
                  'result': {
                    'status': 'DECLINED',
                    'reason_code': 'PRICE_MISMATCH',
                  },
                }),
              ),
              200,
            );
          }),
        ),
      );

      final result = await api.submitResult(
        42,
        status: 'DECLINED',
        reasonCode: 'PRICE_MISMATCH',
      );
      expect(result.resultStatus, 'DECLINED');
      expect(result.resultReasonCode, 'PRICE_MISMATCH');
    },
  );
}
