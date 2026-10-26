/// Real implementation of [IJpListingRepository] hitting `/api/jp/listings`.
library;

import 'package:house_booking/data/models/jp/jp_listing.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_listing_repository.dart';

class ApiJpListingRepository implements IJpListingRepository {
  const ApiJpListingRepository({ApiClient? client})
      : _client = client ?? const ApiClient();

  final ApiClient _client;

  @override
  Future<List<JpListingSummary>> search(JpListingSearchParams params) async {
    final response = await _client.get(
      '/api/jp/listings',
      queryParameters: params.toQueryParameters(),
    );
    final items = response['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => JpListingSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<JpListing> getById(int listingId) async {
    final response = await _client.get('/api/jp/listings/$listingId');
    return JpListing.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<JpListing> create(Map<String, dynamic> payload) async {
    final response = await _client.post('/api/jp/listings', body: payload);
    return JpListing.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<JpListing> update(int listingId, Map<String, dynamic> payload) async {
    final response = await _client.patch(
      '/api/jp/listings/$listingId',
      body: payload,
    );
    return JpListing.fromJson(response as Map<String, dynamic>);
  }
}
