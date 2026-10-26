import 'package:house_booking/data/models/tenant_model.dart';

/// ContractTenantInfo — pivot row data embedded in ContractModel.
class ContractTenantInfo {
  final TenantModel tenant;
  final bool isPrimary;
  final String? joinedAt;
  final String? leftAt;

  const ContractTenantInfo({
    required this.tenant,
    required this.isPrimary,
    this.joinedAt,
    this.leftAt,
  });

  factory ContractTenantInfo.fromJson(Map<String, dynamic> json) {
    return ContractTenantInfo(
      tenant: TenantModel.fromJson(
        Map<String, dynamic>.from(json['tenant'] as Map),
      ),
      isPrimary: json['is_primary'] as bool? ?? false,
      joinedAt: json['joined_at'] as String?,
      leftAt: json['left_at'] as String?,
    );
  }
}

/// ContractModel — mirrors ContractResponse schema from backend.
///
/// Status: 'draft' | 'active' | 'expired' | 'terminated'
class ContractModel {
  final int id;
  final int hostId;
  final int roomId;
  final String startDate;
  final String endDate;
  final double monthlyRent;
  final double deposit;
  final String status;
  final String? terminatedAt;
  final String? actualEndDate;
  final double? depositRefundAmount;
  final String? damageNote;
  final List<String> damagePhotos;
  final List<String> handoverPhotos;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ContractTenantInfo> tenants;

  const ContractModel({
    required this.id,
    required this.hostId,
    required this.roomId,
    required this.startDate,
    required this.endDate,
    required this.monthlyRent,
    required this.deposit,
    required this.status,
    this.terminatedAt,
    this.actualEndDate,
    this.depositRefundAmount,
    this.damageNote,
    required this.damagePhotos,
    required this.handoverPhotos,
    required this.createdAt,
    required this.updatedAt,
    required this.tenants,
  });

  factory ContractModel.fromJson(Map<String, dynamic> json) {
    return ContractModel(
      id: json['id'] as int,
      hostId: json['host_id'] as int,
      roomId: json['room_id'] as int,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      monthlyRent: (json['monthly_rent'] as num).toDouble(),
      deposit: (json['deposit'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String,
      terminatedAt: json['terminated_at'] as String?,
      actualEndDate: json['actual_end_date'] as String?,
      depositRefundAmount: (json['deposit_refund_amount'] as num?)?.toDouble(),
      damageNote: json['damage_note'] as String?,
      damagePhotos:
          (json['damage_photos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      handoverPhotos:
          (json['handover_photos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      tenants:
          (json['tenants'] as List<dynamic>?)
              ?.map(
                (e) => ContractTenantInfo.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          [],
    );
  }

  bool get isActive => status == 'active';
  bool get isDraft => status == 'draft';
  bool get isTerminated => status == 'terminated';

  ContractTenantInfo? get primaryTenant {
    try {
      return tenants.firstWhere((t) => t.isPrimary);
    } catch (_) {
      return tenants.isNotEmpty ? tenants.first : null;
    }
  }
}
