import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/building_public_api.dart';
import 'package:house_booking/features/guest/project/building_public_screen.dart';

import '../helpers/pump_app.dart';

/// Trang dự án công khai: phòng còn trống lên trước, phòng đã thuê phải nhìn
/// ra ngay là không đặt được, và bộ lọc mặc định giấu phòng đã thuê.
class _ApiGia extends BuildingPublicApi {
  const _ApiGia(this.d);
  final DuAnChiTiet? d;
  @override
  Future<DuAnChiTiet?> chiTiet(int id) async => d;
}

/// [toiDungTen] / [daBanGiao] là hai cờ backend tính RIÊNG cho người đang hỏi.
/// Mặc định `false` = người xem không đứng tên toà (khách, hoặc sale đã bàn
/// giao xong).
DuAnChiTiet _mau({
  bool toiDungTen = false,
  bool? daBanGiao,
  bool toiQuanLy = false,
}) => DuAnChiTiet(
  toiDungTen: toiDungTen,
  daBanGiao: daBanGiao,
  toiQuanLy: toiQuanLy,
  id: 7,
  ten: 'Toà S1',
  diaChi: 'Nguyễn Xiển',
  quan: 'Thủ Đức',
  tinh: 'TP.HCM',
  soPhong: 3,
  soPhongTrong: 2,
  giaTu: 9000000,
  saleId: 199,
  saleTen: 'Hồ Tâm',
  phong: const [
    PhongCongKhai(
      id: 1,
      ma: 'S1-1201',
      gia: 9000000,
      sucChua: 2,
      conTrong: true,
      saleId: 199,
      saleTen: 'Hồ Tâm',
    ),
    PhongCongKhai(
      id: 2,
      ma: 'S1-1202',
      gia: 11000000,
      sucChua: 2,
      conTrong: true,
      saleId: 199,
      saleTen: 'Hồ Tâm',
    ),
    PhongCongKhai(
      id: 3,
      ma: 'S1-1203',
      gia: 8000000,
      sucChua: 2,
      conTrong: false,
      saleId: 199,
      saleTen: 'Hồ Tâm',
    ),
  ],
);

