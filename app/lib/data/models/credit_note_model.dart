/// Phase 04 — CreditNote mirrors backend schema.
///
/// A CreditNote is the legal way to "adjust" a paid invoice.
/// Issued against the original invoice (which stays immutable).
class CreditNoteModel {
  final int id;
  final int hostId;
  final int originalInvoiceId;
  final double amount;
  final String reason;
  final String issuedDate; // YYYY-MM-DD
  final DateTime createdAt;

  const CreditNoteModel({
    required this.id,
    required this.hostId,
    required this.originalInvoiceId,
    required this.amount,
    required this.reason,
    required this.issuedDate,
    required this.createdAt,
  });

  factory CreditNoteModel.fromJson(Map<String, dynamic> json) {
    return CreditNoteModel(
      id: json['id'] as int,
      hostId: json['host_id'] as int,
      originalInvoiceId: json['original_invoice_id'] as int,
      amount: (json['amount'] as num).toDouble(),
      reason: (json['reason'] as String?) ?? '',
      issuedDate: json['issued_date'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
