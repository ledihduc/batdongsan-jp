/// Màu pin bản đồ (0074) — luật phân màu là thứ người dùng đọc bản đồ dựa vào,
/// nên nó phải được canh bằng test chứ không chỉ bằng mắt.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/core/theme/design_tokens.dart';

void main() {
  group('pinColorFor', () {
    test('tin BÁN luôn tím, bất kể thuộc nhóm nào', () {
      for (final g in ['stay_long', 'stay_short', 'business', '', null]) {
        expect(HD.pinColorFor(g, isSale: true), HD.pinSale,
            reason: 'nhóm $g khi bán phải ra màu bán');
      }
    });

    test('tin cho thuê đổi màu theo nhóm', () {
      expect(HD.pinColorFor('stay_long', isSale: false), HD.pinStayLong);
      expect(HD.pinColorFor('stay_short', isSale: false), HD.pinStayShort);
      expect(HD.pinColorFor('business', isSale: false), HD.pinBusiness);
    });

    test('nhóm rỗng/lạ rơi về dài hạn, KHÔNG mất pin', () {
      expect(HD.pinColorFor('', isSale: false), HD.pinStayLong);
      expect(HD.pinColorFor(null, isSale: false), HD.pinStayLong);
      expect(HD.pinColorFor('nhom-la', isSale: false), HD.pinStayLong);
    });

    test('4 màu phải KHÁC NHAU và khác đỏ thương hiệu', () {
      final mau = {HD.pinStayLong, HD.pinStayShort, HD.pinBusiness, HD.pinSale};
      expect(mau.length, 4, reason: 'trùng màu = mất ý nghĩa phân loại');
      expect(mau.contains(HD.accent), isFalse,
          reason: 'đỏ dành riêng cho pin ĐANG CHỌN');
    });

    test('chữ trắng trên mọi màu pin phải đủ tương phản (WCAG AA large)', () {
      for (final c in [
        HD.pinStayLong,
        HD.pinStayShort,
        HD.pinBusiness,
        HD.pinSale,
      ]) {
        final ratio = (1.05) / (c.computeLuminance() + 0.05);
        expect(ratio, greaterThanOrEqualTo(3.0),
            reason: 'màu $c: chữ trắng trên pin giá không đọc nổi');
      }
    });
  });

  group('pinIconFor', () {
    test('mỗi nhóm một icon riêng — tin bán chung màu nên icon là thứ phân biệt',
        () {
      final icons = {
        HD.pinIconFor('stay_long'),
        HD.pinIconFor('stay_short'),
        HD.pinIconFor('business'),
      };
      expect(icons.length, 3);
    });

    test('nhóm lạ vẫn ra icon hợp lệ', () {
      expect(HD.pinIconFor(null), isA<IconData>());
    });
  });
}
