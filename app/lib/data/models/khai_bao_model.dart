/// Phase 05 — KhaiBaoTamTru (residence declaration) record.
///
/// Mirrors backend `KhaiBaoResponse` (schemas/khai_bao_tam_tru.py).
/// Status values must match: pending | declared | overdue | skipped.
library;

class KhaiBaoModel {
  final int id;
  final int hostId;
  final int tenantId;
  final int? contractId;
  final int? reservationId;
  final DateTime checkInAt;
  final DateTime? declaredAt;
  final String status; // pending | declared | overdue | skipped
  final String? skipReason;
  final String publicToken;
  final DateTime publicTokenExpiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Denormalised fields populated server-side for UI.
  final String? tenantName;
  final String? tenantPhone;
  final String? roomCode;
  final String? buildingName;
  final int? deadlineSecondsRemaining;

  const KhaiBaoModel({
    required this.id,
    required this.hostId,
    required this.tenantId,
    required this.contractId,
    required this.reservationId,
    required this.checkInAt,
    required this.declaredAt,
    required this.status,
    required this.skipReason,
    required this.publicToken,
    required this.publicTokenExpiresAt,
    required this.createdAt,
    required this.updatedAt,
    required this.tenantName,
    required this.tenantPhone,
    required this.roomCode,
    required this.buildingName,
    required this.deadlineSecondsRemaining,
  });

  bool get isPending => status == 'pending';
  bool get isDeclared => status == 'declared';
  bool get isOverdue => status == 'overdue';
  bool get isSkipped => status == 'skipped';
  bool get isActionable => isPending || isOverdue;

  factory KhaiBaoModel.fromJson(Map<String, dynamic> json) => KhaiBaoModel(
    id: json['id'] as int,
    hostId: json['host_id'] as int,
    tenantId: json['tenant_id'] as int,
    contractId: json['contract_id'] as int?,
    reservationId: json['reservation_id'] as int?,
    checkInAt: DateTime.parse(json['check_in_at'] as String),
    declaredAt: json['declared_at'] != null
        ? DateTime.parse(json['declared_at'] as String)
        : null,
    status: json['status'] as String,
    skipReason: json['skip_reason'] as String?,
    publicToken: json['public_token'] as String,
    publicTokenExpiresAt: DateTime.parse(
      json['public_token_expires_at'] as String,
    ),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    tenantName: json['tenant_name'] as String?,
    tenantPhone: json['tenant_phone'] as String?,
    roomCode: json['room_code'] as String?,
    buildingName: json['building_name'] as String?,
    deadlineSecondsRemaining: json['deadline_seconds_remaining'] as int?,
  );
}

class KhaiBaoDashboardSummary {
  final int pending;
  final int overdue;
  final int declared;
  final int skipped;

  const KhaiBaoDashboardSummary({
    required this.pending,
    required this.overdue,
    required this.declared,
    required this.skipped,
  });

  int get actionable => pending + overdue;

  factory KhaiBaoDashboardSummary.fromJson(Map<String, dynamic> json) =>
      KhaiBaoDashboardSummary(
        pending: json['pending'] as int,
        overdue: json['overdue'] as int,
        declared: json['declared'] as int,
        skipped: json['skipped'] as int,
      );

  static const empty = KhaiBaoDashboardSummary(
    pending: 0,
    overdue: 0,
    declared: 0,
    skipped: 0,
  );
}
