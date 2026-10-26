/// KÊNH KHAI THÁC trong chi tiết phòng — bốn pipeline, không phải bốn cái tên
/// của cùng một thứ.
///
/// Điều phải giữ bằng test:
///  1. **Mặt bằng gọi đúng tên.** Hiện nó thành "thuê dài hạn" là xoá mất một
///     nghiệp vụ: mặt bằng tính theo m²/tháng và có kỳ miễn tiền sửa chữa.
///  2. **Giá luôn kèm ĐƠN VỊ của kênh đó.** Bốn kênh bốn đơn vị; in cứng một
///     hậu tố chính là lỗi đã đẻ ra "5,5tr × 3 đêm".
///  3. **Chốt "đã bán" phải hỏi lại.** Nó gỡ tin của người khác khỏi chợ.
///  4. **Tải hỏng phải nói là hỏng**, không hiện thành "chưa mở kênh nào".
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/services/kenh_khai_thac_api.dart';
import 'package:house_booking/features/host/property/widgets/muc_kenh_khai_thac.dart';

import '../../helpers/pump_app.dart';

class _ApiGia extends KenhKhaiThacApi {
  _ApiGia(this.ds, {this.hong = false});

  final List<KenhKhaiThac> ds;
  final bool hong;
  final List<String> daGoi = [];

  @override
  Future<List<KenhKhaiThac>> cuaPhong(int roomId) async {
    if (hong) throw Exception('mất mạng');
    return ds;
  }

  @override
  Future<KenhKhaiThac> doiTrangThai(
    int roomId,
    String kenh,
    String trangThai,
  ) async {
    daGoi.add('$kenh:$trangThai');
    return _k(kenh: kenh, trangThai: trangThai, daChot: trangThai == 'da_ban');
  }
}

KenhKhaiThac _k({
  String kenh = 'dai_han',
  double gia = 5500000,
  String? donVi,
  String trangThai = 'dang_rao',
  bool daChot = false,
  bool dangBat = true,
  int? toiThieu,
  int? mienPhiThang,
}) => KenhKhaiThac(
  kenh: kenh,
  gia: gia,
  donVi: donVi ??
      switch (kenh) {
        'ngan_han' => 'dem',
        'mat_bang' => 'm2_thang',
        'ban' => 'tong',
        _ => 'thang',
      },
  dangBat: dangBat,
  trangThai: trangThai,
  daChot: daChot,
  toiThieu: toiThieu,
  mienPhiThang: mienPhiThang,
);

Future<void> _dung(WidgetTester t, _ApiGia api) async {
  t.view.physicalSize = const Size(520, 2200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await pumpApp(t, Scaffold(body: ListView(children: [
    MucKenhKhaiThac(roomId: 1, api: api),
  ])));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('liệt kê đủ BỐN kênh dù phòng mới bật một', (t) async {
    await _dung(t, _ApiGia([_k()]));
    expect(find.text('Ở ngắn hạn'), findsOneWidget);
    expect(find.text('Thuê dài hạn'), findsOneWidget);
    expect(find.text('Mặt bằng kinh doanh'), findsOneWidget);
    expect(find.text('Mua bán'), findsOneWidget);
  });

  testWidgets('MẶT BẰNG không được hiện thành "thuê dài hạn"', (t) async {
    await _dung(t, _ApiGia([_k(kenh: 'mat_bang', gia: 250000)]));
    expect(find.text('Mặt bằng kinh doanh'), findsOneWidget);
    // Nhãn của nó phải khác hẳn nhãn kênh thuê nhà ở.
    expect(find.text('Thuê dài hạn'), findsOneWidget); // là kênh KHÁC, vẫn liệt kê
  });

  testWidgets('mỗi kênh hiện ĐÚNG đơn vị giá của mình', (t) async {
    await _dung(t, _ApiGia([
      _k(kenh: 'ngan_han', gia: 350000),
      _k(kenh: 'dai_han', gia: 5500000),
      _k(kenh: 'mat_bang', gia: 250000),
      _k(kenh: 'ban', gia: 3000000000),
    ]));
    expect(find.textContaining('/đêm'), findsOneWidget);
    expect(find.textContaining('/tháng'), findsWidgets);
    expect(find.textContaining('/m²/tháng'), findsOneWidget);
    // "3 tỷ/tổng" là câu vô nghĩa — kênh bán KHÔNG có hậu tố.
    expect(find.text('3 tỷ'), findsOneWidget);
  });

  testWidgets('tham số riêng của MẶT BẰNG: kỳ miễn phí sửa chữa', (t) async {
    await _dung(t, _ApiGia([_k(kenh: 'mat_bang', mienPhiThang: 3)]));
    expect(find.textContaining('miễn phí sửa chữa 3 tháng'), findsOneWidget);
  });

  testWidgets('số đêm tối thiểu chỉ nói "đêm" ở kênh ngắn hạn', (t) async {
    await _dung(t, _ApiGia([_k(kenh: 'ngan_han', toiThieu: 2)]));
    expect(find.textContaining('tối thiểu 2 đêm'), findsOneWidget);
  });

  testWidgets('kênh BÁN có các bước pipeline; kênh thuê thì không', (t) async {
    await _dung(t, _ApiGia([_k(kenh: 'ban'), _k(kenh: 'dai_han')]));
    // Chốt thuê là ký HỢP ĐỒNG, không bấm tay ở đây.
    expect(find.text('Giữ chỗ'), findsOneWidget);
    expect(find.text('Đã cọc'), findsOneWidget);
    expect(find.text('Đã bán'), findsOneWidget);
  });

  testWidgets('bấm ĐÃ BÁN phải hỏi lại — nó gỡ tin của người khác', (t) async {
    final api = _ApiGia([_k(kenh: 'ban')]);
    await _dung(t, api);
    await t.tap(find.text('Đã bán'));
    await t.pumpAndSettle();

    expect(find.text('Đánh dấu ĐÃ BÁN?'), findsOneWidget);
    expect(find.textContaining('kể cả tin do sale khác'), findsOneWidget);
    // Chưa xác nhận thì KHÔNG được gọi API.
    expect(api.daGoi, isEmpty);
  });

  testWidgets('huỷ hộp thoại thì không chốt gì', (t) async {
    final api = _ApiGia([_k(kenh: 'ban')]);
    await _dung(t, api);
    await t.tap(find.text('Đã bán'));
    await t.pumpAndSettle();
    await t.tap(find.text('Huỷ'));
    await t.pumpAndSettle();
    expect(api.daGoi, isEmpty);
  });

  testWidgets('kênh ĐÃ CHỐT chỉ còn "Rao lại", không còn bước tiếp', (t) async {
    await _dung(t, _ApiGia([
      _k(kenh: 'ban', trangThai: 'da_ban', daChot: true),
    ]));
    expect(find.text('Rao lại'), findsOneWidget);
    expect(find.text('Giữ chỗ'), findsNothing);
    expect(find.text('Đã bán'), findsWidgets); // nhãn trạng thái, không phải nút
  });

  testWidgets('tải hỏng → báo lỗi + thử lại, KHÔNG im lặng thành rỗng', (t) async {
    await _dung(t, _ApiGia(const [], hong: true));
    expect(find.text('Không tải được kênh khai thác.'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('kênh chưa bật thì không hiện giá, chỉ có công tắc', (t) async {
    await _dung(t, _ApiGia([_k(kenh: 'dai_han')]));
    // Ba kênh còn lại chưa bật → chỉ một giá hiện ra.
    expect(find.textContaining('/tháng'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(4));
  });
}
