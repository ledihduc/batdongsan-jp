import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/buy_sell_v2_api.dart';

void main() {
  test('parses role-safe buy/sell projection and timeline', () {
    final item = BuySellTransaction.fromMap({
      'id': 7,
      'deal_id': 4,
      'stage': 'DEPOSIT',
      'actor_role': 'buyer',
      'agreed_amount': 2950000000,
      'allowed_stages': ['LEGAL_NOTARY', 'LOST'],
      'payment_mode': 'EVIDENCE_ONLY_NO_GATEWAY_NO_AUTO_SETTLEMENT',
      'documents': [
        {
          'id': 1,
          'document_type': 'DEPOSIT_PROOF',
          'file_url': '/uploads/a.jpg',
        },
      ],
      'timeline': [
        {
          'from_stage': 'NEGOTIATION',
          'to_stage': 'DEPOSIT',
          'actor_role': 'seller',
        },
      ],
    });
    expect(item.stage, 'DEPOSIT');
    expect(item.allowedStages, contains('LEGAL_NOTARY'));
    expect(item.documents.single.type, 'DEPOSIT_PROOF');
    expect(item.timeline.single.role, 'seller');
    expect(item.paymentMode, contains('NO_GATEWAY'));
  });
}
