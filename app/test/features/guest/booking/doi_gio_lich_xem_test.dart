import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/su_kien_lich_su.dart';
import 'package:house_booking/data/models/viewing_appointment_model.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/features/guest/booking/doi_gio_sheet.dart';
import 'package:house_booking/features/guest/booking/phieu_hen_xem_screen.dart';
import 'package:house_booking/features/guest/booking/widgets/appointment_status_chip.dart';
import 'package:house_booking/features/host/dashboard/widgets/hd_appointment_row.dart';

import '../../../helpers/pump_app.dart';

/// BẬN GIỜ NÀY — bên bán xin đổi giờ, khách chọn lại.
///
/// Điều phải giữ:
///   * bên bán chọn được NHIỀU giờ trên nhiều ngày, tối đa 5, kèm lý do; chưa
///     chọn giờ nào thì không gửi được;
///   * nút "Bận · đổi giờ" chỉ có ở lịch còn mở (chờ duyệt / đã duyệt);
///   * phiếu đang chờ chọn giờ KHÔNG bày vé/QR của giờ cũ — bày giờ đề xuất;
///   * giờ đề xuất bị người khác đặt mất thì gạch, không bấm được;
///   * khách bấm giờ đề xuất → gửi đúng ngày/giờ, phiếu chuyển "đã xác nhận" và
///     nhắc "đã đổi từ…";
///   * khách không ưng giờ nào → tự chọn một giờ trống khác.
class _ApiGia extends LichXemApi {
  @override
  Future<List<SuKienLichSu>> lichSu(int id) async => const [
    SuKienLichSu(
      tieuDe: 'Đặt lịch xem nhà',
      ai: NguoiLam(ten: 'Bạn', laBan: true),
    ),
  ];

  _ApiGia({this.ketQuaChon = 'approved'});

  final String ketQuaChon;
  List<GioDeXuat>? daDeXuat;
  String? lyDo;
  GioDeXuat? daChon;
  String? lyDoHuy;

  @override
  Future<PhieuHen> huy(int id, {String lyDo = ''}) async {
    lyDoHuy = lyDo;
    return PhieuHen.fromMap(_phieu(trangThai: 'cancelled', coDoiGio: false));
  }

  @override
  Future<List<NgayTrong>> gioTrong(int id, {int soNgay = 7}) async => const [
    NgayTrong(
      ngay: '2026-09-16',
      gio: ['09:00-10:00', '14:00-15:00', '16:00-17:00'],
    ),
    NgayTrong(
      ngay: '2026-09-17',
      gio: [
        '08:00-09:00',
        '09:00-10:00',
        '10:00-11:00',
        '11:00-12:00',
        '13:00-14:00',
      ],
    ),
  ];

  @override
  Future<PhieuHen> doiGio(
    int id, {
    required List<GioDeXuat> deXuat,
    String lyDo = '',
  }) async {
    daDeXuat = deXuat;
    this.lyDo = lyDo;
    return PhieuHen.fromMap(
      _phieu(
        trangThai: 'doi_gio',
        deXuat: [for (final g in deXuat) g.toMap()..['con_trong'] = true],
      ),
    );
  }

  @override
  Future<PhieuHen> chonGio(int id, GioDeXuat gio) async {
    daChon = gio;
    return PhieuHen.fromMap(
      _phieu(
        trangThai: ketQuaChon,
        ngay: gio.ngay,
        gio: gio.gio,
        dangCho: false,
        deXuat: const [],
      ),
    );
  }
}

