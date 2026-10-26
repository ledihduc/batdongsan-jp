import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:house_booking/core/lifecycle/user_scope_cleanup.dart';
import 'package:house_booking/data/models/analytics_summary_model.dart';
import 'package:house_booking/data/models/drill_node_model.dart';
import 'package:house_booking/data/models/heatmap_cell_model.dart';
import 'package:house_booking/data/models/occupancy_report_model.dart';
import 'package:house_booking/data/models/revenue_report_model.dart';
import 'package:house_booking/data/models/revenue_source_model.dart';
import 'package:house_booking/data/models/source_breakdown_model.dart';
import 'package:house_booking/data/models/trend_bucket_model.dart';
import 'package:house_booking/data/repositories/api_analytics_repository.dart';
import 'package:house_booking/data/repositories/api_report_repository.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/domain/repositories/i_analytics_repository.dart';
import 'package:house_booking/features/host/analytics/services/period_helper.dart';
import 'package:house_booking/providers/analytics_cache.dart';

/// Provider for Phase 06 reports — revenue, occupancy, CSV export.
/// Extended in Phase 04 with v2 analytics endpoints + 5-min cache.
class ReportProvider extends ChangeNotifier implements UserScoped {
  ReportProvider({
    ApiReportRepository? repo,
    IAnalyticsRepository? analyticsRepo,
  })  : _repo = repo ?? ApiReportRepository(),
        _analytics = analyticsRepo ?? ApiAnalyticsRepository();

  final ApiReportRepository _repo;
  final IAnalyticsRepository _analytics;
  final AnalyticsCache _cache = AnalyticsCache();

  // --- v1 state (legacy) ---
  RevenueReportModel? _revenue;
  OccupancyReportModel? _occupancy;
  bool _isLoading = false;
  String? _error;

  RevenueReportModel? get revenue => _revenue;
  OccupancyReportModel? get occupancy => _occupancy;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // --- v2 analytics state (delegated to AnalyticsCache) ---
  AnalyticsSummaryModel? get summary => _cache.summary;
  RevenueTrendModel? get trend => _cache.trend;
  OccupancyHeatmapModel? get heatmap => _cache.heatmap;
  List<RevenueSourceModel>? get sources => _cache.sources;
  SourceBreakdownModel? get sourceBreakdown => _cache.sourceBreakdown;

  bool get summaryLoading => _cache.summaryLoading;
  bool get trendLoading => _cache.trendLoading;
  bool get heatmapLoading => _cache.heatmapLoading;
  bool get sourcesLoading => _cache.sourcesLoading;
  bool get sourceBreakdownLoading => _cache.sourceBreakdownLoading;

  String? get summaryError => _cache.summaryError;
  String? get trendError => _cache.trendError;
  String? get heatmapError => _cache.heatmapError;
  String? get sourcesError => _cache.sourcesError;
  String? get sourceBreakdownError => _cache.sourceBreakdownError;

  // --- offline / stale-cache state (Phase 10) ---
  bool _offline = false;
  DateTime? _lastSuccessfulFetchAt;

  /// True when the last analytics fetch failed with a network error.
  /// Cached data (if any) remains visible behind the [OfflineBadge].
  bool get offline => _offline;

  /// Timestamp of the last fetch that completed without a network error.
  /// Used to compute cache staleness for [StaleCacheBadge].
  DateTime? get lastSuccessfulFetchAt => _lastSuccessfulFetchAt;

