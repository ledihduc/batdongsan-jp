/// Real implementation of [IJpViewingRepository] hitting `/api/jp/viewings`.
library;

import 'package:house_booking/data/models/jp/jp_viewing.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_viewing_repository.dart';

class ApiJpViewingRepository implements IJpViewingRepository {
  const ApiJpViewingRepository({ApiClient? client})
      : _client = client ?? const ApiClient();

  final ApiClient _client;

  @override
  Future<JpViewing> create({
    required int listingId,
    required List<JpViewingSlot> proposedSlots,
    String? message,
  }) async {
    final body = <String, dynamic>{
      'listing_id': listingId,
      'proposed_slots': proposedSlots.map((s) => s.toJson()).toList(),
      if (message != null) 'message': message,
    };
    final response = await _client.post('/api/jp/viewings', body: body);
    return JpViewing.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<JpViewing> getById(int viewingId) async {
    final response = await _client.get('/api/jp/viewings/$viewingId');
    return JpViewing.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<List<JpViewing>> listForTenant(int tenantId) async {
    final response = await _client.get(
      '/api/jp/viewings',
      queryParameters: {'tenant_id': tenantId.toString()},
    );
    final items = response['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => JpViewing.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<JpViewing>> listForAgent(int agentId) async {
    final response = await _client.get(
      '/api/jp/viewings',
      queryParameters: {'agent_id': agentId.toString()},
    );
    final items = response['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => JpViewing.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<JpViewing> confirmSlot({
    required int viewingId,
    required JpViewingSlot slot,
  }) async {
    final response = await _client.post(
      '/api/jp/viewings/$viewingId/confirm',
      body: {'confirmed_slot': slot.toJson()},
    );
    return JpViewing.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<JpViewing> cancel(int viewingId) async {
    final response = await _client.post(
      '/api/jp/viewings/$viewingId/cancel',
      body: {},
    );
    return JpViewing.fromJson(response as Map<String, dynamic>);
  }
}
