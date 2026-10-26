/// APPI consent purpose enum + display helpers.
///
/// Maps to `user_consents.purpose` column in the backend.
/// Required purposes must all be granted before registration completes.
library;

/// The set of personal-information processing purposes disclosed under APPI.
enum ConsentPurpose {
  /// 必須 — Service delivery (物件検索・契約). Cannot be revoked without
  /// terminating the account.
  serviceUse,

  /// 任意 — Marketing and property recommendations.
  marketing,

  /// 任意 — Aggregate analytics / service improvement.
  analytics,

  /// 任意 — Data sharing with licensed broker for transaction processing.
  dataSharingBroker,

  /// 任意 — Data sharing with hoshou-gaisha for tenant screening.
  dataSharingHoshou,
}

/// Whether a purpose is legally required to use the service.
bool isConsentPurposeRequired(ConsentPurpose purpose) {
  return purpose == ConsentPurpose.serviceUse;
}

/// Backend wire value for the purpose enum.
String consentPurposeToWireValue(ConsentPurpose purpose) {
  switch (purpose) {
    case ConsentPurpose.serviceUse:
      return 'service_use';
    case ConsentPurpose.marketing:
      return 'marketing';
    case ConsentPurpose.analytics:
      return 'analytics';
    case ConsentPurpose.dataSharingBroker:
      return 'data_sharing_broker';
    case ConsentPurpose.dataSharingHoshou:
      return 'data_sharing_hoshou';
  }
}

ConsentPurpose consentPurposeFromWireValue(String value) {
  switch (value) {
    case 'service_use':
      return ConsentPurpose.serviceUse;
    case 'marketing':
      return ConsentPurpose.marketing;
    case 'analytics':
      return ConsentPurpose.analytics;
    case 'data_sharing_broker':
      return ConsentPurpose.dataSharingBroker;
    case 'data_sharing_hoshou':
      return ConsentPurpose.dataSharingHoshou;
    default:
      return ConsentPurpose.serviceUse;
  }
}

/// A recorded consent grant for a user+purpose.
class ConsentRecord {
  const ConsentRecord({
    required this.id,
    required this.purpose,
    required this.granted,
    required this.policyVersion,
    this.grantedAt,
    this.revokedAt,
  });

  final int id;
  final ConsentPurpose purpose;

  /// true = granted, false = revoked.
  final bool granted;

  /// Policy version at time of consent (e.g. '2026-10').
  final String policyVersion;

  final String? grantedAt;
  final String? revokedAt;

  factory ConsentRecord.fromJson(Map<String, dynamic> json) {
    return ConsentRecord(
      id: json['id'] as int,
      purpose: consentPurposeFromWireValue(json['purpose'] as String),
      granted: json['granted'] as bool? ?? false,
      policyVersion: json['policy_version'] as String? ?? '',
      grantedAt: json['granted_at'] as String?,
      revokedAt: json['revoked_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'purpose': consentPurposeToWireValue(purpose),
        'granted': granted,
        'policy_version': policyVersion,
        if (grantedAt != null) 'granted_at': grantedAt,
        if (revokedAt != null) 'revoked_at': revokedAt,
      };
}

/// Payload for bulk consent grant at registration.
class ConsentGrantRequest {
  const ConsentGrantRequest({
    required this.purposes,
    required this.policyVersion,
  });

  final List<ConsentPurpose> purposes;
  final String policyVersion;

  Map<String, dynamic> toJson() => {
        'purposes':
            purposes.map(consentPurposeToWireValue).toList(),
        'policy_version': policyVersion,
      };
}
