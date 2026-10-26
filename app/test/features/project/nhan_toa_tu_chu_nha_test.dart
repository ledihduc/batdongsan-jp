/// SALE nhập mã mời của CHỦ NHÀ để nhận phụ trách một toà.
///
/// Chiều ngược của mã bàn giao. Hai luồng song song vì ai chủ động cũng được:
///
///   sale dựng trước    → sale đưa mã bàn giao → chủ nhà nhận quyền SỞ HỮU
///   chủ nhà dựng trước → chủ nhà đưa mã mời   → sale nhận quyền PHỤ TRÁCH
///
/// Điều phải giữ bằng test:
///  1. **Xem trước rồi mới nhận.** Gõ tám ký tự rồi bấm mà không biết mình sắp
///     nhận toà nào, của ai, bao nhiêu phòng — đó là lúc người ta bỏ dở.
///  2. **Toà đã có sale thì nói TRƯỚC**, không để họ nhận xong mới ngạc nhiên.
///  3. **Mã sai chỉ có MỘT câu lỗi** — nói rõ hơn là biến ô này thành máy dò.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/models/phong_xem_truoc.dart';
import 'package:house_booking/data/services/moi_sale_api.dart';
import 'package:house_booking/features/guest/sale/nhan_toa_tu_chu_nha_screen.dart';

import '../../helpers/pump_app.dart';

class _ApiGia extends MoiSaleApi {
  _ApiGia({this.xem, this.nhanRa, this.loiXem = false, this.loiNhan = false});

  final LoiMoiToa? xem;
  final LoiMoiToa? nhanRa;
  final bool loiXem;
  final bool loiNhan;
  final List<String> daTra = [];
  final List<String> daNhan = [];

  @override
  Future<LoiMoiToa> xemTruoc(String ma) async {
    daTra.add(ma);
    if (loiXem) throw Exception('404');
    return xem!;
  }

  @override
  Future<LoiMoiToa> nhan(String ma) async {
    daNhan.add(ma);
    if (loiNhan) throw Exception('404');
    return nhanRa ?? xem!;
  }
}

LoiMoiToa _moi({
  bool daCoSale = false,
  int soPhong = 4,
  int soPhongNhan = 0,
  List<PhongXemTruoc> phong = const [
    PhongXemTruoc(ma: 'P01', dienTich: 25, sucChua: 2, gia: 5500000),
    PhongXemTruoc(
      ma: 'P02',
      dienTich: 82,
      sucChua: 1,
      gia: 12000000,
      conTrong: false,
    ),
  ],
  int conLai = 0,
}) => LoiMoiToa(
  buildingId: 7,
  ten: 'Toà Hoa Sữa',
  diaChi: '1 Lê Lợi',
  soPhong: soPhong,
  chuTen: 'Bà Mai',
  daCoSale: daCoSale,
  soPhongNhan: soPhongNhan,
  phong: phong,
  conLai: conLai,
);

