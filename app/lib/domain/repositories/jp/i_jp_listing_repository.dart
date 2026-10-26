/// Interface for JP listing data access.
library;

import 'package:house_booking/data/models/jp/jp_listing.dart';

/// Query parameters for listing search.
class JpListingSearchParams {
  const JpListingSearchParams({
    this.layouts,
    this.minRent,
    this.maxRent,
    this.minAreaM2,
    this.maxAreaM2,
    this.maxBuildingAgeYears,
    this.maxWalkMinutes,
    this.petsOk,
    this.noGuarantorRequired,
    this.instrumentsOk,
    this.corporateOk,
    this.stationId,
    this.page = 1,
    this.pageSize = 20,
  });

  final List<String>? layouts;
  final int? minRent;
  final int? maxRent;
  final double? minAreaM2;
  final double? maxAreaM2;
  final int? maxBuildingAgeYears;
  final int? maxWalkMinutes;
  final bool? petsOk;
  final bool? noGuarantorRequired;
  final bool? instrumentsOk;
  final bool? corporateOk;
  final int? stationId;
  final int page;
  final int pageSize;

  Map<String, dynamic> toQueryParameters() {
    return {
      if (layouts != null && layouts!.isNotEmpty) 'layouts': layouts!.join(','),
      if (minRent != null) 'min_rent': minRent.toString(),
      if (maxRent != null) 'max_rent': maxRent.toString(),
      if (minAreaM2 != null) 'min_area': minAreaM2.toString(),
      if (maxAreaM2 != null) 'max_area': maxAreaM2.toString(),
      if (maxBuildingAgeYears != null)
        'max_building_age': maxBuildingAgeYears.toString(),
      if (maxWalkMinutes != null) 'max_walk_min': maxWalkMinutes.toString(),
      if (petsOk == true) 'pets_ok': 'true',
      if (noGuarantorRequired == true) 'no_guarantor': 'true',
      if (instrumentsOk == true) 'instruments_ok': 'true',
      if (corporateOk == true) 'corporate_ok': 'true',
      if (stationId != null) 'station_id': stationId.toString(),
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
  }
}

/// JP listing repository interface.
abstract interface class IJpListingRepository {
  /// Fetch paginated JP listings matching [params].
  Future<List<JpListingSummary>> search(JpListingSearchParams params);

  /// Fetch full JP listing detail by [listingId].
  Future<JpListing> getById(int listingId);

  /// Create a new JP listing (owner/sales persona).
  Future<JpListing> create(Map<String, dynamic> payload);

  /// Update an existing JP listing.
  Future<JpListing> update(int listingId, Map<String, dynamic> payload);
}
