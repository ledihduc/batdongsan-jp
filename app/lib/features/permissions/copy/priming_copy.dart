// Single source of truth for all permission priming strings.
// Copy is VERBATIM from researcher-priming-ux-copy.md Sections 3.A–3.F (Medium variant)
// and phase spec table (line 88–90) for contract/reportError contexts.
// DO NOT paraphrase — Phase 7 tests assert exact strings.
//
// JP/i18n (Phase 00): simple string constants below are also registered in
// lib/l10n/*.arb as `priming*` keys. Widgets with BuildContext SHOULD use
// [PrimingL10n] to get the localized string; the const values remain as
// fallback and for tests that do not have a context.

import 'package:flutter/widgets.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Holds copy for one notification priming variant.
class NotificationCopy {
  /// Bold headline shown at top of sheet.
  final String title;

  /// Bullet line 1 benefit.
  final String line1;

  /// Bullet line 2 benefit.
  final String line2;

  /// Bullet line 3 benefit.
  final String line3;

  const NotificationCopy({
    required this.title,
    required this.line1,
    required this.line2,
    required this.line3,
  });
}

/// Holds copy for one camera priming variant.
class CameraCopy {
  /// Bold headline shown at top of sheet.
  final String title;

  /// Body text / benefit explanation (may include bullet lines separated by \n).
  final String body;

  const CameraCopy({required this.title, required this.body});
}

/// Central copy registry.  All VN strings live here — never inline inside widgets.
class PrimingCopy {
  PrimingCopy._();

  // ─────────────────────────────────────────────────────────────────────────
  // Notification copy — 3 role variants (Section 3.A–C, Medium variant)
  // ─────────────────────────────────────────────────────────────────────────

  static const Map<UserRole, NotificationCopy> notification = {
    // Section 3.A — Guest — Medium (30 words)
    UserRole.guest: NotificationCopy(
      title: 'Đừng bỏ lỡ phòng yêu thích',
      line1: 'Nhận thông báo khi có phòng mới được đăng',
      line2: 'Tin nhắn từ chủ nhà',
      line3: 'Các ưu đãi đặc biệt dành riêng cho bạn',
    ),

    // Section 3.B — Host — Medium (35 words)
    UserRole.host: NotificationCopy(
      title: 'Không bỏ lỡ một đơn đặt phòng nào',
      line1: 'Thông báo mới về yêu cầu đặt phòng',
      line2: 'Tin nhắn từ khách tiềm năng',
      line3: 'Lịch xem phòng của khách từ các thành phố khác',
    ),

    // Section 3.C — Admin — Medium (35 words)
    UserRole.admin: NotificationCopy(
      title: 'Giúp bạn quản lý nền tảng hiệu quả',
      line1: 'Thông báo chủ nhà chưa được xác nhận',
      line2: 'Báo cáo vi phạm từ người dùng',
      line3: 'Thống kê hàng ngày về tình trạng nền tảng',
    ),
  };

  // ─────────────────────────────────────────────────────────────────────────
  // Camera copy — 6 context variants (Sections 3.D–F + spec table adaptations)
  // ─────────────────────────────────────────────────────────────────────────

  static const Map<CameraContext, CameraCopy> camera = {
    // Section 3.D — CCCD Upload — Medium (40 words), verbatim
    CameraContext.cccdUpload: CameraCopy(
      title: 'Xác minh danh tính với CCCD',
      body:
          'Xác minh danh tính nhanh chóng với ảnh chứng minh thư:\n'
          '• Quá trình xác minh tự động (dưới 1 phút)\n'
          '• Ảnh của bạn được mã hóa và lưu trữ an toàn\n'
          '• Chúng tôi không bao giờ chia sẻ ảnh của bạn với bên thứ ba.',
    ),

    // Section 3.E — Post House Photo — Medium (40 words), verbatim
    CameraContext.postHousePhoto: CameraCopy(
      title: 'Đăng ảnh để thu hút khách hàng',
      body:
          'Những bức ảnh chất lượng cao giúp bạn kiếm thêm tiền:\n'
          '• Khách hàng lựa chọn phòng có ảnh cao định nghĩa\n'
          '• Tỷ lệ đặt phòng tăng trung bình 40% với ảnh chuyên nghiệp\n'
          '• Gợi ý chụp ảnh từ chủ nhà có kinh nghiệm.',
    ),

    // Spec table line 88 — contractPhoto — Section 3.D adapted ("chứng minh thư" → "hợp đồng")
    CameraContext.contractPhoto: CameraCopy(
      title: 'Xác minh hợp đồng với ảnh',
      body:
          'Xác minh danh tính nhanh chóng với ảnh hợp đồng:\n'
          '• Quá trình xác minh tự động (dưới 1 phút)\n'
          '• Ảnh của bạn được mã hóa và lưu trữ an toàn\n'
          '• Chúng tôi không bao giờ chia sẻ ảnh của bạn với bên thứ ba.',
    ),

    // Spec table line 89 — contractTerminatePhoto — Section 3.D adapted (→ "biên bản kết thúc")
    CameraContext.contractTerminatePhoto: CameraCopy(
      title: 'Xác minh biên bản kết thúc',
      body:
          'Xác minh danh tính nhanh chóng với ảnh biên bản kết thúc:\n'
          '• Quá trình xác minh tự động (dưới 1 phút)\n'
          '• Ảnh của bạn được mã hóa và lưu trữ an toàn\n'
          '• Chúng tôi không bao giờ chia sẻ ảnh của bạn với bên thứ ba.',
    ),

    // Section 3.F — Profile Avatar — Medium (40 words), verbatim
    CameraContext.profileAvatar: CameraCopy(
      title: 'Ảnh đại diện giúp bạn được tin tưởng hơn',
      body:
          'Ảnh đại diện giúp bạn được tin tưởng hơn:\n'
          '• Khách hoặc chủ nhà có khả năng chọn bạn hơn 3 lần\n'
          '• Ảnh rõ ràng, thân thiện giúp bao quanh đó biết bạn là ai\n'
          '• 100% bảo mật: bạn kiểm soát ai có thể xem ảnh.',
    ),

    // Spec table line 90 — reportErrorPhoto — NEW inline (not in research)
    CameraContext.reportErrorPhoto: CameraCopy(
      title: 'Chụp ảnh sự cố',
      body:
          'Chụp ảnh sự cố để chúng tôi xử lý nhanh hơn. '
          'Ảnh giúp đội hỗ trợ hiểu vấn đề chính xác trong vài giây.',
    ),
  };

