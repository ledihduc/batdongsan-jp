/// Giá theo THỊ TRƯỜNG (`japan`), chữ quanh giá theo NGÔN NGỮ giao diện (plan 20261027-1102 Phase 12, F-1/F-2).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/l10n/app_localizations.dart';

HouseModel _house(String tx, {double price = 150000}) => HouseModel(
      id: 1,
      hostId: 1,
      title: 't',
      description: '',
      categoryId: 1,
      price: price,
      area: 20,
      address: 'a',
      city: 'c',
      district: 'd',
      bedrooms: 1,
      bathrooms: 1,
      transactionType: tx,
    );

Future<Map<String, AppLocalizations>> _langs() async => {
      for (final c in const ['ja', 'vi', 'en']) c: await AppLocalizations.delegate.load(Locale(c)),
    };

void main() {
  test('price_format_full_japan_returns_yen_with_commas', () {
    // Act + Assert
    expect(PriceFormat.full(150000, japan: true), '¥150,000');
  });

  test('price_format_compact_japan_returns_yen_with_commas', () {
    // Act + Assert
    expect(PriceFormat.compact(150000, japan: true), '¥150,000');
  });

  test('price_format_full_vietnam_keeps_dong_format', () {
    // Act + Assert
    expect(PriceFormat.full(8000000, japan: false), '8.000.000đ');
    expect(PriceFormat.compact(8000000, japan: false), '8tr');
  });

  test('house_model_period_suffix_of_follows_ui_language', () async {
    // Arrange
    final l = await _langs();
    final rent = _house('rent');
    final sale = _house('sale');
    // Act + Assert
    expect([for (final c in ['ja', 'vi', 'en']) rent.periodSuffixOf(l[c]!)], ['/月', '/tháng', '/month']);
    expect([for (final c in ['ja', 'vi', 'en']) sale.periodSuffixOf(l[c]!)], ['', '', '']);
  });

  test('house_model_price_label_of_follows_ui_language', () async {
    // Arrange
    final l = await _langs();
    // Act + Assert
    expect([for (final c in ['ja', 'vi', 'en']) _house('rent').priceLabelOf(l[c]!)], ['賃料', 'Giá thuê', 'Rent']);
    expect([for (final c in ['ja', 'vi', 'en']) _house('sale').priceLabelOf(l[c]!)], ['価格', 'Giá bán', 'Price']);
  });

  test('house_model_price_compact_label_of_japan_yen_with_localized_suffix', () async {
    // Arrange — thẻ tin ở home/list dùng nhãn gọn: bản jp phải ra ¥ ở mọi ngôn ngữ, hậu tố theo ngôn ngữ
    final l = await _langs();
    final rent = _house('rent');
    // Act + Assert
    expect(rent.priceCompactLabelOf(l['en']!, japan: true), '¥150,000/month');
    expect(rent.priceCompactLabelOf(l['ja']!, japan: true), '¥150,000/月');
    expect(_house('rent', price: 8000000).priceCompactLabelOf(l['vi']!, japan: false), '8tr/tháng');
  });

  test('house_model_legacy_getters_unchanged', () {
    // Arrange — màn ngoài luồng demo vẫn dùng getter cũ (NF-1)
    final rent = _house('rent');
    // Act + Assert
    expect(rent.priceLabel, 'Giá thuê');
    expect(rent.pricePeriodSuffix, '/tháng');
  });
}
