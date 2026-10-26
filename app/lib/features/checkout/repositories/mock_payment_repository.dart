/// In-memory mock for [IPaymentRepository].
///
/// Simulates the full lifecycle: create → pending → succeeded after 9 s.
library;

import 'package:house_booking/features/checkout/models/konbini_voucher.dart';
import 'package:house_booking/features/checkout/models/payment_intent.dart';
import 'package:house_booking/features/checkout/repositories/i_payment_repository.dart';

class MockPaymentRepository implements IPaymentRepository {
  final Map<int, JpPaymentIntent> _intents = {};
  final Map<int, KonbiniVoucher> _vouchers = {};
  int _nextId = 3001;

  @override
  Future<JpInvoiceSummary> getInvoiceSummary(int invoiceId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return JpInvoiceSummary(
      id: invoiceId,
      title: '賃料 — 2026年11月分',
      amountJpy: 85000,
      dueDate: '2026-11-05',
    );
  }

  @override
  Future<JpPaymentIntent> createPaymentIntent({
    required int invoiceId,
    required JpPaymentMethod method,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final id = _nextId++;
    final intent = JpPaymentIntent(
      id: id,
      invoiceId: invoiceId,
      amountJpy: 85000,
      status: JpPaymentIntentStatus.pending,
      paymentMethod: method,
      createdAt: DateTime.now().toIso8601String(),
      expiresAt: DateTime.now()
          .add(const Duration(days: 3))
          .toIso8601String(),
    );
    _intents[id] = intent;

    if (method == JpPaymentMethod.konbini) {
      _vouchers[id] = KonbiniVoucher(
        paymentIntentId: id,
        voucherNumber: '12345678901234',
        deadline: DateTime.now()
            .add(const Duration(days: 3))
            .toIso8601String(),
        acceptedStores: [
          KonbiniStore.sevenEleven,
          KonbiniStore.familyMart,
          KonbiniStore.lawson,
          KonbiniStore.ministop,
        ],
        instructions:
            'コンビニのレジまたはマルチコピー機でバーコードまたは番号を提示してください。',
      );
    }

    // Simulate payment succeeding after 9 seconds.
    Future<void>.delayed(const Duration(seconds: 9)).then((_) {
      if (_intents.containsKey(id)) {
        _intents[id] = JpPaymentIntent(
          id: id,
          invoiceId: invoiceId,
          amountJpy: 85000,
          status: JpPaymentIntentStatus.succeeded,
          paymentMethod: method,
          createdAt: intent.createdAt,
          expiresAt: intent.expiresAt,
        );
      }
    });

    return intent;
  }

  @override
  Future<JpPaymentIntent> getPaymentIntent(int intentId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final intent = _intents[intentId];
    if (intent == null) {
      throw Exception('PaymentIntent $intentId not found');
    }
    return intent;
  }

  @override
  Future<KonbiniVoucher> getKonbiniVoucher(int intentId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final voucher = _vouchers[intentId];
    if (voucher == null) {
      throw Exception('No konbini voucher for intent $intentId');
    }
    return voucher;
  }
}
