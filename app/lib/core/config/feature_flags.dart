/// Compile-time feature flags surfaced via `--dart-define`.
///
/// Per Q7 lock (2026-07-02): flags are build-time only, no Remote Config.
/// Toggle by passing `--dart-define=FLAG_NAME=true` at `flutter build` /
/// `flutter run` time.
///
/// Any flag that gates a partially-shipped shell (see [roleShellsV2Enabled])
/// MUST leave both code paths in place so a rollback is a build-flag flip,
/// not a code revert.
library;

class FeatureFlags {
  const FeatureFlags._();

  /// Enables role-specific shell routing (Phase 04):
  /// - Operator (auth guest + active delegation) auto-lands on `/operator`
  ///   instead of the default GuestShell at `/`.
  /// - Tenant shell (blocked on backend U2) will opt in here once backend
  ///   ships the tenant JWT endpoint.
  ///
  /// Default: OFF for progressive rollout (Q11 — Admin ships first inside
  /// the existing router; Operator behind this flag; Tenant deferred).
  static const bool roleShellsV2Enabled = bool.fromEnvironment(
    'ROLE_SHELLS_V2_ENABLED',
    defaultValue: false,
  );

  /// Enables tenant shell scaffolding. Gated separately from
  /// [roleShellsV2Enabled] so tenant work can be dark-launched.
  ///
  /// Default: OFF — backend U2 (tenant JWT endpoint) is not yet available.
  static const bool tenantShellEnabled = bool.fromEnvironment(
    'TENANT_SHELL_ENABLED',
    defaultValue: false,
  );

  /// Build-time feature flag for the "post transaction picker + auto-publish" release.
  /// Shows the "Đăng cho thuê / Đăng bán" segmented picker on the post-listing form
  /// and removes the client-side `status: 'pending'` override so backend defaults apply.
  ///
  /// Toggle via: `flutter run --dart-define=LISTING_V2_ENABLED=true`
  /// Default: ON (true) — picker is shown by default.
  static const bool listingV2Enabled = bool.fromEnvironment(
    'LISTING_V2_ENABLED',
    defaultValue: true,
  );

  /// Bật mảng MUA/BÁN bất động sản. Theo quyết định pivot (2026-07): tập trung
  /// sàn THUÊ & CHO THUÊ, loại bỏ đăng tin BĐS mua/bán (dễ tạo rác).
  /// OFF (default) → ẩn segmented "Mua bán" ở trang chủ + nút "Tính khoản vay"
  /// (công cụ cho người mua). Giữ code sau flag để bật lại chỉ bằng build-flag,
  /// không cần revert (nguyên tắc dark-launch của repo). So sánh BĐS GIỮ vì
  /// vẫn hữu ích cho nhà thuê.
  ///
  /// Toggle: `flutter build web --dart-define=SALE_ENABLED=true`
  static const bool saleEnabled = bool.fromEnvironment(
    'SALE_ENABLED',
    defaultValue: false,
  );

  /// Đợt 2 redesign quản trị host: bỏ tab lồng (Tin đăng/Nhà trọ trong "Tổng
  /// quan") → 1 dashboard vận hành trực tiếp, Tin đăng chuyển sang nút phụ.
  /// OFF (default) → giữ nguyên 2-tab hiện tại (dark-launch, rủi ro 0 cho user).
  /// Bật để QA trên thiết bị thật trước khi rollout: `--dart-define=HOST_SINGLE_DASHBOARD=true`.
  static const bool hostSingleDashboard = bool.fromEnvironment(
    'HOST_SINGLE_DASHBOARD',
    defaultValue: false,
  );

  /// Siêu app nav: bottom-bar 4 mục + FAB tròn giữa (kiểu bTaskee) thay
  /// NavigationBar phẳng. Đổi điều hướng lõi → default OFF (dark-launch),
  /// QA thiết bị thật trước khi bật: `--dart-define=SUPER_APP_NAV=true`.
  static const bool superAppNav = bool.fromEnvironment(
    'SUPER_APP_NAV',
    defaultValue: false,
  );

  /// Redesign v2 — hiện GATE **P1 (khảo sát phân loại)**, rủi ro thấp nên
  /// default ON (không phụ thuộc dart-define, tránh rebuild làm mất tính năng).
  /// P2/P3 (đổi điều hướng/feed thi công) rủi ro cao → khi làm sẽ gate bằng flag
  /// RIÊNG (default OFF, dark-launch), KHÔNG dùng chung flag này.
  static const bool redesignV2 = bool.fromEnvironment(
    'REDESIGN_V2',
    defaultValue: true,
  );

  /// Redesign v2 P2/P3: top split "Bất động sản | Thi công" + feed thi công.
  /// Đã QA (2 world render, 0 crash) → default ON để cố định, không phụ thuộc
  /// build flag. Tắt nhanh nếu cần: `--dart-define=WORLD_SPLIT=false`.
  static const bool worldSplit = bool.fromEnvironment(
    'WORLD_SPLIT',
    defaultValue: true,
  );

  /// Browse-first: khách CHƯA đăng nhập vẫn mở thẳng GuestShell (xem danh sách,
  /// chi tiết, bản đồ, xếp hạng). Mọi hành động cá nhân (lưu/liên hệ/đăng/chat/
  /// cộng đồng) yêu cầu đăng nhập qua bottom-sheet. Default ON (chủ SP duyệt);
  /// tắt để về tường login cũ: `--dart-define=GUEST_BROWSE=false`.
  static const bool guestBrowse = bool.fromEnvironment(
    'GUEST_BROWSE',
    defaultValue: true,
  );

  /// Khối VIDEO REEL (kiểu Facebook Reels) ở đầu MỌI feed (BĐS, Thi công, Cộng
  /// đồng). Default ON. Tắt nhanh nếu tốn băng thông/spam:
  /// `--dart-define=REELS_ENABLED=false` (backend còn kill-switch `reels_enabled`).
  static const bool reelsEnabled = bool.fromEnvironment(
    'REELS_ENABLED',
    defaultValue: true,
  );

  // ── JP Market (Phase 00) ─────────────────────────────────────────────────

  /// Build-time region identifier. Defaults to 'vn' (Vietnam).
  ///
  /// Set to 'jp' to enable Japan-market behaviour: Noto Sans JP font, ¥ currency
  /// formatting, JST timezone, Japanese locale, and VN-only route gating.
  ///
  /// Toggle: `flutter build web --dart-define=REGION=jp`
  static const String region = String.fromEnvironment(
    'REGION',
    defaultValue: 'vn',
  );

  /// True when the build targets the Japan market (`--dart-define=REGION=jp`).
  static bool get isJapan => region == 'jp';
}

/// Top-level alias for [FeatureFlags.listingV2Enabled] — allows
/// `if (kListingV2Enabled)` call-sites consistent with the spec.
const bool kListingV2Enabled = FeatureFlags.listingV2Enabled;

/// Top-level alias for [FeatureFlags.saleEnabled].
const bool kSaleEnabled = FeatureFlags.saleEnabled;
