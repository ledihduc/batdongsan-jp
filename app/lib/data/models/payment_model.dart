/// Phase 04 — Payment mirrors PaymentResponse schema.
class PaymentModel {
  final int id;
  final int hostId;
  final int invoiceId;
  final double amount;
  final String method; // cash|bank_transfer|other
  final DateTime paidAt;
  final String? note;
  final DateTime createdAt;

  const PaymentModel({
    required this.id,
    required this.hostId,
    required this.invoiceId,
    required this.amount,
    required this.method,
    required this.paidAt,
    this.note,
    required this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as int,
      hostId: json['host_id'] as int,
      invoiceId: json['invoice_id'] as int,
      amount: (json['amount'] as num).toDouble(),
      method: json['method'] as String,
      paidAt: DateTime.parse(json['paid_at'] as String),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
