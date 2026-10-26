/// Khoá luật "hồ sơ còn thiếu gì" và bước nhập thông tin sau khi đăng ký.
///
/// Vì sao đáng test: tài khoản mới nào cũng là tài khoản BÁN, tức là đăng ký
/// xong đã có một trang công khai. Nếu luật này lỏng (vd coi bio "ok" là đã
/// viết) thì thẻ nhắc tắt sớm và trang vẫn trống — đúng thứ nó sinh ra để chặn.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/features/guest/profile/ho_so_thieu.dart';

import '../../helpers/pump_app.dart';

UserModel _u({String avatar = '', String? bio, String phone = ''}) => UserModel(
  id: 1,
  name: 'Vũ Đình Văn',
  email: 'v@example.com',
  passwordHash: '',
  phone: phone,
  avatarPath: avatar,
  role: 'guest',
  accountType: 'sale',
  bio: bio,
);

void main() {
  group('HoSoThieu', () {
    test('tài khoản vừa đăng ký thiếu cả ba mục', () {
      final t = HoSoThieu.tu(_u());
      expect(t.thieuAnh, isTrue);
      expect(t.thieuGioiThieu, isTrue);
      expect(t.thieuSoDienThoai, isTrue);
      expect(t.soMucThieu, 3);
      expect(t.daXong, isFalse);
      expect(t.tiLe, 0);
    });

    test('điền đủ thì hết thiếu', () {
      final t = HoSoThieu.tu(
        _u(
          avatar: '/uploads/a.png',
          phone: '0901234567',
          bio: 'Chuyên nhà phố và căn hộ khu vực Thủ Đức, sáu năm trong nghề.',
        ),
      );
      expect(t.daXong, isTrue);
      expect(t.tiLe, 1);
      expect(t.tenMucThieu, isEmpty);
    });

    test('giới thiệu quá ngắn vẫn tính là THIẾU', () {
      // "ok" khác rỗng nhưng khách xem trang vẫn không biết gì về người bán.
      expect(HoSoThieu.tu(_u(bio: 'ok')).thieuGioiThieu, isTrue);
      expect(HoSoThieu.tu(_u(bio: '   ')).thieuGioiThieu, isTrue);
    });

    test('chuỗi toàn khoảng trắng không tính là đã điền', () {
      final t = HoSoThieu.tu(_u(avatar: '   ', phone: '  '));
      expect(t.thieuAnh, isTrue);
      expect(t.thieuSoDienThoai, isTrue);
    });

    test('chưa đăng nhập thì không nhắc gì', () {
      expect(HoSoThieu.tu(null).daXong, isTrue);
    });

    test('thứ tự nhắc: SĐT trước, ảnh sau cùng', () {
      expect(HoSoThieu.tu(_u()).tenMucThieu, [
        'Số điện thoại',
        'Giới thiệu',
        'Ảnh đại diện',
      ]);
    });
  });

  group('TheHoanThienHoSo', () {
    testWidgets('thiếu thì hiện, nói rõ thiếu gì', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: TheHoanThienHoSo(thieu: HoSoThieu.tu(_u()), onNhan: () {}),
        ),
      );
      expect(find.text('Hoàn thiện hồ sơ'), findsOneWidget);
      expect(find.text('0/3'), findsOneWidget);
      expect(
        find.textContaining('Số điện thoại · Giới thiệu'),
        findsOneWidget,
      );
    });

    testWidgets('đủ rồi thì tự ẩn, không chiếm chỗ', (tester) async {
      final xong = HoSoThieu.tu(
        _u(
          avatar: '/uploads/a.png',
          phone: '0901234567',
          bio: 'Chuyên nhà phố và căn hộ khu vực Thủ Đức, sáu năm trong nghề.',
        ),
      );
      await pumpApp(
        tester,
        Scaffold(body: TheHoanThienHoSo(thieu: xong, onNhan: () {})),
      );
      expect(find.text('Hoàn thiện hồ sơ'), findsNothing);
    });

    testWidgets('bấm vào thẻ thì gọi onNhan', (tester) async {
      var mo = 0;
      await pumpApp(
        tester,
        Scaffold(
          body: TheHoanThienHoSo(thieu: HoSoThieu.tu(_u()), onNhan: () => mo++),
        ),
      );
      await tester.tap(find.text('Hoàn thiện hồ sơ'));
      await tester.pump();
      expect(mo, 1);
    });
  });
}
