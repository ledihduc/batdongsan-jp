/// Unit tests for payment intent model + mock repository.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/checkout/models/payment_intent.dart';
import 'package:house_booking/features/checkout/repositories/mock_payment_repository.dart';

void main() {
  group('JpPaymentIntent.fromJson', () {
    test('parses correctly', () {
      final json = {
        'id': 3001,
        'invoice_id': 100,
        'amount_jpy': 85000,
        'status': 'pending',
        'payment_method': 'konbini',
        'created_at': '2026-10-01T10:00:00Z',
      };
      final intent = JpPaymentIntent.fromJson(json);
      expect(intent.id, 3001);
      expect(intent.invoiceId, 100);
      expect(intent.amountJpy, 85000);
      expect(intent.status, JpPaymentIntentStatus.pending);
      expect(intent.paymentMethod, JpPaymentMethod.konbini);
    });

    test('unknown status defaults to pending', () {
      final json = {
        'id': 1,
        'invoice_id': 1,
        'amount_jpy': 1000,
        'status': 'unknown_state',
        'payment_method': 'card',
      };
      final intent = JpPaymentIntent.fromJson(json);
      expect(intent.status, JpPaymentIntentStatus.pending);
    });

    test('terminal statuses set', () {
      expect(kTerminalPaymentStatuses,
          containsAll([
            JpPaymentIntentStatus.succeeded,
            JpPaymentIntentStatus.failed,
            JpPaymentIntentStatus.expired,
          ]));
      expect(kTerminalPaymentStatuses,
          isNot(contains(JpPaymentIntentStatus.pending)));
      expect(kTerminalPaymentStatuses,
          isNot(contains(JpPaymentIntentStatus.processing)));
    });
  });

  group('MockPaymentRepository', () {
    late MockPaymentRepository repo;

    setUp(() => repo = MockPaymentRepository());

    test('getInvoiceSummary returns mock invoice', () async {
      final invoice = await repo.getInvoiceSummary(42);
      expect(invoice.id, 42);
      expect(invoice.amountJpy, greaterThan(0));
    });

    test('createPaymentIntent returns pending intent', () async {
      final intent = await repo.createPaymentIntent(
        invoiceId: 100,
        method: JpPaymentMethod.konbini,
      );
      expect(intent.status, JpPaymentIntentStatus.pending);
      expect(intent.paymentMethod, JpPaymentMethod.konbini);
    });

    test('getPaymentIntent returns created intent', () async {
      final created = await repo.createPaymentIntent(
        invoiceId: 100,
        method: JpPaymentMethod.bankTransfer,
      );
      final fetched = await repo.getPaymentIntent(created.id);
      expect(fetched.id, created.id);
      expect(fetched.invoiceId, 100);
    });

    test('getPaymentIntent throws for unknown id', () async {
      await expectLater(
        repo.getPaymentIntent(99999),
        throwsA(isA<Exception>()),
      );
    });

    test('getKonbiniVoucher returns voucher after konbini intent', () async {
      final intent = await repo.createPaymentIntent(
        invoiceId: 100,
        method: JpPaymentMethod.konbini,
      );
      final voucher = await repo.getKonbiniVoucher(intent.id);
      expect(voucher.voucherNumber, isNotEmpty);
      expect(voucher.acceptedStores, isNotEmpty);
    });

    test('getKonbiniVoucher throws for non-konbini intent', () async {
      final intent = await repo.createPaymentIntent(
        invoiceId: 100,
        method: JpPaymentMethod.bankTransfer,
      );
      await expectLater(
        repo.getKonbiniVoucher(intent.id),
        throwsA(isA<Exception>()),
      );
    });
  });
}
