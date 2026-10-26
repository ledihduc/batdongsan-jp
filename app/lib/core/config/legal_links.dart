/// Liên kết pháp lý — Chính sách quyền riêng tư + Điều khoản.
///
/// Trang thật do web SEO (Next.js) phục vụ tại ancu.digi-lab.vn. Cần truy cập
/// được TRONG app để đạt yêu cầu duyệt của Apple (5.1.1) và Google Play.
/// Override được qua --dart-define nếu đổi domain.
class LegalLinks {
  static const String _base = String.fromEnvironment(
    'LEGAL_BASE_URL',
    defaultValue: 'https://ancu365.ddns.net',
  );

  static const String privacy = '$_base/chinh-sach-quyen-rieng-tu';
  static const String terms = '$_base/dieu-khoan';
}
