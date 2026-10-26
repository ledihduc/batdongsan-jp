import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/ho_so_ngan_han_api.dart';
import 'package:house_booking/data/services/lich_gio_api.dart';
import 'package:house_booking/data/services/lich_ngan_han_api.dart';
import 'package:house_booking/data/services/short_stay_api.dart';
import 'package:house_booking/data/models/reservation_model.dart';
import 'package:house_booking/features/host/ngan_han/ho_so_phong_ngan_han_screen.dart';

import '../../../helpers/pump_app.dart';
import 'ca_thue/ca_thue_gia.dart';

/// Hồ sơ & quản trị phòng NGẮN HẠN — mockup "P201" (12/09/2026).
///
/// Điều phải giữ:
///   * bốn câu hỏi của phòng giờ: ai đang trong phòng · còn mấy phút · ca sau
///     là ai · trả phòng thu bao nhiêu — đều phải đọc được không cần bấm;
///   * quá giờ trả phòng phải NỔI lên, không chìm trong hai mốc thời gian;
///   * phòng trống thì mời mở ca vãng lai, không vẽ khối khách rỗng;
///   * nhận/trả phòng KHÔNG đổi trạng thái trần mà mở đúng quy trình quầy
///     (thu tiền, kiểm phòng, khoá dọn) — bấm một nút rồi quên thu là mất tiền.
class _ApiGia extends HoSoNganHanApi {
  _ApiGia(this.map);

  Map<String, dynamic> map;
  final ngayDaHoi = <String?>[];

  @override
  Future<HoSoNganHan> lay(int roomId, {String? ngay}) async {
    ngayDaHoi.add(ngay);
    return HoSoNganHan.fromMap(map);
  }
}

/// Cục lịch trong thẻ LỊCH PHÒNG tự gọi `lich-gio`; test phải bơm giả, không
/// thì widget đi mạng thật và treo.
class _LichGioGia extends LichGioApi {
  const _LichGioGia();

  @override
  Future<LichGio> lay(int roomId, {String? tuNgay, int soTuan = 4, String moc = 'tuan'}) async =>
      LichGio.fromMap({
        'tu_ngay': '2026-09-07',
        'den_ngay': '2026-10-04',
        'so_tuan': 4,
        'so_ngay': 28,
        'bay_gio': '2026-09-12T16:45',
        'xem_tai_chinh': true,
        'phong': {'id': 7, 'ma': 'P201', 'suc_chua': 2, 'building_id': 10},
        'toa': {'id': 10, 'ten': 'An Cu Garden', 'dia_chi': ''},
        'cac_phong': [
          {'id': 7, 'ma': 'P201'},
        ],
        'kpi': {
          'luot_dat': 1,
          'gio_ban': 4.0,
          'so_ngay': 28,
          'cong_suat': 0.6,
          'doanh_thu': 280000,
        },
        'ngay': [
          for (var i = 0; i < 28; i++)
            {
              'ngay': _isoNgay(DateTime(2026, 9, 7).add(Duration(days: i))),
              'thu': DateTime(2026, 9, 7).add(Duration(days: i)).weekday,
              'hom_nay': i == 5,
              'cuoi_tuan':
                  DateTime(2026, 9, 7).add(Duration(days: i)).weekday >= 6,
              'so_ca': i == 5 ? 1 : 0,
              'gio_ban': i == 5 ? 4.0 : 0.0,
              'ty_le': i == 5 ? 16.7 : 0.0,
              'doanh_thu': i == 5 ? 280000 : 0,
              'muc': i == 5
                  ? [
                      {
                        'loai': 'dat',
                        'id': 88,
                        'gio': 15.0,
                        'so_gio': 4.0,
                        'trang_thai': 'checked_in',
                        'nhan_kieu': 'Theo gio',
                        'ten': 'Nguyen Van An',
                        'tong': 280000,
                      },
                    ]
                  : const [],
            },
        ],
      });
}

String _isoNgay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Thẻ "Sự kiện sắp tới" tự gọi lịch ngày của cả toà — bơm giả cho khỏi đi mạng.
class _LichNgayGia extends LichNganHanApi {
  const _LichNgayGia();

  @override
  Future<LichNgay> ngay(int buildingId, {String? ngay}) async =>
      LichNgay.fromMap(const {
        'ngay': '2026-09-12',
        'bay_gio': '2026-09-12T14:30',
        'xem_tai_chinh': true,
        'toa': {'id': 10, 'ten': 'An Cu Garden', 'dia_chi': ''},
        'kpi': {
          'luot_dat': 1,
          'dang_o': 1,
          'so_phong': 1,
          'cong_suat': 100.0,
          'sap_tra': 0,
          'sap_tra_gio': 3,
          'doanh_thu': 0,
        },
        'phong': [],
        'su_kien': [],
      });
}

