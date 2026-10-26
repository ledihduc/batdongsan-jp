import 'package:house_booking/data/models/analytics_summary_model.dart';
import 'package:house_booking/data/models/heatmap_cell_model.dart';
import 'package:house_booking/data/models/revenue_source_model.dart';
import 'package:house_booking/data/models/source_breakdown_model.dart';
import 'package:house_booking/data/models/trend_bucket_model.dart';

/// Domain interface for all v2 analytics + source CRUD endpoints.
///
/// Consumers: ReportProvider (analytics), SourceManagementScreen (CRUD).
abstract class IAnalyticsRepository {
  // ---------------------------------------------------------------------------
  // Analytics read endpoints (5)
  // ---------------------------------------------------------------------------

  /// GET /api/host/analytics/summary?period=...&date=...
  Future<AnalyticsSummaryModel> fetchSummary({
    required String period, // 'month' | 'year'
    required String date, // 'YYYY-MM' | 'YYYY'
  });

  /// GET /api/host/analytics/revenue-trend?period=...&anchor=...
  Future<RevenueTrendModel> fetchTrend({
    required String period,
    required String anchor,
  });

  /// GET /api/host/analytics/occupancy-heatmap?month=...&building_id=...
  Future<OccupancyHeatmapModel> fetchHeatmap({
    required String month, // 'YYYY-MM'
    int? buildingId,
  });

  /// GET /api/host/analytics/source-breakdown?period=...&date=...
  Future<SourceBreakdownModel> fetchSourceBreakdown({
    required String period,
    required String date,
  });

  /// GET /api/host/analytics/drill-down?level=...&...
  ///
  /// Returns raw JSON map; caller decodes to the appropriate DrillPage type
  /// using RoomListResponse.fromJson / ContractByRoomResponse.fromJson etc.
  Future<Map<String, dynamic>> fetchDrillRaw({
    required String level, // 'room_list' | 'contracts_by_room' | 'tenants_by_contract' | 'invoices_by_tenant'
    Map<String, dynamic>? params,
  });

  // ---------------------------------------------------------------------------
  // Source CRUD endpoints (4)
  // ---------------------------------------------------------------------------

  /// GET /api/host/sources?include_archived=...
  Future<List<RevenueSourceModel>> fetchSources({
    bool includeArchived = false,
  });

  /// POST /api/host/sources body {name, color_hex}
  Future<RevenueSourceModel> createSource({
    required String name,
    required String colorHex,
  });

  /// PATCH /api/host/sources/{id} body {name?, color_hex?, archive?}
  Future<RevenueSourceModel> updateSource({
    required int id,
    String? name,
    String? colorHex,
    bool? archive,
  });

  /// DELETE /api/host/sources/{id}
  ///
  /// Throws [SourceInUseException] when backend returns 409 with
  /// {"detail": "source_in_use"}.
  Future<void> deleteSource(int id);
}

/// Thrown when attempting to delete a source that has associated invoices.
///
/// Phase 08 UI shows: "Đang được sử dụng, hãy lưu trữ thay vì xoá".
class SourceInUseException implements Exception {
  const SourceInUseException();

  @override
  String toString() =>
      'SourceInUseException: source has invoice data and cannot be deleted';
}
