import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/su_kien_lich_su.dart';
import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/features/guest/booking/phieu_hen_xem_screen.dart';
import 'package:house_booking/features/guest/booking/schedule_booking_screen.dart';
import 'package:house_booking/providers/auth_provider.dart';

import '../../../helpers/pump_app.dart';

/// ĐẶT LỊCH XEM NHÀ + PHIẾU HẸN (thuê dài hạn).
///
/// Điều phải giữ:
///   * khung giờ chia Sáng/Chiều/Tối; khung đã có người đặt gạch ngang, không
///     bấm được;
///   * đổi ngày thì bỏ khung đang chọn (khung 15:00 hôm nay ≠ 15:00 ngày mai);
///   * gửi đúng hình thức, số người, tên, SĐT; thiếu khung giờ thì không gửi;
///   * trước khi đặt KHÔNG có nút gọi sale (SĐT còn bị che);
///   * phiếu nói THẬT "chờ sale xác nhận", có mã, QR, nút gọi/Zalo/chỉ đường
///     mở đúng liên kết.
class _AuthGia extends AuthProvider {
  _AuthGia(this._u);

  final UserModel? _u;

  @override
  UserModel? get currentUser => _u;

  @override
  bool get isAuthenticated => _u != null;
}

final _khach = UserModel(
  id: 7,
  name: 'Lê Tuấn Anh',
  email: 'a@t.vn',
  phone: '0918234889',
  passwordHash: '',
  avatarPath: '',
  role: 'guest',
);

Map<String, dynamic> _tin() => {
  'tieu_de': 'Căn hộ 3PN 82m² tầng trung',
  'anh': null,
  'dien_tich': 82,
  'dia_chi': 'Thượng Lý, Hồng Bàng, Hải Phòng',
  'gia': 12000000,
  'don_vi': 'tháng',
  'house_id': 5,
  'room_id': 9,
};

class _ApiGia extends LichXemApi {
  @override
  Future<List<SuKienLichSu>> lichSu(int id) async => const [
    SuKienLichSu(
      tieuDe: 'Đặt lịch xem nhà',
      ai: NguoiLam(ten: 'Bạn', laBan: true),
    ),
  ];

  _ApiGia();

  final hoiKhung = <String>[];
  Map<String, dynamic>? daGui;
  String? loiNhanGui;

  @override
  Future<ThongTinDatLich> thongTinDat({int? houseId, int? roomId}) async =>
      ThongTinDatLich.fromMap({
        'tin': _tin(),
        'sale': {
          'id': 2,
          'ten': 'Hoàng Minh Tuấn',
          'anh': null,
          'sdt': '•••••••456',
          'so_lan_xem_xong': 128,
          'khu_vuc': 'Hồng Bàng, Hải Phòng',
        },
        'diem_don': {
          'dia_chi': 'Thượng Lý, Hồng Bàng',
          'lat': 20.86,
          'lng': 106.67,
        },
        'so_nguoi_toi_da': 10,
      });

  @override
  Future<List<KhungGio>> khungGio(
    String ngay, {
    int? houseId,
    int? roomId,
  }) async {
    hoiKhung.add(ngay);
    return [
      for (final (g, co) in const [
        ('09:00-10:00', false),
        ('11:00-12:00', true),
        ('14:00-15:00', false),
        ('15:00-16:00', false),
        ('18:00-19:00', false),
      ])
        KhungGio(gio: g, daCo: co),
    ];
  }

  @override
  Future<PhieuHen> datLich({
    int? houseId,
    int? roomId,
    required String ngay,
    required String gio,
    required String hinhThuc,
    required int soNguoi,
    required String tenKhach,
    required String sdtKhach,
    String loiNhan = '',
  }) async {
    loiNhanGui = loiNhan;
    daGui = {
      'ngay': ngay,
      'gio': gio,
      'hinh_thuc': hinhThuc,
      'so_nguoi': soNguoi,
      'ten': tenKhach,
      'sdt': sdtKhach,
    };
    return PhieuHen.fromMap(_phieu());
  }
}

