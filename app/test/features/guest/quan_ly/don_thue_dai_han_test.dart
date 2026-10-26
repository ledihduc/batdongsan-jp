import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/don_thue_khach_api.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/data/services/sale_yeu_cau_api.dart';
import 'package:house_booking/features/guest/quan_ly/don_thue_chi_tiet_screen.dart';
import 'package:house_booking/features/guest/quan_ly/don_thue_dai_han_screen.dart';

import '../../../helpers/pump_app.dart';

/// Đơn thuê dài hạn của khách: danh sách chỉ giữ trạng thái và việc cần làm;
/// chi tiết cho thao tác trực tiếp thay vì lộ pipeline nội bộ.
const _buoc = [
  'lead_moi',
  'da_lien_he',
  'da_xac_nhan_lich',
  'sau_xem',
  'muon_thue',
  'cho_coc',
  'da_chot',
];
const _nhan = [
  'Đã gửi yêu cầu',
  'Đã được liên hệ',
  'Đã xác nhận lịch xem',
  'Đã xem nhà',
  'Muốn thuê',
  'Chờ cọc',
  'Đã chốt thuê',
];

Map<String, dynamic> _muc(int id, int so, {bool dong = false}) => {
  'nguon': 'lich_xem',
  'id': id,
  'ma': 'LX-${id.toString().padLeft(4, '0')}',
  'buoc': _buoc[so - 1],
  'buoc_so': so,
  'tong_buoc': 7,
  'nhan': _nhan[so - 1],
  'viec_tiep': dong ? 'Lịch xem đã huỷ' : 'Việc $so',
  'dong': dong,
  'ten': 'Căn $id',
  'dia_chi': 'Hồng Bàng',
  'gia': 8200000,
  'cap_nhat': '2026-09-23T06:00:00',
};

class _Api extends DonThueKhachApi {
  final nhomDaGoi = <String>[];

  @override
  Future<BangDonThue> danhSach({String nhom = 'tat_ca'}) async {
    nhomDaGoi.add(nhom);
    return BangDonThue.fromMap({
      'dem': {
        'tat_ca': 3,
        'dang_xu_ly': 1,
        'cho_coc': 1,
        'da_chot': 0,
        'da_dong': 1,
      },
      'don': nhom == 'cho_coc'
          ? [_muc(33, 6)]
          : [_muc(33, 6), _muc(37, 1), _muc(40, 1, dong: true)],
    });
  }

  @override
  Future<DonThueChiTiet> chiTiet(String nguon, int id) async =>
      DonThueChiTiet.fromMap({
        ..._muc(id, 6),
        'can': [
          {
            'id': 1,
            'house_id': 11,
            'ten': 'Căn hộ 2PN 60m²',
            'dia_chi': 'Thượng Lý',
            'gia': 8200000,
            'khach_thich': true,
          },
        ],
        'lich_xem': {'ngay': '2026-09-25', 'gio': '09:00'},
        'appointment_id': id,
        'journey_id': 7,
        'pipeline': [
          for (var i = 0; i < 7; i++)
            {
              'buoc': _buoc[i],
              'nhan': _nhan[i],
              'xong': i <= 5,
              'dang_o': i == 5,
              'luc': i <= 5 ? '2026-09-2${i}T06:02:00' : null,
            },
        ],
      });
}

class _ApiLich extends DonThueKhachApi {
  @override
  Future<DonThueChiTiet> chiTiet(String nguon, int id) async =>
      DonThueChiTiet.fromMap({
        ..._muc(id, 2),
        'can': [
          {
            'id': 1,
            'house_id': 11,
            'ten': 'Căn hộ 2PN 60m²',
            'dia_chi': 'Thượng Lý',
            'gia': 8200000,
            'khach_thich': true,
          },
        ],
        'lich_xem': {'ngay': '2026-09-25', 'gio': '09:00-10:00'},
        'appointment_id': id,
        'pipeline': const [],
      });
}

class _LichApi extends LichXemApi {
  String trangThai = 'approved';
  int? lichDaHuy;

