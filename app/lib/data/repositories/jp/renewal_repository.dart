/// Real implementation of [IRenewalRepository] hitting `/api/jp/renewals`.
library;

import 'package:house_booking/data/models/jp/renewal.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/domain/repositories/jp/i_renewal_repository.dart';

class RenewalRepository implements IRenewalRepository {
  const RenewalRepository({ApiClient? client})
      : _client = client ?? const ApiClient();

  final ApiClient _client;

  @override
  Future<JpRenewal> getRenewal(int renewalId) async {
    final response = await _client.get('/api/jp/renewals/$renewalId');
    return JpRenewal.fromJson(response);
  }

  @override
  Future<JpRenewal> confirmRenewal(int renewalId) async {
    final response = await _client.post(
      '/api/jp/renewals/$renewalId/confirm',
      body: {},
    );
    return JpRenewal.fromJson(response);
  }

  @override
  Future<JpRenewal> declineRenewal(int renewalId) async {
    final response = await _client.post(
      '/api/jp/renewals/$renewalId/decline',
      body: {},
    );
    return JpRenewal.fromJson(response);
  }
}
