import 'package:house_booking/core/utils/formatters.dart';

class HouseModel {
  final int? id;
  final int hostId;
  final String title;
  final String description;
  final int categoryId;
  final String? categoryName;

  /// Người đăng TỰ KHAI mình là ai (backend 0075): 'owner' (chủ nhà tự đăng)
  /// | 'broker' (đăng hộ / môi giới) | '' (tin cũ, chưa từng được hỏi).
  ///
  /// ⚠️ Rỗng KHÔNG có nghĩa là "chủ nhà" — không hiển thị nhãn nào cả. Đây là
  /// lời tự khai, chưa xác minh giấy tờ, nên nhãn phải kèm chữ "(tự khai)".
  final String sellerType;

  /// Phòng trong DỰ ÁN mà tin này gắn vào; null = tin lẻ, chưa thuộc dự án nào.
  ///
  /// Dùng để lọc danh sách "tin chưa gắn" khi mời gắn vào dự án. Cột tương ứng
  /// ở backend là UNIQUE, nên gắn lần hai bị từ chối — client lọc trước cho
  /// người dùng khỏi chọn nhầm rồi mới ăn lỗi.
  final int? sourceRoomId;
  final Map<String, dynamic>? shortStay;

  /// HẠNG PHÒNG mà tin ngắn hạn neo vào (backend 0130); null = tin không theo
  /// hạng (dài hạn, bán, hoặc tin ngắn hạn cũ neo theo phòng lẻ).
  ///
  /// Khách sạn/homestay bán HẠNG ("Deluxe hướng biển") chứ không bán số phòng —
  /// lễ tân mới gán phòng lúc nhận. Vì thế tin theo hạng KHÔNG có
  /// [sourceRoomId], và mọi lời gọi đặt phòng phải đi qua
  /// `/api/short-stays/tin/{id}/…` để server tự bốc phòng trống.
  final int? loaiPhongId;

  /// Khối mô tả hạng cho màn chi tiết: ten · suc_chua · giuong · anh ·
  /// so_phong (còn mấy phòng) · 3 giá · toa. null khi tin không neo hạng.
  final Map<String, dynamic>? hangPhong;

  /// Nhãn căn trong dự án BĐS ("Căn 1201"). Thuộc tính của chính căn.
  final String unitLabel;

  /// Nhóm master: 'stay_long' | 'stay_short' | 'business' (backend 0074).
  /// Quyết định MÀU PIN trên bản đồ. Tin cũ/API cũ không có → rỗng, pin rơi về
  /// màu nhóm dài hạn thay vì mất pin.
  final String categoryGroup;
  final double price;
  final double area;
  final String address;
  final String city;
  final String district;
  final double? latitude;
  final double? longitude;
  final int bedrooms;
  final int bathrooms;
  final String
  status; // 'published' | 'approved' (legacy) | 'pending' (legacy) | 'rejected' | 'hidden'

  // ── Tin đăng như một bài viết (migration 0090) ──────────────────────────
  /// Ghim lên đầu trang cá nhân của người đăng.
  final bool pinned;
  final int viewCount;
  final int likeCount;
  final int commentCount;

  /// Người đang xem đã tim tin này chưa. Chỉ có khi gọi API kèm token.
  final bool liked;
  final DateTime createdAt;

  // Multi-unit support
  final String listingType; // 'single' | 'multi_unit'
  final int totalUnits;
  final int availableUnits;
  final String genderPref; // 'any' | 'male' | 'female'

  // Relations loaded dynamically
  final List<String> images;
  final List<String> amenities;
  final String? hostName;
  final String? hostAvatar;
  final String? hostPhone;
  // Tín hiệu uy tín chủ nhà (Đợt 1 profile uy tín) — hiện ở card chủ nhà.
  final bool hostVerified;
  final bool hostTrusted; // badge "Chủ nhà tin cậy" (Superhost-style, Đợt 3)
  final double? hostRating;
  final double? hostAvgResponseHours;

  /// Khoảng cách (km) tới điểm tìm — chỉ có khi tìm "quanh đây"/theo địa danh
  /// (backend trả `distance_km` khi sort=distance). null ở các chế độ duyệt khác.
  final double? distanceKm;

