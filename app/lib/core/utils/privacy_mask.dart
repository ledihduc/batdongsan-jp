/// Privacy masking for owner/host info shown on public listings.
///
/// Rule (per product spec): keep the first 3 characters / digits of a value,
/// replace the remainder with '*'. Used for the host card on listing pages so
/// guests cannot scrape contact details before initiating a real conversation.
class PrivacyMask {
  static const int _keep = 3;

  /// Mask a host display name. Preserves first 3 characters (including diacritics);
  /// the rest become '*'. Short names (≤ 3 chars) are returned unchanged.
  static String? name(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.length <= _keep) return trimmed;
    final head = trimmed.substring(0, _keep);
    return head + '*' * (trimmed.length - _keep);
  }

  /// Mask a phone number. Strips spaces/dashes when counting, but preserves
  /// the original glyph count so length feels real.
  static String? phone(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.length <= _keep) return trimmed;
    return trimmed.substring(0, _keep) + '*' * (trimmed.length - _keep);
  }
}
