import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/reservation_model.dart';
import 'package:house_booking/data/services/lich_ngan_han_api.dart';
import 'package:house_booking/data/services/short_stay_api.dart';
import 'package:house_booking/features/host/ngan_han/the_su_kien_hom_nay.dart';

import '../../../helpers/pump_app.dart';

/// SỰ KIỆN SẮP TỚI TRONG HÔM NAY.
///
/// Điều phải giữ:
///   * xếp theo giờ, kèm "còn bao lâu"; quá giờ trả thì nổi đỏ;
///   * nhận/trả phòng mở ĐÚNG quy trình quầy, không đổi trạng thái trần;
///   * dọn xong là việc một nhát nên gọi thẳng bỏ khoá;
///   * cắt bớt khi quá dài, nói rõ còn bao nhiêu việc nữa;
///   * hỏng danh sách không được làm hỏng màn chứa nó.
class _ApiGia extends LichNganHanApi {
  _ApiGia(this.du);

  Map<String, dynamic>? du;

  @override
  Future<LichNgay> ngay(int buildingId, {String? ngay}) async {
    if (du == null) throw Exception('sap');
    return LichNgay.fromMap(du!);
  }
}

class _ShortStayGia extends ShortStayApi {
  const _ShortStayGia(this.ghi);

  final List<String> ghi;

  @override
  Future<void> unblock(int roomId, int blockId) async {
    ghi.add('unblock:$roomId:$blockId');
  }

  @override
  Future<ReservationModel> action(int id, String action, String? reason) async {
    ghi.add(reason == null ? '$action:$id' : '$action:$id:$reason');
    return ReservationModel.fromJson(const {
      'id': 1,
      'room_id': 1,
      'guest_name': 'x',
      'check_in_date': '2026-09-12',
      'check_out_date': '2026-09-13',
      'nights': 1,
      'total_amount': 0,
      'status': 'checked_out',
    });
  }
}

Map<String, dynamic> _du({List<Map<String, dynamic>>? viec}) => {
  'ngay': '2026-09-12',
  'bay_gio': '2026-09-12T14:30',
  'xem_tai_chinh': true,
  'toa': {'id': 10, 'ten': 'An Cư Garden', 'dia_chi': ''},
  'kpi': {
    'luot_dat': 3,
    'dang_o': 2,
    'so_phong': 4,
    'cong_suat': 50.0,
    'sap_tra': 1,
    'sap_tra_gio': 3,
    'doanh_thu': 0,
  },
  'phong': const [],
  'su_kien': viec ??
      [
        {
          'loai': 'cho_duyet',
          'luc': '2026-09-13T21:00',
          'room_id': 3,
          'ma_phong': 'P203',
          'reservation_id': 77,
          'nhan_kieu': 'Qua đêm',
          'ten': 'Hoàng Quân',
          'sale': 'Nguyễn Sale',
        },
        {
          'loai': 'nhan_phong',
          'luc': '2026-09-12T15:00',
          'room_id': 1,
          'ma_phong': 'P201',
          'reservation_id': 88,
          'nhan_kieu': 'Theo giờ',
          'ten': 'Trần Thị Mai',
        },
        {
          'loai': 'tra_phong',
          'luc': '2026-09-12T14:00',
          'room_id': 2,
          'ma_phong': 'P202',
          'reservation_id': 89,
          'nhan_kieu': 'Qua đêm',
          'ten': 'Lê Minh Hoàng',
          'qua_gio': true,
        },
        {
          'loai': 'don_xong',
          'luc': '2026-09-12T18:00',
          'room_id': 4,
          'ma_phong': 'P204',
          'block_id': 5,
          'ghi_chu': 'Vệ sinh phòng',
        },
      ],
};