Map<String, dynamic> _phieu({
  String trangThai = 'pending',
  String hinhThuc = 'truc_tiep',
}) => {
  'id': 42,
  'ma': 'LH-0042',
  'trang_thai': trangThai,
  'ngay': '2026-09-16',
  'gio': '15:00-16:00',
  'hinh_thuc': hinhThuc,
  'so_nguoi': 2,
  'ten_khach': 'Lê Tuấn Anh',
  'sdt_khach': '0918234889',
  'loi_nhan': '',
  'tin': _tin(),
  'sale': {
    'id': 2,
    'ten': 'Hoàng Minh Tuấn',
    'anh': null,
    'sdt': '0988123456',
    'so_lan_xem_xong': 128,
    'khu_vuc': 'Hồng Bàng, Hải Phòng',
  },
  'diem_don': {'dia_chi': 'Thượng Lý, Hồng Bàng', 'lat': 20.86, 'lng': 106.67},
};

void _manRong(WidgetTester t) {
  t.view.physicalSize = const Size(1000, 3200);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Future<_ApiGia> _moDat(WidgetTester t) async {
  _manRong(t);
  final api = _ApiGia();
  await pumpApp(
    t,
    ScheduleBookingScreen(houseId: 5, api: api, homNay: DateTime(2026, 9, 15)),
    auth: _AuthGia(_khach),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 80));
  return api;
}

