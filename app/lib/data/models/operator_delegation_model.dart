/// Data model for an owner-operator delegation record.
///
/// Corresponds to the `delegations` backend table (Phase 01 schema).
/// No freezed — project uses manual fromJson/toJson (researcher-03 §G).
library;

/// Permission presets granted to an operator within a delegation.
enum DelegationRolePreset {
  ownerView,
  operatorFull,
  accountant,
  viewer;

  static DelegationRolePreset fromString(String value) {
    switch (value) {
      case 'owner_view':
        return DelegationRolePreset.ownerView;
      case 'operator_full':
        return DelegationRolePreset.operatorFull;
      case 'accountant':
        return DelegationRolePreset.accountant;
      case 'viewer':
        return DelegationRolePreset.viewer;
      default:
        return DelegationRolePreset.viewer;
    }
  }

  String toApiString() {
    switch (this) {
      case DelegationRolePreset.ownerView:
        return 'owner_view';
      case DelegationRolePreset.operatorFull:
        return 'operator_full';
      case DelegationRolePreset.accountant:
        return 'accountant';
      case DelegationRolePreset.viewer:
        return 'viewer';
    }
  }
}

/// Lifecycle status of a delegation.
enum DelegationStatus {
  pending,
  active,
  paused,
  terminated,
  revokedPending;

  static DelegationStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return DelegationStatus.pending;
      case 'active':
        return DelegationStatus.active;
      case 'paused':
        return DelegationStatus.paused;
      case 'terminated':
        return DelegationStatus.terminated;
      case 'revoked_pending':
        return DelegationStatus.revokedPending;
      default:
        return DelegationStatus.pending;
    }
  }
}

/// Approval threshold configuration for a delegation.
/// Amounts in VND. null = no threshold for that action type.
class DelegationThresholds {
  const DelegationThresholds({
    this.contractCreate,
    this.expenseApproval,
    this.refundApproval,
    this.kb04Filing,
    this.terminationApproval,
  });

  final double? contractCreate;
  final double? expenseApproval;
  final double? refundApproval;
  final double? kb04Filing;
  final double? terminationApproval;

  factory DelegationThresholds.fromJson(Map<String, dynamic> json) {
    return DelegationThresholds(
      contractCreate: (json['contract_create'] as num?)?.toDouble(),
      expenseApproval: (json['expense_approval'] as num?)?.toDouble(),
      refundApproval: (json['refund_approval'] as num?)?.toDouble(),
      kb04Filing: (json['kb04_filing'] as num?)?.toDouble(),
      terminationApproval: (json['termination_approval'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (contractCreate != null) 'contract_create': contractCreate,
    if (expenseApproval != null) 'expense_approval': expenseApproval,
    if (refundApproval != null) 'refund_approval': refundApproval,
    if (kb04Filing != null) 'kb04_filing': kb04Filing,
    if (terminationApproval != null)
      'termination_approval': terminationApproval,
  };
}

/// Full delegation record returned by the backend.
class OperatorDelegationModel {
  const OperatorDelegationModel({
    required this.id,
    required this.ownerUserId,
    required this.operatorUserId,
    required this.rolePreset,
    required this.status,
    required this.createdAt,
    this.ownerName,
    this.ownerAvatarUrl,
    this.operatorName,
    this.operatorAvatarUrl,
    this.thresholds,
    this.permissionSet = const {},
    this.propertyCount = 0,
    this.pendingApprovalCount = 0,
    this.mtdRevenueVnd = 0,
    this.pausedAt,
    this.terminatedAt,
    this.sharedLoginDisclosureAckAt,
    this.soleOwnershipAttestedAt,
  });

  final String id;
  final String ownerUserId;
  final String operatorUserId;
  final DelegationRolePreset rolePreset;
  final DelegationStatus status;
  final DateTime createdAt;

  // Denormalized display fields from backend join.
  final String? ownerName;
  final String? ownerAvatarUrl;
  final String? operatorName;
  final String? operatorAvatarUrl;

  final DelegationThresholds? thresholds;

  /// Server-resolved permission set (e.g. {'contract.create', 'expense.approve'}).
  final Set<String> permissionSet;

  /// KPI fields returned in portfolio list.
  final int propertyCount;
  final int pendingApprovalCount;
  final double mtdRevenueVnd;

  final DateTime? pausedAt;
  final DateTime? terminatedAt;
  final DateTime? sharedLoginDisclosureAckAt;
  final DateTime? soleOwnershipAttestedAt;

  bool get isActive => status == DelegationStatus.active;
  bool get isPaused => status == DelegationStatus.paused;

  factory OperatorDelegationModel.fromJson(Map<String, dynamic> json) {
    final rawPerms = json['permission_set'];
    final Set<String> perms = rawPerms is List
        ? Set<String>.from(rawPerms.whereType<String>())
        : const {};

    final rawThresholds = json['thresholds'];
    final thresholds = rawThresholds is Map<String, dynamic>
        ? DelegationThresholds.fromJson(rawThresholds)
        : null;

    return OperatorDelegationModel(
      id: json['id'] as String,
      ownerUserId: json['owner_user_id'] as String,
      operatorUserId: json['operator_user_id'] as String,
      rolePreset: DelegationRolePreset.fromString(
        (json['role_preset'] as String?) ?? 'viewer',
      ),
      status: DelegationStatus.fromString(
        (json['status'] as String?) ?? 'pending',
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      ownerName: json['owner_name'] as String?,
      ownerAvatarUrl: json['owner_avatar_url'] as String?,
      operatorName: json['operator_name'] as String?,
      operatorAvatarUrl: json['operator_avatar_url'] as String?,
      thresholds: thresholds,
      permissionSet: perms,
      propertyCount: (json['property_count'] as int?) ?? 0,
      pendingApprovalCount: (json['pending_approval_count'] as int?) ?? 0,
      mtdRevenueVnd: (json['mtd_revenue_vnd'] as num?)?.toDouble() ?? 0,
      pausedAt: json['paused_at'] != null
          ? DateTime.tryParse(json['paused_at'] as String)
          : null,
      terminatedAt: json['terminated_at'] != null
          ? DateTime.tryParse(json['terminated_at'] as String)
          : null,
      sharedLoginDisclosureAckAt: json['shared_login_disclosure_ack_at'] != null
          ? DateTime.tryParse(json['shared_login_disclosure_ack_at'] as String)
          : null,
      soleOwnershipAttestedAt: json['sole_ownership_attested_at'] != null
          ? DateTime.tryParse(json['sole_ownership_attested_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_user_id': ownerUserId,
    'operator_user_id': operatorUserId,
    'role_preset': rolePreset.toApiString(),
    'status': status.name,
    'created_at': createdAt.toIso8601String(),
    if (ownerName != null) 'owner_name': ownerName,
    if (operatorName != null) 'operator_name': operatorName,
    if (thresholds != null) 'thresholds': thresholds!.toJson(),
    'permission_set': permissionSet.toList(),
    'property_count': propertyCount,
    'pending_approval_count': pendingApprovalCount,
    'mtd_revenue_vnd': mtdRevenueVnd,
  };
}
