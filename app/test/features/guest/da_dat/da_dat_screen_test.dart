import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/da_dat_api.dart';
import 'package:house_booking/data/services/dang_thue_api.dart';
import 'package:house_booking/data/services/dien_nuoc_api.dart';
import 'package:house_booking/features/guest/da_dat/da_dat_screen.dart';
import 'package:house_booking/features/guest/da_dat/gui_chi_so_sheet.dart';

import '../../../helpers/pump_app.dart';

/// Tab "Đã đặt" v2 — kiểm soát trạng thái, lịch sử, sửa đổi (docs/PLAN-DA-DAT.md).
///
/// Điều phải giữ:
///   * việc CẦN LÀM đứng đầu, tách khỏi danh sách;
///   * sắp tới nhóm theo ngày, lọc được theo loại; việc đã xong không lẫn vào;
///   * thẻ nói thật trạng thái + tiến độ + lần cập nhật cuối;
///   * menu chỉ bày thao tác server cho phép; "Lịch sử thay đổi" luôn có;
///   * lịch sử nhóm theo tháng, rỗng thì nói rõ;
///   * một nguồn hỏng không làm trống nguồn kia.
class _DaDatGia extends DaDatApi {
  const _DaDatGia(this.th, {this.loi = false});

  final TongHopDaDat th;
  final bool loi;

  @override
  Future<TongHopDaDat> tongHop() async {
    if (loi) throw ApiException(500, 'hỏng');
    return th;
  }
}

class _ThueGia extends DangThueApi {
  const _ThueGia(this.ds);

  final List<PhongDangThue> ds;

  @override
  Future<List<PhongDangThue>> cuaToi() async => ds;
}

class _DienNuocGia extends DienNuocApi {
  _DienNuocGia({this.loi});

  final ApiException? loi;
  final daGui = <(int, double, double)>[];

  @override
  Future<void> gui({
    required int contractId,
    required double dien,
    required double nuoc,
    String? anhDien,
    String? anhNuoc,
  }) async {
    if (loi != null) throw loi!;
    daGui.add((contractId, dien, nuoc));
  }
}

Finder _oNhap(String nhan) => find.descendant(
  of: find.byWidgetPredicate((w) => w is DsTextField && w.label == nhan),
  matching: find.byType(TextFormField),
);

final _bayGio = DateTime(2026, 9, 16, 9);

MucDaDat _muc({
  String loai = 'dat_phong',
  int id = 1,
  String tieuDe = 'Deluxe giường đôi · LT-102',
  DateTime? batDau,
  String trangThai = 'pending',
  String nhan = 'Chờ sale xác nhận',
  String tong = 'cho',
  int buoc = 1,
  String? canXuLy,
  bool dangMo = true,
  SuaDuoc suaDuoc = const SuaDuoc(doiGio: true, suaThongTin: true, huy: true),
}) => MucDaDat(
  loai: loai,
  id: id,
  ma: loai == 'dat_phong' ? 'AC-260916-AAAA' : 'LH-00$id',
  tieuDe: tieuDe,
  phuDe: 'Vua Nhà Homestay Lạch Tray',
  batDau: batDau ?? DateTime(2026, 9, 16, 15),
  hinhThuc: loai == 'dat_phong' ? 'Theo giờ · 2 giờ' : 'Xem trực tiếp',
  tien: loai == 'dat_phong' ? 140000 : null,
  trangThai: trangThai,
  nhanTrangThai: nhan,
  tong: tong,
  buoc: buoc,
  cacBuoc: const ['Đã đặt', 'Xác nhận', 'Nhận phòng', 'Trả phòng'],
  viec: dangMo ? 'Xem phiếu' : 'Xem lại',
  canXuLy: canXuLy,
  dangMo: dangMo,
  suaDuoc: suaDuoc,
  capNhatLuc: _bayGio.subtract(const Duration(minutes: 5)),
);

PhongDangThue _thue({String? trangThai, String? lyDo}) => PhongDangThue(
  contractId: 7,
  roomId: 3,
  maPhong: 'P05',
  tenToa: 'Toà B',
  diaChi: '1 Lê Lợi',
  tienThue: 5000000,
  datCoc: 10000000,
  tuNgay: '2026-01-01',
  denNgay: '2026-12-31',
  chiSoTrangThai: trangThai,
  chiSoLyDo: lyDo,
);

