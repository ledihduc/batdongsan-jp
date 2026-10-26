/// JP PaymentIntent model — mirrors backend JpPaymentIntent table.
///
/// Status lifecycle: pending → processing → succeeded | failed | expired.
library;

/// Payment method types supported for JP market.
enum JpPaymentMethod {
  card,
  konbini,
  bankTransfer,
}

/// Terminal statuses — polling should stop at these.
const Set<JpPaymentIntentStatus> kTerminalPaymentStatuses = {
  JpPaymentIntentStatus.succeeded,
  JpPaymentIntentStatus.failed,
  JpPaymentIntentStatus.expired,
};

enum JpPaymentIntentStatus {
  pending,
  processing,
  succeeded,
  failed,
  expired,
}

JpPaymentIntentStatus paymentIntentStatusFromString(String? s) {
  switch (s) {
    case 'processing':
      return JpPaymentIntentStatus.processing;
    case 'succeeded':
      return JpPaymentIntentStatus.succeeded;
    case 'failed':
      return JpPaymentIntentStatus.failed;
    case 'expired':
      return JpPaymentIntentStatus.expired;
    default:
      return JpPaymentIntentStatus.pending;
  }
}

String paymentIntentStatusToString(JpPaymentIntentStatus s) {
  switch (s) {
    case JpPaymentIntentStatus.pending:
      return 'pending';
    case JpPaymentIntentStatus.processing:
      return 'processing';
    case JpPaymentIntentStatus.succeeded:
      return 'succeeded';
    case JpPaymentIntentStatus.failed:
      return 'failed';
    case JpPaymentIntentStatus.expired:
      return 'expired';
  }
}

class JpPaymentIntent {
  const JpPaymentIntent({
    required this.id,
    required this.invoiceId,
    required this.amountJpy,
    required this.status,
    required this.paymentMethod,
    this.komojuPaymentId,
    this.createdAt,
    this.expiresAt,
    this.metadata,
  });

  final int id;
  final int invoiceId;
  final int amountJpy;
  final JpPaymentIntentStatus status;
  final JpPaymentMethod paymentMethod;

  /// Provider-side reference (Komoju payment ID).
  final String? komojuPaymentId;

  final String? createdAt;
  final String? expiresAt;
  final Map<String, dynamic>? metadata;

  factory JpPaymentIntent.fromJson(Map<String, dynamic> json) {
    return JpPaymentIntent(
      id: json['id'] as int,
      invoiceId: json['invoice_id'] as int,
      amountJpy: json['amount_jpy'] as int,
      status: paymentIntentStatusFromString(json['status'] as String?),
      paymentMethod: _methodFromString(json['payment_method'] as String?),
      komojuPaymentId: json['komoju_payment_id'] as String?,
      createdAt: json['created_at'] as String?,
      expiresAt: json['expires_at'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  static JpPaymentMethod _methodFromString(String? s) {
    switch (s) {
      case 'card':
        return JpPaymentMethod.card;
      case 'konbini':
        return JpPaymentMethod.konbini;
      case 'bank_transfer':
        return JpPaymentMethod.bankTransfer;
      default:
        return JpPaymentMethod.konbini;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoice_id': invoiceId,
        'amount_jpy': amountJpy,
        'status': paymentIntentStatusToString(status),
        'payment_method': _methodToString(paymentMethod),
        if (komojuPaymentId != null) 'komoju_payment_id': komojuPaymentId,
        if (createdAt != null) 'created_at': createdAt,
        if (expiresAt != null) 'expires_at': expiresAt,
        if (metadata != null) 'metadata': metadata,
      };

  static String _methodToString(JpPaymentMethod m) {
    switch (m) {
      case JpPaymentMethod.card:
        return 'card';
      case JpPaymentMethod.konbini:
        return 'konbini';
      case JpPaymentMethod.bankTransfer:
        return 'bank_transfer';
    }
  }
}

/// Invoice summary passed to the checkout screen.
class JpInvoiceSummary {
  const JpInvoiceSummary({
    required this.id,
    required this.title,
    required this.amountJpy,
    this.dueDate,
  });

  final int id;
  final String title;
  final int amountJpy;
  final String? dueDate;

  factory JpInvoiceSummary.fromJson(Map<String, dynamic> json) {
    return JpInvoiceSummary(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      amountJpy: json['amount_jpy'] as int,
      dueDate: json['due_date'] as String?,
    );
  }
}