  // ─────────────────────────────────────────────────────────────────────────
  // Universal button labels (AC-N1, AC-C1 — see wireframe in phase spec)
  // ─────────────────────────────────────────────────────────────────────────

  /// Primary action — notification sheet
  static const String btnEnable = 'Bật ngay';

  /// Secondary / defer — notification sheet
  static const String btnDefer = 'Để sau';

  /// Primary action — camera sheet (AC-C1 "Tiếp tục")
  static const String btnContinue = 'Tiếp tục';

  /// Secondary cancel — camera sheet (AC-C1 "Hủy")
  static const String btnCancel = 'Hủy';

  /// Generic close X button accessible label
  static const String btnClose = 'Đóng';

  // ─────────────────────────────────────────────────────────────────────────
  // Trust signals shown below benefit list in notification sheet
  // ─────────────────────────────────────────────────────────────────────────

  static const String trustCanDisable = 'Tắt bất kỳ lúc nào';
  static const String trustNoSpam = 'Không spam — chỉ thông tin hữu ích';

  // ─────────────────────────────────────────────────────────────────────────
  // Soft re-ask banner — Pattern B (Section 5 + spec table lines 91–92)
  // ─────────────────────────────────────────────────────────────────────────

  /// Inline text for denied notification soft re-ask banner.
  static const String softReaskNotif =
      'Bạn đã tắt thông báo. Bật trong Cài đặt để không bỏ lỡ tin nhắn.';

  /// Inline text for denied camera soft re-ask banner.
  static const String softReaskCamera =
      'Bạn đã tắt camera. Bật trong Cài đặt để chụp ảnh phòng.';

  /// CTA label on soft re-ask banner.
  static const String softReaskOpenSettings = 'Mở Cài đặt';

  /// Dismiss label on soft re-ask banner.
  static const String softReaskDismiss = 'Bỏ qua';

  // ─────────────────────────────────────────────────────────────────────────
  // Settings card (Section 5 Pattern A)
  // ─────────────────────────────────────────────────────────────────────────

  static const String settingsNotifTitle = 'Thông báo';
  static const String settingsCameraTitle = 'Camera';
  static const String settingsStatusEnabled = 'Đã bật';
  static const String settingsStatusDisabled = 'Đã tắt';
  static const String settingsActionEnable = 'Bật → Đi tới Cài đặt';
}

/// Localization-aware accessor for priming copy.
///
/// Reads from [AppLocalizations] when a [BuildContext] is available, enabling
/// JP (and future) translations. Falls back to the [PrimingCopy] const values
/// when called outside widget tree (e.g., in tests without a locale).
///
/// Usage in widgets:
/// ```dart
/// final l10n = PrimingL10n.of(context);
/// Text(l10n.btnEnable)
/// ```
class PrimingL10n {
  const PrimingL10n._(this._l);

  final AppLocalizations _l;

  /// Returns [PrimingL10n] backed by [AppLocalizations.of(context)].
  static PrimingL10n of(BuildContext context) {
    return PrimingL10n._(AppLocalizations.of(context));
  }

  String get btnEnable => _l.primingBtnEnable;
  String get btnDefer => _l.primingBtnDefer;
  String get btnContinue => _l.primingBtnContinue;
  String get btnCancel => _l.primingBtnCancel;
  String get btnClose => _l.primingBtnClose;
  String get trustCanDisable => _l.primingTrustCanDisable;
  String get trustNoSpam => _l.primingTrustNoSpam;
  String get softReaskNotif => _l.primingSoftReaskNotif;
  String get softReaskCamera => _l.primingSoftReaskCamera;
  String get softReaskOpenSettings => _l.primingSoftReaskOpenSettings;
  String get softReaskDismiss => _l.primingSoftReaskDismiss;
  String get settingsNotifTitle => _l.primingSettingsNotifTitle;
  String get settingsCameraTitle => _l.primingSettingsCameraTitle;
  String get settingsStatusEnabled => _l.primingSettingsStatusEnabled;
  String get settingsStatusDisabled => _l.primingSettingsStatusDisabled;
  String get settingsActionEnable => _l.primingSettingsActionEnable;
}
