import 'package:house_booking/data/services/api_client.dart';

/// 5 tiêu chí sao chất lượng (khớp backend) + nhãn tiếng Việt.
const Map<String, String> kQualityCriteriaLabels = {
  'pccc': 'Phòng cháy chữa cháy',
  'full_furniture': 'Đầy đủ nội thất',
  'kitchen': 'Có bếp',
  'private_bathroom': 'Vệ sinh khép kín',
  'air_conditioner': 'Điều hòa',
};

class QualityRating {
  QualityRating.fromMap(Map<String, dynamic> m)
    : criteria = {
        for (final k in kQualityCriteriaLabels.keys)
          k: (m['criteria'] as Map?)?[k] == true,
      },
      selfStar = (m['self_star'] as num?)?.toInt(),
      verifiedStar = (m['verified_star'] as num?)?.toInt(),
      isVerified = m['is_verified'] == true,
      suggestedPrice = (m['suggested_price'] as num?)?.toInt();

  final Map<String, bool> criteria;
  final int? selfStar;
  final int? verifiedStar;
  final bool isVerified;
  final int? suggestedPrice;

  /// Sao hiển thị: ưu tiên verified, fallback self.
  int? get star => verifiedStar ?? selfStar;
  bool get hasRating => star != null;
}

class QualityService {
  final ApiClient _client = const ApiClient();

  Future<QualityRating> get(int houseId) async {
    final res = await _client.get('/api/houses/$houseId/quality');
    return QualityRating.fromMap(res);
  }

  /// Chủ nhà cập nhật 5 tiêu chí (body gửi phẳng đúng model backend).
  Future<QualityRating> set(int houseId, Map<String, bool> criteria) async {
    final res = await _client.put(
      '/api/houses/$houseId/quality',
      body: criteria,
    );
    return QualityRating.fromMap(res);
  }

  /// Chủ nhà yêu cầu thẩm định thực tế (Phase 2). Trả về trạng thái yêu cầu.
  Future<String> requestVerification(int houseId) async {
    final res = await _client.post('/api/houses/$houseId/verification');
    return (res['status'] as String?) ?? 'requested';
  }

  /// Admin/thẩm-định-viên: hàng đợi yêu cầu đang mở.
  Future<List<Map<String, dynamic>>> verificationQueue() async {
    final res = await _client.get('/api/verification/queue');
    return List<Map<String, dynamic>>.from(
      res['requests'] as List? ?? const [],
    );
  }

  /// Admin: hoàn tất thẩm định → gắn verified_star.
  Future<void> completeVerification(
    int reqId,
    int verifiedStar, {
    String? note,
  }) async {
    await _client.post(
      '/api/verification/$reqId/complete',
      body: {'verified_star': verifiedStar, if (note != null) 'note': note},
    );
  }
}
