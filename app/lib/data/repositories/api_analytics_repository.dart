import 'package:house_booking/data/models/analytics_summary_model.dart';
import 'package:house_booking/data/models/heatmap_cell_model.dart';
import 'package:house_booking/data/models/revenue_source_model.dart';
import 'package:house_booking/data/models/source_breakdown_model.dart';
import 'package:house_booking/data/models/trend_bucket_model.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/domain/repositories/i_analytics_repository.dart';

/// v2 analytics + source CRUD repository — mirrors api_report_repository.dart style.
///
/// Constructor accepts optional [ApiClient] for testing.
/// Calls the 9 endpoints specified in Phase 03 / schema freeze doc.
class ApiAnalyticsRepository implements IAnalyticsRepository {
  final ApiClient _client;

  ApiAnalyticsRepository({ApiClient? client})
    : _client = client ?? const ApiClient();

  // ---------------------------------------------------------------------------
  // Analytics — read
  // ---------------------------------------------------------------------------

  @override
  Future<AnalyticsSummaryModel> fetchSummary({
    required String period,
    required String date,
  }) async {
    final resp = await _client.get(
      '/api/host/analytics/summary',
      queryParameters: {'period': period, 'date': date},
    );
    return AnalyticsSummaryModel.fromJson(Map<String, dynamic>.from(resp));
  }

  @override
  Future<RevenueTrendModel> fetchTrend({
    required String period,
    required String anchor,
  }) async {
    final resp = await _client.get(
      '/api/host/analytics/revenue-trend',
      queryParameters: {'period': period, 'anchor': anchor},
    );
    return RevenueTrendModel.fromJson(Map<String, dynamic>.from(resp));
  }

  @override
  Future<OccupancyHeatmapModel> fetchHeatmap({
    required String month,
    int? buildingId,
  }) async {
    final resp = await _client.get(
      '/api/host/analytics/occupancy-heatmap',
      queryParameters: {'month': month, 'building_id': buildingId},
    );
    return OccupancyHeatmapModel.fromJson(Map<String, dynamic>.from(resp));
  }

  @override
  Future<SourceBreakdownModel> fetchSourceBreakdown({
    required String period,
    required String date,
  }) async {
    final resp = await _client.get(
      '/api/host/analytics/source-breakdown',
      queryParameters: {'period': period, 'date': date},
    );
    return SourceBreakdownModel.fromJson(Map<String, dynamic>.from(resp));
  }

  @override
  Future<Map<String, dynamic>> fetchDrillRaw({
    required String level,
    Map<String, dynamic>? params,
  }) async {
    final query = <String, dynamic>{'level': level};
    if (params != null) query.addAll(params);
    final resp = await _client.get(
      '/api/host/analytics/drill-down',
      queryParameters: query,
    );
    return Map<String, dynamic>.from(resp);
  }

  // ---------------------------------------------------------------------------
  // Source CRUD
  // ---------------------------------------------------------------------------

  @override
  Future<List<RevenueSourceModel>> fetchSources({
    bool includeArchived = false,
  }) async {
    final list = await _client.getList(
      '/api/host/sources',
      queryParameters: {if (includeArchived) 'include_archived': true},
    );
    return list
        .map(
          (e) =>
              RevenueSourceModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  @override
  Future<RevenueSourceModel> createSource({
    required String name,
    required String colorHex,
  }) async {
    final resp = await _client.post(
      '/api/host/sources',
      body: {'name': name, 'color_hex': colorHex},
    );
    return RevenueSourceModel.fromJson(Map<String, dynamic>.from(resp));
  }

  @override
  Future<RevenueSourceModel> updateSource({
    required int id,
    String? name,
    String? colorHex,
    bool? archive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (colorHex != null) body['color_hex'] = colorHex;
    if (archive != null) body['archive'] = archive;

    final resp = await _client.patch('/api/host/sources/$id', body: body);
    return RevenueSourceModel.fromJson(Map<String, dynamic>.from(resp));
  }

  @override
  Future<void> deleteSource(int id) async {
    try {
      await _client.delete('/api/host/sources/$id');
    } on ApiException catch (e) {
      // 409 = source_in_use: backend returns {"detail": "source_in_use"}
      if (e.statusCode == 409) throw const SourceInUseException();
      rethrow;
    }
  }
}
