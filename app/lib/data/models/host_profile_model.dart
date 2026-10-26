/// HostProfile data model — mirrors backend HostProfileResponse schema.
///
/// CCCD paths are never included in API responses.
/// Use [cccdFrontUploaded] / [cccdBackUploaded] booleans instead.
///
/// Phase 04 addition: [monthlyRevenueGoal] (AC-18).
class HostProfileModel {
  final int id;
  final int userId;
  final bool verified;
  final String? coverPath;
  final bool cccdFrontUploaded;
  final bool cccdBackUploaded;
  final String? bankAccountNumber;
  final String? bankName;
  final String? bankAccountHolder;
  final String? taxId;
  final double? avgResponseHours;
  final double? rating;
  final String? payoutSchedule;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Monthly revenue goal in VND. Null = not set.
  final double? monthlyRevenueGoal;

  const HostProfileModel({
    required this.id,
    required this.userId,
    required this.verified,
    this.coverPath,
    required this.cccdFrontUploaded,
    required this.cccdBackUploaded,
    this.bankAccountNumber,
    this.bankName,
    this.bankAccountHolder,
    this.taxId,
    this.avgResponseHours,
    this.rating,
    this.payoutSchedule,
    required this.createdAt,
    required this.updatedAt,
    this.monthlyRevenueGoal,
  });

  factory HostProfileModel.fromJson(Map<String, dynamic> json) {
    return HostProfileModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      verified: json['verified'] as bool? ?? false,
      coverPath: json['cover_path'] as String?,
      cccdFrontUploaded: json['cccd_front_uploaded'] as bool? ?? false,
      cccdBackUploaded: json['cccd_back_uploaded'] as bool? ?? false,
      bankAccountNumber: json['bank_account_number'] as String?,
      bankName: json['bank_name'] as String?,
      bankAccountHolder: json['bank_account_holder'] as String?,
      taxId: json['tax_id'] as String?,
      avgResponseHours: (json['avg_response_hours'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble(),
      payoutSchedule: json['payout_schedule'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      monthlyRevenueGoal: (json['monthly_revenue_goal'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'verified': verified,
    'cover_path': coverPath,
    'cccd_front_uploaded': cccdFrontUploaded,
    'cccd_back_uploaded': cccdBackUploaded,
    'bank_account_number': bankAccountNumber,
    'bank_name': bankName,
    'bank_account_holder': bankAccountHolder,
    'tax_id': taxId,
    'avg_response_hours': avgResponseHours,
    'rating': rating,
    'payout_schedule': payoutSchedule,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'monthly_revenue_goal': monthlyRevenueGoal,
  };

  HostProfileModel copyWith({
    bool? verified,
    String? coverPath,
    bool? cccdFrontUploaded,
    bool? cccdBackUploaded,
    String? bankAccountNumber,
    String? bankName,
    String? bankAccountHolder,
    String? taxId,
    double? avgResponseHours,
    double? rating,
    String? payoutSchedule,
    double? monthlyRevenueGoal,
    bool clearMonthlyGoal = false,
  }) {
    return HostProfileModel(
      id: id,
      userId: userId,
      verified: verified ?? this.verified,
      coverPath: coverPath ?? this.coverPath,
      cccdFrontUploaded: cccdFrontUploaded ?? this.cccdFrontUploaded,
      cccdBackUploaded: cccdBackUploaded ?? this.cccdBackUploaded,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankName: bankName ?? this.bankName,
      bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
      taxId: taxId ?? this.taxId,
      avgResponseHours: avgResponseHours ?? this.avgResponseHours,
      rating: rating ?? this.rating,
      payoutSchedule: payoutSchedule ?? this.payoutSchedule,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      monthlyRevenueGoal: clearMonthlyGoal
          ? null
          : (monthlyRevenueGoal ?? this.monthlyRevenueGoal),
    );
  }

  /// True when all onboarding steps are complete.
  bool get isOnboardingComplete =>
      cccdFrontUploaded &&
      cccdBackUploaded &&
      bankAccountNumber != null &&
      bankName != null;
}
