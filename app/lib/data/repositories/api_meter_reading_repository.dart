import 'package:house_booking/data/models/meter_reading_model.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Repository for /api/host/meter-readings endpoints (Phase 04).
class ApiMeterReadingRepository {
  final ApiClient _client = const ApiClient();

  Future<List<MeterReadingModel>> fetchReadings({
    int? roomId,
    String? fromDate,
    String? toDate,
  }) async {
    final query = <String, dynamic>{
      if (roomId != null) 'room_id': roomId,
      if (fromDate != null) 'from_date': fromDate,
      if (toDate != null) 'to_date': toDate,
    };
    final list = await _client.getList(
      '/api/host/meter-readings',
      queryParameters: query,
    );
    return list
        .map(
          (e) =>
              MeterReadingModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<MeterReadingModel> createReading({
    required int roomId,
    required String readingDate, // YYYY-MM-DD
    double electricityKwh = 0,
    double waterM3 = 0,
    String? note,
  }) async {
    final resp = await _client.post(
      '/api/host/meter-readings',
      body: {
        'room_id': roomId,
        'reading_date': readingDate,
        'electricity_kwh': electricityKwh,
        'water_m3': waterM3,
        if (note != null) 'note': note,
      },
    );
    return MeterReadingModel.fromJson(Map<String, dynamic>.from(resp));
  }

  /// Batch create one reading per room for a single reading_date.
  Future<List<MeterReadingModel>> createBatch({
    required String readingDate,
    required List<Map<String, dynamic>> readings,
  }) async {
    final list = await _client.postList(
      '/api/host/meter-readings/batch',
      body: {'reading_date': readingDate, 'readings': readings},
    );
    return list
        .map(
          (e) =>
              MeterReadingModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }
}