  PhieuHen _phieu() => PhieuHen(
    id: 33,
    ma: 'LX-0033',
    ngay: '2026-09-25',
    gio: '09:00-10:00',
    trangThai: trangThai,
    tin: const TomTatCan(tieuDe: 'Căn hộ 2PN 60m²'),
  );

  @override
  Future<PhieuHen> phieu(int id) async => _phieu();

  @override
  Future<PhieuHen> huy(int id, {String lyDo = ''}) async {
    lichDaHuy = id;
    trangThai = 'cancelled';
    return _phieu();
  }
}

void main() {
  testWidgets('danh sách chỉ giữ tên, trạng thái và việc cần làm', (t) async {
    final api = _Api();
    await pumpApp(t, DonThueDaiHanScreen(api: api));
    await t.pumpAndSettle();
    expect(api.nhomDaGoi, ['tat_ca']);
    expect(find.text('Căn 33'), findsOneWidget);
    expect(find.text('Căn 37'), findsOneWidget);
    expect(find.text('LX-0033'), findsNothing);
    expect(find.text('Bước 6/7'), findsNothing);
    expect(find.text('Chờ cọc'), findsWidgets);
    expect(find.text('Đã đóng'), findsWidgets);

    await t.tap(find.byKey(const Key('don-thue-nhom-cho_coc')));
    await t.pumpAndSettle();
    expect(api.nhomDaGoi.last, 'cho_coc');
    expect(find.text('Căn 37'), findsNothing);
  });

  testWidgets('chi tiết chỉ giữ trạng thái hiện tại và nút đặt cọc', (t) async {
    t.view.physicalSize = const Size(430, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpApp(
      t,
      DonThueChiTietScreen(nguon: 'lich_xem', id: 33, api: _Api()),
    );
    await t.pumpAndSettle();
    expect(find.text('Tiến trình thuê'), findsNothing);
    expect(find.text('Đã gửi yêu cầu'), findsNothing);
    expect(find.text('Đã xác nhận lịch xem'), findsNothing);
    expect(find.text('Xem phiếu hẹn xem nhà'), findsNothing);
    expect(find.text('Đặt cọc & xác nhận thuê'), findsOneWidget);
    expect(find.text('Căn hộ 2PN 60m²'), findsOneWidget);
    expect(find.text('25/09/2026 · 09:00'), findsOneWidget);
  });

  testWidgets('lịch xem được đổi hoặc huỷ trực tiếp, không mở phiếu hẹn', (
    t,
  ) async {
    final lichApi = _LichApi();
    await pumpApp(
      t,
      DonThueChiTietScreen(
        nguon: 'lich_xem',
        id: 33,
        api: _ApiLich(),
        lichXemApi: lichApi,
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('Đã được liên hệ'), findsOneWidget);
    expect(find.byKey(const Key('don-thue-doi-lich')), findsOneWidget);
    expect(find.byKey(const Key('don-thue-huy-lich')), findsOneWidget);
    expect(find.text('Xem phiếu hẹn xem nhà'), findsNothing);
    expect(find.text('Tiến trình thuê'), findsNothing);

    await t.tap(find.byKey(const Key('don-thue-huy-lich')));
    await t.pumpAndSettle();
    expect(find.text('Huỷ lịch xem nhà?'), findsOneWidget);
    await t.tap(find.byKey(const Key('don-thue-xac-nhan-huy-lich')));
    await t.pumpAndSettle();
    expect(lichApi.lichDaHuy, 33);
    expect(find.text('Đã huỷ lịch xem nhà'), findsOneWidget);
    expect(find.byKey(const Key('don-thue-doi-lich')), findsNothing);
  });

  test('mốc không kèm múi giờ được hiểu là UTC', () {
    expect(gioVNTuUtc('2026-09-23T06:02:00'), DateTime(2026, 9, 23, 13, 2));
    expect(gioVNTuUtc('2026-09-23T06:02:00Z'), DateTime(2026, 9, 23, 13, 2));
    expect(
      gioVNTuUtc('2026-09-23T13:02:00+07:00'),
      DateTime(2026, 9, 23, 13, 2),
    );
    expect(gioVNTuUtc(null), isNull);
  });
}
