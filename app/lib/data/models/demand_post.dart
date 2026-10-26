/// Tin NHU CẦU — "Cần thuê" / "Cần mua".
///
/// Khác `HouseModel` (tin rao có thật: địa chỉ, ảnh, giá cụ thể), đây là thứ
/// người ĐANG TÌM đăng lên: khu vực mong muốn, khoảng ngân sách, vài yêu cầu.
/// Backend lưu ở bảng riêng `demand_posts` — xem `app/domain/demand_post.py`.
///
/// KHÔNG có số điện thoại: liên hệ đi qua chat trong app.
class DemandPost {
  const DemandPost({
    required this.id,
    required this.kind,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.provinceCode,
    this.provinceName,
    this.areaLabel,
    this.categoryNames = const [],
    this.categoryIds = const [],
    this.budgetMin,
    this.budgetMax,
    this.areaMin,
    this.bedroomsMin,
    this.moveInDate,
    this.durationMonths,
    this.occupants,
    this.paymentMethod,
    this.purpose,
    this.needs = const [],
    this.note,
    this.authorId,
    this.authorName,
    this.authorAvatar,
  });

  final int id;

  /// 'rent' = cần thuê · 'buy' = cần mua.
  final String kind;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;

  final String? provinceCode;
  final String? provinceName;
  final String? areaLabel;
  final List<String> categoryNames;
  final List<int> categoryIds;

  final double? budgetMin;
  final double? budgetMax;
  final double? areaMin;
  final int? bedroomsMin;

  final DateTime? moveInDate;
  final int? durationMonths;
  final int? occupants;

  final String? paymentMethod;
  final String? purpose;

  final List<String> needs;
  final String? note;

  final int? authorId;
  final String? authorName;
  final String? authorAvatar;

  bool get laThue => kind == 'rent';

  /// Còn hiệu lực? Hạn do backend tính, client chỉ hiển thị — nhưng danh sách
  /// "tin của tôi" trả cả tin đã hết hạn nên vẫn cần cờ này để vẽ nhãn.
  bool get conHieuLuc =>
      status == 'open' && expiresAt.isAfter(DateTime.now().toUtc());

  static DateTime _ngay(dynamic v, {DateTime? mac}) {
    if (v is String && v.isNotEmpty) {
      return DateTime.tryParse(v) ?? (mac ?? DateTime.now());
    }
    return mac ?? DateTime.now();
  }

  factory DemandPost.fromJson(Map<String, dynamic> j) {
    final author = j['author'] as Map<String, dynamic>?;
    return DemandPost(
      id: (j['id'] as num).toInt(),
      kind: (j['kind'] as String?) ?? 'rent',
      status: (j['status'] as String?) ?? 'open',
      createdAt: _ngay(j['created_at']),
      expiresAt: _ngay(j['expires_at']),
      provinceCode: j['province_code'] as String?,
      provinceName: j['province_name'] as String?,
      areaLabel: j['area_label'] as String?,
      categoryNames: List<String>.from(
        (j['category_names'] as List?) ?? const [],
      ),
      categoryIds: ((j['category_ids'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      budgetMin: (j['budget_min'] as num?)?.toDouble(),
      budgetMax: (j['budget_max'] as num?)?.toDouble(),
      areaMin: (j['area_min'] as num?)?.toDouble(),
      bedroomsMin: (j['bedrooms_min'] as num?)?.toInt(),
      moveInDate: j['move_in_date'] == null ? null : _ngay(j['move_in_date']),
      durationMonths: (j['duration_months'] as num?)?.toInt(),
      occupants: (j['occupants'] as num?)?.toInt(),
      paymentMethod: j['payment_method'] as String?,
      purpose: j['purpose'] as String?,
      needs: List<String>.from((j['needs'] as List?) ?? const []),
      note: j['note'] as String?,
      authorId: (author?['id'] as num?)?.toInt(),
      authorName: author?['name'] as String?,
      authorAvatar: author?['avatar_path'] as String?,
    );
  }
}