Map<String, dynamic> _phieu({
  String trangThai = 'doi_gio',
  String ngay = '2026-09-16',
  String gio = '10:00-11:00',
  bool dangCho = true,
  bool coDoiGio = true,
  List<Map<String, dynamic>>? deXuat,
}) => {
  'id': 42,
  'ma': 'LH-0042',
  'trang_thai': trangThai,
  'ngay': ngay,
  'gio': gio,
  'hinh_thuc': 'truc_tiep',
  'so_nguoi': 1,
  'ten_khach': 'Lê Tuấn Anh',
  'sdt_khach': '0918234889',
  'loi_nhan': '',
  'tin': {
    'tieu_de': 'Căn hộ 3PN 82m² tầng trung',
    'anh': null,
    'dien_tich': 82,
    'dia_chi': 'Thượng Lý',
    'gia': 12000000,
    'don_vi': 'tháng',
  },
  'sale': {
    'id': 2,
    'ten': 'Hoàng Minh Tuấn',
    'anh': null,
    'sdt': '0988123456',
    'so_lan_xem_xong': 3,
    'khu_vuc': '',
  },
  'diem_don': {'dia_chi': 'Thượng Lý', 'lat': 20.86, 'lng': 106.67},
  'doi_gio': !coDoiGio
      ? null
      : {
          'dang_cho_chon': dangCho,
          'gio_cu': '2026-09-16 10:00-11:00',
          'ly_do': 'Có việc đột xuất',
          'nguoi_doi': 'Chủ Nhà',
          'la_sale': false,
          'de_xuat':
              deXuat ??
              [
                {
                  'ngay': '2026-09-16',
                  'gio': '14:00-15:00',
                  'con_trong': false,
                },
                {'ngay': '2026-09-16', 'gio': '16:00-17:00', 'con_trong': true},
              ],
        },
};

