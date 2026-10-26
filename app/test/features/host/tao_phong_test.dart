import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/room_model.dart';
import 'package:house_booking/features/host/property/providers/room_provider.dart';
import 'package:house_booking/features/host/property/screens/room_form_screen.dart';
import 'package:provider/provider.dart';

import '../../helpers/pump_app.dart';

/// TỜ KHAI PHÒNG MỚI — bốn điều phải giữ:
///
/// 1. **Bắt buộc chọn loại khai thác.** Trước đây form không hỏi, nên phòng tạo
///    ra không thuộc kênh nào — không ra chợ được, và không ai biết vì sao.
/// 2. **Form đổi theo loại đã chọn.** Mặt bằng có kỳ miễn tiền sửa; ngắn hạn và
///    mua bán không hỏi điện nước (điện của homestay tính theo đêm, người mua
///    trả tiền điện của chính họ sau khi sang tên).
/// 3. **Giá đi kèm ĐƠN VỊ.** Ghi trơ "Giá thuê (VNĐ)" cho cả bốn kênh chính là
///    thứ đã đẻ ra lỗi lấy giá THÁNG nhân số ĐÊM.
/// 4. **Ô trống gửi `null`, gõ 0 gửi `0`.** `null` = theo giá toà, `0` = miễn
///    phí. Gộp hai thứ là mất hẳn khả năng khai "phòng này bao nước".
class _ProviderGia extends RoomProvider {
  Map<String, dynamic>? daGoi;

  @override
  Future<RoomModel?> createRoom(
    int buildingId, {
    required String code,
    double? areaM2,
    int capacity = 1,
    double basePrice = 0,
    String? note,
    List<String> images = const [],
    String? kenh,
    int? toiThieu,
    double? datCoc,
    int? mienPhiThang,
    double? giaDien,
    double? giaNuoc,
    double? phiDichVu,
    List<String> dichVuGom = const [],
    List<String> doTrongPhong = const [],
    String? tang,
    String? huong,
  }) async {
    daGoi = {
      'tang': tang,
      'huong': huong,
      'code': code,
      'base_price': basePrice,
      'kenh': kenh,
      'toi_thieu': toiThieu,
      'mien_phi_thang': mienPhiThang,
      'gia_dien': giaDien,
      'gia_nuoc': giaNuoc,
      'phi_dich_vu': phiDichVu,
      'dich_vu_gom': dichVuGom,
      'do_trong_phong': doTrongPhong,
    };
    return RoomModel(
      id: 1,
      buildingId: buildingId,
      code: code,
      capacity: capacity,
      basePrice: basePrice,
      status: 'vacant',
      images: const [],
      createdAt: DateTime(2026, 9, 9),
      updatedAt: DateTime(2026, 9, 9),
    );
  }
}

