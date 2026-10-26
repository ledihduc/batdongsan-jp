import 'package:house_booking/data/models/analytics_summary_model.dart';
import 'package:house_booking/data/models/heatmap_cell_model.dart';
import 'package:house_booking/data/models/revenue_source_model.dart';
import 'package:house_booking/data/models/source_breakdown_model.dart';
import 'package:house_booking/data/models/trend_bucket_model.dart';

/// Cache key tuple: identifies a specific metric + period + date combination.
class _CacheKey {
  final String metric;
  final String period;
  final String date;

  const _CacheKey(this.metric, this.period, this.date);

  @override
  bool operator ==(Object other) =>
      other is _CacheKey &&
      metric == other.metric &&
      period == other.period &&
      date == other.date;

  @override
  int get hashCode => Object.hash(metric, period, date);
}

/// Holds all analytics state for ReportProvider extension.
///
/// Extracted to keep ReportProvider under 200 LOC.
class AnalyticsCache {
  static const Duration defaultMaxAge = Duration(minutes: 5);

  // --- Data ---
  AnalyticsSummaryModel? summary;
  RevenueTrendModel? trend;
  OccupancyHeatmapModel? heatmap;
  List<RevenueSourceModel>? sources;
  SourceBreakdownModel? sourceBreakdown;

  // --- Per-metric loading flags ---
  bool summaryLoading = false;
  bool trendLoading = false;
  bool heatmapLoading = false;
  bool sourcesLoading = false;
  bool sourceBreakdownLoading = false;

  // --- Per-metric error messages ---
  String? summaryError;
  String? trendError;
  String? heatmapError;
  String? sourcesError;
  String? sourceBreakdownError;

  // --- Last-fetch timestamps keyed by _CacheKey ---
  final Map<_CacheKey, DateTime> _fetchedAt = {};

  // --- Last-fetch cache key per metric (for eviction on param change) ---
  _CacheKey? _lastSummaryKey;
  _CacheKey? _lastTrendKey;
  _CacheKey? _lastHeatmapKey;
  _CacheKey? _lastSourcesKey;
  _CacheKey? _lastBreakdownKey;

  /// Returns true when data for [metric] fetched with [period]/[date] is still
  /// within [maxAge]. Returns false if never fetched, stale, or params changed.
  bool isFresh(
    String metric,
    String period,
    String date, {
    Duration maxAge = defaultMaxAge,
  }) {
    final key = _CacheKey(metric, period, date);
    final fetchedAt = _fetchedAt[key];
    if (fetchedAt == null) return false;
    return DateTime.now().difference(fetchedAt) < maxAge;
  }

  void markFetched(String metric, String period, String date) {
    final key = _CacheKey(metric, period, date);
    _fetchedAt[key] = DateTime.now();
    switch (metric) {
      case 'summary':
        if (_lastSummaryKey != null && _lastSummaryKey != key) {
          _fetchedAt.remove(_lastSummaryKey);
        }
        _lastSummaryKey = key;
      case 'trend':
        if (_lastTrendKey != null && _lastTrendKey != key) {
          _fetchedAt.remove(_lastTrendKey);
        }
        _lastTrendKey = key;
      case 'heatmap':
        if (_lastHeatmapKey != null && _lastHeatmapKey != key) {
          _fetchedAt.remove(_lastHeatmapKey);
        }
        _lastHeatmapKey = key;
      case 'sources':
        if (_lastSourcesKey != null && _lastSourcesKey != key) {
          _fetchedAt.remove(_lastSourcesKey);
        }
        _lastSourcesKey = key;
      case 'breakdown':
        if (_lastBreakdownKey != null && _lastBreakdownKey != key) {
          _fetchedAt.remove(_lastBreakdownKey);
        }
        _lastBreakdownKey = key;
    }
  }

  /// Evict sources cache so next fetchSources call goes to network.
  void invalidateSources() {
    sources = null;
    if (_lastSourcesKey != null) {
      _fetchedAt.remove(_lastSourcesKey);
      _lastSourcesKey = null;
    }
  }
}
