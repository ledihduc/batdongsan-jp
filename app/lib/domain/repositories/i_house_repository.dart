import 'package:house_booking/data/models/house_model.dart';

abstract class IHouseRepository {
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
    String? group,   // 0074: nhóm master (stay_long|stay_short|business)
  });
  Future<HouseModel?> getHouseById(int id);
  /// Creates a house.
  /// - [token]: new JWT if the backend auto-upgraded the caller to host
  ///   (first listing as guest); null otherwise.
  /// - [status]: trạng thái tin server GÁN (`published` khi lên ngay, hoặc
  ///   `pending_review` khi tin bán rơi vào tiền kiểm) → UI báo đúng sự thật,
  ///   không còn "đăng thành công" giả khi tin thực ra đang chờ duyệt.
  Future<({String? token, String? status})> createHouse(HouseModel house);
  Future<bool> updateHouse(HouseModel house);
  Future<bool> deleteHouse(int id);
  
  Future<List<Map<String, dynamic>>> getCategories();
  Future<List<Map<String, dynamic>>> getAmenities();
}
