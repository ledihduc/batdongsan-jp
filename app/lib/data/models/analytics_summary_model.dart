/// Analytics summary model — mirrors GET /api/host/analytics/summary response.
///
/// JSON contract frozen in _analytics_shapes.md §1.
class AnalyticsSummaryModel {
  final PeriodInfo period;
  final KpiBlock kpis;
  final DeltaBlock deltas;

  const AnalyticsSummaryModel({
    required this.period,
    required this.kpis,
    required this.deltas,
  });

  factory AnalyticsSummaryModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummaryModel(
      period: PeriodInfo.fromJson(
        Map<String, dynamic>.from(json['period'] as Map),
      ),
      kpis: KpiBlock.fromJson(Map<String, dynamic>.from(json['kpis'] as Map)),
      deltas: DeltaBlock.fromJson(
        Map<String, dynamic>.from(json['deltas'] as Map? ?? const {}),
      ),
    );
  }
}

/// Period metadata returned alongside analytics responses.
class PeriodInfo {
  /// "month" or "year"
  final String type;

  /// HCM-scoped period key: "YYYY-MM" or "YYYY" — use directly for display.
  final String date;

  /// UTC start boundary (inclusive). Only use for raw timestamp math.
  final DateTime startUtc;

  /// UTC end boundary (exclusive). Only use for raw timestamp math.
  final DateTime endUtc;

  const PeriodInfo({
    required this.type,
    required this.date,
    required this.startUtc,
    required this.endUtc,
  });

  factory PeriodInfo.fromJson(Map<String, dynamic> json) {
    return PeriodInfo(
      type: json['type'] as String? ?? 'month',
      date: json['date'] as String? ?? '',
      startUtc: DateTime.parse(json['start_utc'] as String),
      endUtc: DateTime.parse(json['end_utc'] as String),
    );
  }
}

/// KPI metrics block.
///
/// [commissionTotal] is informational only — NOT subtracted from [netRevenue].
class KpiBlock {
  final double grossRevenue;
  final double netRevenue;
  final double refundTotal;
  final double commissionTotal;

  /// 0–100 float representing occupancy percentage.
  final double occupancyPct;

  /// Average Daily Rate (for homestay reservations).
  final double adr;

  /// Count of reservations created in the period.
  final int bookingPace;

  const KpiBlock({
    required this.grossRevenue,
    required this.netRevenue,
    required this.refundTotal,
    required this.commissionTotal,
    required this.occupancyPct,
    required this.adr,
    required this.bookingPace,
  });

  factory KpiBlock.fromJson(Map<String, dynamic> json) {
    return KpiBlock(
      grossRevenue: (json['gross_revenue'] as num? ?? 0).toDouble(),
      netRevenue: (json['net_revenue'] as num? ?? 0).toDouble(),
      refundTotal: (json['refund_total'] as num? ?? 0).toDouble(),
      commissionTotal: (json['commission_total'] as num? ?? 0).toDouble(),
      occupancyPct: (json['occupancy_pct'] as num? ?? 0).toDouble(),
      adr: (json['adr'] as num? ?? 0).toDouble(),
      bookingPace: (json['booking_pace'] as num? ?? 0).toInt(),
    );
  }
}

/// Period-over-period delta metrics.
///
/// All fields are nullable: null means prior period had zero revenue
/// (AC-02 — never divide by zero).
class DeltaBlock {
  /// Gross revenue % change vs prior period. Null when prior = 0.
  final double? grossRevenuePct;

  /// Net revenue % change vs prior period. Null when prior = 0.
  final double? netRevenuePct;

  /// Absolute percentage-point difference in occupancy (not %).
  final double? occupancyPctDiff;

  const DeltaBlock({
    this.grossRevenuePct,
    this.netRevenuePct,
    this.occupancyPctDiff,
  });

  factory DeltaBlock.fromJson(Map<String, dynamic> json) {
    return DeltaBlock(
      grossRevenuePct: (json['gross_revenue_pct'] as num?)?.toDouble(),
      netRevenuePct: (json['net_revenue_pct'] as num?)?.toDouble(),
      occupancyPctDiff: (json['occupancy_pct_diff'] as num?)?.toDouble(),
    );
  }
}
