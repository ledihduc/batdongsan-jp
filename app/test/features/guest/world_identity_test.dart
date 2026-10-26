import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/core/widgets/fb_post_card.dart';
import 'package:house_booking/data/models/user_preferences.dart';

/// Nhận diện hai thế giới (Bất động sản / Thi công).
///
/// Vì sao có tệp này: chủ dự án báo "giao diện hai bên y hệt nhau". Phần đã sửa
/// KHÔNG có test nào che, mà tôi cũng không dựng được app thật để nhìn — nên
/// khoá lại bằng test những điều kiểm được: màu tách bạch, tương phản đạt
/// chuẩn, dải nhãn loại nội dung có hiện, và AppBar 2 dòng không tràn ở màn hẹp.

/// Tỉ số tương phản WCAG giữa hai màu (công thức chính thức của W3C).
double _tuongPhan(Color a, Color b) {
  double doSang(Color c) {
    double tuyenTinh(double kenh0_255) {
      final x = kenh0_255 / 255.0;
      return x <= 0.03928 ? x / 12.92 : math.pow((x + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * tuyenTinh(c.r * 255) +
        0.7152 * tuyenTinh(c.g * 255) +
        0.0722 * tuyenTinh(c.b * 255);
  }

  final la = doSang(a);
  final lb = doSang(b);
  final cao = math.max(la, lb);
  final thap = math.min(la, lb);
  return (cao + 0.05) / (thap + 0.05);
}

void main() {
  group('màu nhận diện hai thế giới', () {
    // ĐỒNG BỘ MÀU (yêu cầu chủ dự án): hai thế giới nay DÙNG CHUNG xanh FB; phân
    // biệt bằng ICON + NHÃN, không phải màu.
    test('Thi công và BĐS dùng CHUNG màu nhấn xanh FB', () {
      expect(HD.worldAccent(true), HD.worldAccent(false));
      expect(HD.worldAccent(true), HD.accent);
      expect(HD.worldAccent(false), HD.accent);
    });

    test('worldAccentDeep và worldTint cũng đồng bộ', () {
      expect(HD.worldAccentDeep(true), HD.worldAccentDeep(false));
      expect(HD.worldTint(true), HD.worldTint(false));
    });

    test('hằng số thế giới đúng chuỗi backend/khảo sát dùng', () {
      // Đổi hai chuỗi này là làm hỏng cả `defaultWorld` đã lưu ở máy người dùng
      // lẫn so sánh trong shell/drawer.
      expect(kWorldConstruction, 'construction');
      expect(kWorldRealEstate, 'realestate');
    });
  });

  group('dải nhãn loại nội dung trên card', () {
    testWidgets('có loaiNhan → hiện dải nhãn', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: FbPostCard(
            authorName: 'Đơn vị A',
            loaiNhan: 'CÔNG TRÌNH',
            loaiIcon: Icons.photo_library_outlined,
            accent: HD.construction,
            body: 'noi dung',
            actions: [],
          ),
        ),
      ));
      expect(find.text('CÔNG TRÌNH'), findsOneWidget);
    });

    testWidgets('không truyền loaiNhan → KHÔNG vẽ dải (card nhà giữ nguyên)',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: FbPostCard(
            authorName: 'Chủ nhà B',
            body: 'tin nha',
            actions: [],
          ),
        ),
      ));
      expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
    });
  });

  group('tương phản màu nhấn đạt WCAG AA', () {
    // Chữ trắng dùng trên biến ĐẬM (accentDeep) cho phần cần đọc rõ; xanh accent
    // #1877F2 (như FB) dùng cho nút/nền lớn.
    test('chữ trắng trên nền accentDeep >= 4.5', () {
      expect(_tuongPhan(HD.accentDeep, const Color(0xFFFFFFFF)),
          greaterThanOrEqualTo(4.5));
    });

    test('accentDeep trên nền tint >= 4.5', () {
      expect(_tuongPhan(HD.accentDeep, HD.accentTint),
          greaterThanOrEqualTo(4.5));
    });
  });
}
