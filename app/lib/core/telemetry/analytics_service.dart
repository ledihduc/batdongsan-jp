import 'package:flutter/foundation.dart';

/// Lightweight analytics facade. Currently a noop that prints in debug mode.
///
/// Q8 decision — stub interface so audit call sites (role_upgraded,
/// permission_denied) can be wired now and swapped for Firebase Analytics
/// / Sentry later without touching call sites.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  void logEvent(String name, {Map<String, Object?> props = const {}}) {
    if (kDebugMode) {
      debugPrint('[analytics] $name ${props.isEmpty ? '' : props}');
    }
    // TODO(analytics): wire to Firebase Analytics / Sentry when infra ready.
  }
}
