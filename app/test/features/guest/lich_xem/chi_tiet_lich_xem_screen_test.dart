import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/data/services/viewing_v2_api.dart';
import 'package:house_booking/features/guest/lich_xem/chi_tiet_lich_xem_screen.dart';
import 'package:house_booking/features/guest/lich_xem/trang_thai_xem.dart';

import '../../../helpers/pump_app.dart';

/// Luồng lịch xem phòng phía khách (mockup 04/10/2026): Đã gửi lịch → Đã xác
/// nhận → Đã xem (đánh giá) → Đã chốt / Không chốt / Đã hủy.
final _bayGio = DateTime(2026, 10, 6, 12);

Map<String, dynamic> _phieu(String tt, {String? ketQua}) => {
  'id': 42,
  'ma': 'LH-0042',
  'trang_thai': tt,
  'ngay': '2026-10-07',
  'gio': '09:00-10:00',
  'loai': 'xem',
  'ket_qua': ketQua,
  'tin': {
    'tieu_de': 'Căn hộ Riverside',
    'anh_ds': <String>[],
    'dia_chi': '12 Nguyễn Hữu Thọ, Quận 7, TP.HCM',
    'house_id': 5,
  },
  'sale': {
    'id': 3,
    'ten': 'Nguyễn Minh Anh',
    'sdt': '0901111002',
    'so_lan_xem_xong': 128,
    'danh_gia': 4.9,
  },
};

class _LichGia extends LichXemApi {
  _LichGia(this.tt, {this.ketQua});

  String tt;
  String? ketQua;
  String? lyDoHuy;

  @override
  Future<PhieuHen> phieu(int id) async =>
      PhieuHen.fromMap(_phieu(tt, ketQua: ketQua));

  @override
  Future<PhieuHen> huy(int id, {String lyDo = ''}) async {
    lyDoHuy = lyDo;
    tt = 'cancelled';
    return PhieuHen.fromMap(_phieu(tt));
  }
}

/// Server chưa bật luồng v2 → 404, màn phải ghi theo luồng cũ.
class _V2Tat extends ViewingV2Api {
  @override
  Future<CanonicalViewing> submitResult(
    int id, {
    required String status,
    String? reasonCode,
    String? reasonNote,
  }) async => throw ApiException(404, 'Luồng lịch xem mới chưa được bật');
}

class _V2Ok extends ViewingV2Api {
  final goi = <String>[];

  @override
  Future<CanonicalViewing> submitResult(
    int id, {
    required String status,
    String? reasonCode,
    String? reasonNote,
  }) async {
    goi.add('$status|${reasonNote ?? ''}');
    return CanonicalViewing.fromMap({'id': id});
  }
}

class _JourneyGia extends RentalJourneyApi {
  final goi = <String>[];

  @override
  Future<RentalJourney> submitViewingResult(
    int appointmentId, {
    required bool interested,
    String? reason,
  }) async {
    goi.add('$interested|${reason ?? ''}');
    return RentalJourney.fromMap({'id': 1});
  }
}

