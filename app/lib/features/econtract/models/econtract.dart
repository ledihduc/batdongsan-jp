/// Electronic contract model — maps to /api/jp/econtracts.
///
/// Used with CloudSign. Status lifecycle:
///   pending → signed | expired | cancelled.
library;

/// Terminal statuses — polling should stop at these.
const Set<EcontractStatus> kTerminalEcontractStatuses = {
  EcontractStatus.signed,
  EcontractStatus.expired,
  EcontractStatus.cancelled,
};

enum EcontractStatus {
  pending,
  signed,
  expired,
  cancelled,
}

EcontractStatus econtractStatusFromString(String? s) {
  switch (s) {
    case 'signed':
      return EcontractStatus.signed;
    case 'expired':
      return EcontractStatus.expired;
    case 'cancelled':
      return EcontractStatus.cancelled;
    default:
      return EcontractStatus.pending;
  }
}

String econtractStatusToString(EcontractStatus s) {
  switch (s) {
    case EcontractStatus.pending:
      return 'pending';
    case EcontractStatus.signed:
      return 'signed';
    case EcontractStatus.expired:
      return 'expired';
    case EcontractStatus.cancelled:
      return 'cancelled';
  }
}

class Econtract {
  const Econtract({
    required this.id,
    required this.applicationId,
    required this.status,
    this.signingUrl,
    this.downloadUrl,
    this.cloudSignDocumentId,
    this.createdAt,
    this.signedAt,
  });

  final int id;
  final int applicationId;
  final EcontractStatus status;

  /// URL of the CloudSign signing page (may be null if not yet issued).
  final String? signingUrl;

  /// Signed PDF download URL (populated after signing).
  final String? downloadUrl;

  final String? cloudSignDocumentId;
  final String? createdAt;
  final String? signedAt;

  factory Econtract.fromJson(Map<String, dynamic> json) {
    return Econtract(
      id: json['id'] as int,
      applicationId: json['application_id'] as int,
      status: econtractStatusFromString(json['status'] as String?),
      signingUrl: json['signing_url'] as String?,
      downloadUrl: json['download_url'] as String?,
      cloudSignDocumentId: json['cloud_sign_document_id'] as String?,
      createdAt: json['created_at'] as String?,
      signedAt: json['signed_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'application_id': applicationId,
        'status': econtractStatusToString(status),
        if (signingUrl != null) 'signing_url': signingUrl,
        if (downloadUrl != null) 'download_url': downloadUrl,
        if (cloudSignDocumentId != null)
          'cloud_sign_document_id': cloudSignDocumentId,
        if (createdAt != null) 'created_at': createdAt,
        if (signedAt != null) 'signed_at': signedAt,
      };
}
