import 'package:house_booking/data/models/khai_bao_model.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Repository for /api/host/khai-bao endpoints (Phase 05).
class ApiKhaiBaoRepository {
  final ApiClient _client = const ApiClient();

  Future<List<KhaiBaoModel>> fetchList({
    String? status, // pending | declared | overdue | skipped
    int? buildingId,
  }) async {
    final query = <String, dynamic>{
      if (status != null) 'status': status,
      if (buildingId != null) 'building_id': buildingId,
    };
    final list = await _client.getList(
      '/api/host/khai-bao',
      queryParameters: query,
    );
    return list
        .map((e) => KhaiBaoModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<KhaiBaoModel> getDetail(int id) async {
    final resp = await _client.get('/api/host/khai-bao/$id');
    return KhaiBaoModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<KhaiBaoModel> markDeclared(int id, {DateTime? declaredAt}) async {
    final resp = await _client.patch(
      '/api/host/khai-bao/$id/declared',
      body: {
        if (declaredAt != null) 'declared_at': declaredAt.toIso8601String(),
      },
    );
    return KhaiBaoModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<KhaiBaoModel> markSkipped(int id, {required String reason}) async {
    final resp = await _client.patch(
      '/api/host/khai-bao/$id/skipped',
      body: {'reason': reason},
    );
    return KhaiBaoModel.fromJson(Map<String, dynamic>.from(resp));
  }

  Future<KhaiBaoDashboardSummary> fetchDashboardSummary() async {
    final resp = await _client.get('/api/host/khai-bao/dashboard-summary');
    return KhaiBaoDashboardSummary.fromJson(Map<String, dynamic>.from(resp));
  }
}
