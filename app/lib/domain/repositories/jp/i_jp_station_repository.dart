/// Interface for JP station search data access.
library;

import 'package:house_booking/data/models/jp/jp_station.dart';

abstract interface class IJpStationRepository {
  /// Search stations by name prefix.
  Future<List<JpStation>> search(String query);

  /// Fetch a station by its ID.
  Future<JpStation> getById(int stationId);
}
