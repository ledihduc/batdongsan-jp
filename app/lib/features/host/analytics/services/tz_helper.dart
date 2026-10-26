import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Timezone utilities for Asia/Ho_Chi_Minh (UTC+7).
///
/// All server datetimes are UTC. This helper converts them to HCM local time
/// for display purposes only. Period keys ("2026-07") are already HCM-scoped
/// and must NOT be converted — only raw UTC timestamps need conversion.
class TzHelper {
  TzHelper._();

  static bool _initialized = false;

  /// Lazily initialize timezone database (idempotent).
  static void _ensureInit() {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    _initialized = true;
  }

  static tz.Location get _hcm {
    _ensureInit();
    return tz.getLocation('Asia/Ho_Chi_Minh');
  }

  /// Convert a UTC [DateTime] to Asia/Ho_Chi_Minh local time.
  ///
  /// Input must be UTC (or will be treated as UTC if not specified).
  static DateTime toHcm(DateTime utc) {
    _ensureInit();
    final utcTime = tz.TZDateTime.from(
      utc.isUtc ? utc : utc.toUtc(),
      tz.UTC,
    );
    return tz.TZDateTime.from(utcTime, _hcm);
  }

  /// Returns the current time in Asia/Ho_Chi_Minh timezone.
  static DateTime hcmNow() {
    _ensureInit();
    return tz.TZDateTime.now(_hcm);
  }

  /// Returns midnight of the first day of [ref]'s month in HCM time.
  ///
  /// Example: ref = 2026-07-15 HCM → 2026-07-01T00:00:00 HCM
  static DateTime hcmStartOfMonth(DateTime ref) {
    _ensureInit();
    final hcmRef = ref is tz.TZDateTime ? ref : tz.TZDateTime.from(ref.toUtc(), _hcm);
    return tz.TZDateTime(_hcm, hcmRef.year, hcmRef.month, 1);
  }
}
