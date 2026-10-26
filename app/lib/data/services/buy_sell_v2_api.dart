import 'dart:math';

import 'package:house_booking/data/services/api_client.dart';

class BuySellV2Api {
  const BuySellV2Api({ApiClient client = const ApiClient()}) : _client = client;
  final ApiClient _client;

  Future<BuySellTransaction> createFromDeal(int dealId) async =>
      BuySellTransaction.fromMap(
        await _client.post(
          '/api/v2/buy-sell/transactions/from-deal/$dealId',
          extraHeaders: {'Idempotency-Key': _key('create-$dealId')},
        ),
      );

  Future<List<BuySellTransaction>> list({String? stage}) async {
    final data = await _client.get(
      '/api/v2/buy-sell/transactions',
      queryParameters: {if (stage != null) 'stage': stage},
    );
    return [
      for (final value in data['items'] as List? ?? const [])
        BuySellTransaction.fromMap((value as Map).cast<String, dynamic>()),
    ];
  }

  Future<BuySellTransaction> detail(int id) async => BuySellTransaction.fromMap(
    await _client.get('/api/v2/buy-sell/transactions/$id'),
  );

  Future<BuySellTransaction> transition(
    int id,
    String stage, {
    double? offerAmount,
    double? agreedAmount,
    String? reasonCode,
    String note = '',
  }) async => BuySellTransaction.fromMap(
    await _client.post(
      '/api/v2/buy-sell/transactions/$id/transition',
      body: {
        'to_stage': stage,
        if (offerAmount != null) 'offer_amount': offerAmount,
        if (agreedAmount != null) 'agreed_amount': agreedAmount,
        if (reasonCode != null) 'reason_code': reasonCode,
        'note': note,
      },
      extraHeaders: {'Idempotency-Key': _key('$id-$stage')},
    ),
  );

  Future<BuySellTransaction> addDocument(
    int id, {
    required String type,
    required String fileUrl,
  }) async => BuySellTransaction.fromMap(
    await _client.post(
      '/api/v2/buy-sell/transactions/$id/documents',
      body: {'document_type': type, 'file_url': fileUrl},
      extraHeaders: {'Idempotency-Key': _key('$id-document')},
    ),
  );

  String _key(String action) =>
      'buy-sell-$action-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 20)}';
}

class BuySellTransaction {
  const BuySellTransaction({
    required this.id,
    required this.dealId,
    required this.stage,
    required this.actorRole,
    required this.offerAmount,
    required this.agreedAmount,
    required this.allowedStages,
    required this.documents,
    required this.timeline,
    required this.paymentMode,
  });

  factory BuySellTransaction.fromMap(Map<String, dynamic> map) =>
      BuySellTransaction(
        id: (map['id'] as num?)?.toInt() ?? 0,
        dealId: (map['deal_id'] as num?)?.toInt() ?? 0,
        stage: map['stage'] as String? ?? 'INTERESTED',
        actorRole: map['actor_role'] as String? ?? 'buyer',
        offerAmount: (map['offer_amount'] as num?)?.toDouble(),
        agreedAmount: (map['agreed_amount'] as num?)?.toDouble(),
        allowedStages: {
          for (final value in map['allowed_stages'] as List? ?? const [])
            '$value',
        },
        documents: [
          for (final value in map['documents'] as List? ?? const [])
            BuySellDocument.fromMap((value as Map).cast<String, dynamic>()),
        ],
        timeline: [
          for (final value in map['timeline'] as List? ?? const [])
            BuySellEvent.fromMap((value as Map).cast<String, dynamic>()),
        ],
        paymentMode: map['payment_mode'] as String? ?? 'EVIDENCE_ONLY',
      );

  final int id;
  final int dealId;
  final String stage;
  final String actorRole;
  final double? offerAmount;
  final double? agreedAmount;
  final Set<String> allowedStages;
  final List<BuySellDocument> documents;
  final List<BuySellEvent> timeline;
  final String paymentMode;
}

class BuySellDocument {
  const BuySellDocument({
    required this.id,
    required this.type,
    required this.url,
  });
  factory BuySellDocument.fromMap(Map<String, dynamic> map) => BuySellDocument(
    id: (map['id'] as num?)?.toInt() ?? 0,
    type: map['document_type'] as String? ?? 'OTHER',
    url: map['file_url'] as String? ?? '',
  );
  final int id;
  final String type;
  final String url;
}

class BuySellEvent {
  const BuySellEvent({
    required this.from,
    required this.to,
    required this.role,
  });
  factory BuySellEvent.fromMap(Map<String, dynamic> map) => BuySellEvent(
    from: map['from_stage'] as String? ?? '',
    to: map['to_stage'] as String? ?? '',
    role: map['actor_role'] as String? ?? '',
  );
  final String from;
  final String to;
  final String role;
}
