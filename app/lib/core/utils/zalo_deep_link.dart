/// Phase 04 — Zalo deep-link helper for invoice share.
///
/// Mirrors backend `app/utils/zalo.py`:
///   - normalises VN phone (strips +84/84/0 prefix, reformats with 0)
///   - builds `https://zalo.me/{phone}?body={quotedMessage}` URL
///
/// Used by the host invoice detail screen to launch Zalo chat with the tenant.

/// Normalises a Vietnamese phone number to local `0xxxxxxxxx` form.
/// Returns the input unchanged if it can't be parsed.
String normaliseVnPhone(String raw) {
  final stripped = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  String digits;
  if (stripped.startsWith('+84')) {
    digits = '0${stripped.substring(3)}';
  } else if (stripped.startsWith('84')) {
    digits = '0${stripped.substring(2)}';
  } else if (stripped.startsWith('0')) {
    digits = stripped;
  } else {
    digits = '0$stripped';
  }
  return digits;
}

/// Builds a Zalo share-link URL.
String buildZaloShareLink(String phone, String message) {
  final norm = normaliseVnPhone(phone);
  final body = Uri.encodeQueryComponent(message);
  return 'https://zalo.me/$norm?body=$body';
}
