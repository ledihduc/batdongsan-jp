/// Danh sách mã vùng quy hoạch rủi ro.
///
/// Mirror backend `config.risky_zone_codes` — phải đồng bộ thủ công.
/// TODO: thay bằng endpoint `/api/planning/risky-codes` trong Phase 2
/// để tránh drift giữa FE và BE.
class RiskyZoneCodes {
  // Không cho phép khởi tạo — class chỉ chứa const / static.
  const RiskyZoneCodes._();

  /// Tập hợp mã vùng rủi ro — dùng Set để O(1) lookup.
  static const Set<String> codes = {
    'DGT', // Đất giao thông (giải tỏa)
    'CXP', // Cây xanh công viên
    'DCC', // Đất công cộng
    'DXH', // Đất xã hội (công trình hành chính)
  };

  /// Trả về true nếu [code] thuộc tập mã rủi ro.
  /// Null-safe: null luôn trả false.
  static bool isRisky(String? code) => code != null && codes.contains(code);
}
