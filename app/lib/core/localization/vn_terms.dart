/// Canonical Vietnamese terminology — one preferred term per concept.
///
/// Prefer these constants over inline strings for tab labels, badges,
/// filter chips, and column headers. Full glossary in
/// `docs/vietnamese-glossary.md`.
///
/// Enforcement is soft — copy inside long-form dialogs / help text is
/// exempt when a natural sentence reads better with a synonym.
library;

class VnTerms {
  const VnTerms._();

  // ── Roles ────────────────────────────────────────────────────────────
  static const String guest = 'Khách thuê';
  static const String host = 'Chủ nhà';
  static const String admin = 'Quản trị';
  static const String operatorRole = 'Đại lý quản lý';
  static const String tenant = 'Người thuê';

  // ── Booking & appointments ───────────────────────────────────────────
  static const String booking = 'Đặt phòng';
  static const String bookingHistory = 'Lịch sử đặt phòng';
  static const String viewingAppointment = 'Đặt lịch xem nhà';

  // ── Property ─────────────────────────────────────────────────────────
  static const String room = 'Phòng';
  static const String apartment = 'Căn hộ';
  static const String building = 'Tòa nhà';
  static const String vacant = 'Phòng trống';

  // ── Lifecycle ────────────────────────────────────────────────────────
  static const String checkIn = 'Nhận phòng';
  static const String checkOut = 'Trả phòng';
  static const String cancel = 'Hủy';
  static const String pending = 'Chờ xác nhận';

  // ── Financial ────────────────────────────────────────────────────────
  static const String invoice = 'Hóa đơn';

  // ── Engagement ───────────────────────────────────────────────────────
  static const String wishlist = 'Yêu thích';

  // ── Ops ──────────────────────────────────────────────────────────────
  static const String delegation = 'Ủy thác quản lý';
  static const String approval = 'Duyệt tin';
}
