/// JP 入居申込 (tenant application) model.
///
/// Maps to backend `TenantApplication` table. PII fields (年収, 保証人)
/// are flagged `pii=True` server-side. No field-level encryption at rest yet
/// (deferred to P2 APPI work — see phase-01-core-chintai-backend.md §Security).
library;

/// Application lifecycle status.
enum JpApplicationStatus {
  draft,
  submitted,
  underReview,
  approved,
  rejected,
  withdrawn,
}

JpApplicationStatus jpApplicationStatusFromString(String? s) {
  switch (s) {
    case 'submitted':
      return JpApplicationStatus.submitted;
    case 'under_review':
      return JpApplicationStatus.underReview;
    case 'approved':
      return JpApplicationStatus.approved;
    case 'rejected':
      return JpApplicationStatus.rejected;
    case 'withdrawn':
      return JpApplicationStatus.withdrawn;
    default:
      return JpApplicationStatus.draft;
  }
}

String jpApplicationStatusToString(JpApplicationStatus s) {
  switch (s) {
    case JpApplicationStatus.draft:
      return 'draft';
    case JpApplicationStatus.submitted:
      return 'submitted';
    case JpApplicationStatus.underReview:
      return 'under_review';
    case JpApplicationStatus.approved:
      return 'approved';
    case JpApplicationStatus.rejected:
      return 'rejected';
    case JpApplicationStatus.withdrawn:
      return 'withdrawn';
  }
}

/// 勤務先 — employer information.
class JpEmployerInfo {
  const JpEmployerInfo({
    required this.companyName,
    required this.employmentType,
    required this.annualIncomeJpy,
    this.yearsEmployed,
    this.phone,
    this.address,
  });

  final String companyName;

  /// e.g. '正社員', '契約社員', '自営業', 'パート'.
  final String employmentType;

  /// 年収 in JPY (PII — do not log).
  final int annualIncomeJpy;

  final int? yearsEmployed;
  final String? phone;
  final String? address;

  factory JpEmployerInfo.fromJson(Map<String, dynamic> json) {
    return JpEmployerInfo(
      companyName: json['company_name'] as String? ?? '',
      employmentType: json['employment_type'] as String? ?? '',
      annualIncomeJpy: json['annual_income_jpy'] as int? ?? 0,
      yearsEmployed: json['years_employed'] as int?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'company_name': companyName,
        'employment_type': employmentType,
        'annual_income_jpy': annualIncomeJpy,
        if (yearsEmployed != null) 'years_employed': yearsEmployed,
        if (phone != null) 'phone': phone,
        if (address != null) 'address': address,
      };
}

/// 連帯保証人 / 緊急連絡先 contact entry.
class JpContactPerson {
  const JpContactPerson({
    required this.name,
    required this.relationship,
    required this.phone,
    this.address,
    this.annualIncomeJpy,
  });

  final String name;

  /// Relationship to tenant, e.g. '父', '母', '配偶者'.
  final String relationship;

  final String phone;
  final String? address;

  /// 年収 — only required for 連帯保証人.
  final int? annualIncomeJpy;

