/// JP rental money fields.
///
/// Maps 1:1 to the backend `JpRentalTerms` table. High legal risk — labels
/// must display in Japanese per spec §03. Do NOT store or display in any
/// generic price field.
library;

/// Immutable value object representing the chintai money matrix.
class JpRentalTerms {
  const JpRentalTerms({
    required this.id,
    required this.monthlyRent,
    this.managementFee,
    this.shikikin,
    this.shikikinMonths,
    this.reikin,
    this.reikinMonths,
    this.hoshoukin,
    this.hoshoukinMonths,
    this.koushinryo,
    this.koushinryoMonths,
    this.brokerageFeeRate,
    this.guaranteeCompanyFee,
    this.taxIncluded = false,
    this.kyouekihi,
  });

  final int id;

  /// 月額家賃 — monthly base rent in JPY (integer, no decimals).
  final int monthlyRent;

  /// 管理費 — common area management fee in JPY.
  final int? managementFee;

  /// 敷金 — security deposit in JPY (overrides [shikikinMonths] when present).
  final int? shikikin;

  /// Number of months of rent used to compute 敷金 (e.g. 2 = 2 months rent).
  final double? shikikinMonths;

  /// 礼金 — key money in JPY.
  final int? reikin;

  /// Number of months of rent used to compute 礼金.
  final double? reikinMonths;

  /// 保証金 — additional guarantee deposit in JPY.
  final int? hoshoukin;
  final double? hoshoukinMonths;

  /// 更新料 — lease renewal fee in JPY.
  final int? koushinryo;
  final double? koushinryoMonths;

  /// 仲介手数料率 — brokerage fee as a rate of one month's rent (typically 0.5–1.0).
  final double? brokerageFeeRate;

  /// 保証会社料 — guarantee company fee in JPY.
  final int? guaranteeCompanyFee;

  /// Whether 消費税 is included in the stated rent.
  final bool taxIncluded;

  /// 共益費 — common service charge in JPY (may overlap with [managementFee]).
  final int? kyouekihi;

  factory JpRentalTerms.fromJson(Map<String, dynamic> json) {
    return JpRentalTerms(
      id: json['id'] as int,
      monthlyRent: json['monthly_rent'] as int,
      managementFee: json['management_fee'] as int?,
      shikikin: json['shikikin'] as int?,
      shikikinMonths: (json['shikikin_months'] as num?)?.toDouble(),
      reikin: json['reikin'] as int?,
      reikinMonths: (json['reikin_months'] as num?)?.toDouble(),
      hoshoukin: json['hoshoukin'] as int?,
      hoshoukinMonths: (json['hoshoukin_months'] as num?)?.toDouble(),
      koushinryo: json['koushinryo'] as int?,
      koushinryoMonths: (json['koushinryo_months'] as num?)?.toDouble(),
      brokerageFeeRate: (json['brokerage_fee_rate'] as num?)?.toDouble(),
      guaranteeCompanyFee: json['guarantee_company_fee'] as int?,
      taxIncluded: json['tax_included'] as bool? ?? false,
      kyouekihi: json['kyouekihi'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'monthly_rent': monthlyRent,
        if (managementFee != null) 'management_fee': managementFee,
        if (shikikin != null) 'shikikin': shikikin,
        if (shikikinMonths != null) 'shikikin_months': shikikinMonths,
        if (reikin != null) 'reikin': reikin,
        if (reikinMonths != null) 'reikin_months': reikinMonths,
        if (hoshoukin != null) 'hoshoukin': hoshoukin,
        if (hoshoukinMonths != null) 'hoshoukin_months': hoshoukinMonths,
        if (koushinryo != null) 'koushinryo': koushinryo,
        if (koushinryoMonths != null) 'koushinryo_months': koushinryoMonths,
        if (brokerageFeeRate != null) 'brokerage_fee_rate': brokerageFeeRate,
        if (guaranteeCompanyFee != null)
          'guarantee_company_fee': guaranteeCompanyFee,
        'tax_included': taxIncluded,
        if (kyouekihi != null) 'kyouekihi': kyouekihi,
      };

  JpRentalTerms copyWith({
    int? monthlyRent,
    int? managementFee,
    int? shikikin,
    double? shikikinMonths,
    int? reikin,
    double? reikinMonths,
    int? hoshoukin,
    double? hoshoukinMonths,
    int? koushinryo,
    double? koushinryoMonths,
    double? brokerageFeeRate,
    int? guaranteeCompanyFee,
    bool? taxIncluded,
    int? kyouekihi,
  }) {
    return JpRentalTerms(
      id: id,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      managementFee: managementFee ?? this.managementFee,
      shikikin: shikikin ?? this.shikikin,
      shikikinMonths: shikikinMonths ?? this.shikikinMonths,
      reikin: reikin ?? this.reikin,
      reikinMonths: reikinMonths ?? this.reikinMonths,
      hoshoukin: hoshoukin ?? this.hoshoukin,
      hoshoukinMonths: hoshoukinMonths ?? this.hoshoukinMonths,
      koushinryo: koushinryo ?? this.koushinryo,
      koushinryoMonths: koushinryoMonths ?? this.koushinryoMonths,
      brokerageFeeRate: brokerageFeeRate ?? this.brokerageFeeRate,
      guaranteeCompanyFee: guaranteeCompanyFee ?? this.guaranteeCompanyFee,
      taxIncluded: taxIncluded ?? this.taxIncluded,
      kyouekihi: kyouekihi ?? this.kyouekihi,
    );
  }
}
