import 'package:flutter/foundation.dart';
import 'package:house_booking/core/lifecycle/user_scope_cleanup.dart';
import 'package:house_booking/data/models/meter_reading_model.dart';
import 'package:house_booking/data/repositories/api_meter_reading_repository.dart';
import 'package:house_booking/data/services/api_client.dart';

/// MeterReadingProvider — manages monthly electricity/water readings per room.
class MeterReadingProvider extends ChangeNotifier implements UserScoped {
  final ApiMeterReadingRepository _repo = ApiMeterReadingRepository();

  List<MeterReadingModel> _readings = [];
  bool _isLoading = false;
  String? _error;

  List<MeterReadingModel> get readings => List.unmodifiable(_readings);
  bool get isLoading => _isLoading;
  String? get error => _error;

  @override
  void resetUserScope() {
    _readings = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> fetchReadings({
    int? roomId,
    String? fromDate,
    String? toDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _readings = await _repo.fetchReadings(
        roomId: roomId,
        fromDate: fromDate,
        toDate: toDate,
      );
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Không thể tải chỉ số';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<MeterReadingModel?> createReading({
    required int roomId,
    required String readingDate,
    double electricityKwh = 0,
    double waterM3 = 0,
    String? note,
  }) async {
    try {
      final reading = await _repo.createReading(
        roomId: roomId,
        readingDate: readingDate,
        electricityKwh: electricityKwh,
        waterM3: waterM3,
        note: note,
      );
      _readings = [reading, ..._readings];
      notifyListeners();
      return reading;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  /// Batch create for many rooms on one [readingDate].
  /// Each reading entry must include: room_id, electricity_kwh, water_m3.
  Future<List<MeterReadingModel>?> createBatch({
    required String readingDate,
    required List<Map<String, dynamic>> readings,
  }) async {
    try {
      final created = await _repo.createBatch(
        readingDate: readingDate,
        readings: readings,
      );
      _readings = [...created, ..._readings];
      notifyListeners();
      return created;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }
}
