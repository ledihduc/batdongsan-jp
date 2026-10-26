/// Sale dựng dự án — hai điều dễ mất nhất.
///
/// 1. LỐI VÀO. `ProjectStrip` trước đây ẩn hẳn khi chưa có dự án nào, nên người
///    bán mới lập tài khoản mở trang mình ra không hề biết là dựng được dự án —
///    đường duy nhất nằm sau nút ⚙. Chỗ trống nhất của màn hình lại là chỗ duy
///    nhất không nói gì.
/// 2. KHÔNG ĐÒI TIN ĐĂNG TRƯỚC. Lời mời phải nói thẳng điều đó, vì thứ tự
///    "đăng tin rồi mới có dự án" là thứ người bán hay tự cho là bắt buộc.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/building_public_api.dart';
import 'package:house_booking/features/guest/project/project_strip.dart';

import '../../helpers/pump_app.dart';

/// API giả — trả đúng danh sách dự án được bơm vào, không chạm mạng.
class _ApiGia implements BuildingPublicApi {
  _ApiGia(this._ds);

  final List<DuAnTomTat> _ds;

  @override
  Future<List<DuAnTomTat>> cuaNguoi(int ownerId) async => _ds;

  /// `ProjectStrip` không gọi tới, nhưng `implements` đòi đủ mặt.
  @override
  Future<DuAnChiTiet?> chiTiet(int id) async => null;
}

DuAnTomTat _duAn() => const DuAnTomTat(
  id: 1,
  ten: 'Vinhomes Grand Park S1',
  diaChi: 'Nguyen Xien',
  quan: 'Thu Duc',
  tinh: 'TP Ho Chi Minh',
  soPhong: 12,
  soPhongTrong: 3,
  giaTu: 5000000,
);

Future<void> _dung(
  WidgetTester t, {
  required bool laChuTrang,
  List<DuAnTomTat> ds = const [],
}) async {
  await pumpApp(
    t,
    Scaffold(
      body: ProjectStrip(
        ownerId: 7,
        api: _ApiGia(ds),
        onSua: laChuTrang ? () {} : null,
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('chủ trang CHƯA có dự án → vẫn thấy lời mời tạo', (t) async {
    await _dung(t, laChuTrang: true);
    expect(find.text('Dựng dự án BĐS'), findsOneWidget);
  });

  testWidgets('lời mời nói rõ KHÔNG cần tin đăng trước', (t) async {
    await _dung(t, laChuTrang: true);
    expect(
      find.text('Chưa có tin đăng nào vẫn tạo được'),
      findsOneWidget,
    );
  });

  testWidgets('bấm vào lời mời thì mở được màn quản lý dự án', (t) async {
    var mo = 0;
    await pumpApp(
      t,
      Scaffold(
        body: ProjectStrip(ownerId: 7, api: _ApiGia(const []), onSua: () => mo++),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Dựng dự án BĐS'));
    await t.pump();
    expect(mo, 1);
  });

  testWidgets('KHÁCH xem trang người khác chưa có dự án → ẩn hẳn', (t) async {
    // Mời người lạ "dựng dự án" trên trang của người khác là vô nghĩa.
    await _dung(t, laChuTrang: false);
    expect(find.text('Dựng dự án BĐS'), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('dự án CHƯA CÓ PHÒNG → nhãn "Đang cập nhật", không phải "Hết phòng"', (
    t,
  ) async {
    // Sale dựng dự án trước rồi gắn tin sau là luồng hợp lệ. Gọi đó là "Hết
    // phòng" vừa sai với khách, vừa báo cho chính chủ vừa tạo xong rằng dự án
    // của họ đã bán sạch.
    await _dung(
      t,
      laChuTrang: true,
      ds: [
        const DuAnTomTat(
          id: 9,
          ten: 'Vin Home Ocean Park',
          diaChi: 'Da Ton',
          quan: 'Gia Lam',
          tinh: 'Ha Noi',
          soPhong: 0,
          soPhongTrong: 0,
        ),
      ],
    );
    expect(find.text('Đang cập nhật'), findsOneWidget);
    expect(find.text('Hết phòng'), findsNothing);
  });

  testWidgets('hết phòng trống THẬT (có phòng, 0 trống) vẫn ghi "Hết phòng"', (
    t,
  ) async {
    await _dung(
      t,
      laChuTrang: true,
      ds: [
        const DuAnTomTat(
          id: 9,
          ten: 'Toa da kin',
          diaChi: 'x',
          quan: 'y',
          tinh: 'z',
          soPhong: 6,
          soPhongTrong: 0,
        ),
      ],
    );
    expect(find.text('Hết phòng'), findsOneWidget);
    expect(find.text('Đang cập nhật'), findsNothing);
  });

  testWidgets('NHIỀU ảnh → thẻ kéo trượt được + có chấm trang', (t) async {
    // Một dự án gồm nhiều căn; khoe được đúng một khung hình thì khách không
    // hình dung nổi nó gồm những gì.
    await _dung(
      t,
      laChuTrang: true,
      ds: [
        const DuAnTomTat(
          id: 5,
          ten: 'Toa nhieu anh',
          diaChi: 'x',
          quan: 'y',
          tinh: 'z',
          soPhong: 3,
          soPhongTrong: 2,
          anh: ['/uploads/a.jpg', '/uploads/b.jpg', '/uploads/c.jpg'],
        ),
      ],
    );
    expect(find.byType(PageView), findsOneWidget);
    // Chấm trang: thiếu nó thì ảnh thứ hai trở đi vô hình, không ai nghĩ đến
    // chuyện vuốt một tấm ảnh trông như tĩnh.
    expect(find.byType(BangChuyenAnh), findsOneWidget);
  });

  testWidgets('MỘT ảnh → KHÔNG dựng PageView', (t) async {
    // Thẻ nằm trong dải trượt ngang; một vùng cuộn lồng vào chỉ cướp thao tác
    // vuốt của dải bên ngoài mà không đổi lại được gì.
    await _dung(
      t,
      laChuTrang: true,
      ds: [
        const DuAnTomTat(
          id: 5,
          ten: 'Toa mot anh',
          diaChi: 'x',
          quan: 'y',
          tinh: 'z',
          soPhong: 1,
          soPhongTrong: 1,
          anh: ['/uploads/a.jpg'],
        ),
      ],
    );
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('không ảnh nào → vẫn vẽ thẻ, không nổ', (t) async {
    await _dung(
      t,
      laChuTrang: true,
      ds: [
        const DuAnTomTat(
          id: 5,
          ten: 'Toa khong anh',
          diaChi: 'x',
          quan: 'y',
          tinh: 'z',
          soPhong: 0,
          soPhongTrong: 0,
        ),
      ],
    );
    expect(find.text('Toa khong anh'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('có dự án rồi thì hiện dải, không hiện lời mời', (t) async {
    await _dung(t, laChuTrang: true, ds: [_duAn()]);
    expect(find.text('Dựng dự án BĐS'), findsNothing);
    expect(find.text('Dự án BĐS'), findsOneWidget);
    expect(find.text('Vinhomes Grand Park S1'), findsOneWidget);
  });
}