void main() {
  group('Đặt lịch xem', () {
    testWidgets('hiện căn, sale, khung giờ chia buổi', (t) async {
      await _moDat(t);
      expect(find.text('Căn hộ 3PN 82m² tầng trung'), findsOneWidget);
      expect(find.text('Hôm nay'), findsOneWidget);
      expect(find.text('Ngày mai'), findsOneWidget);
      expect(find.text('Buổi sáng'), findsOneWidget);
      expect(find.text('Buổi chiều'), findsOneWidget);
      expect(find.text('Buổi tối'), findsOneWidget);
      expect(find.text('Hoàng Minh Tuấn'), findsOneWidget);
      expect(find.text('128 lượt xem nhà thành công'), findsOneWidget);
    });

    testWidgets('trước khi đặt KHÔNG lộ SĐT sale, không có nút gọi', (t) async {
      await _moDat(t);
      expect(find.text('0988123456'), findsNothing);
      expect(find.byKey(const Key('phieu-goi')), findsNothing);
    });

    testWidgets('khung đã có người đặt không bấm được', (t) async {
      final api = await _moDat(t);
      await t.tap(find.byKey(const Key('lich-xem-gio-11:00')));
      await t.pump();
      await t.tap(find.byKey(const Key('lich-xem-xac-nhan')));
      await t.pump();
      expect(api.daGui, isNull);
    });

    testWidgets("changing days keeps selected slots", (t) async {
      final api = await _moDat(t);
      await t.tap(find.byKey(const Key('lich-xem-gio-15:00')));
      await t.tap(find.byKey(const Key("lich-xem-gio-14:00")));
      await t.pump();
      await t.tap(find.byKey(const Key('lich-xem-ngay-17')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(api.hoiKhung.last, '2026-09-17');
      await t.tap(find.byKey(const Key("lich-xem-gio-09:00")));
      await t.tap(find.byKey(const Key("lich-xem-gio-14:00")));
      await t.pump();
      expect(
        find.text("Khung gi\u1edd b\u1ea1n \u0111\u00e3 ch\u1ecdn (4)"),
        findsOneWidget,
      );
      await t.tap(find.byKey(const Key('lich-xem-xac-nhan')));
      await t.pump();
      expect(api.loiNhanGui, contains("4."));
      expect(api.daGui, isNotNull);
    });
    testWidgets('gửi đúng hình thức, số người, tên, SĐT rồi mở phiếu', (
      t,
    ) async {
      final api = await _moDat(t);
      await t.tap(find.byKey(const Key('lich-xem-gio-15:00')));
      await t.tap(find.byKey(const Key('lich-xem-hinh-thuc-video')));
      await t.tap(find.byKey(const Key('lich-xem-them-nguoi')));
      await t.pump();
      expect(find.text('2'), findsWidgets);

      await t.tap(find.byKey(const Key('lich-xem-xac-nhan')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));

      expect(api.daGui, {
        'ngay': '2026-09-15',
        'gio': '15:00-16:00',
        'hinh_thuc': 'video',
        'so_nguoi': 2,
        'ten': 'Lê Tuấn Anh',
        'sdt': '0918234889',
      });
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Phiếu hẹn xem nhà'), findsOneWidget);
    });
  });

  group('Phiếu hẹn', () {
    Future<List<Uri>> moPhieu(WidgetTester t, Map<String, dynamic> du) async {
      _manRong(t);
      final mo = <Uri>[];
      await pumpApp(
        t,
        PhieuHenXemScreen(
          phieuBanDau: PhieuHen.fromMap(du),
          api: _ApiGia(),
          moLink: (u) async => mo.add(u),
        ),
      );
      await t.pump();
      return mo;
    }

    testWidgets('nói thật: đang chờ sale xác nhận, có mã và QR', (t) async {
      await moPhieu(t, _phieu());
      expect(find.text('Đã gửi · chờ sale xác nhận'), findsOneWidget);
      expect(find.text('#LH-0042'), findsOneWidget);
      expect(find.byKey(const Key('phieu-qr')), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
    });

    testWidgets('sale đã duyệt thì đổi nhãn', (t) async {
      _manRong(t);
      await pumpApp(
        t,
        PhieuHenXemScreen(
          phieuBanDau: PhieuHen.fromMap(_phieu(trangThai: 'approved')),
          api: _ApiGia(),
          bayGio: DateTime(2026, 9, 16, 14),
        ),
      );
      expect(find.text('Sale đã xác nhận lịch'), findsOneWidget);
      expect(find.byKey(const Key('phieu-thue-ngay')), findsOneWidget);
      expect(find.byKey(const Key('phieu-gui-ket-qua')), findsNothing);
    });

    testWidgets('đến giờ hẹn tự mở gửi kết quả, không cần sale hoàn tất', (
      t,
    ) async {
      _manRong(t);
      await pumpApp(
        t,
        PhieuHenXemScreen(
          phieuBanDau: PhieuHen.fromMap(_phieu(trangThai: 'approved')),
          api: _ApiGia(),
          bayGio: DateTime(2026, 9, 16, 15),
        ),
      );
      expect(find.byKey(const Key('phieu-gui-ket-qua')), findsOneWidget);
      expect(find.byKey(const Key('phieu-thue-ngay')), findsNothing);
    });

    testWidgets('gọi / Zalo / chỉ đường mở đúng liên kết', (t) async {
      final mo = await moPhieu(t, _phieu());
      await t.tap(find.byKey(const Key('phieu-goi')));
      await t.tap(find.byKey(const Key('phieu-zalo')));
      await t.tap(find.byKey(const Key('phieu-chi-duong')));
      await t.pump();
      expect(mo[0].toString(), 'tel:0988123456');
      expect(mo[1].toString(), 'https://zalo.me/0988123456');
      expect(mo[2].host, 'www.google.com');
      expect(mo[2].queryParameters['destination'], '20.86,106.67');
    });

    testWidgets('lưu lịch mở Google Calendar đúng giờ hẹn', (t) async {
      final mo = await moPhieu(t, _phieu());
      await t.tap(find.byKey(const Key('phieu-luu-lich')));
      await t.pump();
      expect(mo.single.host, 'calendar.google.com');
      expect(
        mo.single.queryParameters['dates'],
        '20260916T150000/20260916T160000',
      );
    });

    testWidgets('xem qua video thì không mời chỉ đường', (t) async {
      await moPhieu(t, _phieu(hinhThuc: 'video'));
      expect(find.byKey(const Key('phieu-chi-duong')), findsNothing);
      expect(find.text('Video call'), findsOneWidget);
    });
  });
}
