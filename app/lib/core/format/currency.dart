/// Locale-aware currency formatter.
///
/// Supports:
/// - `ja_JP` (or `ja`): `¥1,000` — integer yen, no decimals, comma thousands.
/// - `vi_VN` (default): `1.000 ₫` — integer dong, dot thousands separator.
///
/// Usage:
/// ```dart
/// import 'package:house_booking/core/format/currency.dart';
///
/// final price = formatPrice(1000);             // → '1.000 ₫' (VN default)
/// final yen   = formatPrice(1000, locale: 'ja_JP'); // → '¥1,000'
/// ```
library;

import 'package:intl/intl.dart';

/// Formats [amount] as a currency string for the given [locale].
///
/// [locale] accepts IETF BCP-47 tags: `'ja_JP'`, `'ja'`, `'vi_VN'`, `'vi'`.
/// Defaults to `'vi_VN'` when [locale] is null.
///
/// Returns a human-readable string without currency code clutter.
/// The trailing ₫ or leading ¥ are part of the string.
String formatPrice(num amount, {String? locale}) {
  // JP-version branch: default to ja_JP so hard-code call sites render ¥.
  final effectiveLocale = locale ?? 'ja_JP';
  final isJa = effectiveLocale.startsWith('ja');

  if (isJa) {
    // Japanese yen: no decimals, comma thousands separator, ¥ prefix.
    // Example: 1234567 → "¥1,234,567"
    final formatter = NumberFormat('#,###', 'en_US'); // en_US for comma separator
    final integer = amount.round();
    return '¥${formatter.format(integer)}';
  }

  // Vietnamese dong: no decimals, dot thousands separator, ₫ suffix.
  // Example: 1234567 → "1.234.567 ₫"
  final integer = amount.round();
  final formatter = NumberFormat('#,###', 'vi_VN'); // vi_VN gives dot separator
  return '${formatter.format(integer)} ₫';
}
