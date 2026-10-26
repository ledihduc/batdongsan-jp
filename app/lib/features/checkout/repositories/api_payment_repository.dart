/// HTTP implementation of [IPaymentRepository].
///
/// Hits /api/jp/payments on the backend.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:house_booking/features/checkout/models/konbini_voucher.dart';
import 'package:house_booking/features/checkout/models/payment_intent.dart';
import 'package:house_booking/features/checkout/repositories/i_payment_repository.dart';

class ApiPaymentRepository implements IPaymentRepository {
  ApiPaymentRepository({
    required this.baseUrl,
    required this.authToken,
  });

  final String baseUrl;
  final String authToken;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static String _methodWire(JpPaymentMethod m) {
    switch (m) {
      case JpPaymentMethod.card:
        return 'card';
      case JpPaymentMethod.konbini:
        return 'konbini';
      case JpPaymentMethod.bankTransfer:
        return 'bank_transfer';
    }
  }

  @override
  Future<JpInvoiceSummary> getInvoiceSummary(int invoiceId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/jp/payments/invoices/$invoiceId'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to get invoice: ${response.statusCode}');
    }
    return JpInvoiceSummary.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<JpPaymentIntent> createPaymentIntent({
    required int invoiceId,
    required JpPaymentMethod method,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/jp/payments'),
      headers: _headers,
      body: jsonEncode({
        'invoice_id': invoiceId,
        'payment_method': _methodWire(method),
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'Failed to create payment intent: ${response.statusCode}');
    }
    return JpPaymentIntent.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<JpPaymentIntent> getPaymentIntent(int intentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/jp/payments/$intentId'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to get payment intent: ${response.statusCode}');
    }
    return JpPaymentIntent.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<KonbiniVoucher> getKonbiniVoucher(int intentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/jp/payments/$intentId/voucher'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to get konbini voucher: ${response.statusCode}');
    }
    return KonbiniVoucher.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }
}
