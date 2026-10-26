/// Phase 04 — ServiceFee + ContractServiceFee mirrors backend schemas.
class ServiceFeeModel {
  final int id;
  final int hostId;
  final int buildingId;
  final String name;
  final double unitPrice;
  final String billingCycle; // monthly|one_time
  final bool isActive;
  final DateTime createdAt;

  const ServiceFeeModel({
    required this.id,
    required this.hostId,
    required this.buildingId,
    required this.name,
    required this.unitPrice,
    required this.billingCycle,
    required this.isActive,
    required this.createdAt,
  });

  factory ServiceFeeModel.fromJson(Map<String, dynamic> json) {
    return ServiceFeeModel(
      id: json['id'] as int,
      hostId: json['host_id'] as int,
      buildingId: json['building_id'] as int,
      name: json['name'] as String,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      billingCycle: (json['billing_cycle'] as String?) ?? 'monthly',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ContractServiceFeeModel {
  final int contractId;
  final int serviceFeeId;
  final double monthlyAmount;
  final String? serviceFeeName;

  const ContractServiceFeeModel({
    required this.contractId,
    required this.serviceFeeId,
    required this.monthlyAmount,
    this.serviceFeeName,
  });

  factory ContractServiceFeeModel.fromJson(Map<String, dynamic> json) {
    return ContractServiceFeeModel(
      contractId: json['contract_id'] as int,
      serviceFeeId: json['service_fee_id'] as int,
      monthlyAmount: (json['monthly_amount'] as num).toDouble(),
      serviceFeeName: json['service_fee_name'] as String?,
    );
  }
}
