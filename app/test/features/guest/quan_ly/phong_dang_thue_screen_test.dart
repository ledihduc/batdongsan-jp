import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/services/giay_to_hop_dong_api.dart';
import 'package:house_booking/data/services/dang_thue_api.dart';
import 'package:house_booking/features/guest/quan_ly/phong_dang_thue_screen.dart';

import '../../../helpers/pump_app.dart';

/// Chuỗi màn khách đang thuê theo mockup 04/10/2026: chi tiết phòng → hợp
/// đồng · hóa đơn → chi tiết hóa đơn · điện nước · báo sự cố.
class _DangThueGia extends DangThueApi {
  final suCo = <Map<String, Object>>[];

  @override
  Future<Map<String, dynamic>> hoSo(int contractId) async => {
    'room': {
      'code': 'P305',
      'images': <String>[],
      'area_m2': 28,
      'tang': '3',
      'loai_phong': 'Studio',
    },
    'toa': {
      'ten': 'Vạn Phúc Residence',
      'dia_chi': '12 Nguyễn Thị Thập, Quận 7, TP.HCM',
    },
    'hop_dong': {
      'id': 7,
      'bat_dau': '2026-09-01',
      'ket_thuc': '2027-08-31',
      'tien_thue': 5000000,
      'tien_coc': 10000000,
      'ngay_thanh_toan': 5,
      'hinh_thuc_thanh_toan': 'chuyen_khoan',
    },
    'ngay_ky': '2026-09-01',
    'anh_hop_dong': <String>[],
    'lien_he': {'vai': 'Quản lý', 'ten': 'Chị Lan', 'sdt': '0909000111'},
    'thanh_toan': {
      'bin': '970436',
      'ngan_hang': 'VCB',
      'so_tai_khoan': '0123456789',
      'chu_tai_khoan': 'NGUYEN VAN A',
    },
    'dien_nuoc': {'thang': '2026-10', 'trang_thai': 'chua_gui'},
    'dien_nuoc_lich_su': [
      {'thang': '2026-09', 'ngay_gui': '2026-09-02', 'trang_thai': 'da_duyet'},
    ],
    'hoa_don': [
      {
        'id': 1,
        'so': 'HD-001',
        'ky': '2026-10',
        'tong': 5090000,
        'da_tra': 0,
        'trang_thai': 'sent',
        'han_dong': '2099-10-05',
      },
      {
        'id': 2,
        'ky': '2026-09',
        'tong': 5090000,
        'da_tra': 5090000,
        'trang_thai': 'paid',
        'han_dong': '2026-09-05',
      },
    ],
  };

  @override
  Future<void> baoSuCo({
    required int contractId,
    required String loai,
    required String moTa,
    List<String> anh = const [],
  }) async {
    suCo.add({'contract': contractId, 'loai': loai, 'mo_ta': moTa});
  }
}

/// Giấy tờ hợp đồng giả: khởi đầu thiếu cả hai, khách tải là ghi lại.
class _GiayToGia extends GiayToHopDongApi {
  final taiLen = <(String, List<String>)>[];
  var co = <String>{};

  GiayToHopDong _goi(int id) => GiayToHopDong.fromMap({
    'contract_id': id,
    'vai': 'khach',
    'hop_dong': [if (co.contains('hop_dong')) {'id': 1, 'url': '/uploads/hd.jpg', 'nhan_vai': 'Khách thuê', 'xoa_duoc': true}],
    'minh_chung_coc': const [],
    'thieu': [for (final l in ['hop_dong', 'minh_chung_coc']) if (!co.contains(l)) l],
  });

  @override
  Future<GiayToHopDong> xem(int contractId) async => _goi(contractId);

  @override
  Future<GiayToHopDong> them(int contractId, String loai, List<String> urls) async {
    taiLen.add((loai, urls));
    co.add(loai);
    return _goi(contractId);
  }
}

