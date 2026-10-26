/// Data model for approval requests in the delegation approval workflow.
///
/// When an operator performs an action above the threshold, a pending approval
/// request is created for the owner to approve or reject.
library;

enum ApprovalStatus {
  pending,
  approved,
  rejected,
  expired,
  autoApproved;

  static ApprovalStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return ApprovalStatus.pending;
      case 'approved':
        return ApprovalStatus.approved;
      case 'rejected':
        return ApprovalStatus.rejected;
      case 'expired':
        return ApprovalStatus.expired;
      case 'auto_approved':
        return ApprovalStatus.autoApproved;
      default:
        return ApprovalStatus.pending;
    }
  }
}

enum ApprovalActionType {
  contractCreate,
  expenseApproval,
  refundApproval,
  kb04Filing,
  terminationApproval,
  other;

  static ApprovalActionType fromString(String value) {
    switch (value) {
      case 'contract_create':
        return ApprovalActionType.contractCreate;
      case 'expense_approval':
        return ApprovalActionType.expenseApproval;
      case 'refund_approval':
        return ApprovalActionType.refundApproval;
      case 'kb04_filing':
        return ApprovalActionType.kb04Filing;
      case 'termination_approval':
        return ApprovalActionType.terminationApproval;
      default:
        return ApprovalActionType.other;
    }
  }

  String displayLabel() {
    switch (this) {
      case ApprovalActionType.contractCreate:
        return 'Tạo hợp đồng';
      case ApprovalActionType.expenseApproval:
        return 'Phê duyệt chi phí';
      case ApprovalActionType.refundApproval:
        return 'Hoàn tiền';
      case ApprovalActionType.kb04Filing:
        return 'Khai báo KB04';
      case ApprovalActionType.terminationApproval:
        return 'Chấm dứt hợp đồng';
      case ApprovalActionType.other:
        return 'Khác';
    }
  }
}

class ApprovalRequestModel {
  const ApprovalRequestModel({
    required this.id,
    required this.delegationId,
    required this.ownerUserId,
    required this.operatorUserId,
    required this.actionType,
    required this.status,
    required this.requestedAt,
    this.entityId,
    this.entityType,
    this.amountVnd,
    this.ownerName,
    this.operatorName,
    this.operatorAvatarUrl,
    this.actionDescription,
    this.payload,
    this.slaExpiresAt,
    this.resolvedAt,
    this.rejectionReason,
    this.ownerNotifiedAt,
    this.ownerNotificationChannel,
    this.requiresBiometric = false,
  });

  final String id;
  final String delegationId;
  final String ownerUserId;
  final String operatorUserId;
  final ApprovalActionType actionType;
  final ApprovalStatus status;
  final DateTime requestedAt;

  final String? entityId;
  final String? entityType;

  /// Amount in VND — triggers biometric prompt when >= 50,000,000 (AC-29b).
  final double? amountVnd;

  // Denormalized display fields.
  final String? ownerName;
  final String? operatorName;
  final String? operatorAvatarUrl;
  final String? actionDescription;

  /// Full payload of the pending operation (for display in detail sheet).
  final Map<String, dynamic>? payload;

  final DateTime? slaExpiresAt;
  final DateTime? resolvedAt;
  final String? rejectionReason;

  // Escalation ladder status (AC-30b).
  final DateTime? ownerNotifiedAt;
  final String? ownerNotificationChannel;

  /// True when amountVnd >= 50,000,000 — computed server-side (AC-29b).
  final bool requiresBiometric;

  bool get isPending => status == ApprovalStatus.pending;

  factory ApprovalRequestModel.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    final Map<String, dynamic>? payload = rawPayload is Map<String, dynamic>
        ? rawPayload
        : null;

    return ApprovalRequestModel(
      id: json['id'] as String,
      delegationId: json['delegation_id'] as String,
      ownerUserId: json['owner_user_id'] as String,
      operatorUserId: json['operator_user_id'] as String,
      actionType: ApprovalActionType.fromString(
        (json['action_type'] as String?) ?? 'other',
      ),
      status: ApprovalStatus.fromString(
        (json['status'] as String?) ?? 'pending',
      ),
      requestedAt: DateTime.parse(json['requested_at'] as String),
      entityId: json['entity_id'] as String?,
      entityType: json['entity_type'] as String?,
      amountVnd: (json['amount_vnd'] as num?)?.toDouble(),
      ownerName: json['owner_name'] as String?,
      operatorName: json['operator_name'] as String?,
      operatorAvatarUrl: json['operator_avatar_url'] as String?,
      actionDescription: json['action_description'] as String?,
      payload: payload,
      slaExpiresAt: json['sla_expires_at'] != null
          ? DateTime.tryParse(json['sla_expires_at'] as String)
          : null,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      ownerNotifiedAt: json['owner_notified_at'] != null
          ? DateTime.tryParse(json['owner_notified_at'] as String)
          : null,
      ownerNotificationChannel: json['owner_notification_channel'] as String?,
      requiresBiometric: (json['requires_biometric'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'delegation_id': delegationId,
    'owner_user_id': ownerUserId,
    'operator_user_id': operatorUserId,
    'action_type': actionType.name,
    'status': status.name,
    'requested_at': requestedAt.toIso8601String(),
    if (entityId != null) 'entity_id': entityId,
    if (amountVnd != null) 'amount_vnd': amountVnd,
    'requires_biometric': requiresBiometric,
  };
}
