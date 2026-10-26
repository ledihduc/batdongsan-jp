import 'package:house_booking/data/models/revenue_report_model.dart';

/// Source breakdown response — mirrors GET /api/host/analytics/source-breakdown.
///
/// JSON contract frozen in _analytics_shapes.md §4.
class SourceBreakdownModel {
  /// HCM-scoped period key: "YYYY-MM" or "YYYY".
  final String period;

  /// Total revenue across all sources.
  final double total;

  /// Items sorted by amount DESC. Max 8 named + 1 "Khác" bucket.
  final List<SourceBreakdownItem> items;

  const SourceBreakdownModel({
    required this.period,
    required this.total,
    required this.items,
  });

  factory SourceBreakdownModel.fromJson(Map<String, dynamic> json) {
    final itemList = (json['items'] as List? ?? const [])
        .map(
          (e) =>
              SourceBreakdownItem.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    return SourceBreakdownModel(
      period: json['period'] as String? ?? '',
      total: (json['total'] as num? ?? 0).toDouble(),
      items: itemList,
    );
  }
}