void main() {
  late _DangThueGia api;
  late _GiayToGia giayTo;

  Future<void> dung(WidgetTester t) async {
    t.view.physicalSize = const Size(400, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    api = _DangThueGia();
    giayTo = _GiayToGia();
    await pumpApp(t, PhongDangThueScreen(contractId: 7, api: api, giayToApi: giayTo));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }

  Future<void> mo(WidgetTester t, String loi) async {
    await t.tap(find.byKey(Key('loi-$loi')));
    await t.pumpAndSettle();
  }

  testWidgets('màn 2: chi tiết phòng đang thuê đúng mockup', (t) async {
    await dung(t);
    expect(find.text('Phòng 305 – Vạn Phúc Residence'), findsOneWidget);
    expect(find.text('Quận 7, TP.HCM'), findsOneWidget);
    expect(find.text('Đang thuê'), findsOneWidget);
    expect(find.text('01/09/2026 – 31/08/2027'), findsOneWidget);
    for (final l in ['Hợp đồng', 'Hóa đơn', 'Điện nước', 'Báo sự cố']) {
      expect(find.byKey(Key('loi-$l')), findsOneWidget);
    }
    expect(find.text('Thông tin phòng'), findsOneWidget);
    expect(find.text('Studio'), findsOneWidget);
    expect(find.text('28 m²'), findsOneWidget);
    expect(find.text('Thông tin liên hệ'), findsOneWidget);
    expect(find.text('Quản lý · Chị Lan'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('màn 3: hợp đồng hiện tại + thông tin hợp đồng', (t) async {
    await dung(t);
    await mo(t, 'Hợp đồng');
    expect(find.text('Hợp đồng hiện tại'), findsOneWidget);
    expect(find.text('Đang hiệu lực'), findsOneWidget);
    expect(find.text('HD305_01092026.pdf'), findsOneWidget);
    expect(find.text('5.000.000đ/tháng'), findsOneWidget);
    expect(find.text('10.000.000đ'), findsOneWidget);
    expect(find.text('Ngày 05'), findsOneWidget);
    expect(find.text('Gia hạn hợp đồng'), findsOneWidget);
  });

  testWidgets('màn 3: giấy tờ hợp đồng — cảnh báo thiếu, khách tự tải lên', (t) async {
    await dung(t);
    await mo(t, 'Hợp đồng');
    await t.scrollUntilVisible(find.byKey(const Key('giay-to-hop-dong')), 300);
    expect(find.byKey(const Key('giay-to-canh-bao')), findsOneWidget);
    expect(find.textContaining('Hợp đồng · chưa có'), findsOneWidget);
    expect(find.byKey(const Key('giay-to-tai-hop_dong')), findsOneWidget);
    expect(find.byKey(const Key('giay-to-tai-minh_chung_coc')), findsOneWidget);
  });

  testWidgets('màn 4-5: hóa đơn theo tab rồi chi tiết + chuyển khoản', (
    t,
  ) async {
    await dung(t);
    await mo(t, 'Hóa đơn');
    expect(find.text('Hóa đơn tháng 10/2026'), findsOneWidget);
    expect(find.text('Hóa đơn tháng 09/2026'), findsNothing);
    await t.tap(find.byKey(const Key('tab-phai')));
    await t.pump();
    expect(find.text('Hóa đơn tháng 09/2026'), findsOneWidget);
    expect(find.text('Đã thanh toán'), findsWidgets);
    await t.tap(find.byKey(const Key('tab-trai')));
    await t.pump();
    await t.tap(find.text('Thanh toán'));
    await t.pumpAndSettle();
    expect(find.text('Chi tiết hóa đơn'), findsWidgets);
    expect(find.text('Chuyển khoản ngân hàng'), findsOneWidget);
    await t.tap(find.byKey(const Key('thanh-toan-ngay')));
    await t.pumpAndSettle();
    expect(find.text('0123456789'), findsOneWidget);
    // Có BIN → mã VietQR điền sẵn số tiền + nội dung (chuyển khoản ngay trong app).
    expect(find.byKey(const Key('hoa-don-vietqr')), findsOneWidget);
  });

  testWidgets('màn 6: điện nước — kỳ chưa gửi và kỳ đã gửi', (t) async {
    await dung(t);
    await mo(t, 'Điện nước');
    expect(find.text('Kỳ tháng 10/2026'), findsOneWidget);
    expect(find.text('Chưa gửi ảnh'), findsWidgets);
    expect(find.text('Gửi ảnh'), findsOneWidget);
    await t.tap(find.byKey(const Key('tab-phai')));
    await t.pump();
    expect(find.text('Kỳ tháng 09/2026'), findsOneWidget);
    expect(find.text('Đã gửi ngày 02/09/2026'), findsOneWidget);
  });

  testWidgets('màn 9-10: báo sự cố gửi đúng API rồi xác nhận', (t) async {
    await dung(t);
    await mo(t, 'Báo sự cố');
    expect(find.text('Loại sự cố *', findRichText: true), findsOneWidget);
    await t.tap(find.byKey(const Key('loai-su-co')));
    await t.pumpAndSettle();
    await t.tap(find.text('Điện').last);
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const Key('mo-ta-su-co')),
      'Ổ cắm cạnh giường bị chập',
    );
    await t.pump();
    await t.tap(find.byKey(const Key('gui-su-co')));
    await t.pumpAndSettle();
    expect(api.suCo, [
      {'contract': 7, 'loai': 'Điện', 'mo_ta': 'Ổ cắm cạnh giường bị chập'},
    ]);
    expect(find.text('Đã gửi yêu cầu'), findsOneWidget);
    expect(find.byKey(const Key('ve-trang-chu')), findsOneWidget);
  });
}