Future<void> _dung(
  WidgetTester t, {
  List<MucDaDat> sapToi = const [],
  List<MucDaDat> lichSu = const [],
  List<PhongDangThue> thue = const [],
  DienNuocApi? dienNuoc,
  bool loiTongHop = false,
}) async {
  t.view.physicalSize = const Size(1200, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await pumpApp(
    t,
    DaDatScreen(
      api: _DaDatGia(TongHopDaDat(sapToi: sapToi, lichSu: lichSu), loi: loiTongHop),
      dangThueApi: _ThueGia(thue),
      dienNuocApi: dienNuoc,
      bayGio: _bayGio,
    ),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('ba tab: Sắp tới · Đang thuê · Lịch sử, kèm số đếm', (t) async {
    await _dung(t, sapToi: [_muc()], lichSu: [_muc(id: 2, dangMo: false)]);
    expect(find.text('ĐÃ ĐẶT'), findsOneWidget);
    expect(find.text('Sắp tới (1)'), findsOneWidget);
    expect(find.text('Đang thuê (0)'), findsOneWidget);
    expect(find.text('Lịch sử (1)'), findsOneWidget);
  });

  testWidgets('việc CẦN LÀM đứng đầu, tách khỏi danh sách', (t) async {
    await _dung(t, sapToi: [
      _muc(),
      _muc(
        loai: 'xem_nha',
        id: 9,
        tieuDe: 'Căn hộ 3PN',
        trangThai: 'doi_gio',
        nhan: 'Bên bán bận · chọn giờ mới',
        tong: 'doi',
        canXuLy: 'Bên bán bận giờ bạn chọn — chọn giờ mới',
      ),
    ]);
    expect(find.text('CẦN BẠN XỬ LÝ · 1'), findsOneWidget);
    expect(find.byKey(const Key('can-xu-ly-xem_nha-9')), findsOneWidget);
    expect(find.text('Bên bán bận giờ bạn chọn — chọn giờ mới'), findsOneWidget);
  });

  testWidgets('sắp tới nhóm Hôm nay / Ngày mai / Trong 7 ngày', (t) async {
    await _dung(t, sapToi: [
      _muc(id: 1, batDau: DateTime(2026, 9, 16, 15)),
      _muc(id: 2, batDau: DateTime(2026, 9, 17, 10)),
      _muc(id: 3, batDau: DateTime(2026, 9, 20, 10)),
    ]);
    expect(find.text('HÔM NAY · 1'), findsOneWidget);
    expect(find.text('NGÀY MAI · 1'), findsOneWidget);
    expect(find.text('TRONG 7 NGÀY · 1'), findsOneWidget);
  });

  testWidgets('lọc theo loại: Đặt phòng / Xem nhà', (t) async {
    await _dung(t, sapToi: [
      _muc(id: 1),
      _muc(loai: 'xem_nha', id: 2, tieuDe: 'Căn hộ 3PN'),
    ]);
    expect(find.text('Căn hộ 3PN'), findsOneWidget);
    await t.tap(find.byKey(const Key('loc-sap-toi-dat_phong')));
    await t.pump();
    expect(find.text('Căn hộ 3PN'), findsNothing);
    expect(find.text('Deluxe giường đôi · LT-102'), findsOneWidget);
    await t.tap(find.byKey(const Key('loc-sap-toi-xem_nha')));
    await t.pump();
    expect(find.text('Deluxe giường đôi · LT-102'), findsNothing);
  });

  testWidgets('thẻ nói thật trạng thái, tiền, lần cập nhật cuối', (t) async {
    await _dung(t, sapToi: [_muc(trangThai: 'approved', nhan: 'Đã xác nhận · phòng được giữ', buoc: 2)]);
    expect(find.text('Đã xác nhận · phòng được giữ'), findsOneWidget);
    expect(find.text('Theo giờ · 2 giờ · 140.000đ'), findsOneWidget);
    expect(find.text('Cập nhật 5 phút trước'), findsOneWidget);
    expect(find.text('#AC-260916-AAAA'), findsOneWidget);
  });

  testWidgets('menu chỉ bày thao tác được phép, lịch sử luôn có', (t) async {
    await _dung(t, sapToi: [
      _muc(suaDuoc: const SuaDuoc(suaThongTin: true)),
    ]);
    await t.tap(find.byKey(const Key('menu-dat_phong-1')));
    await t.pumpAndSettle();
    expect(find.text('Đổi giờ'), findsNothing);
    expect(find.text('Huỷ'), findsNothing);
    expect(find.text('Sửa thông tin'), findsOneWidget);
    expect(find.text('Lịch sử thay đổi'), findsOneWidget);
  });

  testWidgets('sắp tới rỗng → nói rõ và chỉ đường', (t) async {
    await _dung(t);
    expect(find.text('Chưa có gì sắp tới'), findsOneWidget);
  });

  testWidgets('lịch sử nhóm theo tháng, việc đã xong không lẫn vào Sắp tới', (t) async {
    await _dung(t, lichSu: [
      _muc(id: 5, trangThai: 'cancelled', nhan: 'Đã huỷ', tong: 'huy', dangMo: false,
          suaDuoc: const SuaDuoc()),
    ]);
    expect(find.text('Chưa có gì sắp tới'), findsOneWidget);
    await t.tap(find.text('Lịch sử (1)'));
    await t.pumpAndSettle();
    expect(find.text('THÁNG 9/2026 · 1'), findsOneWidget);
    expect(find.text('Đã huỷ'), findsOneWidget);
  });

  testWidgets('lịch sử rỗng → không nói dối là có dữ liệu', (t) async {
    await _dung(t);
    await t.tap(find.text('Lịch sử (0)'));
    await t.pumpAndSettle();
    expect(find.text('Chưa có gì trong lịch sử'), findsOneWidget);
  });

  testWidgets('tổng hợp hỏng vẫn hiện phòng đang thuê, báo có phần chưa tải', (t) async {
    await _dung(t, loiTongHop: true, thue: [_thue()]);
    expect(find.textContaining('chưa tải được'), findsWidgets);
    expect(find.text('Đang thuê (1)'), findsOneWidget);
  });

  testWidgets('phòng đang thuê hiện tiền tháng và ngày hết hạn', (t) async {
    await _dung(t, thue: [_thue()]);
    await t.tap(find.textContaining('Đang thuê ('));
    await t.pumpAndSettle();
    expect(find.text('Phòng P05 · Toà B'), findsOneWidget);
    expect(find.textContaining('/ tháng'), findsOneWidget);
    expect(find.text('Đến 31/12/2026'), findsOneWidget);
  });

  testWidgets('chưa thuê phòng nào → nói rõ vì sao trống', (t) async {
    await _dung(t);
    await t.tap(find.textContaining('Đang thuê ('));
    await t.pumpAndSettle();
    expect(find.text('Bạn chưa thuê phòng nào'), findsOneWidget);
    // Không để trống trơn: nói ra điều kiện để nó hiện ra.
    expect(find.textContaining('số điện thoại'), findsOneWidget);
  });

  Future<void> moTamGui(WidgetTester t, _DienNuocGia api) async {
    await _dung(t, thue: [_thue()], dienNuoc: api);
    await t.tap(find.textContaining('Đang thuê ('));
    await t.pumpAndSettle();
    await t.tap(find.text('Gửi chỉ số điện nước'));
    await t.pumpAndSettle();
    await t.enterText(_oNhap('Chỉ số điện (kWh)'), '972');
    await t.enterText(_oNhap('Chỉ số nước (m³)'), '125');
    final nut = find.descendant(
      of: find.byType(GuiChiSoSheet),
      matching: find.byType(DsButton),
    );
    await t.ensureVisible(nut);
    await t.tap(nut);
    await t.pumpAndSettle();
  }

  testWidgets('người thuê gửi chỉ số tháng này cho ĐÚNG hợp đồng', (t) async {
    final api = _DienNuocGia();
    await moTamGui(t, api);
    expect(api.daGui, [(7, 972.0, 125.0)]);
    expect(find.byType(GuiChiSoSheet), findsNothing);
  });

  testWidgets('server từ chối → hiện NGUYÊN VĂN lý do, tấm vẫn mở', (t) async {
    final api = _DienNuocGia(
      loi: ApiException(
        422,
        'Chỉ số nhỏ hơn tháng trước (điện 852, nước 110). Kiểm tra lại công tơ.',
      ),
    );
    await moTamGui(t, api);
    expect(find.textContaining('nhỏ hơn tháng trước'), findsOneWidget);
    expect(find.byType(GuiChiSoSheet), findsOneWidget);
  });

  testWidgets('chỉ số tháng này đã duyệt → không mời gửi nữa', (t) async {
    await _dung(t, thue: [_thue(trangThai: 'da_duyet')]);
    await t.tap(find.textContaining('Đang thuê ('));
    await t.pumpAndSettle();
    expect(find.text('Gửi chỉ số điện nước'), findsNothing);
    expect(find.textContaining('đã duyệt'), findsOneWidget);
  });

  testWidgets('bị yêu cầu chụp lại → nói lý do, nút thành Gửi lại', (t) async {
    await _dung(
      t,
      thue: [_thue(trangThai: 'can_chup_lai', lyDo: 'Ảnh công tơ bị mờ')],
    );
    await t.tap(find.textContaining('Đang thuê ('));
    await t.pumpAndSettle();
    expect(find.textContaining('Ảnh công tơ bị mờ'), findsOneWidget);
    expect(find.text('Gửi lại chỉ số'), findsOneWidget);
  });
}
