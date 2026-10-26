import 'package:flutter/foundation.dart';

/// Stub analytics cho planning feature.
///
/// KHÔNG log lat/lng raw — chỉ log zone_code (privacy).
/// TODO(analytics): tích hợp Firebase Analytics / Mixpanel khi user confirm
/// platform (Q5 BA open question). Thay debugPrint bằng actual SDK call.
class PlanningAnalytics {
  // Không cho phép khởi tạo — class chỉ chứa static methods.
  const PlanningAnalytics._();

  /// Ghi log khi modal cảnh báo vùng rủi ro được hiển thị.
  /// Tên event: `host_warned_zone_risky`.
  static void logRiskyWarning(String? zoneCode) {
    debugPrint('[planning_analytics] host_warned_zone_risky zone=$zoneCode');
    // TODO(analytics): FirebaseAnalytics.instance.logEvent(
    //   name: 'host_warned_zone_risky',
    //   parameters: {'zone_code': zoneCode ?? 'unknown'},
    // );
  }

  /// Ghi log khi user tap badge quy hoạch trên house detail.
  /// Tên event: `planning_badge_tap`.
  static void logBadgeTap(String? zoneCode) {
    debugPrint('[planning_analytics] planning_badge_tap zone=$zoneCode');
    // TODO(analytics): FirebaseAnalytics.instance.logEvent(
    //   name: 'planning_badge_tap',
    //   parameters: {'zone_code': zoneCode ?? 'unknown'},
    // );
  }

  /// Ghi log khi user tap nút "Kiểm tra quy hoạch" trên post-house screen.
  /// Tên event: `planning_check_button_tap`.
  static void logCheckButtonTap() {
    debugPrint('[planning_analytics] planning_check_button_tap');
    // TODO(analytics): FirebaseAnalytics.instance.logEvent(
    //   name: 'planning_check_button_tap',
    // );
  }
}
