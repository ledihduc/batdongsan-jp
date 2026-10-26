import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _journey({
  String role = 'customer',
  List<String> actions = const ['CONFIRM_RENTAL'],
}) => {
  'id': 18,
  'appointment_id': 27,
  'status': 'CUSTOMER_CONFIRMATION_PENDING',
  'viewer_role': role,
  'subject': {
    'title': 'Phòng 101 · Sunrise Q7',
    'image': '/uploads/room.jpg',
    'room_id': 9,
    'house_id': 12,
  },
  'participants': {
    'customer': {'id': 4, 'name': 'Nguyễn Minh Anh'},
    'sale': {'id': 5, 'name': 'Trần Văn Long'},
    'owner': {'id': 6, 'name': 'Nguyễn Hữu Thọ'},
  },
  'appointment': {
    'date': '2026-09-22',
    'time': '09:00-10:00',
    'status': 'completed',
  },
  'contract': {
    'urls': ['/uploads/contract.pdf'],
    'note': 'Đủ chữ ký',
  },
  'total_deposit': 10000000,
  'payments': [
    {
      'kind': 'APP_DEPOSIT',
      'amount': 5000000,
      'status': 'SUBMITTED',
      'proof_urls': ['/uploads/app.jpg'],
      'submitted_at': '2026-09-20T10:00:00',
      'acknowledged_at': null,
    },
  ],
  'available_actions': actions,
  'cancel_reason': null,
};

void main() {
  test('parses journey and keeps server-owned available actions', () async {
    final api = RentalJourneyApi(
      client: ApiClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'data': [_journey()]}),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      ),
    );

    final rows = await api.list(view: 'customer');

    expect(rows, hasLength(1));
    expect(rows.single.subject.title, 'Phòng 101 · Sunrise Q7');
    expect(rows.single.payment('APP_DEPOSIT')?.amount, 5000000);
    expect(rows.single.can(RentalJourneyAction.confirmRental), isTrue);
  });

  test('sale contract request uses the backend contract exactly', () async {
    late http.Request request;
    final api = RentalJourneyApi(
      client: ApiClient(
        client: MockClient((incoming) async {
          request = incoming;
          // `http.Response(String)` mã hoá latin1 → chữ có dấu ném lỗi; trả BYTE.
          return http.Response.bytes(
            utf8.encode(jsonEncode(_journey(role: 'sale'))),
            200,
          );
        }),
      ),
    );

    await api.submitContract(
      18,
      urls: const ['/uploads/contract.pdf'],
      totalDeposit: 10000000,
      note: 'Đủ chữ ký',
    );

    expect(request.method, 'PUT');
    expect(request.url.path, '/api/rental-journeys/18/contract');
    expect(jsonDecode(request.body), {
      'urls': ['/uploads/contract.pdf'],
      'total_deposit': 10000000,
      'note': 'Đủ chữ ký',
    });
  });

  test('customer final confirmation is a dedicated endpoint', () async {
    late http.Request request;
    final api = RentalJourneyApi(
      client: ApiClient(
        client: MockClient((incoming) async {
          request = incoming;
          return http.Response.bytes(utf8.encode(jsonEncode(_journey())), 200);
        }),
      ),
    );

    await api.confirm(18);

    expect(request.method, 'POST');
    expect(request.url.path, '/api/rental-journeys/18/confirm');
  });
}