void main() {
  Future<void> dung(
    WidgetTester t,
    LichXemApi api, {
    ViewingV2Api? v2,
    RentalJourneyApi? journey,
  }) async {
    t.view.physicalSize = const Size(400, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpApp(
      t,
      ChiTietLichXemScreen(
        appointmentId: 42,
        api: api,
        v2Api: v2 ?? _V2Ok(),
        journeyApi: journey ?? _JourneyGia(),
        bayGio: _bayGio,
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }

  test('quy đổi trạng thái thô sang bước của khách', () {
    final luc = DateTime(2026, 10, 7, 9);
    BuocXem b(String tt, {String? kq, DateTime? now}) =>
        buocXemCua(tt, ketQua: kq, luc: luc, bayGio: now ?? _bayGio);
    expect(b('pending'), BuocXem.daGui);
    expect(b('pending', now: DateTime(2026, 10, 7, 10)), BuocXem.hetHan);
    expect(b('doi_gio'), BuocXem.choChonGio);
    expect(b('approved'), BuocXem.daXacNhan);
    // Đã duyệt mà tới giờ hẹn → coi là đã xem (sale hiếm khi bấm hoàn thành).
    expect(b('approved', now: DateTime(2026, 10, 7, 9, 5)), BuocXem.daXem);
    expect(b('completed'), BuocXem.daXem);
    expect(b('completed', kq: 'chot'), BuocXem.daChot);
    expect(b('completed', kq: 'khong_chot'), BuocXem.khongChot);
    expect(b('cancelled'), BuocXem.daHuy);
    expect(b('rejected'), BuocXem.daHuy);
  });

  testWidgets('Đã gửi lịch: sale phụ trách + 5 bước + hủy → màn 5c', (t) async {
    final api = _LichGia('pending');
    await dung(t, api);
    expect(find.text('Căn hộ Riverside'), findsOneWidget);
    expect(find.text('Đã gửi lịch'), findsWidgets);
    expect(find.text('Thứ 4, 07/10/2026 • 09:00 - 10:00'), findsOneWidget);
    expect(find.text('Nguyễn Minh Anh'), findsOneWidget);
    expect(find.text('4.9'), findsOneWidget);
    expect(find.text('(128 lượt xem)'), findsOneWidget);
    expect(find.byKey(const Key('thanh-buoc-xem')), findsOneWidget);
    expect(find.byKey(const Key('hop-da-gui')), findsOneWidget);
    expect(find.text('Nhắn tin với sale'), findsOneWidget);

    await t.tap(find.byKey(const Key('huy-lich')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('ly-do-Tôi đã tìm được phòng khác')));
    await t.pump();
    await t.tap(find.byKey(const Key('xac-nhan-huy')));
    await t.pumpAndSettle();
    expect(api.lyDoHuy, 'Tôi đã tìm được phòng khác');
    expect(find.text('Đã hủy lịch xem phòng'), findsOneWidget);
    expect(find.byKey(const Key('ket-qua-dat-lai')), findsOneWidget);
    expect(find.byKey(const Key('ve-trang-chu')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Đã xác nhận: hộp xanh hẹn giờ + Đổi lịch', (t) async {
    await dung(t, _LichGia('approved'));
    expect(find.text('Đã xác nhận'), findsWidgets);
    expect(
      find.text(
        'Sale đã xác nhận lịch với chủ nhà. Hẹn gặp bạn lúc 09:00, '
        'Thứ 4, 07/10 tại Căn hộ Riverside.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('doi-lich')), findsOneWidget);
    expect(find.byKey(const Key('huy-lich')), findsNothing);
  });

  testWidgets('Đã xem: chốt + ghi chú → gửi v2 → màn 5a', (t) async {
    final v2 = _V2Ok();
    await dung(t, _LichGia('completed'), v2: v2);
    expect(find.text('Bạn thấy phòng này thế nào?'), findsOneWidget);
    expect(find.text('Sale: Nguyễn Minh Anh'), findsOneWidget);
    await t.tap(find.byKey(const Key('chon-chot')));
    await t.pump();
    await t.enterText(
      find.byKey(const Key('ghi-chu-danh-gia')),
      'Phòng sáng, hợp giá',
    );
    await t.tap(find.byKey(const Key('gui-danh-gia')));
    await t.pumpAndSettle();
    expect(v2.goi, ['INTERESTED|Phòng sáng, hợp giá']);
    expect(find.text('Đã chốt phòng!'), findsOneWidget);
    expect(find.byKey(const Key('ket-qua-xem-phong')), findsOneWidget);
  });

  testWidgets('Đã xem: v2 chưa bật → ghi luồng cũ → màn 5b', (t) async {
    final journey = _JourneyGia();
    await dung(
      t,
      _LichGia('completed'),
      v2: _V2Tat(),
      journey: journey,
    );
    await t.tap(find.byKey(const Key('chon-khong-chot')));
    await t.pump();
    await t.tap(find.byKey(const Key('gui-danh-gia')));
    await t.pumpAndSettle();
    expect(journey.goi, ['false|']);
    expect(find.text('Bạn chưa chốt phòng'), findsOneWidget);
    expect(find.byKey(const Key('ket-qua-xem-them')), findsOneWidget);
  });

  testWidgets('Đã chốt: mở lại từ lịch sử thấy hộp "Đang thuê"', (t) async {
    await dung(t, _LichGia('completed', ketQua: 'chot'));
    expect(find.text('Đã chốt'), findsWidgets);
    expect(find.byKey(const Key('hop-da-chot')), findsOneWidget);
    expect(find.text('Bạn thấy phòng này thế nào?'), findsNothing);
  });

  testWidgets('golden 360px: bốn dáng của màn chi tiết', (t) async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final (ten, tt) in const [
      ('da_gui', 'pending'),
      ('da_xac_nhan', 'approved'),
      ('da_xem', 'completed'),
      ('da_huy', 'cancelled'),
    ]) {
      t.view.physicalSize = const Size(360, 860);
      t.view.devicePixelRatio = 1;
      await pumpApp(
        t,
        ChiTietLichXemScreen(
          key: ValueKey(ten),
          appointmentId: 42,
          api: _LichGia(tt),
          v2Api: _V2Ok(),
          journeyApi: _JourneyGia(),
          bayGio: _bayGio,
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull);
      await expectLater(
        find.byType(ChiTietLichXemScreen),
        matchesGoldenFile('goldens/lich_xem_$ten.png'),
      );
    }
    t.view.reset();
  });
}
