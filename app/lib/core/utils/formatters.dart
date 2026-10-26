/// Format giá VND dạng "8.000.000đ" (đầy đủ) hoặc "8tr" (compact).
class PriceFormat {
  static String full(double price) {
    final v = price.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < v.length; i++) {
      if (i > 0 && (v.length - i) % 3 == 0) buf.write('.');
      buf.write(v[i]);
    }
    return '${buf.toString()}đ';
  }

  static String compact(double price) {
    if (price >= 1000000000) {
      final b = price / 1000000000;
      return '${b.toStringAsFixed(b % 1 == 0 ? 0 : 1)} tỷ';
    }
    if (price >= 1000000) {
      final m = price / 1000000;
      return '${m.toStringAsFixed(m % 1 == 0 ? 0 : 1)}tr';
    }
    if (price >= 1000) {
      final k = price / 1000;
      return '${k.toStringAsFixed(k % 1 == 0 ? 0 : 1)}k';
    }
    return '${price.toStringAsFixed(0)}đ';
  }
}