  @override
  void resetUserScope() {
    _revenue = null;
    _occupancy = null;
    _isLoading = false;
    _error = null;
    _offline = false;
    _lastSuccessfulFetchAt = null;
    // Reset delegated analytics cache.
    _cache.summary = null;
    _cache.trend = null;
    _cache.heatmap = null;
    _cache.sources = null;
    _cache.sourceBreakdown = null;
    _cache.summaryLoading = false;
    _cache.trendLoading = false;
    _cache.heatmapLoading = false;
    _cache.sourcesLoading = false;
    _cache.sourceBreakdownLoading = false;
    _cache.summaryError = null;
    _cache.trendError = null;
    _cache.heatmapError = null;
    _cache.sourcesError = null;
    _cache.sourceBreakdownError = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Offline guard helper (Phase 09 Fix #4)
  // ---------------------------------------------------------------------------

  /// Runs [body] and handles [SocketException] / [TimeoutException] by setting
  /// [_offline] = true and returning null so callers can preserve cached data.
  ///
  /// On success, resets [_offline] to false and updates [_lastSuccessfulFetchAt].
  /// Non-network exceptions are rethrown unchanged so callers handle them.
  Future<T?> _runWithOfflineGuard<T>(Future<T> Function() body) async {
    try {
      final result = await body();
      _offline = false;
      _lastSuccessfulFetchAt = DateTime.now();
      return result;
    } on SocketException {
      _offline = true;
      notifyListeners();
      return null;
    } on TimeoutException {
      _offline = true;
      notifyListeners();
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Cache freshness helper (AC-01)
  // ---------------------------------------------------------------------------

  /// Returns true when [metric] data is still fresh for [period]/[date].
  ///
  /// [maxAge] defaults to 5 minutes per AC-01.
  bool isFresh(
    String metric,
    String period,
    String date, {
    Duration maxAge = const Duration(minutes: 5),
  }) =>
      _cache.isFresh(metric, period, date, maxAge: maxAge);

  // ---------------------------------------------------------------------------
  // v1 legacy methods
  // ---------------------------------------------------------------------------

  Future<void> fetchRevenue({
    required String period,
    required String date,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _revenue = await _repo.fetchRevenue(period: period, date: date);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchOccupancy({
    required String month,
    int? buildingId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _occupancy = await _repo.fetchOccupancy(
        month: month,
        buildingId: buildingId,
      );
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns raw CSV bytes (UTF-8). Caller saves/shares the result.
  Future<List<int>?> downloadInvoicesCsv({required String month}) async {
    try {
      _error = null;
      return await _repo.exportInvoicesCsv(month: month);
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // v2 analytics fetch methods
  // ---------------------------------------------------------------------------

  Future<void> fetchAnalyticsSummary({
    required PeriodType period,
    required DateTime date,
    bool force = false,
  }) async {
    final periodStr = period == PeriodType.month ? 'month' : 'year';
    final dateStr = PeriodHelper.formatPeriodKey(period, date);

    if (!force && isFresh('summary', periodStr, dateStr)) return;

    _cache.summaryLoading = true;
    _cache.summaryError = null;
    notifyListeners();

    try {
      final result = await _runWithOfflineGuard(
        () => _analytics.fetchSummary(period: periodStr, date: dateStr),
      );
      if (result != null) {
        _cache.summary = result;
        _cache.markFetched('summary', periodStr, dateStr);
      }
      if (_offline) return;
    } on ApiException catch (e) {
      _cache.summaryError = e.message;
    } finally {
      _cache.summaryLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchTrend({
    required PeriodType period,
    required DateTime anchor,
    bool force = false,
  }) async {
    final periodStr = period == PeriodType.month ? 'month' : 'year';
    final anchorStr = PeriodHelper.formatPeriodKey(period, anchor);

    if (!force && isFresh('trend', periodStr, anchorStr)) return;

    _cache.trendLoading = true;
    _cache.trendError = null;
    notifyListeners();

    try {
      final result = await _runWithOfflineGuard(
        () => _analytics.fetchTrend(period: periodStr, anchor: anchorStr),
      );
      if (result != null) {
        _cache.trend = result;
        _cache.markFetched('trend', periodStr, anchorStr);
      }
      if (_offline) return;
    } on ApiException catch (e) {
      _cache.trendError = e.message;
    } finally {
      _cache.trendLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchHeatmap({
    required DateTime month,
    int? buildingId,
    bool force = false,
  }) async {
    final monthStr = PeriodHelper.formatPeriodKey(PeriodType.month, month);
    final buildingKey = buildingId?.toString() ?? '';

    if (!force && isFresh('heatmap', monthStr, buildingKey)) return;

    _cache.heatmapLoading = true;
    _cache.heatmapError = null;
    notifyListeners();

    try {
      final result = await _runWithOfflineGuard(
        () => _analytics.fetchHeatmap(month: monthStr, buildingId: buildingId),
      );
      if (result != null) {
        _cache.heatmap = result;
        _cache.markFetched('heatmap', monthStr, buildingKey);
      }
      if (_offline) return;
    } on ApiException catch (e) {
      _cache.heatmapError = e.message;
    } finally {
      _cache.heatmapLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSources({
    bool includeArchived = false,
    bool force = false,
  }) async {
    final key = includeArchived ? 'all' : 'active';
    if (!force && isFresh('sources', key, '')) return;

    _cache.sourcesLoading = true;
    _cache.sourcesError = null;
    notifyListeners();

    try {
      final result = await _runWithOfflineGuard(
        () => _analytics.fetchSources(includeArchived: includeArchived),
      );
      if (result != null) {
        _cache.sources = result;
        _cache.markFetched('sources', key, '');
      }
      if (_offline) return;
    } on ApiException catch (e) {
      _cache.sourcesError = e.message;
    } finally {
      _cache.sourcesLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSourceBreakdown({
    required PeriodType period,
    required DateTime date,
    bool force = false,
  }) async {
    final periodStr = period == PeriodType.month ? 'month' : 'year';
    final dateStr = PeriodHelper.formatPeriodKey(period, date);

    if (!force && isFresh('breakdown', periodStr, dateStr)) return;

    _cache.sourceBreakdownLoading = true;
    _cache.sourceBreakdownError = null;
    notifyListeners();

    try {
      final result = await _runWithOfflineGuard(
        () => _analytics.fetchSourceBreakdown(period: periodStr, date: dateStr),
      );
      if (result != null) {
        _cache.sourceBreakdown = result;
        _cache.markFetched('breakdown', periodStr, dateStr);
      }
      if (_offline) return;
    } on ApiException catch (e) {
      _cache.sourceBreakdownError = e.message;
    } finally {
      _cache.sourceBreakdownLoading = false;
      notifyListeners();
    }
  }

  /// Drill-down is paginated user navigation — NOT cached.
  /// Caller decodes the returned map using the appropriate DrillPage factory.
  Future<RoomListResponse> fetchDrillRooms({
    int? buildingId,
    int page = 1,
    int pageSize = 50,
  }) async {
    final raw = await _analytics.fetchDrillRaw(
      level: 'room_list',
      params: {
        'page': page,
        'page_size': pageSize,
        'building_id': buildingId,
      },
    );
    return RoomListResponse.fromJson(raw);
  }

  Future<ContractByRoomResponse> fetchDrillContracts({
    required int roomId,
    int page = 1,
    int pageSize = 50,
  }) async {
    final raw = await _analytics.fetchDrillRaw(
      level: 'contracts_by_room',
      params: {'room_id': roomId, 'page': page, 'page_size': pageSize},
    );
    return ContractByRoomResponse.fromJson(raw);
  }

  Future<TenantByContractResponse> fetchDrillTenants({
    required int contractId,
    int page = 1,
    int pageSize = 50,
  }) async {
    final raw = await _analytics.fetchDrillRaw(
      level: 'tenants_by_contract',
      params: {'contract_id': contractId, 'page': page, 'page_size': pageSize},
    );
    return TenantByContractResponse.fromJson(raw);
  }

  Future<InvoiceByTenantResponse> fetchDrillInvoices({
    required int tenantId,
    int page = 1,
    int pageSize = 50,
  }) async {
    final raw = await _analytics.fetchDrillRaw(
      level: 'invoices_by_tenant',
      params: {'tenant_id': tenantId, 'page': page, 'page_size': pageSize},
    );
    return InvoiceByTenantResponse.fromJson(raw);
  }

  // ---------------------------------------------------------------------------
  // Source CRUD
  // ---------------------------------------------------------------------------

  /// Create a new source. Invalidates sources cache on success.
  Future<void> createSource({
    required String name,
    required String colorHex,
  }) async {
    await _analytics.createSource(name: name, colorHex: colorHex);
    _cache.invalidateSources();
    notifyListeners();
  }

  /// Update an existing source. Invalidates sources cache on success.
  Future<void> updateSource({
    required int id,
    String? name,
    String? colorHex,
  }) async {
    await _analytics.updateSource(id: id, name: name, colorHex: colorHex);
    _cache.invalidateSources();
    notifyListeners();
  }

  /// Archive a source (soft delete). Invalidates sources cache on success.
  Future<void> archiveSource(int id) async {
    await _analytics.updateSource(id: id, archive: true);
    _cache.invalidateSources();
    notifyListeners();
  }

  /// Hard delete a source.
  ///
  /// Throws [SourceInUseException] (409) when source has invoice data.
  /// Caller (Phase 08 UI) should catch and show:
  /// "Đang được sử dụng, hãy lưu trữ thay vì xoá".
  Future<void> deleteSource(int id) async {
    await _analytics.deleteSource(id); // may throw SourceInUseException
    _cache.invalidateSources();
    notifyListeners();
  }

  /// Optimistic UI helper for [SourceManagementScreen].
  ///
  /// Replaces the in-memory sources list without invalidating the cache key,
  /// so the screen reflects an immediate change. The caller is responsible for
  /// either re-fetching (success) or reverting with the original snapshot
  /// (error).
  void patchSourcesOptimistic(List<RevenueSourceModel> updated) {
    _cache.sources = updated;
    notifyListeners();
  }
}