  /// Lý do admin từ chối (chỉ có khi status='rejected').
  final String? rejectionReason;

  // Transaction type + trust + ward (D1, D4, D10)
  /// 'rent' | 'sale'. Default 'rent'. (D1)
  final String transactionType;

  /// Admin-trusted listing badge. Server-controlled; read-only on client. (D4)
  final bool isTrusted;

  /// Timestamp when admin trusted the listing; null if not trusted. (D4)
  final DateTime? trustedAt;

  /// Canonical ward slug for location filtering. (D10)
  final String? wardSlug;

  /// Legacy ward slug kept for backward-compat with old URLs. (D10)
  final String? wardSlugLegacy;

  /// Pháp lý (chỉ tin mua bán): red_book|pink_book|sale_contract|pending.
  final String? legalStatus;

  /// Loại sản phẩm: 'apartment' | 'boarding_house' | 'homestay' | 'industrial'.
  /// 'industrial' = BĐS công nghiệp (P3). Default 'apartment'.
  final String productType;

  /// Thuộc tính KCN khi productType='industrial' (P3): {area_ha, power_mva,
  /// fire_safety, kcn_legal}. null với tin thường.
  final Map<String, dynamic>? industrialAttrs;

  // Tìm kiếm nâng cao (0071): hướng nhà + cache điểm đánh giá.
  final String? direction; // slug 8 hướng, null = chưa khai
  final double ratingAvg;
  final int ratingCount;

