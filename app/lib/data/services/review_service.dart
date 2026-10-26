import 'package:house_booking/data/models/review_model.dart';
import 'package:house_booking/data/services/api_client.dart';

class ReviewSummary {
  final List<ReviewModel> reviews;
  final double average;
  final int count;
  ReviewSummary({
    required this.reviews,
    required this.average,
    required this.count,
  });
}

class ReviewService {
  final ApiClient _client = const ApiClient();

  Future<ReviewSummary> fetchByHouse(int houseId) async {
    final res = await _client.get('/api/houses/$houseId/reviews');
    final list = List<Map<String, dynamic>>.from(res['reviews'] as List? ?? []);
    return ReviewSummary(
      reviews: list.map((m) => ReviewModel.fromMap(m)).toList(),
      average: (res['average'] as num?)?.toDouble() ?? 0,
      count: (res['count'] as int?) ?? 0,
    );
  }

  Future<bool> submit({
    required int userId,
    required int houseId,
    required int rating,
    required String comment,
  }) async {
    // user_id derived from JWT sub server-side — không cần truyền.
    await _client.post(
      '/api/reviews',
      body: {'house_id': houseId, 'rating': rating, 'comment': comment},
    );
    return true;
  }

  /// Chủ nhà đánh giá KHÁCH THUÊ (Đợt 3, chiều ngược). reviewer từ JWT.
  Future<void> reviewGuest({
    required int guestId,
    required int rating,
    String? comment,
  }) async {
    await _client.post(
      '/api/guest-reviews',
      body: {
        'guest_id': guestId,
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
  }

  /// Uy tín khách thuê (sao + số giao dịch) cho chủ nhà xem khi nhận lịch hẹn.
  Future<Map<String, dynamic>> userTrust(int userId) async {
    return await _client.get('/api/users/$userId/trust');
  }
}
