/// Interface for payment operations.
///
/// Hits /api/jp/payments on the backend.
library;

import 'package:house_booking/features/checkout/models/konbini_voucher.dart';
import 'package:house_booking/features/checkout/models/payment_intent.dart';

abstract interface class IPaymentRepository {
  /// Create a payment intent for the given invoice.
  Future<JpPaymentIntent> createPaymentIntent({
    required int invoiceId,
    required JpPaymentMethod method,
  });

  /// Fetch current status of a payment intent.
  Future<JpPaymentIntent> getPaymentIntent(int intentId);

  /// Fetch konbini voucher for a konbini payment intent.
  Future<KonbiniVoucher> getKonbiniVoucher(int intentId);

  /// Fetch invoice summary by ID.
  Future<JpInvoiceSummary> getInvoiceSummary(int invoiceId);
}