class _ShortStayGia extends ShortStayApi {
  const _ShortStayGia(this.ghi);

  final List<String> ghi;

  @override
  Future<ReservationModel> action(int id, String action, String? reason) async {
    ghi.add('$action:$id');
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

Map<String, dynamic> _du({
  Map<String, dynamic>? khach,
  List<Map<String, dynamic>> lich = const [],
  double doanhThu = 0,
}) => {
  'ngay': '2026-09-12',
  'bay_gio': '2026-09-12T16:45',
  'xem_tai_chinh': true,
  'room': {
    'id': 7,
    'ma': 'P201',
    'trang_thai': 'occupied',
    'dien_tich': 28,
    'tang': '2',
    'suc_chua': 2,
    'loai_phong': 'Studio VIP',
    'do_trong_phong': ['dieu_hoa', 'nong_lanh'],
    'anh': [],
  },
  'toa': {'id': 3, 'ten': 'An Cư Garden', 'dia_chi': '25 Hoàng Văn Thụ'},
  'gia': {
    'gio': 80000,
    'qua_dem': 650000,
    'ngay': 900000,
    'niem_yet': 650000,
    'dang_bat': true,
    'gia_dien': 3500,
    'gia_nuoc': 15000,
  },
  'khach': khach,
  'lich': lich,
  'thong_ke_ngay': {'so_ca': lich.length, 'so_chan': 0, 'doanh_thu': doanhThu},
};

Map<String, dynamic> _khachDangO({bool quaGio = false, String trangThai = 'checked_in'}) => {
  'reservation_id': 88,
  'trang_thai': trangThai,
  'kieu': 'theo_gio',
  'nhan_kieu': 'Theo giờ',
  'vao': '2026-09-12T14:00',
  'ra': '2026-09-12T18:00',
  'so_dem': 1,
  'nguon': 'manual',
  'ten': 'Nguyễn Văn An',
  'sdt': '0982345678',
  'ma_dat': 'AC-260912-AB12',
  'tong': 370000,
  'coc': 200000,
  'con_thu': 170000,
  'tien_do': {
    'tong_phut': 240,
    'da_o_phut': quaGio ? 270 : 165,
    'con_phut': quaGio ? 30 : 75,
    'phan_tram': quaGio ? 100 : 68.8,
    'qua_gio': quaGio,
  },
};

Future<({_ApiGia api, List<String> ghi, CaThueGia quay})> _mo(
  WidgetTester t,
  Map<String, dynamic> du,
) async {
  t.view.physicalSize = const Size(1000, 2600);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  final api = _ApiGia(du);
  final ghi = <String>[];
  final quay = CaThueGia(mauCa());
  await pumpApp(
    t,
    HoSoPhongNganHanScreen(
      roomId: 7,
      api: api,
      shortStayApi: _ShortStayGia(ghi),
      caThueApi: quay,
      lichGioApi: const _LichGioGia(),
      lichApi: const _LichNgayGia(),
      ngayBanDau: '2026-09-12',
    ),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
  return (api: api, ghi: ghi, quay: quay);
}

void main() {
  testWidgets('khách đang trong phòng: tên, giờ, tiến độ và tiền cần thu', (t) async {
    await _mo(t, _du(khach: _khachDangO()));
    expect(find.text('Phòng P201'), findsOneWidget);
    expect(find.text('Đang có khách'), findsOneWidget);
    expect(find.text('KHÁCH ĐANG TRONG PHÒNG'), findsOneWidget);
    expect(find.text('Nguyễn Văn An'), findsOneWidget);
    expect(find.textContaining('Nhận 14:00'), findsOneWidget);
    expect(find.text('Còn 1h15'), findsOneWidget);
    // Bảng giá ba hình thức, đúng như mockup (giá luôn đi kèm đơn vị).
    expect(find.text('80.000đ/giờ'), findsOneWidget);
    expect(find.text('650.000đ/đêm'), findsOneWidget);
    expect(find.text('900.000đ/ngày'), findsOneWidget);
    // Tiền của ca: cọc đã nhận và số phải thu khi trả phòng.
    expect(find.text('200.000đ'), findsOneWidget);
    expect(find.text('170.000đ'), findsNWidgets(2)); // ô "cần thu" + dòng tổng
  });

  testWidgets('quá giờ trả phòng thì nổi lên ở nhãn và tiến độ', (t) async {
    await _mo(t, _du(khach: _khachDangO(quaGio: true)));
    expect(find.text('Quá giờ trả'), findsOneWidget);
    expect(find.text('Quá giờ 30 phút'), findsOneWidget);
  });

  testWidgets('trả phòng: mở thủ tục check-out, không đổi trạng thái trần', (t) async {
    final r = await _mo(t, _du(khach: _khachDangO()));
    await t.tap(find.byKey(const ValueKey('checkout-quyet-toan')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));

    expect(find.text('Trả phòng & quyết toán'), findsOneWidget);
    expect(find.text('CHECKLIST KIỂM PHÒNG NHANH'), findsOneWidget);
    expect(r.ghi, isEmpty, reason: 'không được check-out trần bỏ qua quyết toán');
    expect(r.quay.ghi, contains('lay:88'));
  });

  testWidgets('ca đã duyệt chưa tới giờ: mời NHẬN PHÒNG, mở quy trình 3 bước', (t) async {
    final r = await _mo(t, _du(khach: _khachDangO(trangThai: 'approved')));
    expect(find.text('CA SẮP TỚI'), findsOneWidget);
    expect(find.text('Sắp có khách'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nhan-phong-chinh')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Quy trình check-in'), findsOneWidget);
    expect(find.text('Bước 1/3'), findsOneWidget);
    expect(r.ghi, isEmpty, reason: 'check-in chỉ xảy ra ở cuối quy trình');
  });

  testWidgets('phòng trống: mời mở ca vãng lai, không vẽ khối khách rỗng', (t) async {
    await _mo(t, _du());
    expect(find.text('PHÒNG ĐANG TRỐNG'), findsOneWidget);
    expect(find.text('Trống'), findsOneWidget);
    expect(find.byKey(const ValueKey('khach-dang-o')), findsNothing);
    expect(find.byKey(const ValueKey('tai-chinh-ca')), findsNothing);
    // ĐÚNG MỘT nút mở ca — ở thanh dưới. Thẻ "phòng trống" chỉ chỉ đường tới
    // nó; hai nút đỏ giống hệt nhau trên một màn là lỗi, không phải tiện.
    expect(find.byKey(const ValueKey('mo-ca-chinh')), findsOneWidget);
    expect(find.text('Mở ca cho khách vãng lai'), findsOneWidget);
  });

  testWidgets('lịch trong ngày: ca thuê và khoảng khoá dọn phòng', (t) async {
    await _mo(t, _du(
      lich: [
        {
          'loai': 'dat', 'id': 88, 'tu': '2026-09-12T14:00', 'den': '2026-09-12T18:00',
          'kieu': 'theo_gio', 'nhan_kieu': 'Theo giờ', 'trang_thai': 'checked_in',
          'nguon': 'manual', 'ten': 'Nguyễn Văn An', 'tong': 370000,
        },
        {
          'loai': 'chan', 'id': 5, 'tu': '2026-09-12T18:00',
          'den': '2026-09-12T19:30', 'ghi_chu': 'Dọn phòng, thay ga gối',
        },
        {
          'loai': 'dat', 'id': 91, 'tu': '2026-09-12T20:00', 'den': '2026-09-13T11:00',
          'kieu': 'qua_dem', 'nhan_kieu': 'Qua đêm', 'trang_thai': 'approved',
          'nguon': 'agoda', 'ten': 'Trần Thị Mai', 'tong': 650000,
        },
      ],
      doanhThu: 1020000,
    ));
    expect(find.text('14:00 – 18:00'), findsOneWidget);
    expect(find.text('Dọn phòng, thay ga gối'), findsOneWidget);
    expect(find.text('Trần Thị Mai'), findsOneWidget);
    expect(find.text('Đang trong phòng'), findsOneWidget);
    expect(find.text('1.020.000đ'), findsOneWidget);
    expect(find.byKey(const ValueKey('them-ca')), findsOneWidget);
    expect(find.byKey(const ValueKey('khoa-don-phong')), findsOneWidget);
  });

  testWidgets('cục lịch: bấm một ngày thì hỏi server đúng ngày đó', (t) async {
    final r = await _mo(t, _du());
    await t.tap(find.byKey(const ValueKey('o-lich-2026-09-13')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(r.api.ngayDaHoi.last, '2026-09-13');
  });

  testWidgets('thẻ lịch có cục lịch 4 tuần thay cho ba tab ngày', (t) async {
    await _mo(t, _du());
    expect(find.byKey(const ValueKey('ngay-1')), findsNothing);
    expect(find.byKey(const ValueKey('o-lich-2026-09-12')), findsOneWidget);
    expect(find.byKey(const ValueKey('o-lich-2026-10-04')), findsOneWidget);
    expect(find.text('Xem sơ đồ 4 tuần'), findsOneWidget);
  });
}