Future<(_ApiGia, List<String>)> _mo(
  WidgetTester t, {
  Map<String, dynamic>? du,
  int soToiDa = 4,
}) async {
  t.view.physicalSize = const Size(1000, 1800);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  final api = _ApiGia(du ?? _du());
  final ghi = <String>[];
  await pumpApp(
    t,
    Scaffold(
      body: SingleChildScrollView(
        child: TheSuKienHomNay(
          buildingId: 10,
          roomIdNhanManh: 1,
          api: api,
          shortStayApi: _ShortStayGia(ghi),
          soToiDa: soToiDa,
        ),
      ),
    ),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
  return (api, ghi);
}

void main() {
  testWidgets('liệt kê việc kèm giờ và còn bao lâu', (t) async {
    await _mo(t);
    expect(find.text('Sự kiện sắp tới trong hôm nay'), findsOneWidget);
    expect(find.text('P201 · Trần Thị Mai'), findsOneWidget);
    expect(find.text('15:00'), findsOneWidget);
    expect(find.text('Trong 30 phút'), findsOneWidget);
    expect(find.text('Nhận phòng'), findsOneWidget);
    expect(find.text('Trả phòng'), findsOneWidget);
    expect(find.text('Hoàn thành'), findsOneWidget);
  });

  testWidgets('quá giờ trả thì nói thẳng là quá', (t) async {
    await _mo(t);
    expect(find.text('Check-out · đã quá giờ'), findsOneWidget);
    expect(find.text('Quá 30 phút'), findsOneWidget);
  });

  testWidgets('nhận phòng mở quy trình 3 bước, không đổi trạng thái trần', (t) async {
    final (_, ghi) = await _mo(t);
    await t.tap(find.byKey(const ValueKey('su-kien-nhan_phong-88')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Quy trình check-in'), findsOneWidget);
    expect(ghi, isEmpty);
  });

  testWidgets('dọn xong gọi thẳng bỏ khoá', (t) async {
    final (_, ghi) = await _mo(t);
    await t.tap(find.byKey(const ValueKey('su-kien-don_xong-5')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(ghi, ['unblock:4:5']);
  });

  testWidgets('quá dài thì cắt bớt và nói còn bao nhiêu việc', (t) async {
    await _mo(t, soToiDa: 2);
    expect(find.text('Còn 2 việc nữa trong hôm nay.'), findsOneWidget);
  });

  testWidgets('đơn chờ duyệt đứng đầu, ghi rõ qua sale nào', (t) async {
    await _mo(t);
    expect(find.text('ĐƠN MỚI'), findsOneWidget);
    expect(find.text('P203 · Hoàng Quân'), findsOneWidget);
    expect(find.textContaining('qua sale Nguyễn Sale'), findsOneWidget);
    final yDon = t.getTopLeft(find.text('P203 · Hoàng Quân')).dy;
    final yNhan = t.getTopLeft(find.text('P201 · Trần Thị Mai')).dy;
    expect(yDon, lessThan(yNhan));
  });

  testWidgets('duyệt đơn ngay tại chỗ', (t) async {
    final (_, ghi) = await _mo(t);
    await t.tap(find.byKey(const ValueKey('duyet-77')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(ghi, ['approve:77']);
  });

  testWidgets('từ chối phải có lý do rồi mới gửi', (t) async {
    final (_, ghi) = await _mo(t);
    await t.tap(find.byKey(const ValueKey('tu-choi-77')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('xac-nhan-tu-choi')));
    await t.pump();
    expect(ghi, isEmpty, reason: 'lý do trống thì chưa gửi');

    await t.enterText(find.byKey(const ValueKey('ly-do-tu-choi')), 'Phòng đang sửa');
    await t.tap(find.byKey(const ValueKey('xac-nhan-tu-choi')));
    await t.pumpAndSettle();
    expect(ghi, ['reject:77:Phòng đang sửa']);
  });

  testWidgets('không có việc nào thì nói thẳng, không để khoảng trống', (t) async {
    await _mo(t, du: _du(viec: const []));
    expect(find.textContaining('Hôm nay không có việc nào'), findsOneWidget);
    expect(find.text('Xem tất cả'), findsNothing);
  });

  testWidgets('API hỏng thì báo gọn, không ném lỗi ra màn', (t) async {
    final api = _ApiGia(null);
    await pumpApp(
      t,
      Scaffold(body: TheSuKienHomNay(buildingId: 10, api: api)),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Chưa tải được việc trong ngày.'), findsOneWidget);
    expect(tester_khongLoi(t), isTrue);
  });
}

/// Không có ngoại lệ nào chưa bắt lọt ra khung widget.
bool tester_khongLoi(WidgetTester t) => t.takeException() == null;