Future<_ProviderGia> _dung(WidgetTester t) async {
  final p = _ProviderGia();
  t.view.physicalSize = const Size(520, 2600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await pumpApp(
    t,
    ChangeNotifierProvider<RoomProvider>.value(
      value: p,
      child: const RoomFormScreen(buildingId: 7),
    ),
  );
  await t.pumpAndSettle();
  return p;
}

Future<void> _chon(WidgetTester t, String nhan) async {
  await t.tap(find.text(nhan));
  await t.pumpAndSettle();
}

/// Tìm ô nhập theo NHÃN. `DsTextField` vẽ nhãn ở một `Text` phía TRÊN ô, không
/// nằm trong `decoration`, nên `widgetWithText` không thấy.
Finder _o(String nhan) => find.descendant(
  of: find.byWidgetPredicate((w) => w is DsTextField && w.label == nhan),
  matching: find.byType(TextFormField),
);

Future<void> _dien(WidgetTester t, String nhan, String giaTri) async {
  await t.enterText(_o(nhan), giaTri);
  await t.pump();
}

Future<void> _dienMa(WidgetTester t, String ma) => _dien(t, 'Mã phòng *', ma);

void main() {
  testWidgets('chưa chọn loại → chưa hiện ô nào của phòng', (t) async {
    await _dung(t);
    expect(find.text('Loại khai thác'.toUpperCase()), findsOneWidget);
    // Không bày một form dài rồi mới báo lỗi ở cuối: chưa chọn thì chưa có gì.
    expect(find.text('Thông tin phòng'.toUpperCase()), findsNothing);
  });

  testWidgets('chưa chọn loại mà bấm lưu → chặn, KHÔNG gọi API', (t) async {
    final p = await _dung(t);
    await t.tap(find.text('Tạo phòng'));
    await t.pumpAndSettle();
    expect(find.text('Chọn loại khai thác trước'), findsOneWidget);
    expect(p.daGoi, isNull);
  });

  testWidgets('chọn thuê → hỏi tiếp nhà ở hay mặt bằng', (t) async {
    await _dung(t);
    expect(find.text('Cho thuê để làm gì?'), findsNothing);
    await _chon(t, 'Cho thuê dài hạn / kinh doanh');
    expect(find.text('Cho thuê để làm gì?'), findsOneWidget);
    expect(find.text('Nhà ở'), findsOneWidget);
    expect(find.text('Mặt bằng kinh doanh'), findsOneWidget);
  });

  testWidgets('nhà ở → giá /tháng, KHÔNG có kỳ miễn tiền sửa', (t) async {
    await _dung(t);
    await _chon(t, 'Cho thuê dài hạn / kinh doanh');
    expect(find.text('GIÁ/THÁNG'), findsOneWidget);
    expect(find.text('MIỄN TIỀN THUÊ ĐỂ SỬA CHỮA (THÁNG)'), findsNothing);
  });

  testWidgets('mặt bằng → giá /m²/tháng VÀ có kỳ miễn tiền sửa', (t) async {
    await _dung(t);
    await _chon(t, 'Cho thuê dài hạn / kinh doanh');
    await _chon(t, 'Mặt bằng kinh doanh');
    expect(find.text('GIÁ/M²/THÁNG'), findsOneWidget);
    expect(find.text('MIỄN TIỀN THUÊ ĐỂ SỬA CHỮA (THÁNG)'), findsOneWidget);
  });

  testWidgets('ngắn hạn → giá /đêm, hỏi số ĐÊM tối thiểu', (t) async {
    await _dung(t);
    await _chon(t, 'Ở ngắn hạn');
    expect(find.text('GIÁ/ĐÊM'), findsOneWidget);
    expect(find.text('SỐ ĐÊM TỐI THIỂU'), findsOneWidget);
  });

  testWidgets('mua bán → giá không hậu tố, cọc tính %, không hỏi tối thiểu', (
    t,
  ) async {
    await _dung(t);
    await _chon(t, 'Mua bán');
    expect(find.text('GIÁ'), findsOneWidget);
    expect(find.text('CỌC (%)'), findsOneWidget);
    expect(find.text('SỐ THÁNG TỐI THIỂU'), findsNothing);
  });

  // ── Điện nước dịch vụ chỉ hỏi cho thuê theo tháng ───────────────────────────

  testWidgets('thuê → có khối điện nước dịch vụ', (t) async {
    await _dung(t);
    await _chon(t, 'Cho thuê dài hạn / kinh doanh');
    expect(find.text('ĐIỆN NƯỚC DỊCH VỤ'), findsOneWidget);
    expect(find.text('GIÁ ĐIỆN (Đ/KWH)'), findsOneWidget);
  });

  testWidgets('ngắn hạn → KHÔNG hỏi điện nước', (t) async {
    await _dung(t);
    await _chon(t, 'Ở ngắn hạn');
    expect(find.text('ĐIỆN NƯỚC DỊCH VỤ'), findsNothing);
  });

  testWidgets('mua bán → KHÔNG hỏi điện nước', (t) async {
    await _dung(t);
    await _chon(t, 'Mua bán');
    expect(find.text('ĐIỆN NƯỚC DỊCH VỤ'), findsNothing);
  });

  testWidgets('phí dịch vụ = 0 → ẩn danh sách "gồm những gì"', (t) async {
    await _dung(t);
    await _chon(t, 'Cho thuê dài hạn / kinh doanh');
    // Chưa nhập phí → mời khai "gồm gì" là hỏi về một khoản không ai trả tiền.
    expect(find.text('PHÍ DỊCH VỤ GỒM'), findsNothing);
  });

  testWidgets('nhập phí dịch vụ → hiện danh sách "gồm những gì"', (t) async {
    await _dung(t);
    await _chon(t, 'Cho thuê dài hạn / kinh doanh');
    await _dien(t, 'Phí dịch vụ (đ/tháng)', '150000');
    await t.pumpAndSettle();
    expect(find.text('PHÍ DỊCH VỤ GỒM'), findsOneWidget);
    expect(find.text('Gửi xe'), findsOneWidget);
  });

  testWidgets('đồ trong phòng hỏi ở MỌI loại', (t) async {
    await _dung(t);
    await _chon(t, 'Mua bán');
    expect(find.text('ĐỒ TRONG PHÒNG'), findsOneWidget);
    expect(find.text('Điều hoà'), findsOneWidget);
  });

  // ── Payload ────────────────────────────────────────────────────────────────

  testWidgets('ô giá điện để TRỐNG → gửi null, không gửi 0', (t) async {
    final p = await _dung(t);
    await _chon(t, 'Cho thuê dài hạn / kinh doanh');
    await _dienMa(t, 'P01');
    await t.tap(find.text('Tạo phòng'));
    await t.pumpAndSettle();

    expect(p.daGoi!['kenh'], 'dai_han');
    // `null` = theo giá toà. Gửi 0 ở đây là ép mọi phòng thành "điện miễn phí".
    expect(p.daGoi!['gia_dien'], isNull);
  });

  testWidgets('gõ 0 vào giá nước → gửi 0 (bao nước), không phải null', (t) async {
    final p = await _dung(t);
    await _chon(t, 'Cho thuê dài hạn / kinh doanh');
    await _dienMa(t, 'P01');
    await _dien(t, 'Giá nước (đ/m³)', '0');
    await t.tap(find.text('Tạo phòng'));
    await t.pumpAndSettle();
    expect(p.daGoi!['gia_nuoc'], 0);
  });

  testWidgets('mặt bằng → gửi đúng kênh và kỳ miễn tiền sửa', (t) async {
    final p = await _dung(t);
    await _chon(t, 'Cho thuê dài hạn / kinh doanh');
    await _chon(t, 'Mặt bằng kinh doanh');
    await _dienMa(t, 'MB01');
    await _dien(t, 'Miễn tiền thuê để sửa chữa (tháng)', '3');
    await t.tap(find.text('Tạo phòng'));
    await t.pumpAndSettle();
    expect(p.daGoi!['kenh'], 'mat_bang');
    expect(p.daGoi!['mien_phi_thang'], 3);
  });

  testWidgets('tick đồ trong phòng → gửi đúng KEY, không gửi nhãn', (t) async {
    final p = await _dung(t);
    await _chon(t, 'Mua bán');
    await _dienMa(t, 'P01');
    await t.tap(find.text('Điều hoà'));
    await t.pumpAndSettle();
    await t.tap(find.text('Tạo phòng'));
    await t.pumpAndSettle();
    expect(p.daGoi!['do_trong_phong'], ['dieu_hoa']);
  });

  testWidgets('thiếu mã phòng → chặn, KHÔNG gọi API', (t) async {
    final p = await _dung(t);
    await _chon(t, 'Mua bán');
    await t.tap(find.text('Tạo phòng'));
    await t.pumpAndSettle();
    expect(find.text('Vui lòng nhập mã phòng'), findsOneWidget);
    expect(p.daGoi, isNull);
  });
}
