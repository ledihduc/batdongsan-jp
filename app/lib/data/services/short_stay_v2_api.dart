import 'dart:math';

import 'package:house_booking/data/services/api_client.dart';

enum ShortStayRole { customer, sale, owner }

class ShortStayV2Api {
  const ShortStayV2Api({ApiClient client = const ApiClient()}) : _client = client;
  final ApiClient _client;

  Future<ShortStayQuote> quote({
    required int roomTypeId,
    required int ratePlanId,
    required String checkIn,
    required String checkOut,
    int guests = 1,
  }) async => ShortStayQuote.fromMap(
    await _client.get(
      '/api/v2/short-stay/quote',
      queryParameters: {
        'room_type_id': roomTypeId,
        'rate_plan_id': ratePlanId,
        'check_in_date': checkIn,
        'check_out_date': checkOut,
        'guest_count': guests,
      },
    ),
  );

  Future<ShortStayRequest> create({
    required int roomTypeId,
    required int ratePlanId,
    required String checkIn,
    required String checkOut,
    int guests = 1,
  }) async => ShortStayRequest.fromMap(
    await _client.post(
      '/api/v2/short-stay/requests',
      body: {
        'room_type_id': roomTypeId,
        'rate_plan_id': ratePlanId,
        'check_in_date': checkIn,
        'check_out_date': checkOut,
        'guest_count': guests,
      },
      extraHeaders: {'Idempotency-Key': _key('create')},
    ),
  );

  Future<List<ShortStayRequest>> list(ShortStayRole role) async {
    final data = await _client.get(
      '/api/v2/short-stay/requests',
      queryParameters: {'mode': role.name},
    );
    return [
      for (final value in data['items'] as List? ?? const [])
        ShortStayRequest.fromMap((value as Map).cast<String, dynamic>()),
    ];
  }

  Future<ShortStayRequest> transition(
    int id,
    ShortStayRole role,
    String action, {
    Map<String, dynamic> payload = const {},
  }) async => ShortStayRequest.fromMap(
    await _client.post(
      '/api/v2/short-stay/requests/$id/transition?mode=${role.name}',
      body: {'action': action, 'payload': payload},
      extraHeaders: {'Idempotency-Key': _key('$id-$action')},
    ),
  );

  String _key(String action) =>
      'short-$action-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 20)}';
}

class ShortStayQuote {
  const ShortStayQuote({
    required this.nightlyPrice,
    required this.nights,
    required this.totalAmount,
    required this.priceSource,
  });
  factory ShortStayQuote.fromMap(Map<String, dynamic> map) => ShortStayQuote(
    nightlyPrice: (map['nightly_price'] as num?)?.toDouble() ?? 0,
    nights: (map['nights'] as num?)?.toInt() ?? 0,
    totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
    priceSource: map['price_source'] as String? ?? 'RATE_PLAN',
  );
  final double nightlyPrice;
  final int nights;
  final double totalAmount;
  final String priceSource;
}

class ShortStayRequest {
  const ShortStayRequest({
    required this.id,
    required this.status,
    required this.roomTypeId,
    required this.assignedRoomId,
    required this.quote,
    required this.allowedActions,
  });
  factory ShortStayRequest.fromMap(Map<String, dynamic> map) => ShortStayRequest(
    id: (map['id'] as num?)?.toInt() ?? 0,
    status: map['status'] as String? ?? 'REQUESTED',
    roomTypeId: (map['room_type_id'] as num?)?.toInt() ?? 0,
    assignedRoomId: (map['assigned_room_id'] as num?)?.toInt(),
    quote: ShortStayQuote.fromMap(
      (map['quote_snapshot'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    allowedActions: {for (final value in map['allowed_actions'] as List? ?? const []) '$value'},
  );
  final int id;
  final String status;
  final int roomTypeId;
  final int? assignedRoomId;
  final ShortStayQuote quote;
  final Set<String> allowedActions;
}
