/// BboxGuard — kiểm tra tọa độ có nằm trong lãnh thổ Việt Nam không.
/// Chạy trên cả hai path: tap bản đồ và chọn kết quả search (AC-06, AC-17).
class BboxGuard {
  // Bbox bao phủ toàn lãnh thổ VN (đất liền + đảo gần bờ).
  static const double minLat = 8.0;
  static const double maxLat = 23.5;
  static const double minLng = 102.0;
  static const double maxLng = 110.0;

  /// Trả true nếu [lat], [lng] nằm trong bbox Việt Nam.
  static bool isInsideVN(double lat, double lng) =>
      lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
}
