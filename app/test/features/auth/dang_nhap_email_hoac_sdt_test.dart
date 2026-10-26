/// Một ô đăng nhập cho CẢ email lẫn số điện thoại.
///
/// Người Việt nhớ số của mình chắc hơn nhớ email, và nhiều người bán chỉ dùng
/// Zalo. Bắt buộc email lúc đăng ký là một rào chắn ngay ở cửa vào.
///
/// Phần kiểm ở app CHỈ để báo sớm cho người dùng; quyền phán quyết ở máy chủ
/// (`app/services/dinh_danh.py`). Vì vậy test ở đây canh **thông báo nói đúng
/// thứ người ta đang gõ** — gõ số mà bị mắng "email chưa đúng định dạng" thì họ
/// không hiểu mình sai ở đâu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/core/utils/dinh_danh.dart';
import 'package:house_booking/features/auth/login_screen.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('phân loại email / số', () {
    test('có @ là email', () {
      expect(DinhDanh.laEmail('a@b.com'), isTrue);
      expect(DinhDanh.laEmail('0912345678'), isFalse);
    });

    test('nhận mọi cách gõ số quen thuộc', () {
      for (final s in [
        '0912345678',
        '+84912345678',
        '84912345678',
        '0912 345 678',
        '0912.345.678',
        '+84 912 345 678',
        '0387654321',
      ]) {
        expect(DinhDanh.sdtHopLe(s), isTrue, reason: s);
      }
    });

    test('KHÔNG nhận số bàn và số sai độ dài', () {
      // Số bàn 02x là số dùng chung của cả văn phòng — không phải định danh.
      for (final s in ['0212345678', '091234567', '09123456789', 'abc', '']) {
        expect(DinhDanh.sdtHopLe(s), isFalse, reason: s);
      }
    });

    test('email sai dạng bị bắt', () {
      expect(DinhDanh.hopLe('a@b'), isFalse);
      expect(DinhDanh.hopLe('@b.com'), isFalse);
      expect(DinhDanh.hopLe('a@b.com'), isTrue);
    });
  });

  group('màn đăng nhập', () {
    Future<void> dung(WidgetTester t) async {
      t.view.physicalSize = const Size(500, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await pumpApp(t, const LoginScreen());
      await t.pumpAndSettle();
    }

    testWidgets('ô đầu tiên nói rõ nhận CẢ HAI', (t) async {
      await dung(t);
      // `DsTextField` IN HOA nhãn, nên tìm đúng chuỗi hiện ra màn hình chứ
      // không phải chuỗi trong tệp dịch.
      expect(find.text('EMAIL HOẶC SỐ ĐIỆN THOẠI'), findsOneWidget);
      // Nhãn cũ chỉ nói "Email" — người có mỗi số sẽ nghĩ mình không đăng nhập
      // được rồi bỏ đi.
      expect(find.text('EMAIL'), findsNothing);
    });

    testWidgets('bỏ trống → đòi email HOẶC số, không đòi riêng email', (
      t,
    ) async {
      await dung(t);
      await t.tap(find.text('Đăng nhập'));
      await t.pumpAndSettle();
      expect(find.text('Nhập email hoặc số điện thoại'), findsOneWidget);
    });

    testWidgets('gõ SỐ sai → báo lỗi theo SỐ, không mắng về email', (t) async {
      await dung(t);
      await t.enterText(find.byType(TextFormField).first, '0212345678');
      await t.tap(find.text('Đăng nhập'));
      await t.pumpAndSettle();
      expect(find.textContaining('Số điện thoại chưa đúng'), findsOneWidget);
    });

    testWidgets('gõ EMAIL sai → báo lỗi theo email', (t) async {
      await dung(t);
      await t.enterText(find.byType(TextFormField).first, 'abc@def');
      await t.tap(find.text('Đăng nhập'));
      await t.pumpAndSettle();
      expect(find.text('Email chưa đúng định dạng'), findsOneWidget);
    });

    testWidgets('số hợp lệ → qua được cửa kiểm ở app', (t) async {
      await dung(t);
      await t.tap(find.byKey(const ValueKey('login-account-picker')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('login-role-customer')));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, '0912345678');
      await t.enterText(find.byType(TextFormField).last, 'Matkhau.123');
      // Validate the complete form, including the role, without making a real
      // HTTP request. Submission is covered with a fake server in role tests.
      expect(t.state<FormState>(find.byType(Form)).validate(), isTrue);
      await t.pumpAndSettle();
      expect(find.text('Nhập email hoặc số điện thoại'), findsNothing);
      expect(find.textContaining('Số điện thoại chưa đúng'), findsNothing);
    });
  });
}
