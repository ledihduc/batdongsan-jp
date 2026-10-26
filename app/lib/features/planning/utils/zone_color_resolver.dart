import 'package:flutter/material.dart';

/// Chuyển chuỗi hex màu quy hoạch thành Color với opacity phù hợp.
/// AC-11: dark mode dùng opacity thấp hơn 10% so với light.
Color resolveZoneColor(String? hex, {bool dark = false}) {
  Color base = Colors.blue.shade300;

  if (hex != null && hex.isNotEmpty) {
    try {
      base = Color(int.parse(hex.replaceFirst('#', '0xff')));
    } catch (_) {
      // hex không hợp lệ → dùng màu mặc định
    }
  }

  // dark mode: opacity 0.4 (= 0.5 - 10%); light mode: 0.5
  return dark ? base.withValues(alpha: 0.4) : base.withValues(alpha: 0.5);
}

/// Màu gốc (đục) của một vùng quy hoạch từ chuỗi hex backend trả về.
///
/// Tách riêng khỏi [resolveZoneColor] vì polygon trên bản đồ và ô màu trong
/// chú giải phải dùng CHUNG một nguồn màu — lệch nhau thì chú giải nói dối.
const Color kZoneFallbackColor = Color(0xFF4287F5);

Color parseZoneHex(String? hex) {
  if (hex == null || hex.isEmpty) return kZoneFallbackColor;
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? kZoneFallbackColor : Color(v);
}

/// Alpha dùng cho phần TÔ của polygon quy hoạch trên bản đồ web.
const double kZoneFillAlpha = 0.45;
