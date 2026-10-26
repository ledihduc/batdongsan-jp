/// Model for JP admin KPI dashboard data.
///
/// 5 KPI cards: active listings, pending applications,
/// active contracts, avg days to sign, monthly revenue.
library;

/// A single KPI metric with current value and period-over-period delta.
class KpiMetric {
  const KpiMetric({
    required this.value,
    this.unit,
    this.delta,
    this.deltaPositive,
    this.subtitle,
  });

  final String value;
  final String? unit;
  // e.g. "+12%" or "-3"
  final String? delta;
  // null means neutral (no color change)
  final bool? deltaPositive;
  final String? subtitle;

  factory KpiMetric.fromJson(Map<String, dynamic> json) => KpiMetric(
        value: json['value'] as String,
        unit: json['unit'] as String?,
        delta: json['delta'] as String?,
        deltaPositive: json['delta_positive'] as bool?,
        subtitle: json['subtitle'] as String?,
      );
}

/// Aggregate JP KPI payload for a prefecture + date range.
class JpAdminKpi {
  const JpAdminKpi({
    required this.activeListings,
    required this.pendingApplications,
    required this.activeContracts,
    required this.avgDaysToSign,
    required this.monthlyRevenueYen,
    required this.prefecture,
    required this.periodLabel,
  });

  final KpiMetric activeListings;
  final KpiMetric pendingApplications;
  final KpiMetric activeContracts;
  final KpiMetric avgDaysToSign;
  final KpiMetric monthlyRevenueYen;
  final String prefecture;
  final String periodLabel;

  factory JpAdminKpi.fromJson(Map<String, dynamic> json) => JpAdminKpi(
        activeListings: KpiMetric.fromJson(
            json['active_listings'] as Map<String, dynamic>),
        pendingApplications: KpiMetric.fromJson(
            json['pending_applications'] as Map<String, dynamic>),
        activeContracts: KpiMetric.fromJson(
            json['active_contracts'] as Map<String, dynamic>),
        avgDaysToSign: KpiMetric.fromJson(
            json['avg_days_to_sign'] as Map<String, dynamic>),
        monthlyRevenueYen: KpiMetric.fromJson(
            json['monthly_revenue_yen'] as Map<String, dynamic>),
        prefecture: json['prefecture'] as String,
        periodLabel: json['period_label'] as String,
      );
}
