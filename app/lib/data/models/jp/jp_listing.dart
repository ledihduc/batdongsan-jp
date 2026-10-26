/// JP listing model — extends base listing data with JP-specific fields.
///
/// Composes [JpRentalTerms], [JpPropertyInfo], and [JpTransitAccess] list.
/// The base listing (id, title, images, address, host) is referenced by [listingId]
/// and fetched separately to avoid duplication with the existing HouseModel.
library;

import 'jp_rental_terms.dart';
import 'jp_property_info.dart';
import 'jp_station.dart';

/// Full JP listing detail returned by `GET /api/jp/listings/:id`.
class JpListing {
  const JpListing({
    required this.listingId,
    required this.title,
    required this.rentalTerms,
    required this.propertyInfo,
    this.transitAccesses = const [],
    this.description,
    this.imageUrls = const [],
    this.hostName,
    this.hostAvatarUrl,
    this.prefecture,
    this.city,
    this.address,
    this.isPublished = false,
    this.assignedAgentId,
  });

  /// ID matching the existing `house` / listing record in the base system.
  final int listingId;

  final String title;

  /// Chintai money matrix.
  final JpRentalTerms rentalTerms;

  /// Physical/structural info.
  final JpPropertyInfo propertyInfo;

  /// Transit access list — typically 1–3 nearest stations.
  final List<JpTransitAccess> transitAccesses;

  final String? description;
  final List<String> imageUrls;
  final String? hostName;
  final String? hostAvatarUrl;
  final String? prefecture;
  final String? city;
  final String? address;
  final bool isPublished;

  /// 仲介担当者ID — agent assigned to this listing. Null if not yet assigned.
  final int? assignedAgentId;

  /// Returns the nearest transit access entry sorted by walk minutes.
  JpTransitAccess? get nearestStation {
    if (transitAccesses.isEmpty) return null;
    final sorted = List<JpTransitAccess>.from(transitAccesses)
      ..sort((a, b) => a.walkMinutes.compareTo(b.walkMinutes));
    return sorted.first;
  }

  factory JpListing.fromJson(Map<String, dynamic> json) {
    final transitRaw = json['transit_accesses'] as List<dynamic>? ?? [];
    final imageRaw = json['image_urls'] as List<dynamic>? ?? [];

    return JpListing(
      listingId: json['listing_id'] as int,
      title: json['title'] as String? ?? '',
      rentalTerms: JpRentalTerms.fromJson(
        json['rental_terms'] as Map<String, dynamic>,
      ),
      propertyInfo: JpPropertyInfo.fromJson(
        json['property_info'] as Map<String, dynamic>,
      ),
      transitAccesses: transitRaw
          .map((e) => JpTransitAccess.fromJson(e as Map<String, dynamic>))
          .toList(),
      description: json['description'] as String?,
      imageUrls: imageRaw.map((e) => e as String).toList(),
      hostName: json['host_name'] as String?,
      hostAvatarUrl: json['host_avatar_url'] as String?,
      prefecture: json['prefecture'] as String?,
      city: json['city'] as String?,
      address: json['address'] as String?,
      isPublished: json['is_published'] as bool? ?? false,
      assignedAgentId: json['assigned_agent_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'listing_id': listingId,
        'title': title,
        'rental_terms': rentalTerms.toJson(),
        'property_info': propertyInfo.toJson(),
        'transit_accesses': transitAccesses.map((t) => t.toJson()).toList(),
        if (description != null) 'description': description,
        'image_urls': imageUrls,
        if (hostName != null) 'host_name': hostName,
        if (hostAvatarUrl != null) 'host_avatar_url': hostAvatarUrl,
        if (prefecture != null) 'prefecture': prefecture,
        if (city != null) 'city': city,
        if (address != null) 'address': address,
        'is_published': isPublished,
        if (assignedAgentId != null) 'assigned_agent_id': assignedAgentId,
      };
}

/// Summary card model returned by `GET /api/jp/listings` (list endpoint).
class JpListingSummary {
  const JpListingSummary({
    required this.listingId,
    required this.title,
    required this.monthlyRent,
    required this.layout,
    required this.floorAreaM2,
    this.nearestStationName,
    this.nearestStationWalkMin,
    this.thumbnailUrl,
    this.city,
    this.isPublished = false,
  });

  final int listingId;
  final String title;
  final int monthlyRent;
  final String layout;
  final double floorAreaM2;
  final String? nearestStationName;
  final int? nearestStationWalkMin;
  final String? thumbnailUrl;
  final String? city;
  final bool isPublished;

  factory JpListingSummary.fromJson(Map<String, dynamic> json) {
    return JpListingSummary(
      listingId: json['listing_id'] as int,
      title: json['title'] as String? ?? '',
      monthlyRent: json['monthly_rent'] as int? ?? 0,
      layout: json['layout'] as String? ?? '',
      floorAreaM2: (json['floor_area_m2'] as num?)?.toDouble() ?? 0,
      nearestStationName: json['nearest_station_name'] as String?,
      nearestStationWalkMin: json['nearest_station_walk_min'] as int?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      city: json['city'] as String?,
      isPublished: json['is_published'] as bool? ?? false,
    );
  }
}
