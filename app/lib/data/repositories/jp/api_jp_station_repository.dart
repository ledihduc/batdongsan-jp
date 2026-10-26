/// Real implementation of [IJpStationRepository] hitting `/api/jp/stations`.
library;

import 'package:house_booking/data/models/jp/jp_station.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_station_repository.dart';

class ApiJpStationRepository implements IJpStationRepository {
  const ApiJpStationRepository({ApiClient? client})
      : _client = client ?? const ApiClient();

  final ApiClient _client;

  @override
  Future<List<JpStation>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final response = await _client.get(
      '/api/jp/stations',
      queryParameters: {'q': query.trim(), 'limit': '20'},
    );
    final items = response['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => JpStation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<JpStation> getById(int stationId) async {
    final response = await _client.get('/api/jp/stations/$stationId');
    return JpStation.fromJson(response as Map<String, dynamic>);
  }
}
