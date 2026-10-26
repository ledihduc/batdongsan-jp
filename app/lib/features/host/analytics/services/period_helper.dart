/// Period type used across analytics screens.
enum PeriodType { month, year }

/// Helpers for period navigation, formatting, and TZ-safe date shifting.
///
/// "Period key" is the canonical ISO string sent to the backend:
///   month → "YYYY-MM"
///   year  → "YYYY"
class PeriodHelper {
  PeriodHelper._();

  /// Returns the backend period key for [type] and [date].
  ///
  /// month: "2026-07"
  /// year:  "2026"
  static String formatPeriodKey(PeriodType type, DateTime date) {
    if (type == PeriodType.month) {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    }
    return date.year.toString();
  }

  /// Shifts [base] by [delta] periods (positive = forward, negative = back).
  ///
  /// TZ-safe: operates on local year/month/day integers, never on raw
  /// millisecond offsets that can drift around DST transitions.
  ///
  /// Cross-year: Dec 2025 + 1 month → Jan 2026.
  /// Leap-year: Feb 29 2024 + 12 months → Feb 28 2025 (day clamped).
  static DateTime shift(PeriodType type, DateTime base, int delta) {
    if (type == PeriodType.year) {
      return _clampedDate(base.year + delta, base.month, base.day);
    }
    // month shift
    int totalMonths = base.year * 12 + (base.month - 1) + delta;
    final int newYear = totalMonths ~/ 12;
    final int newMonth = totalMonths % 12 + 1;
    final int maxDay = _daysInMonth(newYear, newMonth);
    final int newDay = base.day.clamp(1, maxDay);
    return DateTime(newYear, newMonth, newDay);
  }

  /// Human-readable label for UI display.
  ///
  /// [locale] currently supports 'vi' only (default).
  /// month: "Tháng 7/2026"
  /// year:  "Năm 2026"
  static String displayLabel(
    PeriodType type,
    DateTime date, {
    String locale = 'vi',
  }) {
    if (type == PeriodType.month) {
      return 'Tháng ${date.month}/${date.year}';
    }
    return 'Năm ${date.year}';
  }

  /// Parses a period key back to a DateTime (first day of the period).
  ///
  /// "2026-07" → DateTime(2026, 7, 1)
  /// "2026"    → DateTime(2026, 1, 1)
  static DateTime parseKey(PeriodType type, String key) {
    if (type == PeriodType.month) {
      final parts = key.split('-');
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
    }
    return DateTime(int.parse(key), 1, 1);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static DateTime _clampedDate(int year, int month, int day) {
    final max = _daysInMonth(year, month);
    return DateTime(year, month, day.clamp(1, max));
  }

  static int _daysInMonth(int year, int month) {
    // DateTime overflow trick: day 0 of next month = last day of this month
    return DateTime(year, month + 1, 0).day;
  }
}
