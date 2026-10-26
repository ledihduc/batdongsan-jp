/// Konbini payment voucher data returned by the backend.
///
/// Rendered on KonbiniVoucherScreen after a konbini PaymentIntent is created.
library;

/// Supported konbini store brands.
enum KonbiniStore {
  sevenEleven,
  familyMart,
  lawson,
  ministop,
  seicomart,
}

/// Display name for each store brand.
String konbiniStoreName(KonbiniStore store) {
  switch (store) {
    case KonbiniStore.sevenEleven:
      return 'セブン-イレブン';
    case KonbiniStore.familyMart:
      return 'ファミリーマート';
    case KonbiniStore.lawson:
      return 'ローソン';
    case KonbiniStore.ministop:
      return 'ミニストップ';
    case KonbiniStore.seicomart:
      return 'セイコーマート';
  }
}

class KonbiniVoucher {
  const KonbiniVoucher({
    required this.paymentIntentId,
    required this.voucherNumber,
    required this.deadline,
    required this.acceptedStores,
    required this.instructions,
  });

  final int paymentIntentId;

  /// The numeric string the customer enters at the store terminal.
  final String voucherNumber;

  /// ISO-8601 deadline for payment.
  final String deadline;

  /// Stores that accept this voucher number.
  final List<KonbiniStore> acceptedStores;

  /// Localised instructions (from Komoju; should NOT be re-translated).
  final String instructions;

  factory KonbiniVoucher.fromJson(Map<String, dynamic> json) {
    final storesRaw = json['accepted_stores'] as List<dynamic>? ?? [];
    return KonbiniVoucher(
      paymentIntentId: json['payment_intent_id'] as int,
      voucherNumber: json['voucher_number'] as String,
      deadline: json['deadline'] as String,
      acceptedStores: storesRaw
          .map((s) => _storeFromString(s as String))
          .whereType<KonbiniStore>()
          .toList(),
      instructions: json['instructions'] as String? ?? '',
    );
  }

  static KonbiniStore? _storeFromString(String s) {
    switch (s) {
      case 'seven_eleven':
        return KonbiniStore.sevenEleven;
      case 'family_mart':
        return KonbiniStore.familyMart;
      case 'lawson':
        return KonbiniStore.lawson;
      case 'ministop':
        return KonbiniStore.ministop;
      case 'seicomart':
        return KonbiniStore.seicomart;
      default:
        return null;
    }
  }
}