/// [toi] = id người đang xem. `null` = khách vãng lai chưa đăng nhập.
Future<void> _dung(WidgetTester t, DuAnChiTiet? d, {int? toi}) async {
  // Màn thử mặc định 800x600 không đủ cao: bìa 16:9 + hàng số đã chiếm gần hết,
  // danh sách phòng nằm ngoài vùng dựng nên finder không thấy.
  t.view.physicalSize = const Size(500, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await pumpApp(
    t,
    BuildingPublicScreen(buildingId: 7, api: _ApiGia(d)),
    auth: toi == null ? null : SignedInAuthProvider(id: toi),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('mặc định chỉ hiện phòng còn trống', (t) async {
    await _dung(t, _mau());
    expect(find.text('Phòng S1-1201'), findsOneWidget);
    expect(find.text('Phòng S1-1202'), findsOneWidget);
    expect(find.text('Phòng S1-1203'), findsNothing);
  });

  testWidgets('tắt bộ lọc thì hiện cả phòng đã thuê', (t) async {
    await _dung(t, _mau());
    await t.tap(find.text('Chỉ còn trống'));
    await t.pumpAndSettle();
    expect(find.text('Phòng S1-1203'), findsOneWidget);
    expect(find.text('Đã thuê'), findsOneWidget);
  });

  testWidgets('giá từ lấy phòng trống rẻ nhất, không phải phòng đã thuê', (
    t,
  ) async {
    await _dung(t, _mau());
    // 8tr là phòng ĐÃ THUÊ — không được quảng cáo.
    expect(find.text('8tr'), findsNothing);
    expect(find.text('9tr'), findsWidgets);
  });

  testWidgets('không tìm thấy dự án thì không nổ', (t) async {
    await _dung(t, null);
    expect(find.text('Không tìm thấy dự án này'), findsOneWidget);
  });

  _nhomChinhChu();
  _nhomMaBanGiao();
  _nhomSoPhong();
}

// ── Lối vào SỔ PHÒNG ─────────────────────────────────────────────────────────
//
// Bug thật: sau khi chủ nhà và sale liên kết, cả hai mở dự án ra chỉ thấy MẶT
// NGOÀI — bảng phòng kiểu khách sạn. Muốn xem chi tiết phòng phải quay ra, bấm
// ⚙, vào "Dự án & phòng đang quản lý" rồi mở lại đúng toà vừa xem.
//
// Điều kiện là `toiQuanLy` (backend hỏi đúng cổng gác của API phòng), không
// phải "tôi là sale của mọi phòng" — cách cũ bỏ sót CHỦ NHÀ và sale chỉ giữ
// vài phòng.

void _nhomSoPhong() {
  testWidgets('người quản lý → có nút Mở sổ phòng', (t) async {
    await _dung(t, _mau(toiQuanLy: true), toi: 199);
    expect(find.text('Mở sổ phòng'), findsOneWidget);
  });

  testWidgets('CHỦ NHÀ (không phải sale phòng nào) vẫn vào được', (t) async {
    // Chủ nhà không đứng tên sale của phòng nào cả, nên điều kiện cũ loại họ ra
    // khỏi chính toà của mình.
    await _dung(t, _mau(toiQuanLy: true, toiDungTen: true), toi: 900);
    expect(find.text('Mở sổ phòng'), findsOneWidget);
    expect(find.text('Bạn đang phụ trách dự án này'), findsNothing);
    expect(find.text('Nhắn cho Hồ Tâm'), findsNothing);
  });

  testWidgets('KHÁCH vãng lai → không có nút nào của người trong nhà', (t) async {
    await _dung(t, _mau());
    expect(find.text('Mở sổ phòng'), findsNothing);
    expect(find.text('Nhắn cho Hồ Tâm'), findsOneWidget);
  });

  testWidgets('người dùng KHÁC → cũng không', (t) async {
    await _dung(t, _mau(), toi: 500);
    expect(find.text('Mở sổ phòng'), findsNothing);
  });

  testWidgets('sale phụ trách nhưng backend nói KHÔNG quản lý → ẩn nút', (
    t,
  ) async {
    // Không đoán từ `saleId`: cổng gác thật nằm ở backend, app chỉ hỏi.
    await _dung(t, _mau(toiQuanLy: false), toi: 199);
    expect(find.text('Bạn đang phụ trách dự án này'), findsOneWidget);
    expect(find.text('Mở sổ phòng'), findsNothing);
  });
}


// ── Không mời người ta nhắn tin cho chính mình ───────────────────────────────
//
// Trang này dùng chung cho KHÁCH và cho chính SALE phụ trách (họ mở từ trang
// cá nhân của mình). Trước đây thanh dưới cùng chỉ đọc `saleId` rồi vẽ
// "Nhắn cho <tên>", không hề biết người đang xem là ai — nên sale mở dự án của
// mình ra thì thấy "Nhắn cho <tên mình>", bấm vào là mở hồ sơ của chính mình.
void _nhomChinhChu() {
  testWidgets('KHÁCH vãng lai → vẫn có nút nhắn cho sale', (t) async {
    await _dung(t, _mau());
    expect(find.text('Nhắn cho Hồ Tâm'), findsOneWidget);
  });

  testWidgets('người dùng KHÁC sale → vẫn có nút nhắn', (t) async {
    await _dung(t, _mau(), toi: 500);
    expect(find.text('Nhắn cho Hồ Tâm'), findsOneWidget);
  });

  testWidgets('CHÍNH SALE phụ trách → KHÔNG mời nhắn cho chính mình', (t) async {
    await _dung(t, _mau(), toi: 199);
    expect(find.text('Nhắn cho Hồ Tâm'), findsNothing);
    expect(find.text('Bạn đang phụ trách dự án này'), findsOneWidget);
  });

  testWidgets('CHÍNH SALE → dòng sale ở mỗi phòng hết là đường dẫn', (t) async {
    // Mở hồ sơ của chính mình từ đây là một cú bấm không dẫn tới đâu cả.
    await _dung(t, _mau(), toi: 199);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });
}

// ── Mã bàn giao: chỉ SALE phụ trách thấy, và KHÔNG nằm trong dữ liệu trang ──
//
// Trang này công khai. Mã bàn giao mà nằm trong phản hồi của nó thì bất kỳ ai
// mở trang cũng chiếm được toà — nên nút chỉ mọc cho người phụ trách, và mã
// chỉ được lấy khi họ bấm, qua endpoint có kiểm quyền.

void _nhomMaBanGiao() {
  testWidgets('SALE ĐANG ĐỨNG TÊN → có nút lấy mã bàn giao', (t) async {
    await _dung(t, _mau(toiDungTen: true, daBanGiao: false, toiQuanLy: true), toi: 199);
    expect(find.text('Mã bàn giao cho chủ nhà'), findsOneWidget);
  });

  testWidgets('KHÁCH vãng lai → KHÔNG có nút mã bàn giao', (t) async {
    await _dung(t, _mau());
    expect(find.text('Mã bàn giao cho chủ nhà'), findsNothing);
  });

  testWidgets('người dùng KHÁC → cũng KHÔNG có', (t) async {
    await _dung(t, _mau(), toi: 500);
    expect(find.text('Mã bàn giao cho chủ nhà'), findsNothing);
  });

  // ── Bug thật 09/09/2026 ────────────────────────────────────────────────────
  //
  // Sale mở dự án mình phụ trách, bấm nút, nhận "Không lấy được mã bàn giao."
  // Toà đã bàn giao hôm trước: `host_id` nay là chủ nhà. Endpoint gác theo
  // `host_id` nên 404 là đúng — sai ở chỗ app suy "tôi bàn giao được" từ "tôi
  // phụ trách mọi phòng", hai thứ khác nhau.

  testWidgets('SALE của toà ĐÃ BÀN GIAO → KHÔNG còn nút, và nói rõ vì sao', (
    t,
  ) async {
    await _dung(t, _mau(toiDungTen: false, daBanGiao: true, toiQuanLy: true), toi: 199);
    // Vẫn là người phụ trách...
    expect(find.text('Bạn đang phụ trách dự án này'), findsOneWidget);
    // ...nhưng nút bàn giao phải biến mất thay vì bấm vào rồi báo lỗi.
    expect(find.text('Mã bàn giao cho chủ nhà'), findsNothing);
    // Im lặng thì giống tính năng hỏng — phải nói ra.
    expect(find.text('Đã bàn giao cho chủ nhà'), findsOneWidget);
  });

  testWidgets('SALE được CHỦ NHÀ mời vào → KHÔNG có nút bàn giao', (t) async {
    // Chiều mã mời: chủ nhà dựng toà rồi mời sale. Chưa bàn giao lần nào,
    // nhưng sale cũng chưa bao giờ đứng tên nên không có gì để bàn giao.
    await _dung(t, _mau(toiDungTen: false, daBanGiao: false, toiQuanLy: true), toi: 199);
    expect(find.text('Bạn đang phụ trách dự án này'), findsOneWidget);
    expect(find.text('Mã bàn giao cho chủ nhà'), findsNothing);
    // Chưa bàn giao thì đừng bịa là đã bàn giao.
    expect(find.text('Đã bàn giao cho chủ nhà'), findsNothing);
  });
}