  factory JpContactPerson.fromJson(Map<String, dynamic> json) {
    return JpContactPerson(
      name: json['name'] as String? ?? '',
      relationship: json['relationship'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String?,
      annualIncomeJpy: json['annual_income_jpy'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'relationship': relationship,
        'phone': phone,
        if (address != null) 'address': address,
        if (annualIncomeJpy != null) 'annual_income_jpy': annualIncomeJpy,
      };
}

/// A reference to an uploaded document (stored via signed-URL flow).
class JpDocumentRef {
  const JpDocumentRef({
    required this.type,
    required this.storageKey,
    this.uploadedAt,
  });

  /// Document type code, e.g. 'id_card', 'income_certificate', 'residence_card'.
  final String type;

  /// Supabase Storage key or presigned path.
  final String storageKey;

  final String? uploadedAt;

  factory JpDocumentRef.fromJson(Map<String, dynamic> json) {
    return JpDocumentRef(
      type: json['type'] as String,
      storageKey: json['storage_key'] as String,
      uploadedAt: json['uploaded_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'storage_key': storageKey,
        if (uploadedAt != null) 'uploaded_at': uploadedAt,
      };
}

/// Full 入居申込 (tenant application).
class JpApplication {
  const JpApplication({
    required this.id,
    required this.listingId,
    required this.tenantId,
    required this.status,
    required this.applicantName,
    required this.applicantPhone,
    required this.applicantEmail,
    this.employer,
    this.guarantor,
    this.emergencyContact,
    this.documents = const [],
    this.message,
    this.agentNote,
    this.createdAt,
    this.updatedAt,
    this.listingTitle,
    this.reviewedByAgentId,
  });

  final int id;
  final int listingId;
  final int tenantId;
  final JpApplicationStatus status;

  // ── Step 1: Basic info ───────────────────────────────────────────────────
  final String applicantName;
  final String applicantPhone;
  final String applicantEmail;

  // ── Step 2: Employer + income ────────────────────────────────────────────
  final JpEmployerInfo? employer;

  // ── Step 3: Guarantor + emergency contact ────────────────────────────────
  final JpContactPerson? guarantor;
  final JpContactPerson? emergencyContact;

  // ── Step 4: Document uploads ─────────────────────────────────────────────
  final List<JpDocumentRef> documents;

  // ── Step 5 / metadata ────────────────────────────────────────────────────
  final String? message;
  final String? agentNote;
  final String? createdAt;
  final String? updatedAt;
  final String? listingTitle;
  final int? reviewedByAgentId;

  factory JpApplication.fromJson(Map<String, dynamic> json) {
    final docsRaw = json['documents'] as List<dynamic>? ?? [];
    return JpApplication(
      id: json['id'] as int,
      listingId: json['listing_id'] as int,
      tenantId: json['tenant_id'] as int,
      status: jpApplicationStatusFromString(json['status'] as String?),
      applicantName: json['applicant_name'] as String? ?? '',
      applicantPhone: json['applicant_phone'] as String? ?? '',
      applicantEmail: json['applicant_email'] as String? ?? '',
      employer: json['employer'] != null
          ? JpEmployerInfo.fromJson(json['employer'] as Map<String, dynamic>)
          : null,
      guarantor: json['guarantor'] != null
          ? JpContactPerson.fromJson(
              json['guarantor'] as Map<String, dynamic>)
          : null,
      emergencyContact: json['emergency_contact'] != null
          ? JpContactPerson.fromJson(
              json['emergency_contact'] as Map<String, dynamic>)
          : null,
      documents: docsRaw
          .map((e) => JpDocumentRef.fromJson(e as Map<String, dynamic>))
          .toList(),
      message: json['message'] as String?,
      agentNote: json['agent_note'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      listingTitle: json['listing_title'] as String?,
      reviewedByAgentId: json['reviewed_by_agent_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'listing_id': listingId,
        'tenant_id': tenantId,
        'status': jpApplicationStatusToString(status),
        'applicant_name': applicantName,
        'applicant_phone': applicantPhone,
        'applicant_email': applicantEmail,
        if (employer != null) 'employer': employer!.toJson(),
        if (guarantor != null) 'guarantor': guarantor!.toJson(),
        if (emergencyContact != null)
          'emergency_contact': emergencyContact!.toJson(),
        'documents': documents.map((d) => d.toJson()).toList(),
        if (message != null) 'message': message,
        if (agentNote != null) 'agent_note': agentNote,
        if (createdAt != null) 'created_at': createdAt,
        if (updatedAt != null) 'updated_at': updatedAt,
        if (listingTitle != null) 'listing_title': listingTitle,
        if (reviewedByAgentId != null)
          'reviewed_by_agent_id': reviewedByAgentId,
      };
}

/// Agent's review decision on an application.
class JpApplicationReview {
  const JpApplicationReview({
    required this.applicationId,
    required this.decision,
    this.note,
    this.reviewedAt,
  });

  final int applicationId;

  /// 'approved' | 'rejected'.
  final String decision;

  final String? note;
  final String? reviewedAt;

  factory JpApplicationReview.fromJson(Map<String, dynamic> json) {
    return JpApplicationReview(
      applicationId: json['application_id'] as int,
      decision: json['decision'] as String,
      note: json['note'] as String?,
      reviewedAt: json['reviewed_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'application_id': applicationId,
        'decision': decision,
        if (note != null) 'note': note,
        if (reviewedAt != null) 'reviewed_at': reviewedAt,
      };
}
