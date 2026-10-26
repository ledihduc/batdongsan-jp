import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/domain/repositories/i_house_repository.dart';

class ApiHouseRepository implements IHouseRepository {
  final ApiClient _client = const ApiClient();

  @override
  Future<List<HouseModel>> getHouses({
    String? query,
    int? categoryId,
    double? minPrice,
    double? maxPrice,
    double? minArea,
    double? maxArea,
    String? status,
    int? limit,
    int? offset,
    int? hostId,
    String? transactionType,
    String? wardSlug,
    bool? isTrusted,
    // Tìm kiếm nâng cao (0071)
    List<int>? categoryIds,
    List<String>? directions,
    int? minBedrooms,
    double? minRating,
    int? minQualityStar,
    List<String>? amenities,
    String? sort,
    String? group, // 0074: nhóm master (stay_long|stay_short|business)
    // Khu vực: có toạ độ thì backend chuyển sang nhánh PostGIS bán kính.
    double? nearLat,
    double? nearLng,
    double? radiusKm,
  }) async {
    String? csv(List? xs) => (xs == null || xs.isEmpty) ? null : xs.join(',');
    final response = await _client.get(
      '/api/houses',
      queryParameters: {
        'query': query,
        'categoryId': categoryId,
        'minPrice': minPrice,
        'maxPrice': maxPrice,
        'minArea': minArea,
        'maxArea': maxArea,
        'status': status,
        'limit': limit,
        'offset': offset,
        'hostId': hostId,
        'transaction_type': transactionType,
        'ward_slug': wardSlug,
        'is_trusted': isTrusted,
        'categoryIds': csv(categoryIds),
        'direction': csv(directions),
        'minBedrooms': (minBedrooms != null && minBedrooms > 0)
            ? minBedrooms
            : null,
        'minRating': (minRating != null && minRating > 0) ? minRating : null,
        'minQualityStar': (minQualityStar != null && minQualityStar > 0)
            ? minQualityStar
            : null,
        'amenities': csv(amenities),
        'sort': (sort != null && sort.isNotEmpty) ? sort : null,
        'group': (group != null && group.isNotEmpty) ? group : null,
        'near_lat': nearLat,
        'near_lng': nearLng,
        'radius_km': (nearLat != null && nearLng != null) ? radiusKm : null,
      },
    );

    final houses = List<Map<String, dynamic>>.from(response['houses'] as List);
    return houses
        .map(
          (map) => HouseModel.fromMap(
            map,
            images: List<String>.from(map['images'] as List? ?? const []),
            amenities: List<String>.from(map['amenities'] as List? ?? const []),
          ),
        )
        .toList();
  }