  HouseModel({
    this.id,
    required this.hostId,
    required this.title,
    required this.description,
    required this.categoryId,
    this.categoryName,
    this.categoryGroup = '',
    this.sellerType = '',
    this.sourceRoomId,
    this.shortStay,
    this.loaiPhongId,
    this.hangPhong,
    this.unitLabel = '',
    required this.price,
    required this.area,
    required this.address,
    required this.city,
    required this.district,
    this.latitude,
    this.longitude,
    required this.bedrooms,
    required this.bathrooms,
    this.status = 'published',
    this.pinned = false,
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.liked = false,
    DateTime? createdAt,
    this.images = const [],
    this.amenities = const [],
    this.hostName,
    this.hostAvatar,
    this.hostPhone,
    this.hostVerified = false,
    this.hostTrusted = false,
    this.hostRating,
    this.hostAvgResponseHours,
    this.listingType = 'single',
    this.totalUnits = 1,
    this.availableUnits = 1,
    this.genderPref = 'any',
    this.distanceKm,
    this.rejectionReason,
    this.transactionType = 'rent',
    this.isTrusted = false,
    this.trustedAt,
    this.wardSlug,
    this.wardSlugLegacy,
    this.legalStatus,
    this.productType = 'apartment',
    this.industrialAttrs,
    this.direction,
    this.ratingAvg = 0,
    this.ratingCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Nhãn khoảng cách gọn kiểu VN: "300 m" (<1km) hoặc "1,2 km".
  String? get distanceLabel {
    final d = distanceKm;
    if (d == null) return null;
    if (d < 1) return '${(d * 1000).round()} m';
    return '${d.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  bool get isMultiUnit => listingType == 'multi_unit';
  bool get isFull => isMultiUnit && availableUnits <= 0;

  bool get isForSale => transactionType == 'sale';
  bool get isForRent => transactionType == 'rent';
  bool get isIndustrial => productType == 'industrial';
  String get priceLabel => isForSale ? 'Giá bán' : 'Giá thuê';
  String get pricePeriodSuffix => isForSale ? '' : '/tháng';

  /// Nhãn giá gọn cho card/list — nguồn duy nhất để hiển thị giá theo loại tin:
  /// bán → "2,5 tỷ" (đơn vị tỷ), thuê → "8tr/tháng". Dùng thay mọi chỗ trước
  /// đây hardcode "/tháng" hoặc tự format triệu (sai với tin bán tiền tỷ).
  String get priceCompactLabel =>
      '${PriceFormat.compact(price)}$pricePeriodSuffix';

  factory HouseModel.fromMap(
    Map<String, dynamic> map, {
    List<String> images = const [],
    List<String> amenities = const [],
  }) {
    return HouseModel(
      id: map['id'],
      hostId: map['host_id'],
      title: map['title'],
      description: map['description'],
      categoryId: map['category_id'],
      categoryName: map['category_name'],
      categoryGroup: (map['category_group'] as String?) ?? '',
      sellerType: (map['seller_type'] as String?) ?? '',
      sourceRoomId: (map['source_room_id'] as num?)?.toInt(),
      shortStay: (map['short_stay'] as Map?)?.cast<String, dynamic>(),
      loaiPhongId: (map['loai_phong_id'] as num?)?.toInt(),
      hangPhong: (map['hang_phong'] as Map?)?.cast<String, dynamic>(),
      unitLabel: (map['unit_label'] as String?) ?? '',
      price: (map['price'] as num).toDouble(),
      area: (map['area'] as num).toDouble(),
      address: map['address'],
      city: map['city'],
      district: map['district'],
      latitude: map['latitude'] != null
          ? (map['latitude'] as num).toDouble()
          : null,
      longitude: map['longitude'] != null
          ? (map['longitude'] as num).toDouble()
          : null,
      bedrooms: map['bedrooms'],
      bathrooms: map['bathrooms'],
      status: map['status'] ?? 'published',
      pinned: map['pinned'] == true,
      viewCount: (map['view_count'] as num?)?.toInt() ?? 0,
      likeCount: (map['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (map['comment_count'] as num?)?.toInt() ?? 0,
      liked: map['liked'] == true,
      createdAt: DateTime.parse(map['created_at']),
      images: images,
      amenities: amenities,
      hostName: map['host_name'],
      hostAvatar: map['host_avatar'],
      hostPhone: map['host_phone'],
      hostVerified: map['host_verified'] == true,
      hostTrusted: map['host_trusted'] == true,
      hostRating: (map['host_rating'] as num?)?.toDouble(),
      hostAvgResponseHours: (map['host_avg_response_hours'] as num?)
          ?.toDouble(),
      listingType: (map['listing_type'] as String?) ?? 'single',
      totalUnits: (map['total_units'] as num?)?.toInt() ?? 1,
      availableUnits: (map['available_units'] as num?)?.toInt() ?? 1,
      genderPref: (map['gender_pref'] as String?) ?? 'any',
      distanceKm: (map['distance_km'] as num?)?.toDouble(),
      rejectionReason: map['rejection_reason'] as String?,
      transactionType: (map['transaction_type'] as String?) ?? 'rent',
      isTrusted: (map['is_trusted'] as bool?) ?? false,
      trustedAt: map['trusted_at'] != null
          ? DateTime.parse(map['trusted_at'] as String)
          : null,
      wardSlug: map['ward_slug'] as String?,
      wardSlugLegacy: map['ward_slug_legacy'] as String?,
      legalStatus: map['legal_status'] as String?,
      productType: (map['product_type'] as String?) ?? 'apartment',
      industrialAttrs: (map['industrial_attrs'] as Map?)
          ?.cast<String, dynamic>(),
      direction: map['direction'] as String?,
      ratingAvg: ((map['rating_avg'] as num?) ?? 0).toDouble(),
      ratingCount: (map['rating_count'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'host_id': hostId,
      'title': title,
      'description': description,
      'category_id': categoryId,
      'price': price,
      'area': area,
      'address': address,
      'city': city,
      'district': district,
      if (sellerType.isNotEmpty) 'seller_type': sellerType,
      if (unitLabel.isNotEmpty) 'unit_label': unitLabel,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'listing_type': listingType,
      'total_units': totalUnits,
      'available_units': availableUnits,
      'gender_pref': genderPref,
      'transaction_type': transactionType,
      'is_trusted': isTrusted,
      if (wardSlug != null) 'ward_slug': wardSlug,
      if (wardSlugLegacy != null) 'ward_slug_legacy': wardSlugLegacy,
      if (legalStatus != null) 'legal_status': legalStatus,
      if (productType != 'apartment') 'product_type': productType,
      if (industrialAttrs != null) 'industrial_attrs': industrialAttrs,
      if (direction != null) 'direction': direction,
      if (loaiPhongId != null) 'loai_phong_id': loaiPhongId,
    };
  }
}
