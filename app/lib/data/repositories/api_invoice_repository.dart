import 'package:house_booking/data/models/credit_note_model.dart';
import 'package:house_booking/data/models/invoice_model.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Repository for /api/host/invoices endpoints (Phase 04).
class ApiInvoiceRepository {
  /// [client] chỉ để TEST bơm client giả — mặc định vẫn là client thật.
  ApiInvoiceRepository({ApiClient client = const ApiClient()})
    : _client = client;

  final ApiClient _client;

  Future<List<InvoiceModel>> fetchInvoices({
    String? status,
    int? contractId,
    String? month, // YYYY-MM
  }) async {
    final query = <String, dynamic>{
      if (status != null) 'status': status,
      if (contractId != null) 'contract_id': contractId,
      if (month != null) 'month': month,
    };
    final list = await _client.getList(
      '/api/host/invoices',
      queryParameters: query,
    );
    return list
        .map((e) => InvoiceModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<InvoiceModel> getInvoice(int invoiceId) async {
    final resp = await _client.get('/api/host/invoices/$invoiceId');
    return InvoiceModel.fromJson(Map<String, dynamic>.from(resp));
  }

  /// Generate draft invoices for all active contracts in a building for a month.
  /// Idempotent — already-existing (contract, period) rows are skipped.
  ///
  /// Hai đơn giá `null` = **để server hỏi từng phòng** (phòng khai riêng → toà
  /// khai chung → hằng số). Trước migration 0104 hai tham số này mặc định
  /// 3500/15000 và LUÔN được gửi, nên mọi phòng trong lô bị áp cùng một giá —
  /// giá riêng của phòng có khai cũng vô nghĩa. Chỉ gửi khi người dùng thực sự
  /// muốn ghi đè cho cả lô.
  Future<List<InvoiceModel>> generateBatch({
    required int buildingId,
    required String month, // YYYY-MM
    double? electricityUnitPrice,
    double? waterUnitPrice,
  }) async {
    final list = await _client.postList(
      '/api/host/invoices/generate-batch',
      body: {
        'building_id': buildingId,
        'month': month,
        if (electricityUnitPrice != null)
          'electricity_unit_price': electricityUnitPrice,
        if (waterUnitPrice != null) 'water_unit_price': waterUnitPrice,
      },
    );
    return list
        .map((e) => InvoiceModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<InvoiceModel> sendInvoice(int invoiceId) async {
    final resp = await _client.patch('/api/host/invoices/$invoiceId/send');
    return InvoiceModel.fromJson(Map<String, dynamic>.from(resp));
  }

  /// Record a payment. Backend returns the updated InvoiceResponse only —
  /// the payment row is created server-side and not echoed back.
  Future<InvoiceModel> recordPayment(
    int invoiceId, {
    required double amount,
    String method = 'cash',
    String? paidAt,
    String? note,
  }) async {
    final resp = await _client.patch(
      '/api/host/invoices/$invoiceId/pay',
      body: {
        'amount': amount,
        'method': method,
        if (paidAt != null) 'paid_at': paidAt,
        if (note != null) 'note': note,
      },
    );
    return InvoiceModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<CreditNoteModel> issueCreditNote(
    int invoiceId, {
    required double amount,
    String reason = '',
    required String issuedDate, // YYYY-MM-DD
  }) async {
    final resp = await _client.post(
      '/api/host/invoices/$invoiceId/credit-note',
      body: {'amount': amount, 'reason': reason, 'issued_date': issuedDate},
    );
    return CreditNoteModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<DebtAgingReport> fetchDebtAging() async {
    final resp = await _client.get('/api/host/invoices/debt-aging');
    return DebtAgingReport.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<List<NeedsReminderItem>> fetchNeedsReminder() async {
    final list = await _client.getList('/api/host/invoices/needs-reminder');
    return list
        .map(
          (e) =>
              NeedsReminderItem.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  /// Returns the Zalo deep-link URL for the primary tenant of [invoiceId].
  Future<String> fetchZaloLink(int invoiceId) async {
    final resp = await _client.get('/api/host/invoices/$invoiceId/zalo-link');
    return resp['url'] as String;
  }
}
