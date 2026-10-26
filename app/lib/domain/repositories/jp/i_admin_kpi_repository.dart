/// Interface for JP admin KPI data.
///
/// Backend endpoint: GET /api/jp/admin/kpi?prefecture=&from=&to=
library;

import 'package:house_booking/data/models/jp/admin_kpi.dart';

abstract interface class IAdminKpiRepository {
  /// Fetch aggregated KPI for [prefecture] and date range.
  ///
  /// [prefecture] — JIS prefecture code or empty string for all-Japan.
  /// [from] / [to] — inclusive date boundaries (UTC midnight).
  Future<JpAdminKpi> getKpi({
    required String prefecture,
    required DateTime from,
    required DateTime to,
  });
}
