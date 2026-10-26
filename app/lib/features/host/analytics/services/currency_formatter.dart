import 'package:intl/intl.dart';

/// Formats VND amounts per AC-03 requirements.
///
/// Uses vi_VN locale for full format; abbreviated form uses
/// Vietnamese short suffixes: k (nghìn), tr (triệu), tỷ (tỷ).
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _vndFull = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  /// Format [amount] as VND.
  ///
  /// [abbreviated] = false → "5.000.000 ₫"
  /// [abbreviated] = true  → "5 tr", "1,5 tr", "1,2k", "1,5 tỷ"
  static String format(double amount, {bool abbreviated = false}) {
    if (!abbreviated) {
      return _vndFull.format(amount);
    }
    return _abbreviate(amount);
  }

  /// Format a percentage value.
  ///
  /// Returns "—" when [pct] is null.
  /// Otherwise: "15.0%" with [decimals] decimal places.
  static String formatPct(double? pct, {int decimals = 1}) {
    if (pct == null) return '—';
    return '${pct.toStringAsFixed(decimals)}%';
  }

  static String _abbreviate(double amount) {
    const double billion = 1e9;
    const double million = 1e6;
    const double thousand = 1e3;

    if (amount.abs() >= billion) {
      final v = amount / billion;
      return '${_compact(v)} tỷ';
    }
    if (amount.abs() >= million) {
      final v = amount / million;
      return '${_compact(v)} tr';
    }
    if (amount.abs() >= thousand) {
      final v = amount / thousand;
      return '${_compact(v)}k';
    }
    return _vndFull.format(amount);
  }

  /// Formats a double compactly: removes trailing ".0", keeps up to 1 decimal.
  static String _compact(double v) {
    if (v == v.truncate()) {
      return v.truncate().toString();
    }
    // Keep 1 decimal place, strip trailing zero
    final s = v.toStringAsFixed(1);
    return s;
  }
}
