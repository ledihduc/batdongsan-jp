/// Model for JP lease renewal (更新).
///
/// Represents an upcoming or in-progress renewal notification
/// with contract summary and 更新料 breakdown.
library;

/// Single line item in the 更新料 breakdown.
class RenewalFeeItem {
  const RenewalFeeItem({
    required this.label,
    required this.amountYen,
  });

  final String label;
  final int amountYen;

  factory RenewalFeeItem.fromJson(Map<String, dynamic> json) => RenewalFeeItem(
        label: json['label'] as String,
        amountYen: json['amount_yen'] as int,
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'amount_yen': amountYen,
      };
}

/// Renewal status values.
enum RenewalStatus {
  pending,
  confirmed,
  declined,
  expired,
}

/// Complete JP lease renewal record.
class JpRenewal {
  const JpRenewal({
    required this.id,
    required this.contractId,
    required this.propertyName,
    required this.roomNumber,
    required this.tenantName,
    required this.currentTermEnd,
    required this.newTermEnd,
    required this.monthlyRentYen,
    required this.feeItems,
    required this.status,
    this.confirmedAt,
  });

  final int id;
  final int contractId;
  final String propertyName;
  final String roomNumber;
  final String tenantName;
  final DateTime currentTermEnd;
  final DateTime newTermEnd;
  final int monthlyRentYen;
  final List<RenewalFeeItem> feeItems;
  final RenewalStatus status;
  final DateTime? confirmedAt;

  int get totalFeeYen => feeItems.fold(0, (sum, item) => sum + item.amountYen);

  factory JpRenewal.fromJson(Map<String, dynamic> json) => JpRenewal(
        id: json['id'] as int,
        contractId: json['contract_id'] as int,
        propertyName: json['property_name'] as String,
        roomNumber: json['room_number'] as String,
        tenantName: json['tenant_name'] as String,
        currentTermEnd: DateTime.parse(json['current_term_end'] as String),
        newTermEnd: DateTime.parse(json['new_term_end'] as String),
        monthlyRentYen: json['monthly_rent_yen'] as int,
        feeItems: (json['fee_items'] as List<dynamic>)
            .map((e) => RenewalFeeItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        status: _parseStatus(json['status'] as String),
        confirmedAt: json['confirmed_at'] != null
            ? DateTime.parse(json['confirmed_at'] as String)
            : null,
      );

  static RenewalStatus _parseStatus(String s) {
    switch (s) {
      case 'confirmed':
        return RenewalStatus.confirmed;
      case 'declined':
        return RenewalStatus.declined;
      case 'expired':
        return RenewalStatus.expired;
      default:
        return RenewalStatus.pending;
    }
  }
}
