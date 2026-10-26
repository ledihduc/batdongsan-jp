// DEPRECATED — to be removed post launch.
// Active caller: lib/providers/report_provider.dart (_repo field — v1 legacy).
// Replacement: ApiAnalyticsRepository (v2 endpoints).
// Sunset: after report_provider.dart migrates fully to v2 analytics.
import 'package:house_booking/data/models/occupancy_report_model.dart';
import 'package:house_booking/data/models/revenue_report_model.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Repository for /api/host/reports endpoints (Phase 06).
class ApiReportRepository {
  final ApiClient _client = const ApiClient();

  Future<RevenueReportModel> fetchRevenue({
    required String period, // 'month' | 'year'
    required String date, // 'YYYY-MM' or 'YYYY'
  }) async {
    final resp = await _client.get(
      '/api/host/reports/revenue',
      queryParameters: {'period': period, 'date': date},
    );
    return RevenueReportModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<OccupancyReportModel> fetchOccupancy({
    required String month,
    int? buildingId,
  }) async {
    final resp = await _client.get(
      '/api/host/reports/occupancy',
      queryParameters: {
        'month': month,
        if (buildingId != null) 'building_id': buildingId,
      },
    );
    return OccupancyReportModel.fromJson(Map<String, dynamic>.from(resp));
  }

  /// Returns raw CSV bytes for the given month (UTF-8 encoded).
  Future<List<int>> exportInvoicesCsv({required String month}) async {
    return _client.getBytes(
      '/api/host/reports/export',
      queryParameters: {'type': 'invoices', 'month': month},
    );
  }
}
