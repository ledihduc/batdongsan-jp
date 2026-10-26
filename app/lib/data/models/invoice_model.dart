/// Phase 04 — Invoice + InvoiceLineItem mirrors backend schemas.
///
/// Status flow: draft → sent → paid (or → overdue → paid) | cancelled
/// Money values are VND (no fractional cents) but kept as double to match JSON.

class InvoiceLineItem {
  final int id;
  final int invoiceId;
  final String
  category; // rent|electricity|water|service|deposit_refund|damage_deduction|adjustment
  final String description;
  final double quantity;
  final double unitPrice;
  final double amount;
  final int sortOrder;

  const InvoiceLineItem({
    required this.id,
    required this.invoiceId,
    required this.category,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    required this.sortOrder,
  });

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) {
    return InvoiceLineItem(
      id: json['id'] as int,
      invoiceId: json['invoice_id'] as int,
      category: json['category'] as String,
      description: (json['description'] as String?) ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      amount: (json['amount'] as num).toDouble(),
      sortOrder: (json['sort_order'] as int?) ?? 0,
    );
  }
}

class InvoiceModel {
  final int id;
  final int hostId;
  final int contractId;
  final String invoiceNumber;
  final String periodStart; // YYYY-MM-DD
  final String periodEnd;
  final String issuedDate;
  final String dueDate;
  final String status; // draft|sent|paid|overdue|cancelled
  final double totalAmount;
  final double paidAmount;
  final DateTime? paidAt;
  final String? publicToken;
  final DateTime? publicTokenExpiresAt;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<InvoiceLineItem> lineItems;

  const InvoiceModel({
    required this.id,
    required this.hostId,
    required this.contractId,
    required this.invoiceNumber,
    required this.periodStart,
    required this.periodEnd,
    required this.issuedDate,
    required this.dueDate,
    required this.status,
    required this.totalAmount,
    required this.paidAmount,
    this.paidAt,
    this.publicToken,
    this.publicTokenExpiresAt,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.lineItems,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] as int,
      hostId: json['host_id'] as int,
      contractId: json['contract_id'] as int,
      invoiceNumber: json['invoice_number'] as String,
      periodStart: json['period_start'] as String,
      periodEnd: json['period_end'] as String,
      issuedDate: json['issued_date'] as String,
      dueDate: json['due_date'] as String,
      status: json['status'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      publicToken: json['public_token'] as String?,
      publicTokenExpiresAt: json['public_token_expires_at'] != null
          ? DateTime.parse(json['public_token_expires_at'] as String)
          : null,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lineItems:
          (json['line_items'] as List<dynamic>?)
              ?.map(
                (e) => InvoiceLineItem.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          [],
    );
  }

  bool get isDraft => status == 'draft';
  bool get isSent => status == 'sent';
  bool get isPaid => status == 'paid';
  bool get isOverdue => status == 'overdue';
  bool get isCancelled => status == 'cancelled';
  bool get isUnpaid => status == 'sent' || status == 'overdue';
  double get remainingAmount => totalAmount - paidAmount;
}

class DebtAgingBucket {
  final String bucket; // '0-30' | '30-60' | '>60'
  final int count;
  final double totalAmount;
  final List<int> invoiceIds;

  const DebtAgingBucket({
    required this.bucket,
    required this.count,
    required this.totalAmount,
    required this.invoiceIds,
  });

  factory DebtAgingBucket.fromJson(Map<String, dynamic> json) {
    return DebtAgingBucket(
      bucket: json['bucket'] as String,
      count: json['count'] as int,
      totalAmount: (json['total_amount'] as num).toDouble(),
      invoiceIds:
          (json['invoice_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }
}

class DebtAgingReport {
  final List<DebtAgingBucket> buckets;
  final double totalUnpaid;

  const DebtAgingReport({required this.buckets, required this.totalUnpaid});

  factory DebtAgingReport.fromJson(Map<String, dynamic> json) {
    return DebtAgingReport(
      buckets:
          (json['buckets'] as List<dynamic>?)
              ?.map(
                (e) => DebtAgingBucket.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          [],
      totalUnpaid: (json['total_unpaid'] as num?)?.toDouble() ?? 0,
    );
  }
}

class NeedsReminderItem {
  final int invoiceId;
  final int contractId;
  final String roomCode;
  final String tenantName;
  final String tenantPhone;
  final int daysOverdue;
  final double amountDue;

  const NeedsReminderItem({
    required this.invoiceId,
    required this.contractId,
    required this.roomCode,
    required this.tenantName,
    required this.tenantPhone,
    required this.daysOverdue,
    required this.amountDue,
  });

  factory NeedsReminderItem.fromJson(Map<String, dynamic> json) {
    return NeedsReminderItem(
      invoiceId: json['invoice_id'] as int,
      contractId: json['contract_id'] as int,
      roomCode: (json['room_code'] as String?) ?? '',
      tenantName: (json['tenant_name'] as String?) ?? '',
      tenantPhone: (json['tenant_phone'] as String?) ?? '',
      daysOverdue: json['days_overdue'] as int,
      amountDue: (json['amount_due'] as num).toDouble(),
    );
  }
}