Future<void> _dung(WidgetTester t, _ApiGia api) async {
  t.view.physicalSize = const Size(520, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await pumpApp(t, NhanToaTuChuNhaScreen(api: api));
  await t.pumpAndSettle();
}

Future<void> _go(WidgetTester t, String ma) async {
  await t.enterText(find.byType(TextField), ma);
  await t.tap(find.text('Tra mã'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('chưa tra thì CHƯA có nút nhận', (t) async {
    await _dung(t, _ApiGia(xem: _moi()));
    expect(find.text('Nhận toà này'), findsNothing);
  });

  testWidgets('bỏ trống mà bấm tra → đòi nhập mã, không gọi API', (t) async {
    final api = _ApiGia(xem: _moi());
    await _dung(t, api);
    await t.tap(find.text('Tra mã'));
    await t.pumpAndSettle();
    expect(find.text('Nhập mã chủ nhà gửi cho bạn'), findsOneWidget);
    expect(api.daTra, isEmpty);
  });

  testWidgets('tra xong hiện ĐỦ thứ cần biết trước khi nhận', (t) async {
    await _dung(t, _ApiGia(xem: _moi(soPhong: 4)));
    await _go(t, 'abcd2345');
    expect(find.text('Toà Hoa Sữa'), findsOneWidget);
    expect(find.text('1 Lê Lợi'), findsOneWidget);
    expect(find.textContaining('4 phòng'), findsOneWidget);
    expect(find.textContaining('Bà Mai'), findsOneWidget);
    expect(find.text('Nhận toà này'), findsOneWidget);
  });

  testWidgets('mã gõ chữ thường vẫn gửi lên dạng HOA', (t) async {
    // Báo "mã sai" chỉ vì một chữ thường là lỗi của app, không phải của người
    // dùng.
    final api = _ApiGia(xem: _moi());
    await _dung(t, api);
    await _go(t, 'abcd2345');
    expect(api.daTra.single, 'ABCD2345');
  });

  testWidgets('toà ĐÃ CÓ sale thì nói trước, không để nhận xong mới biết', (
    t,
  ) async {
    await _dung(t, _ApiGia(xem: _moi(daCoSale: true)));
    await _go(t, 'ABCD2345');
    expect(
      find.textContaining('đã có sale phụ trách'),
      findsOneWidget,
    );
  });

  testWidgets('toà chưa có sale thì KHÔNG doạ người ta', (t) async {
    await _dung(t, _ApiGia(xem: _moi()));
    await _go(t, 'ABCD2345');
    expect(find.textContaining('đã có sale phụ trách'), findsNothing);
  });

  testWidgets('mã sai → MỘT câu lỗi, không lộ lý do', (t) async {
    await _dung(t, _ApiGia(loiXem: true));
    await _go(t, 'SAISAI11');
    // Vẫn đúng MỘT câu cho mọi lý do (sai · đã dùng · của người khác), nhưng
    // có kèm đường đi tiếp: lý do trượt hay gặp nhất là chủ nhà gửi nhầm mã
    // BÀN GIAO — hai mã đều tám ký tự, cùng bảng chữ.
    expect(find.textContaining('Mã không đúng hoặc đã được dùng.'), findsOneWidget);
    expect(find.textContaining('Mời sale phụ trách'), findsOneWidget);
    expect(find.text('Nhận toà này'), findsNothing);
  });

  testWidgets('bấm nhận → gọi API đúng mã đã tra', (t) async {
    final api = _ApiGia(xem: _moi(), nhanRa: _moi(soPhongNhan: 4));
    await _dung(t, api);
    await _go(t, 'ABCD2345');
    await t.tap(find.text('Nhận toà này'));
    await t.pumpAndSettle();
    expect(api.daNhan.single, 'ABCD2345');
  });

  testWidgets('mã vừa hết hiệu lực giữa chừng → báo, không im lặng', (t) async {
    final api = _ApiGia(xem: _moi(), loiNhan: true);
    await _dung(t, api);
    await _go(t, 'ABCD2345');
    await t.tap(find.text('Nhận toà này'));
    await t.pumpAndSettle();
    expect(find.textContaining('vừa hết hiệu lực'), findsOneWidget);
  });

  // ── Xem TỪNG PHÒNG trước khi nhận ──────────────────────────────────────────
  //
  // Nút cuối hỏi "nhận toà này?" — trước đây hỏi mà chỉ đưa tên toà, địa chỉ và
  // SỐ phòng. Không kiểm được gì: sale/chủ nhà gõ nhầm diện tích hay dựng nhầm
  // sang toà bên cạnh thì chỉ lộ ra sau khi đã nhận.

  testWidgets('tra xong hiện TỪNG phòng, không chỉ con số', (t) async {
    await _dung(t, _ApiGia(xem: _moi()));
    await _go(t, 'ABCD2345');
    expect(find.text('P01'), findsOneWidget);
    expect(find.text('P02'), findsOneWidget);
    expect(find.textContaining('25m²'), findsOneWidget);
  });

  testWidgets('phòng đã có người nhìn ra ngay', (t) async {
    await _dung(t, _ApiGia(xem: _moi()));
    await _go(t, 'ABCD2345');
    expect(find.text('Đã thuê'), findsOneWidget);
  });

  testWidgets('toà 0 phòng → nói thẳng, không để khoảng trống', (t) async {
    await _dung(t, _ApiGia(xem: _moi(soPhong: 0, phong: const [])));
    await _go(t, 'ABCD2345');
    expect(find.text('Toà này chưa có phòng nào.'), findsOneWidget);
    // Vẫn nhận được — 0 phòng là trạng thái hợp lệ.
    expect(find.text('Nhận toà này'), findsOneWidget);
  });

  testWidgets('toà lớn bị cắt bớt → nói còn bao nhiêu', (t) async {
    await _dung(t, _ApiGia(xem: _moi(soPhong: 65, conLai: 5)));
    await _go(t, 'ABCD2345');
    expect(find.text('và 5 phòng nữa'), findsOneWidget);
  });
}