void _manRong(WidgetTester t) {
  t.view.physicalSize = const Size(1000, 2400);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Future<void> _cho(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

ViewingAppointmentModel _lich(String status) => ViewingAppointmentModel(
  id: 42,
  guestId: 7,
  bookingDate: '2026-09-16',
  bookingTime: '10:00-11:00',
  message: '',
  status: status,
  houseTitle: 'Căn hộ 3PN',
  guestName: 'Lê Tuấn Anh',
  lyDoDoi: status == 'doi_gio' ? 'Có việc đột xuất' : null,
);

void main() {
  group('Bên bán: Bận · đổi giờ', () {
    Future<(_ApiGia, List<PhieuHen?>)> moSheet(WidgetTester t) async {
      _manRong(t);
      final api = _ApiGia();
      final kq = <PhieuHen?>[];
      await pumpApp(
        t,
        Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async => kq.add(
                await moXinDoiGio(
                  ctx,
                  appointmentId: 42,
                  ngayHienTai: '2026-09-16',
                  gioHienTai: '10:00-11:00',
                  api: api,
                ),
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      );
      await t.tap(find.text('mở'));
      await _cho(t);
      return (api, kq);
    }

    testWidgets('chọn giờ trên hai ngày + lý do rồi gửi', (t) async {
      final (api, kq) = await moSheet(t);
      expect(find.text('Bận giờ này? Đề xuất giờ khác'), findsOneWidget);
      expect(find.textContaining('Khách hẹn 10:00 · T4 16/09'), findsOneWidget);

      final gui = find.byKey(const Key('doi-gio-gui'));
      expect(t.widget<FilledButton>(gui).onPressed, isNull);

      await t.tap(find.byKey(const Key('doi-gio-o-2026-09-16-14:00')));
      await t.tap(find.byKey(const Key('doi-gio-ngay-2026-09-17')));
      await t.pump();
      await t.tap(find.byKey(const Key('doi-gio-o-2026-09-17-09:00')));
      await t.tap(find.text('Có việc đột xuất'));
      await t.pump();
      expect(find.text('Gửi 2 giờ cho khách chọn'), findsOneWidget);

      await t.tap(gui);
      await _cho(t);
      expect(api.daDeXuat, const [
        GioDeXuat(ngay: '2026-09-16', gio: '14:00-15:00'),
        GioDeXuat(ngay: '2026-09-17', gio: '09:00-10:00'),
      ]);
      expect(api.lyDo, 'Có việc đột xuất');
      expect(kq.single?.trangThai, 'doi_gio');
      expect(find.text('Bận giờ này? Đề xuất giờ khác'), findsNothing);
    });

    testWidgets('tối đa 5 giờ đề xuất', (t) async {
      final (_, _) = await moSheet(t);
      await t.tap(find.byKey(const Key('doi-gio-ngay-2026-09-17')));
      await t.pump();
      for (final g in ['08:00', '09:00', '10:00', '11:00', '13:00']) {
        await t.tap(find.byKey(Key('doi-gio-o-2026-09-17-$g')));
        await t.pump();
      }
      await t.tap(find.byKey(const Key('doi-gio-ngay-2026-09-16')));
      await t.pump();
      await t.tap(find.byKey(const Key('doi-gio-o-2026-09-16-14:00')));
      await t.pump();
      expect(find.text('ĐÃ CHỌN 5/5'), findsOneWidget);
    });

    testWidgets('nút đổi giờ chỉ có ở lịch còn mở', (t) async {
      _manRong(t);
      for (final (status, co) in const [
        ('pending', true),
        ('approved', true),
        ('rejected', false),
        ('doi_gio', false),
      ]) {
        await pumpApp(
          t,
          Scaffold(
            body: HDAppointmentRow(
              appointment: _lich(status),
              onApprove: () {},
              onReject: () {},
              onLock: () {},
              onDoiGio: () {},
            ),
          ),
        );
        expect(
          find.byKey(const Key('doi-gio-42')),
          co ? findsOneWidget : findsNothing,
          reason: status,
        );
      }
      expect(
        find.textContaining('đang chờ khách chọn giờ mới'),
        findsOneWidget,
      );
    });
  });

  group('Khách: chọn lại giờ', () {
    Future<_ApiGia> moPhieu(
      WidgetTester t, {
      String ketQua = 'approved',
    }) async {
      _manRong(t);
      final api = _ApiGia(ketQuaChon: ketQua);
      await pumpApp(
        t,
        PhieuHenXemScreen(
          phieuBanDau: PhieuHen.fromMap(_phieu()),
          api: api,
          moLink: (_) async {},
        ),
      );
      await t.pump();
      return api;
    }

    testWidgets('bày giờ đề xuất, không bày vé/QR của giờ cũ', (t) async {
      await moPhieu(t);
      expect(find.text('Bên bán bận · chờ bạn chọn giờ mới'), findsOneWidget);
      expect(
        find.textContaining('Chủ nhà Chủ Nhà bận lúc 10:00 · T4 16/09'),
        findsOneWidget,
      );
      expect(find.textContaining('Có việc đột xuất'), findsOneWidget);
      expect(find.byKey(const Key('phieu-qr')), findsNothing);
      expect(find.byKey(const Key('phieu-luu-lich')), findsNothing);
      expect(find.text('Đã có người đặt'), findsOneWidget);
    });

    testWidgets('giờ đã bị đặt mất không bấm được', (t) async {
      final api = await moPhieu(t);
      await t.tap(find.byKey(const Key('de-xuat-2026-09-16-14:00')));
      await _cho(t);
      expect(api.daChon, isNull);
    });

    testWidgets('bấm giờ đề xuất → xác nhận ngay, nhắc đã đổi từ giờ cũ', (
      t,
    ) async {
      final api = await moPhieu(t);
      await t.tap(find.byKey(const Key('de-xuat-2026-09-16-16:00')));
      await _cho(t);
      expect(
        api.daChon,
        const GioDeXuat(ngay: '2026-09-16', gio: '16:00-17:00'),
      );
      expect(find.text('Sale đã xác nhận lịch'), findsOneWidget);
      expect(find.byKey(const Key('phieu-da-doi-tu')), findsOneWidget);
      expect(find.text('Đã đổi từ 10:00 · T4 16/09'), findsOneWidget);
      expect(find.byKey(const Key('phieu-qr')), findsOneWidget);
    });

    testWidgets('không ưng giờ nào → tự chọn giờ trống khác', (t) async {
      final api = await moPhieu(t, ketQua: 'pending');
      await t.tap(find.byKey(const Key('chon-gio-khac')));
      await _cho(t);
      expect(find.text('Chọn giờ xem khác'), findsOneWidget);
      await t.tap(find.byKey(const Key('doi-gio-ngay-2026-09-17')));
      await t.pump();
      await t.tap(find.byKey(const Key('doi-gio-o-2026-09-17-11:00')));
      await t.pump();
      await t.tap(find.byKey(const Key('chon-gio-xac-nhan')));
      await _cho(t);
      expect(
        api.daChon,
        const GioDeXuat(ngay: '2026-09-17', gio: '11:00-12:00'),
      );
      expect(find.text('Đã gửi · chờ sale xác nhận'), findsOneWidget);
    });

    testWidgets('chip trạng thái nói đúng việc khách cần làm', (t) async {
      await pumpApp(
        t,
        const Scaffold(body: AppointmentStatusChip(status: 'doi_gio')),
      );
      expect(find.text('Bên bán bận · chọn giờ mới'), findsOneWidget);
    });
  });

  group('Khách: huỷ lịch hẹn', () {
    Future<_ApiGia> moPhieu(WidgetTester t, Map<String, dynamic> du) async {
      _manRong(t);
      final api = _ApiGia();
      await pumpApp(
        t,
        PhieuHenXemScreen(
          phieuBanDau: PhieuHen.fromMap(du),
          api: api,
          bayGio: DateTime(2026, 9, 15),
          moLink: (_) async {},
        ),
      );
      await t.pump();
      return api;
    }

    testWidgets('hỏi lại trước khi huỷ; "Giữ lịch" thì không gọi server', (
      t,
    ) async {
      final api = await moPhieu(
        t,
        _phieu(trangThai: 'pending', coDoiGio: false),
      );
      await t.tap(find.byKey(const Key('phieu-huy')));
      await _cho(t);
      expect(find.text('Huỷ lịch hẹn này?'), findsOneWidget);
      await t.tap(find.byKey(const Key('phieu-huy-giu-lai')));
      await _cho(t);
      expect(api.lyDoHuy, isNull);
      expect(find.byKey(const Key('phieu-qr')), findsOneWidget);
    });

    testWidgets('huỷ kèm lý do → phiếu chuyển "đã huỷ", không còn QR', (
      t,
    ) async {
      final api = await moPhieu(
        t,
        _phieu(trangThai: 'approved', coDoiGio: false),
      );
      await t.tap(find.byKey(const Key('phieu-huy')));
      await _cho(t);
      await t.tap(find.text('Đã tìm được chỗ khác'));
      await t.pump();
      await t.tap(find.byKey(const Key('phieu-huy-xac-nhan')));
      await _cho(t);
      expect(api.lyDoHuy, 'Đã tìm được chỗ khác');
      expect(find.text('Bạn đã huỷ lịch hẹn'), findsOneWidget);
      expect(find.byKey(const Key('phieu-qr')), findsNothing);
      expect(find.byKey(const Key('phieu-huy')), findsNothing);
      expect(find.text('Quay lại'), findsOneWidget);
    });

    testWidgets('đang chờ chọn giờ mới vẫn huỷ được', (t) async {
      await moPhieu(t, _phieu());
      expect(find.text('Không đi được nữa? Huỷ lịch'), findsOneWidget);
    });

    testWidgets('sheet chọn giờ có nút đóng', (t) async {
      _manRong(t);
      final kq = <PhieuHen?>[];
      await pumpApp(
        t,
        Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async => kq.add(
                await moChonGioKhac(ctx, appointmentId: 42, api: _ApiGia()),
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      );
      await t.tap(find.text('mở'));
      await _cho(t);
      await t.tap(find.byKey(const Key('doi-gio-dong')));
      await _cho(t);
      expect(find.text('Chọn giờ xem khác'), findsNothing);
      expect(kq, [null]);
    });
  });
}
