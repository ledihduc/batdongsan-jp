import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/room_model.dart';
import 'package:house_booking/features/host/property/providers/room_provider.dart';
import 'package:house_booking/features/host/property/screens/room_form_screen.dart';
import 'package:provider/provider.dart';

import '../../helpers/pump_app.dart';

/// SỬA PHÒNG — chủ nhà đổi lại thông tin phòng đã tạo.
///
/// Tới trước hôm nay việc này **không làm được**: `ApiRoomRepository.updateRoom`
/// có sẵn nhưng `RoomProvider` thiếu hẳn hàm và không màn nào gọi. Tạo phòng
/// xong là xong — sai mã phòng, sai giá điện, thiếu một món đồ, đều phải sống
/// chung với nó.
///
/// Hai điều phải giữ:
///
/// 1. **Không hỏi lại loại khai thác.** Kênh có vòng đời riêng (đang rao · giữ
///    chỗ · đã bán) và sửa nó ở tờ khai thông tin là đổi trạng thái bán hàng
///    bằng một cái form nhập liệu.
/// 2. **Ô giá tiện ích để trống = quay về giá toà.** Phải gửi `null` tường
///    minh; bỏ khoá đi thì PATCH giữ nguyên giá cũ và người dùng xoá mãi không
///    được.
class _ProviderGia extends RoomProvider {
  Map<String, dynamic>? daGoi;

  @override
  Future<bool> updateRoom(
    int roomId, {
    String? code,
    double? areaM2,
    int? capacity,
    double? basePrice,
    String? note,
    List<String>? images,
    double? giaDien,
    double? giaNuoc,
    double? phiDichVu,
    List<String>? dichVuGom,
    List<String>? doTrongPhong,
    bool xoaGiaTienIch = false,
    String? tang,
    String? huong,
    bool guiViTri = false,
  }) async {
    daGoi = {
      'tang': tang,
      'huong': huong,
      'gui_vi_tri': guiViTri,
      'room_id': roomId,
      'code': code,
      'base_price': basePrice,
      'gia_dien': giaDien,
      'gia_nuoc': giaNuoc,
      'dich_vu_gom': dichVuGom,
      'do_trong_phong': doTrongPhong,
      'xoa_gia_tien_ich': xoaGiaTienIch,
    };
    return true;
  }
}

RoomModel _phong({
  String code = 'P01',
  double? giaDien,
  List<String> doDac = const ['giuong'],
}) => RoomModel(
  id: 25,
  buildingId: 6,
  code: code,
  areaM2: 25,
  capacity: 2,
  basePrice: 5000000,
  status: 'vacant',
  images: const [],
  note: 'ghi chu cu',
  createdAt: DateTime(2026, 9, 9),
  updatedAt: DateTime(2026, 9, 9),
  giaDien: giaDien,
  dichVuGom: const ['gui_xe'],
  doTrongPhong: doDac,
);

Finder _o(String nhan) => find.descendant(
  of: find.byWidgetPredicate((w) => w is DsTextField && w.label == nhan),
  matching: find.byType(TextFormField),
);

Future<_ProviderGia> _dung(WidgetTester t, RoomModel p) async {
  final pr = _ProviderGia();
  t.view.physicalSize = const Size(520, 2600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await pumpApp(
    t,
    ChangeNotifierProvider<RoomProvider>.value(
      value: pr,
      child: RoomFormScreen(buildingId: 6, phong: p),
    ),
  );
  await t.pumpAndSettle();
  return pr;
}

void main() {
  testWidgets('mở ra là SỬA, không phải khai mới', (t) async {
    await _dung(t, _phong());
    expect(find.text('SỬA PHÒNG'), findsOneWidget);
    expect(find.text('Lưu thay đổi'), findsOneWidget);
    expect(find.text('Tạo phòng'), findsNothing);
  });

  testWidgets('KHÔNG hỏi lại loại khai thác', (t) async {
    // Kênh có vòng đời riêng; sửa ở đây là đổi trạng thái bán hàng bằng một
    // form nhập liệu.
    await _dung(t, _phong());
    expect(find.text('LOẠI KHAI THÁC'), findsNothing);
    expect(find.text('Cho thuê dài hạn / kinh doanh'), findsNothing);
  });

  testWidgets('điền sẵn dữ liệu cũ, không bắt gõ lại', (t) async {
    await _dung(t, _phong(code: 'P07', giaDien: 4500));
    expect(find.text('P07'), findsOneWidget);
    expect(find.text('5000000'), findsOneWidget);
    expect(find.text('4500'), findsOneWidget);
    expect(find.text('ghi chu cu'), findsOneWidget);
  });

  testWidgets('tick đồ đang có được đánh dấu sẵn', (t) async {
    await _dung(t, _phong(doDac: const ['giuong', 'dieu_hoa']));
    final chip = t.widgetList<FilterChip>(find.byType(FilterChip));
    final daChon = [
      for (final c in chip)
        if (c.selected) ((c.label as Text).data ?? ''),
    ];
    expect(daChon, containsAll(<String>['Giường', 'Điều hoà', 'Gửi xe']));
  });

  testWidgets('sửa mã phòng → gửi đúng mã mới', (t) async {
    final pr = await _dung(t, _phong());
    await t.enterText(_o('Mã phòng *'), 'P09');
    await t.tap(find.text('Lưu thay đổi'));
    await t.pumpAndSettle();
    expect(pr.daGoi!['room_id'], 25);
    expect(pr.daGoi!['code'], 'P09');
  });

  testWidgets('xoá trắng giá điện → gửi null KÈM cờ xoá', (t) async {
    // Bỏ khoá đi thì PATCH giữ nguyên giá cũ; người dùng xoá mãi không được.
    final pr = await _dung(t, _phong(giaDien: 4500));
    await t.enterText(_o('Giá điện (đ/kWh)'), '');
    await t.tap(find.text('Lưu thay đổi'));
    await t.pumpAndSettle();
    expect(pr.daGoi!['gia_dien'], isNull);
    expect(pr.daGoi!['xoa_gia_tien_ich'], isTrue);
  });

  testWidgets('khối điện nước LUÔN hỏi khi sửa', (t) async {
    // Phòng đang tồn tại chạy được nhiều kênh cùng lúc — gác theo một kênh là
    // khoá mất ô nhập của những kênh còn lại.
    await _dung(t, _phong());
    expect(find.text('ĐIỆN NƯỚC DỊCH VỤ'), findsOneWidget);
  });

  testWidgets('thiếu mã phòng → chặn, KHÔNG gọi API', (t) async {
    final pr = await _dung(t, _phong());
    await t.enterText(_o('Mã phòng *'), '');
    await t.tap(find.text('Lưu thay đổi'));
    await t.pumpAndSettle();
    expect(find.text('Vui lòng nhập mã phòng'), findsOneWidget);
    expect(pr.daGoi, isNull);
  });
}
