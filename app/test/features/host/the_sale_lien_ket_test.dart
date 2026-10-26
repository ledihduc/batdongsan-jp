/// Thẻ SALE PHỤ TRÁCH trên màn quản lý của chủ nhà.
///
/// Chủ nhà không tự tìm khách — người họ gọi khi phòng trống là sale. Số đó
/// phải nằm ở màn mở hằng ngày, không phải sau ba lớp menu.
///
/// Hai bất biến: chỉ hiện liên kết CÒN HIỆU LỰC, và API hỏng thì ẩn im lặng
/// (đây là thẻ phụ, không được làm vỡ màn quản lý).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/services/sale_link_api.dart';
import 'package:house_booking/features/host/widgets/the_sale_lien_ket.dart';

import '../../helpers/pump_app.dart';

class _ApiGia extends SaleLinkApi {
  _ApiGia(this._ds, {this.loi = false});

  final List<LienKet> _ds;
  final bool loi;

  @override
  Future<List<LienKet>> cuaToiBenChu() async {
    if (loi) throw Exception('mạng hỏng');
    return _ds;
  }
}

LienKet _lk({
  String ten = 'Vũ Đình Văn',
  String trangThai = 'active',
  int buildingId = 10,
  String buildingName = 'Toà Hoa Sữa',
}) => LienKet(
  id: buildingId,
  saleId: 58,
  ownerId: 61,
  tenDoiPhuong: ten,
  trangThai: trangThai,
  buildingId: buildingId,
  buildingName: buildingName,
);

Future<void> _dung(WidgetTester t, _ApiGia api) async {
  await pumpApp(t, Scaffold(body: TheSaleLienKet(api: api)));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('có sale đang phụ trách → hiện tên', (t) async {
    await _dung(t, _ApiGia([_lk()]));
    expect(find.text('Sale đang phối hợp'), findsOneWidget);
    expect(find.text('Vũ Đình Văn'), findsOneWidget);
    expect(find.text('Toà Hoa Sữa'), findsOneWidget);
  });

  testWidgets('Nhiều toà có sale riêng → hiện từng sale và đúng toà', (
    t,
  ) async {
    // Mỗi toà có một sale; cùng chủ nhà có thể liên kết nhiều toà.
    await _dung(
      t,
      _ApiGia([
        _lk(ten: 'Vũ Đình Văn'),
        _lk(
          ten: 'Lê Quang Vinh',
          buildingId: 20,
          buildingName: 'Toà Phượng Vĩ',
        ),
      ]),
    );
    expect(find.text('Vũ Đình Văn'), findsOneWidget);
    expect(find.text('Lê Quang Vinh'), findsOneWidget);
    expect(find.text('Toà Hoa Sữa'), findsOneWidget);
    expect(find.text('Toà Phượng Vĩ'), findsOneWidget);
    expect(find.text('Sale đang phối hợp'), findsOneWidget);
  });

  testWidgets('chưa liên kết ai → hiện lời mời, KHÔNG vẽ thẻ rỗng', (t) async {
    await _dung(t, _ApiGia(const []));
    expect(find.text('Liên kết với sale'), findsOneWidget);
    expect(find.text('Sale đang phối hợp'), findsNothing);
  });

  testWidgets('liên kết ĐÃ NGẮT không được hiện như đang phụ trách', (t) async {
    // Bản ghi giữ lại để tra lịch sử, không phải để khoe người đã nghỉ.
    await _dung(t, _ApiGia([_lk(trangThai: 'ended')]));
    expect(find.text('Liên kết với sale'), findsOneWidget);
    expect(find.text('Vũ Đình Văn'), findsNothing);
  });

  testWidgets('API hỏng → ẩn im lặng, không làm vỡ màn quản lý', (t) async {
    await _dung(t, _ApiGia(const [], loi: true));
    expect(find.text('Sale đang phối hợp'), findsNothing);
    expect(find.text('Liên kết với sale'), findsNothing);
  });
}
