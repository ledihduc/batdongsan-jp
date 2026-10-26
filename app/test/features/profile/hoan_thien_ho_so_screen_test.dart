/// Khoá bước NHẬP THÔNG TIN sau khi đăng ký.
///
/// Hai điều dễ vỡ mà test này giữ:
///  1. Luồng bắt buộc phải THẬT SỰ chặn — không nút back, không lùi được. Bỏ
///     sót thì người dùng bấm back là vào app với hồ sơ trống, đúng thứ màn này
///     sinh ra để chặn.
///  2. Ràng buộc SĐT và giới thiệu phải chạy ở FE. Backend nhận cả hai trường
///     này không kèm ràng buộc nào, nên đây là chốt chặn duy nhất.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/features/auth/hoan_thien_ho_so_screen.dart';
import 'package:house_booking/providers/auth_provider.dart';

import '../../helpers/pump_app.dart';

class _AuthGia extends AuthProvider {
  _AuthGia(this._u);

  final UserModel? _u;

  /// Lần gọi lưu gần nhất — null nghĩa là chưa lưu lần nào.
  Map<String, String?>? daLuu;

  @override
  UserModel? get currentUser => _u;

  @override
  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? avatarPath,
    String? email,
    String? birthday,
    String? bio,
    String? idNumber,
  }) async {
    daLuu = {'phone': phone, 'bio': bio, 'avatarPath': avatarPath};
    return true;
  }
}

UserModel _moiDangKy() => UserModel(
  id: 7,
  name: 'Vũ Đình Văn',
  email: 'v@example.com',
  passwordHash: '',
  phone: '',
  avatarPath: '',
  role: 'guest',
  accountType: 'sale',
);

void main() {
  Future<_AuthGia> dung(WidgetTester t, {required bool batBuoc}) async {
    // Màn cao hơn 800px mặc định của test: nút submit nằm cuối một ListView,
    // ở khung mặc định nó chưa được dựng nên `find.text` trả về rỗng.
    t.view.physicalSize = const Size(500, 1800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final auth = _AuthGia(_moiDangKy());
    await pumpApp(t, HoanThienHoSoScreen(batBuoc: batBuoc), auth: auth);
    await t.pump();
    return auth;
  }

  /// `PopScope` có tham số kiểu nên `find.byType(PopScope)` không khớp — tìm
  /// bằng vị từ rồi đọc `canPop` qua dynamic.
  bool luiDuoc(WidgetTester t) {
    final w = t.widgetList(
      find.byWidgetPredicate((w) => w is PopScope),
    ).first as dynamic;
    return w.canPop as bool;
  }

  testWidgets('luồng bắt buộc không có nút quay lại', (t) async {
    await dung(t, batBuoc: true);
    expect(find.text('Còn một bước nữa'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(luiDuoc(t), isFalse);
  });

  testWidgets('mở từ tab Cá nhân thì lùi được', (t) async {
    await dung(t, batBuoc: false);
    expect(find.text('Hoàn thiện hồ sơ'), findsOneWidget);
    expect(luiDuoc(t), isTrue);
  });

  testWidgets('bỏ trống thì KHÔNG lưu, báo lỗi từng ô', (t) async {
    final auth = await dung(t, batBuoc: true);
    await t.tap(find.text('Xong, vào app'));
    await t.pump();
    expect(auth.daLuu, isNull);
    expect(
      find.text('Nhập số điện thoại để khách liên hệ được'),
      findsOneWidget,
    );
    expect(find.text('Viết vài dòng để khách biết bạn làm gì'), findsOneWidget);
  });

  testWidgets('giới thiệu cụt lủn cũng bị chặn', (t) async {
    final auth = await dung(t, batBuoc: true);
    await t.enterText(find.byType(TextFormField).first, '0901234567');
    await t.enterText(find.byType(TextFormField).last, 'ok');
    await t.tap(find.text('Xong, vào app'));
    await t.pump();
    expect(auth.daLuu, isNull);
    expect(find.textContaining('ít nhất 20 ký tự'), findsOneWidget);
  });

  testWidgets('số điện thoại sai độ dài bị chặn', (t) async {
    final auth = await dung(t, batBuoc: true);
    await t.enterText(find.byType(TextFormField).first, '0901');
    await t.enterText(
      find.byType(TextFormField).last,
      'Chuyên nhà phố khu vực Thủ Đức, sáu năm trong nghề.',
    );
    await t.tap(find.text('Xong, vào app'));
    await t.pump();
    expect(auth.daLuu, isNull);
    expect(find.text('Số điện thoại không hợp lệ'), findsOneWidget);
  });

  testWidgets('điền đủ thì lưu đúng nội dung', (t) async {
    final auth = await dung(t, batBuoc: true);
    await t.enterText(find.byType(TextFormField).first, '0901234567');
    await t.enterText(
      find.byType(TextFormField).last,
      'Chuyên nhà phố và căn hộ khu vực Thủ Đức, sáu năm trong nghề.',
    );
    await t.tap(find.text('Xong, vào app'));
    await t.pump();
    expect(auth.daLuu?['phone'], '0901234567');
    expect(auth.daLuu?['bio'], contains('Thủ Đức'));
    // Không chọn ảnh mới -> gửi null để repository bỏ qua, KHÔNG xoá ảnh cũ.
    expect(auth.daLuu?['avatarPath'], isNull);
  });

  testWidgets('chip gợi ý chèn được câu mở đầu', (t) async {
    await dung(t, batBuoc: true);
    await t.tap(find.text('Nhận ký gửi bán, cho thuê tại'));
    await t.pump();
    expect(find.textContaining('Nhận ký gửi bán'), findsWidgets);
  });
}
