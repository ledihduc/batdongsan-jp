/// JP 内見 (viewing appointment) model.
///
/// Maps to backend `Viewing` table. Tenant proposes ≤3 slots;
/// agent confirms one; both are notified.
library;

/// Status of a JP viewing appointment.
enum JpViewingStatus {
  pending,
  confirmed,
  rejected,
  cancelled,
  completed,
}

JpViewingStatus jpViewingStatusFromString(String? s) {
  switch (s) {
    case 'confirmed':
      return JpViewingStatus.confirmed;
    case 'rejected':
      return JpViewingStatus.rejected;
    case 'cancelled':
      return JpViewingStatus.cancelled;
    case 'completed':
      return JpViewingStatus.completed;
    default:
      return JpViewingStatus.pending;
  }
}

String jpViewingStatusToString(JpViewingStatus status) {
  switch (status) {
    case JpViewingStatus.pending:
      return 'pending';
    case JpViewingStatus.confirmed:
      return 'confirmed';
    case JpViewingStatus.rejected:
      return 'rejected';
    case JpViewingStatus.cancelled:
      return 'cancelled';
    case JpViewingStatus.completed:
      return 'completed';
  }
}

/// A single proposed time slot.
class JpViewingSlot {
  const JpViewingSlot({
    required this.startAt,
    this.endAt,
  });

  /// ISO-8601 datetime string (JST), e.g. '2026-11-01T10:00:00+09:00'.
  final String startAt;

  /// Optional end time; defaults to 1 hour after [startAt] if omitted.
  final String? endAt;

  factory JpViewingSlot.fromJson(Map<String, dynamic> json) {
    return JpViewingSlot(
      startAt: json['start_at'] as String,
      endAt: json['end_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'start_at': startAt,
        if (endAt != null) 'end_at': endAt,
      };
}

/// A complete JP viewing record.
class JpViewing {
  const JpViewing({
    required this.id,
    required this.listingId,
    required this.tenantId,
    required this.proposedSlots,
    required this.status,
    this.confirmedSlot,
    this.agentId,
    this.agentName,
    this.tenantName,
    this.listingTitle,
    this.message,
    this.createdAt,
  });

  final int id;
  final int listingId;
  final int tenantId;

  /// Tenant proposes 1–3 slots; agent picks one.
  final List<JpViewingSlot> proposedSlots;

  final JpViewingStatus status;

  /// The slot confirmed by the agent; null until confirmed.
  final JpViewingSlot? confirmedSlot;

  final int? agentId;
  final String? agentName;
  final String? tenantName;
  final String? listingTitle;

  /// Optional message from the tenant.
  final String? message;

  final String? createdAt;

  factory JpViewing.fromJson(Map<String, dynamic> json) {
    final slotsRaw = json['proposed_slots'] as List<dynamic>? ?? [];
    final confirmedRaw = json['confirmed_slot'] as Map<String, dynamic>?;

    return JpViewing(
      id: json['id'] as int,
      listingId: json['listing_id'] as int,
      tenantId: json['tenant_id'] as int,
      proposedSlots: slotsRaw
          .map((e) => JpViewingSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: jpViewingStatusFromString(json['status'] as String?),
      confirmedSlot:
          confirmedRaw != null ? JpViewingSlot.fromJson(confirmedRaw) : null,
      agentId: json['agent_id'] as int?,
      agentName: json['agent_name'] as String?,
      tenantName: json['tenant_name'] as String?,
      listingTitle: json['listing_title'] as String?,
      message: json['message'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'listing_id': listingId,
        'tenant_id': tenantId,
        'proposed_slots': proposedSlots.map((s) => s.toJson()).toList(),
        'status': jpViewingStatusToString(status),
        if (confirmedSlot != null) 'confirmed_slot': confirmedSlot!.toJson(),
        if (agentId != null) 'agent_id': agentId,
        if (agentName != null) 'agent_name': agentName,
        if (tenantName != null) 'tenant_name': tenantName,
        if (listingTitle != null) 'listing_title': listingTitle,
        if (message != null) 'message': message,
        if (createdAt != null) 'created_at': createdAt,
      };
}
