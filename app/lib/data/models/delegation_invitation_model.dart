/// Data model for delegation invitation records.
///
/// An owner sends an invitation; the targeted operator accepts or rejects it.
library;

enum InvitationStatus {
  pending,
  accepted,
  rejected,
  expired;

  static InvitationStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return InvitationStatus.pending;
      case 'accepted':
        return InvitationStatus.accepted;
      case 'rejected':
        return InvitationStatus.rejected;
      case 'expired':
        return InvitationStatus.expired;
      default:
        return InvitationStatus.pending;
    }
  }
}

class DelegationInvitationModel {
  const DelegationInvitationModel({
    required this.id,
    required this.ownerUserId,
    required this.operatorEmail,
    required this.status,
    required this.createdAt,
    this.delegationId,
    this.ownerName,
    this.operatorUserId,
    this.operatorName,
    this.rolePreset,
    this.expiresAt,
    this.respondedAt,
    this.rejectionReason,
  });

  final String id;
  final String ownerUserId;
  final String operatorEmail;
  final InvitationStatus status;
  final DateTime createdAt;

  // Set after invitation is accepted and delegation is created.
  final String? delegationId;

  // Denormalized display fields.
  final String? ownerName;
  final String? operatorUserId;
  final String? operatorName;
  final String? rolePreset;
  final DateTime? expiresAt;
  final DateTime? respondedAt;
  final String? rejectionReason;

  bool get isPending => status == InvitationStatus.pending;

  factory DelegationInvitationModel.fromJson(Map<String, dynamic> json) {
    return DelegationInvitationModel(
      id: json['id'] as String,
      ownerUserId: json['owner_user_id'] as String,
      operatorEmail: json['operator_email'] as String,
      status: InvitationStatus.fromString(
        (json['status'] as String?) ?? 'pending',
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      delegationId: json['delegation_id'] as String?,
      ownerName: json['owner_name'] as String?,
      operatorUserId: json['operator_user_id'] as String?,
      operatorName: json['operator_name'] as String?,
      rolePreset: json['role_preset'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      respondedAt: json['responded_at'] != null
          ? DateTime.tryParse(json['responded_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_user_id': ownerUserId,
    'operator_email': operatorEmail,
    'status': status.name,
    'created_at': createdAt.toIso8601String(),
    if (delegationId != null) 'delegation_id': delegationId,
    if (operatorUserId != null) 'operator_user_id': operatorUserId,
    if (rolePreset != null) 'role_preset': rolePreset,
    if (rejectionReason != null) 'rejection_reason': rejectionReason,
  };
}
