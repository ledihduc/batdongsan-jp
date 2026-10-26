/// Real implementation of [IAdminKpiRepository] hitting `/api/jp/admin/kpi`.
library;

import 'package:house_booking/data/models/jp/admin_kpi.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/domain/repositories/jp/i_admin_kpi_repository.dart';

class AdminKpiRepository implements IAdminKpiRepository {
  const AdminKpiRepository({ApiClient? client})
      : _client = client ?? const ApiClient();

  final ApiClient _client;

  @override
  Future<JpAdminKpi> getKpi({
    required String prefecture,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _client.get(
      '/api/jp/admin/kpi',
      queryParameters: {
        if (prefecture.isNotEmpty) 'prefecture': prefecture,
        'from': from.toIso8601String().split('T').first,
        'to': to.toIso8601String().split('T').first,
      },
    );
    return JpAdminKpi.fromJson(response);
  }
}
