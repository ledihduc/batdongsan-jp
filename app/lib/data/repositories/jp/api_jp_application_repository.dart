/// Real implementation of [IJpApplicationRepository] hitting `/api/jp/applications`.
library;

import 'package:house_booking/data/models/jp/jp_application.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_application_repository.dart';

class ApiJpApplicationRepository implements IJpApplicationRepository {
  const ApiJpApplicationRepository({ApiClient? client})
      : _client = client ?? const ApiClient();

  final ApiClient _client;

  @override
  Future<JpApplication> getById(int applicationId) async {
    final response =
        await _client.get('/api/jp/applications/$applicationId');
    return JpApplication.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<List<JpApplication>> listForTenant(int tenantId) async {
    final response = await _client.get(
      '/api/jp/applications',
      queryParameters: {'tenant_id': tenantId.toString()},
    );
    final items = response['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => JpApplication.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<JpApplication>> listForAgent(int agentId) async {
    final response = await _client.get(
      '/api/jp/applications',
      queryParameters: {'agent_id': agentId.toString()},
    );
    final items = response['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => JpApplication.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<JpApplication> saveDraft(JpApplication application) async {
    final body = application.toJson();
    if (application.id == 0) {
      final response =
          await _client.post('/api/jp/applications', body: body);
      return JpApplication.fromJson(response as Map<String, dynamic>);
    }
    final response = await _client.patch(
      '/api/jp/applications/${application.id}',
      body: body,
    );
    return JpApplication.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<JpApplication> submit(int applicationId) async {
    final response = await _client.post(
      '/api/jp/applications/$applicationId/submit',
      body: {},
    );
    return JpApplication.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<JpApplicationReview> review(JpApplicationReview r) async {
    final response = await _client.post(
      '/api/jp/application-reviews',
      body: r.toJson(),
    );
    return JpApplicationReview.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<JpApplication> withdraw(int applicationId) async {
    final response = await _client.post(
      '/api/jp/applications/$applicationId/withdraw',
      body: {},
    );
    return JpApplication.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<Map<String, String>> requestUploadUrl({
    required int applicationId,
    required String documentType,
    required String filename,
  }) async {
    final response = await _client.post(
      '/api/jp/applications/$applicationId/upload-url',
      body: {
        'document_type': documentType,
        'filename': filename,
      },
    );
    return {
      'upload_url': response['upload_url'] as String,
      'storage_key': response['storage_key'] as String,
    };
  }
}