  /// ĐẾM số tin khớp bộ lọc, không tải danh sách.
  ///
  /// Dùng cho nút "Xem N tin" ở bảng lọc: người dùng phải biết mình sắp còn lại
  /// bao nhiêu tin TRƯỚC khi bấm áp dụng, nếu không sẽ rơi vào vòng lặp mù —
  /// áp dụng, ra rỗng, mở lại, nới điều kiện, lặp lại.
  ///
  /// `limit: 1` vì chỉ cần trường `total` của phản hồi; kéo cả trang tin về rồi
  /// vứt đi là lãng phí đúng lúc người dùng đang kéo thanh trượt.
  Future<int> countHouses({
    String? query,
    int? categoryId,
    double? minPrice,
    double? maxPrice,
    double? minArea,
    double? maxArea,
    String? transactionType,
    int? minBedrooms,
    String? group,
    // Nhóm nâng cao (0071) — PHẢI có mặt ở đây y như trong [getHouses]: con số
    // trên nút "Xem N tin" chỉ đúng khi hai lời gọi mang CÙNG bộ điều kiện.
    // Thiếu một tham số ở đây là nút hứa 120 tin rồi danh sách trả về 7.
    List<String>? directions,
    bool? isTrusted,
    double? minRating,
    int? minQualityStar,
    double? nearLat,
    double? nearLng,
    double? radiusKm,
  }) async {
    String? csv(List? xs) => (xs == null || xs.isEmpty) ? null : xs.join(',');
    final response = await _client.get(
      '/api/houses',
      queryParameters: {
        'query': query,
        'categoryId': categoryId,
        'minPrice': minPrice,
        'maxPrice': maxPrice,
        'minArea': minArea,
        'maxArea': maxArea,
        'transaction_type': transactionType,
        'minBedrooms': (minBedrooms != null && minBedrooms > 0)
            ? minBedrooms
            : null,
        'group': (group != null && group.isNotEmpty) ? group : null,
        'direction': csv(directions),
        'is_trusted': isTrusted,
        'minRating': (minRating != null && minRating > 0) ? minRating : null,
        'minQualityStar': (minQualityStar != null && minQualityStar > 0)
            ? minQualityStar
            : null,
        'near_lat': nearLat,
        'near_lng': nearLng,
        'radius_km': (nearLat != null && nearLng != null) ? radiusKm : null,
        'limit': 1,
      },
    );
    return (response['total'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<HouseModel?> getHouseById(int id) async {
    final response = await _client.get('/api/houses/$id');
    final map = Map<String, dynamic>.from(response['house'] as Map);
    return HouseModel.fromMap(
      map,
      images: List<String>.from(map['images'] as List? ?? const []),
      amenities: List<String>.from(map['amenities'] as List? ?? const []),
    );
  }

  @override
  Future<({String? token, String? status})> createHouse(
    HouseModel house,
  ) async {
    final resp = await _client.post(
      '/api/houses',
      body: {
        ...house.toMap(),
        'images': house.images,
        'amenities': house.amenities,
      },
    );
    final token = resp['token'];
    final house0 = resp['house'];
    final status = house0 is Map ? house0['status'] : null;
    return (
      token: token is String && token.isNotEmpty ? token : null,
      status: status is String && status.isNotEmpty ? status : null,
    );
  }

  @override
  Future<bool> updateHouse(HouseModel house) async {
    // SECURITY (H1): strip `status` from PUT body — status transitions must
    // go through admin moderation endpoints. Backend allowlist also excludes
    // status; this is belt-and-suspenders defense-in-depth.
    final body = Map<String, dynamic>.from(house.toMap())
      ..remove('status')
      ..['images'] = house.images
      ..['amenities'] = house.amenities;
    await _client.put('/api/houses/${house.id}', body: body);
    return true;
  }

  /// Admin: bật/tắt cờ Uy tín cho một tin đăng (M7).
  ///
  /// Gọi PATCH /api/admin/houses/{id}/trusted. Trả về [HouseModel] mới với
  /// [HouseModel.isTrusted] + [HouseModel.trustedAt] từ server (authoritative).
  /// Nếu backend không trả về `trusted_at`, giữ nguyên giá trị của [source]
  /// khi bật (fallback DateTime.now chỉ dùng khi thực sự thiếu).
  Future<HouseModel> setTrusted(HouseModel source, bool value) async {
    final res = await _client.patch(
      '/api/admin/houses/${source.id}/trusted',
      body: {'is_trusted': value},
    );
    // Server thường trả nguyên trạng thái updated house.
    final rawHouse = res['house'];
    if (rawHouse is Map) {
      final map = Map<String, dynamic>.from(rawHouse);
      return HouseModel.fromMap(
        map,
        images: List<String>.from(map['images'] as List? ?? source.images),
        amenities: List<String>.from(
          map['amenities'] as List? ?? source.amenities,
        ),
      );
    }
    // Fallback nếu backend chỉ trả {is_trusted, trusted_at}
    final serverTrustedAt = res['trusted_at'];
    return HouseModel(
      id: source.id,
      hostId: source.hostId,
      title: source.title,
      description: source.description,
      categoryId: source.categoryId,
      categoryName: source.categoryName,
      categoryGroup: source.categoryGroup,
      sellerType: source.sellerType,
      price: source.price,
      area: source.area,
      address: source.address,
      city: source.city,
      district: source.district,
      latitude: source.latitude,
      longitude: source.longitude,
      bedrooms: source.bedrooms,
      bathrooms: source.bathrooms,
      status: source.status,
      createdAt: source.createdAt,
      images: source.images,
      amenities: source.amenities,
      hostName: source.hostName,
      hostAvatar: source.hostAvatar,
      hostPhone: source.hostPhone,
      listingType: source.listingType,
      totalUnits: source.totalUnits,
      availableUnits: source.availableUnits,
      genderPref: source.genderPref,
      distanceKm: source.distanceKm,
      rejectionReason: source.rejectionReason,
      transactionType: source.transactionType,
      isTrusted: value,
      trustedAt: value
          ? (serverTrustedAt is String
                ? DateTime.tryParse(serverTrustedAt) ?? DateTime.now()
                : DateTime.now())
          : null,
      wardSlug: source.wardSlug,
      wardSlugLegacy: source.wardSlugLegacy,
      legalStatus: source.legalStatus,
    );
  }

  @override
  Future<bool> deleteHouse(int id) async {
    await _client.delete('/api/houses/$id');
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await _client.get('/api/categories');
    return List<Map<String, dynamic>>.from(response['categories'] as List);
  }

  @override
  Future<List<Map<String, dynamic>>> getAmenities() async {
    final response = await _client.get('/api/amenities');
    return List<Map<String, dynamic>>.from(response['amenities'] as List);
  }

  // ── Geo-search (ngoài interface — chỉ ApiHouseRepository) ──────────────────

  List<HouseModel> _parseHouses(Map<String, dynamic> response) {
    final houses = List<Map<String, dynamic>>.from(response['houses'] as List);
    return houses
        .map(
          (map) => HouseModel.fromMap(
            map,
            images: List<String>.from(map['images'] as List? ?? const []),
            amenities: List<String>.from(map['amenities'] as List? ?? const []),
          ),
        )
        .toList();
  }

  /// Admin: liệt kê tin theo status (pending/approved/rejected/all).
  Future<List<HouseModel>> getAdminHouses(String status) async {
    final response = await _client.get(
      '/api/admin/houses',
      queryParameters: {'status': status},
    );
    return _parseHouses(response);
  }

  /// Admin: duyệt (approve) / từ chối (reject) tin. reject bắt buộc [reason].
  Future<HouseModel> moderateHouse(
    int id,
    String action, {
    String? reason,
  }) async {
    final res = await _client.post(
      '/api/admin/houses/$id/moderate',
      body: {'action': action, if (reason != null) 'reason': reason},
    );
    final map = Map<String, dynamic>.from(res['house'] as Map);
    return HouseModel.fromMap(
      map,
      images: List<String>.from(map['images'] as List? ?? const []),
      amenities: List<String>.from(map['amenities'] as List? ?? const []),
    );
  }

  /// Tìm nhà theo tỉnh/thành (province slug) + quận/huyện, kèm bộ lọc thường.
  Future<List<HouseModel>> getHousesByArea({
    String? province,
    String? district,
    String? query,
    int? categoryId,
    double? minPrice,
    double? maxPrice,
    double? minArea,
    double? maxArea,
    int? limit,
    int? offset,
  }) async {
    final response = await _client.get(
      '/api/houses',
      queryParameters: {
        'province': province,
        'district': district,
        'query': query,
        'categoryId': categoryId,
        'minPrice': minPrice,
        'maxPrice': maxPrice,
        'minArea': minArea,
        'maxArea': maxArea,
        'limit': limit,
        'offset': offset,
      },
    );
    return _parseHouses(response);
  }

  /// Tìm nhà quanh một toạ độ (GPS "quanh đây"), sort theo khoảng cách.
  Future<List<HouseModel>> getHousesNearby({
    required double lat,
    required double lng,
    double radiusKm = 3,
    String? province,
    String? transactionType,
    int? categoryId,
    double? minPrice,
    double? maxPrice,
    double? minArea,
    double? maxArea,
    int? limit,
    int? offset,
  }) async {
    final response = await _client.get(
      '/api/houses',
      queryParameters: {
        'near_lat': lat,
        'near_lng': lng,
        'radius_km': radiusKm,
        // Mặc định feed: GẦN + UY TÍN (blend khoảng cách & rating chủ/tin ở backend).
        'sort': 'near_trust',
        'province': province,
        'transaction_type': transactionType,
        'categoryId': categoryId,
        'minPrice': minPrice,
        'maxPrice': maxPrice,
        'minArea': minArea,
        'maxArea': maxArea,
        'limit': limit,
        'offset': offset,
      },
    );
    return _parseHouses(response);
  }

  /// Chỉ lấy TOẠ ĐỘ của một địa danh, không lấy danh sách nhà kèm theo.
  ///
  /// Dùng cho bảng lọc: ở đó địa danh mới chỉ là một tiêu chí, còn việc nạp
  /// danh sách phải đi qua [getHouses] để CỘNG DỒN với mọi tiêu chí khác
  /// (hướng nhà, uy tín, phòng ngủ…). Gọi thẳng `searchHousesNearPlace` sẽ trả
  /// về danh sách chỉ lọc theo địa danh — tưởng đã lọc mà thật ra chưa.
  ///
  /// `limit: 1` vì chỉ cần trường `place`; không tìm thấy → null.
  Future<({double lat, double lng})?> geocodePlace(String place) async {
    if (place.trim().isEmpty) return null;
    final r = await searchHousesNearPlace(place: place, limit: 1);
    final lat = (r.place?['lat'] as num?)?.toDouble();
    final lng = (r.place?['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
  }

  /// Tìm nhà theo địa danh: backend geocode `place` (Nominatim) → nhà lân cận.
  /// Trả `(place, houses)` — `place` là tâm địa danh đã geocode (null nếu không tìm thấy).
  Future<({Map<String, dynamic>? place, List<HouseModel> houses})>
  searchHousesNearPlace({
    required String place,
    double radiusKm = 3,
    String? transactionType,
    int? categoryId,
    double? minPrice,
    double? maxPrice,
    double? minArea,
    double? maxArea,
    int? limit,
    int? offset,
  }) async {
    final response = await _client.get(
      '/api/houses/search-nearby',
      queryParameters: {
        'place': place,
        'radius_km': radiusKm,
        'transaction_type': transactionType,
        'categoryId': categoryId,
        'minPrice': minPrice,
        'maxPrice': maxPrice,
        'minArea': minArea,
        'maxArea': maxArea,
        'limit': limit,
        'offset': offset,
      },
    );
    final place0 = response['place'];
    return (
      place: place0 is Map ? Map<String, dynamic>.from(place0) : null,
      houses: _parseHouses(response),
    );
  }
}
