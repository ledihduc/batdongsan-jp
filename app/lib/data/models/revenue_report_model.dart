/// Revenue report response (Phase 06 G1 / v1 shim).
///
/// Extended in Phase 04 analytics with [gross], [net], [deltaPct],
/// [sourceBreakdown], and [commissionTotal] fields while preserving
/// backward compat for legacy report screens (v1 shim consumers).
class RevenueReportModel {
  final String period; // 'month' | 'year'
  final String date; // 'YYYY-MM' or 'YYYY'
  final double total;
  final Map<String, double> breakdown;
  final List<RevenueByBuilding> byBuilding;

  // --- Phase 04 analytics fields ---

  /// Gross revenue (sum of paid invoices in period).
  final double gross;

  /// Net revenue = gross − refund_total.
  final double net;

  /// Commission total (informational only, NOT subtracted from net).
  final double commissionTotal;

  /// Period-over-period gross revenue % change. Null when prior = 0 (AC-02).
  final double? deltaPct;

  /// Source breakdown items for the period.
  final List<SourceBreakdownItem> sourceBreakdown;

  const RevenueReportModel({
    required this.period,
    required this.date,
    required this.total,
    required this.breakdown,
    required this.byBuilding,
    this.gross = 0.0,
    this.net = 0.0,
    this.commissionTotal = 0.0,
    this.deltaPct,
    this.sourceBreakdown = const [],
  });

  factory RevenueReportModel.fromJson(Map<String, dynamic> json) {
    final raw = (json['breakdown'] as Map?) ?? const {};
    final breakdown = <String, double>{};
    raw.forEach((k, v) => breakdown[k.toString()] = (v as num).toDouble());

    final buildings = (json['by_building'] as List? ?? const [])
        .map(
          (e) =>
              RevenueByBuilding.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    final sources = (json['source_breakdown'] as List? ?? const [])
        .map(
          (e) =>
              SourceBreakdownItem.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    final total = (json['total'] as num? ?? 0).toDouble();
    // Support both v1 ('total') and v2 ('gross_revenue') backends
    final gross =
        (json['gross'] as num? ?? json['gross_revenue'] as num? ?? total)
            .toDouble();

    return RevenueReportModel(
      period: json['period'] as String? ?? 'month',
      date: json['date'] as String? ?? '',
      total: total,
      breakdown: breakdown,
      byBuilding: buildings,
      gross: gross,
      net: (json['net'] as num? ?? json['net_revenue'] as num? ?? gross)
          .toDouble(),
      commissionTotal: (json['commission_total'] as num? ?? 0).toDouble(),
      deltaPct: (json['delta_pct'] as num? ?? json['gross_revenue_pct'] as num?)
          ?.toDouble(),
      sourceBreakdown: sources,
    );
  }
}

class RevenueByBuilding {
  final int buildingId;
  final String buildingName;
  final double total;

  const RevenueByBuilding({
    required this.buildingId,
    required this.buildingName,
    required this.total,
  });

  factory RevenueByBuilding.fromJson(Map<String, dynamic> json) =>
      RevenueByBuilding(
        buildingId: json['building_id'] as int,
        buildingName: json['building_name'] as String? ?? '',
        total: (json['total'] as num? ?? 0).toDouble(),
      );
}

/// One entry in the source breakdown list for a period.
///
/// [sourceId] is null for the "Khác" (Other) overflow bucket.
class SourceBreakdownItem {
  final int? sourceId;
  final String sourceName;
  final String colorHex;
  final double amount;

  /// Percentage of total (0–100). May have minor float rounding from backend.
  final double pct;

  const SourceBreakdownItem({
    required this.sourceId,
    required this.sourceName,
    required this.colorHex,
    required this.amount,
    required this.pct,
  });

  factory SourceBreakdownItem.fromJson(Map<String, dynamic> json) {
    return SourceBreakdownItem(
      sourceId: json['source_id'] as int?,
      sourceName: json['source_name'] as String? ?? '',
      colorHex: json['color_hex'] as String? ?? '#9E9E9E',
      amount: (json['amount'] as num? ?? 0).toDouble(),
      pct: (json['pct'] as num? ?? 0).toDouble(),
    );
  }
}
