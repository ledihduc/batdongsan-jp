/// Model for JP deposit settlement (敷金精算).
///
/// Covers the owner → itemize → tenant review → accept/dispute flow.
library;

/// Status of the entire settlement.
enum SettlementStatus {
  draft,
  tenantReview,
  tenantAccepted,
  tenantDisputed,
  completed,
}

/// Single deduction line in the settlement.
class DeductionLine {
  const DeductionLine({
    required this.id,
    required this.title,
    required this.amountYen,
    this.photoUrls = const [],
    this.note,
  });

  final String id;
  final String title;
  final int amountYen;
  final List<String> photoUrls;
  final String? note;

  DeductionLine copyWith({
    String? id,
    String? title,
    int? amountYen,
    List<String>? photoUrls,
    String? note,
  }) =>
      DeductionLine(
        id: id ?? this.id,
        title: title ?? this.title,
        amountYen: amountYen ?? this.amountYen,
        photoUrls: photoUrls ?? this.photoUrls,
        note: note ?? this.note,
      );

  factory DeductionLine.fromJson(Map<String, dynamic> json) => DeductionLine(
        id: json['id'] as String,
        title: json['title'] as String,
        amountYen: json['amount_yen'] as int,
        photoUrls: (json['photo_urls'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        note: json['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount_yen': amountYen,
        'photo_urls': photoUrls,
        if (note != null) 'note': note,
      };
}

/// Complete deposit settlement record.
class JpDepositSettlement {
  const JpDepositSettlement({
    required this.id,
    required this.contractId,
    required this.propertyName,
    required this.roomNumber,
    required this.tenantName,
    required this.depositYen,
    required this.deductions,
    required this.status,
    this.disputeReason,
    this.settledAt,
  });

  final int id;
  final int contractId;
  final String propertyName;
  final String roomNumber;
  final String tenantName;
  final int depositYen;
  final List<DeductionLine> deductions;
  final SettlementStatus status;
  final String? disputeReason;
  final DateTime? settledAt;

  int get totalDeductionYen =>
      deductions.fold(0, (sum, d) => sum + d.amountYen);
  int get netRefundYen => depositYen - totalDeductionYen;

  JpDepositSettlement copyWith({
    int? id,
    int? contractId,
    String? propertyName,
    String? roomNumber,
    String? tenantName,
    int? depositYen,
    List<DeductionLine>? deductions,
    SettlementStatus? status,
    String? disputeReason,
    DateTime? settledAt,
  }) =>
      JpDepositSettlement(
        id: id ?? this.id,
        contractId: contractId ?? this.contractId,
        propertyName: propertyName ?? this.propertyName,
        roomNumber: roomNumber ?? this.roomNumber,
        tenantName: tenantName ?? this.tenantName,
        depositYen: depositYen ?? this.depositYen,
        deductions: deductions ?? this.deductions,
        status: status ?? this.status,
        disputeReason: disputeReason ?? this.disputeReason,
        settledAt: settledAt ?? this.settledAt,
      );

  factory JpDepositSettlement.fromJson(Map<String, dynamic> json) =>
      JpDepositSettlement(
        id: json['id'] as int,
        contractId: json['contract_id'] as int,
        propertyName: json['property_name'] as String,
        roomNumber: json['room_number'] as String,
        tenantName: json['tenant_name'] as String,
        depositYen: json['deposit_yen'] as int,
        deductions: (json['deductions'] as List<dynamic>)
            .map((e) => DeductionLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        status: _parseStatus(json['status'] as String),
        disputeReason: json['dispute_reason'] as String?,
        settledAt: json['settled_at'] != null
            ? DateTime.parse(json['settled_at'] as String)
            : null,
      );

  static SettlementStatus _parseStatus(String s) {
    switch (s) {
      case 'tenant_review':
        return SettlementStatus.tenantReview;
      case 'tenant_accepted':
        return SettlementStatus.tenantAccepted;
      case 'tenant_disputed':
        return SettlementStatus.tenantDisputed;
      case 'completed':
        return SettlementStatus.completed;
      default:
        return SettlementStatus.draft;
    }
  }
}
