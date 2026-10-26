import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/reservation_model.dart';
import 'package:house_booking/data/services/lich_ngan_han_api.dart';
import 'package:house_booking/data/services/short_stay_api.dart';
import 'package:house_booking/features/host/ngan_han/lich_ngan_han_screen.dart';

import '../../../helpers/pump_app.dart';
import 'ca_thue/ca_thue_gia.dart';

/// LỊCH PHÒNG NGẮN HẠN — ma trận phòng × giờ của cả toà.
///
/// Điều phải giữ:
///   * mỗi phòng một hàng, mỗi ca một khối đúng khung giờ — đọc được ngay khe
///     nào còn trống để nhận khách đang đứng trước mặt;
///   * khoảng khoá dọn phòng cũng là khối, không giấu;
///   * "việc phải làm" xếp theo giờ và bấm được: nhận / trả (mở đúng quy trình
///     quầy, không đổi trạng thái trần) / dọn xong;
///   * quá giờ trả phải nổi lên đỏ, không chìm trong danh sách.
class _ApiGia extends LichNganHanApi {
  _ApiGia(this.du);

  Map<String, dynamic> du;
  final ngayDaHoi = <String?>[];

  @override
  Future<LichNgay> ngay(int buildingId, {String? ngay}) async {
    ngayDaHoi.add(ngay);
    return LichNgay.fromMap(du);
  }
}

class _ShortStayGia extends ShortStayApi {
  const _ShortStayGia(this.ghi);

  final List<String> ghi;

  @override
  Future<ReservationModel> action(int id, String action, String? reason) async {
    ghi.add('$action:$id');
    return ReservationModel.fromJson(const {
      'id': 1, 'room_id': 1, 'guest_name': 'x',
      'check_in_date': '2026-09-12', 'check_out_date': '2026-09-13',
      'nights': 1, 'total_amount': 0, 'status': 'checked_out',
    });
  }

  @override
  Future<void> unblock(int roomId, int blockId) async {
    ghi.add('unblock:$roomId:$blockId');
  }
}

Map<String, dynamic> _du() => {
  'ngay': '2026-09-12',
  'bay_gio': '2026-09-12T16:30',
  'xem_tai_chinh': true,
  'toa': {'id': 10, 'ten': 'An Cư Garden', 'dia_chi': '25 Hoàng Văn Thụ'},
  'kpi': {
    'luot_dat': 3, 'dang_o': 2, 'so_phong': 4, 'cong_suat': 50.0,
    'sap_tra': 1, 'sap_tra_gio': 3, 'doanh_thu': 1260000,
  },
  'phong': [
    {
      'id': 1, 'ma': 'GARDEN-01', 'suc_chua': 2, 'trang_thai': 'occupied',
      'hang': 'Vườn rộng',
      'muc': [
        {
          'loai': 'dat', 'id': 88, 'tu': '2026-09-12T14:00',
          'den': '2026-09-12T18:00', 'tran_truoc': false, 'tran_sau': false,
          'trang_thai': 'checked_in', 'kieu': 'theo_gio', 'nhan_kieu': 'Theo giờ',
          'nguon': 'manual', 'ten': 'Nguyễn Văn An', 'tong': 280000,
        },
        {
          'loai': 'chan', 'id': 5, 'tu': '2026-09-12T18:00',
          'den': '2026-09-12T19:30', 'tran_truoc': false, 'tran_sau': false,
          'ghi_chu': 'Dọn phòng',
        },
      ],
    },
    {
      'id': 2, 'ma': 'GARDEN-02', 'suc_chua': 2, 'trang_thai': 'vacant',
      'hang': 'Vườn tiêu chuẩn', 'muc': [],
    },
  ],
  'su_kien': [
    {
      'loai': 'tra_phong', 'luc': '2026-09-12T16:00', 'room_id': 1,
      'ma_phong': 'GARDEN-01', 'reservation_id': 88, 'nhan_kieu': 'Theo giờ',
      'ten': 'Nguyễn Văn An', 'qua_gio': true,
    },
    {
      'loai': 'don_xong', 'luc': '2026-09-12T19:30', 'room_id': 1,
      'ma_phong': 'GARDEN-01', 'block_id': 5, 'ghi_chu': 'Dọn phòng',
    },
    {
      'loai': 'nhan_phong', 'luc': '2026-09-12T21:00', 'room_id': 2,
      'ma_phong': 'GARDEN-02', 'reservation_id': 91, 'nhan_kieu': 'Qua đêm',
      'ten': 'Trần Thị Mai',
    },
  ],
};

Future<({_ApiGia api, List<String> ghi, CaThueGia quay})> _mo(WidgetTester t) async {
  t.view.physicalSize = const Size(1100, 2400);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  final api = _ApiGia(_du());
  final ghi = <String>[];
  final quay = CaThueGia(mauCa());
  await pumpApp(
    t,
    LichNganHanScreen(
      buildingId: 10,
      api: api,
      shortStayApi: _ShortStayGia(ghi),
      caThueApi: quay,
      ngayBanDau: '2026-09-12',
    ),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
  return (api: api, ghi: ghi, quay: quay);
}

void main() {
  testWidgets('ma trận: mỗi phòng một hàng, ca và khoá đều có khối', (t) async {
    await _mo(t);
    expect(find.text('Lịch phòng ngắn hạn'), findsOneWidget);
    expect(find.text('An Cư Garden · 4 phòng'), findsOneWidget);
    expect(find.text('GARDEN-01'), findsOneWidget);
    expect(find.text('GARDEN-02'), findsOneWidget);
    expect(find.byKey(const ValueKey('khoi-dat-88')), findsOneWidget);
    expect(find.byKey(const ValueKey('khoi-chan-5')), findsOneWidget);
    expect(find.text('14:00–18:00'), findsOneWidget);
  });

  testWidgets('KPI: lượt đặt, đang ở kèm công suất, sắp trả, doanh thu', (t) async {
    await _mo(t);
    expect(find.text('Lượt đặt'), findsOneWidget);
    expect(find.text('50% công suất'), findsOneWidget);
    expect(find.text('trong 3 giờ tới'), findsOneWidget);
    expect(find.text('1.3tr'), findsOneWidget);
  });

  testWidgets('việc phải làm: quá giờ nổi đỏ, bấm trả phòng mở thủ tục', (t) async {
    final r = await _mo(t);
    expect(find.text('GARDEN-01 · Trả phòng · Nguyễn Văn An'), findsOneWidget);
    expect(find.text('Đã quá giờ trả'), findsOneWidget);
    expect(find.text('quá 30 phút'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('viec-tra_phong-88')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Trả phòng & quyết toán'), findsOneWidget);
    expect(r.quay.ghi, contains('lay:88'));
    expect(r.ghi, isEmpty, reason: 'không check-out trần, phải qua quyết toán');
  });

  testWidgets('dọn xong: bỏ khoá phòng đúng khối', (t) async {
    final r = await _mo(t);
    await t.tap(find.byKey(const ValueKey('viec-don_xong-5')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(r.ghi, ['unblock:1:5']);
  });

  testWidgets('đổi ngày: hỏi server đúng ngày kế tiếp', (t) async {
    final r = await _mo(t);
    await t.tap(find.byKey(const ValueKey('ngay-sau')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(r.api.ngayDaHoi.last, '2026-09-13');
  });
}
