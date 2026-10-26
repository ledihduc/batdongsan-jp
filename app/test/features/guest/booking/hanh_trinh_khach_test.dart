import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/features/guest/booking/coc_xac_nhan_thue_screen.dart';
import 'package:house_booking/features/guest/booking/cho_xac_nhan_hoan_tat_screen.dart';
import 'package:house_booking/features/guest/booking/ket_qua_sau_xem_screen.dart';
import 'package:house_booking/features/guest/booking/yeu_cau_xem_phong_screen.dart';

import '../../../helpers/pump_app.dart';

/// HÀNH TRÌNH THUÊ CỦA KHÁCH — sáu màn theo mockup 20/09/2026.
///
/// Điều phải giữ bằng test:
///   * ngày/giờ không bị hard-code: khách dùng lịch + đồng hồ và thêm nhiều
///     khoảng; server giữ một slot kỹ thuật, toàn bộ khoảng đi trong lời nhắn;
///   * khung đã kín thì không bấm được, không gửi;
///   * "Tôi muốn thuê" / "Không phù hợp" gửi đúng `outcome`, lý do là tuỳ chọn;
///   * chưa khai tài khoản nhận cọc thì nói thẳng, KHÔNG in số tài khoản bịa.
class _LichXemGia extends LichXemApi {
  _LichXemGia({this.gioTheoNgay = const {}});

  /// ngày → các slot 1 tiếng còn trống ('09:00-10:00').
  final Map<String, List<String>> gioTheoNgay;
  Map<String, Object?>? daDat;

  @override
  Future<ThongTinDatLich> thongTinDat({int? houseId, int? roomId}) async =>
      const ThongTinDatLich(
        tin: TomTatCan(
          tieuDe: 'Căn hộ Studio full nội thất',
          dienTich: 28,
          diaChi: 'Quận 7, TP. Hồ Chí Minh',
          gia: 5500000,
          houseId: 7,
        ),
        diemDon: DiemDon(diaChi: '123 Nguyễn Thị Thập, Quận 7'),
      );

  @override
  Future<List<KhungGio>> khungGio(
    String ngay, {
    int? houseId,
    int? roomId,
  }) async {
    final trong = gioTheoNgay[ngay] ?? const <String>[];
    return [
      for (var h = 8; h < 20; h++)
        KhungGio(
          gio:
              '${h.toString().padLeft(2, '0')}:00-'
              '${(h + 1).toString().padLeft(2, '0')}:00',
          daCo: !trong.contains(
            '${h.toString().padLeft(2, '0')}:00-'
            '${(h + 1).toString().padLeft(2, '0')}:00',
          ),
        ),
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
    daDat = {'ngay': ngay, 'gio': gio, 'loi_nhan': loiNhan};
    return const PhieuHen(
      id: 42,
      ma: 'PH-0042',
      ngay: '2026-09-24',
      gio: '09:00-10:00',
      tin: TomTatCan(tieuDe: 'Căn hộ Studio full nội thất'),
    );
  }

  @override
  Future<PhieuHen> phieu(int id) async => const PhieuHen(
    id: 42,
    ma: 'PH-0042',
    ngay: '2026-09-24',
    gio: '09:00-10:00',
    tin: TomTatCan(tieuDe: 'Căn hộ Studio full nội thất'),
  );
}

class _JourneyGia extends RentalJourneyApi {
  _JourneyGia({this.hoSo, this.tk});

  final RentalJourney? hoSo;
  final PlatformPaymentAccount? tk;
  bool? daGuiMuonThue;
  String? lyDo;

  @override
  Future<RentalJourney> submitViewingResult(
    int appointmentId, {
    required bool interested,
    String? reason,
  }) async {
    daGuiMuonThue = interested;
    lyDo = reason;
    return hoSo ?? _hoSoMau();
  }

  @override
  Future<RentalJourney> detail(int id) async => hoSo ?? _hoSoMau();

  @override
  Future<PlatformPaymentAccount> paymentAccount() async =>
      tk ??
      const PlatformPaymentAccount(isConfigured: false, transferPrefix: 'ANCU');
}

RentalJourney _hoSoMau() => RentalJourney.fromMap(_hoSoMauMap());

Map<String, dynamic> _hoSoMauMap() => {
  'id': 9,
  'appointment_id': 42,
  'status': 'CUSTOMER_INTERESTED',
  'viewer_role': 'customer',
  'subject': {'title': 'Căn hộ Studio full nội thất', 'image': null},
  'participants': {
    'customer': {'id': 1, 'name': 'Phạm Minh Tuấn'},
    'sale': {'id': 2, 'name': 'Nguyễn Thị Mai'},
    'owner': {'id': 3, 'name': 'Trần Văn Hùng'},
  },
  'appointment': {
    'date': '2026-09-24',
    'time': '09:00-10:00',
    'status': 'completed',
  },
  'contract': {'urls': [], 'note': null, 'submitted_at': null},
  'total_deposit': 10000000,
  'payments': [],
  'available_actions': ['SUBMIT_APP_DEPOSIT', 'SUBMIT_OWNER_DEPOSIT'],
  'created_at': '2026-09-24T09:00:00',
  'updated_at': '2026-09-24T09:00:00',
};

/// 24/09 và 25/09 — hai cột ngày của màn 1 khi "hôm nay" là 23/09.
const _n1 = '2026-09-24';
const _n2 = '2026-09-25';

void main() {
  Future<_LichXemGia> moMan1(
    WidgetTester t, {
    Map<String, List<String>>? gio,
  }) async {
    t.view.physicalSize = const Size(430, 2200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final api = _LichXemGia(
      gioTheoNgay:
          gio ??
          const {
            _n1: ['09:00-10:00', '10:00-11:00', '14:00-15:00'],
            _n2: ['18:00-19:00'],
          },
    );
    await pumpApp(
      t,
      YeuCauXemPhongScreen(
        houseId: 7,
        api: api,
        layNha: (_) async => null,
        homNay: DateTime(2026, 9, 23),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    return api;
  }

  testWidgets('màn 1: chọn ngày và giờ linh hoạt bằng lịch + đồng hồ', (
    t,
  ) async {
    await moMan1(t);
    expect(find.text('Yêu cầu xem phòng'), findsOneWidget);
    expect(find.text('Căn hộ Studio full nội thất'), findsOneWidget);
    expect(find.textContaining('Chọn ngày và giờ bằng lịch'), findsOneWidget);
    expect(find.byKey(const Key('chon-ngay-xem')), findsOneWidget);
    expect(find.byKey(const Key('chon-gio-bat-dau')), findsOneWidget);
    expect(find.byKey(const Key('chon-gio-ket-thuc')), findsOneWidget);
    expect(find.byKey(const Key('them-khung-gio')), findsOneWidget);
    expect(find.textContaining('24/09/2026'), findsOneWidget);
  });

  testWidgets('màn 1: thêm khoảng rồi gửi slot giữ chỗ và giờ chính xác', (
    t,
  ) async {
    final api = await moMan1(t);
    await t.tap(find.byKey(const Key('them-khung-gio')));
    await t.pumpAndSettle();
    expect(find.text('Các khung đã thêm'), findsOneWidget);
    expect(find.textContaining('09:00 - 10:00'), findsOneWidget);

    await t.tap(find.byKey(const Key('gui-yeu-cau-xem')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));

    expect(api.daDat!['ngay'], _n1);
    expect(api.daDat!['gio'], '09:00-10:00');
    expect(api.daDat!['loi_nhan'], contains('09:00 - 10:00'));
  });

  testWidgets('màn 1: khoảng không có slot trống thì không được thêm', (
    t,
  ) async {
    final api = await moMan1(t, gio: const {_n1: [], _n2: []});
    await t.tap(find.byKey(const Key('them-khung-gio')));
    await t.pumpAndSettle();
    expect(find.textContaining('chưa có giờ nhận xem'), findsOneWidget);
    expect(find.text('Các khung đã thêm'), findsNothing);
    await t.tap(find.byKey(const Key('gui-yeu-cau-xem')));
    await t.pump();
    expect(api.daDat, isNull);
  });

  testWidgets('màn 5: "Tôi muốn thuê" gửi INTERESTED, lý do là tuỳ chọn', (
    t,
  ) async {
    final api = _JourneyGia();
    await pumpApp(t, KetQuaSauXemScreen(appointmentId: 42, api: api));
    await t.pump();
    expect(find.text('Cảm ơn bạn đã xem phòng!'), findsOneWidget);
    await t.tap(find.byKey(const Key('ket-qua-muon-thue')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(api.daGuiMuonThue, isTrue);
    expect(api.lyDo, isNull);
  });

  testWidgets('màn 5: chọn lý do rồi báo không phù hợp', (t) async {
    final api = _JourneyGia();
    await pumpApp(t, KetQuaSauXemScreen(appointmentId: 42, api: api));
    await t.pump();
    await t.tap(find.byKey(const Key('ly-do-Giá không phù hợp')));
    await t.pump();
    await t.tap(find.byKey(const Key('ket-qua-khong-phu-hop')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(api.daGuiMuonThue, isFalse);
    expect(api.lyDo, 'Giá không phù hợp');
  });

  testWidgets('luồng mới: chọn muốn thuê rồi bấm Gửi kết quả mới gọi API', (
    t,
  ) async {
    final api = _JourneyGia();
    const phieu = PhieuHen(
      id: 42,
      ma: 'PH-0042',
      ngay: '2026-09-24',
      gio: '09:00-10:00',
      tin: TomTatCan(tieuDe: 'Căn hộ Studio full nội thất', gia: 5500000),
    );
    await pumpApp(
      t,
      KetQuaSauXemScreen(appointmentId: 42, api: api, phieu: phieu),
    );
    await t.tap(find.byKey(const Key('ket-qua-muon-thue')));
    await t.pump();
    expect(api.daGuiMuonThue, isNull);
    await t.tap(find.byKey(const Key('gui-ket-qua-xem')));
    await t.pumpAndSettle();
    expect(api.daGuiMuonThue, isTrue);
    expect(find.text('Xác nhận muốn thuê'), findsOneWidget);
    expect(find.text('Gửi yêu cầu chốt thuê'), findsOneWidget);
  });

  testWidgets('màn chờ hoàn tất hiển thị trạng thái xác nhận thật', (t) async {
    await pumpApp(t, ChoXacNhanHoanTatScreen(journeyId: 9, api: _JourneyGia()));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Chờ xác nhận hoàn tất'), findsOneWidget);
    expect(find.text('Khách đã xác nhận'), findsOneWidget);
    expect(find.text('Chủ nhà đã xác nhận'), findsOneWidget);
    // Bước cuối là PHÒNG đổi trạng thái, không phải "sale đang kiểm tra" —
    // chốt thuê không có bước nào do sale duyệt (luật 23/09/2026).
    expect(find.text('Phòng chuyển sang đang thuê'), findsOneWidget);
    expect(find.text('Sale đang kiểm tra'), findsNothing);
  });

  testWidgets('màn 6: chưa khai tài khoản thì nói thẳng, không in số bịa', (
    t,
  ) async {
    t.view.physicalSize = const Size(430, 2600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await pumpApp(t, CocXacNhanThueScreen(journeyId: 9, api: _JourneyGia()));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('50% · Vua Nhà'), findsOneWidget);
    expect(find.text('50% · Chủ nhà'), findsOneWidget);
    expect(find.text('Hợp đồng & cọc'), findsOneWidget);
    expect(
      find.textContaining('chưa công bố tài khoản nhận cọc'),
      findsOneWidget,
    );
    // Chưa đủ hai minh chứng → không cho xác nhận.
    final nut = t.widget<FilledButton>(find.byKey(const Key('coc-xac-nhan')));
    expect(nut.onPressed, isNull);
    // …và nói rõ còn thiếu gì, không để nút tắt câm.
    expect(
      find.text(
        'Còn thiếu: hợp đồng (sale gửi) · ảnh chuyển cọc Vua Nhà · '
        'ảnh chuyển cọc chủ nhà',
      ),
      findsOneWidget,
    );
  });

  testWidgets('màn 6: chưa có hợp đồng + số cọc thì không mời tải minh chứng', (
    t,
  ) async {
    t.view.physicalSize = const Size(430, 2600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final chuaCoHopDong = RentalJourney.fromMap({
      ..._hoSoMauMap(),
      'total_deposit': 0,
      'available_actions': ['CANCEL_JOURNEY'],
    });
    await pumpApp(
      t,
      CocXacNhanThueScreen(journeyId: 9, api: _JourneyGia(hoSo: chuaCoHopDong)),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('cho-hop-dong-coc')), findsOneWidget);
    expect(find.text('Đang chờ hợp đồng và số tiền cọc'), findsOneWidget);
    expect(find.byKey(const Key('gui-minh-chung-APP_DEPOSIT')), findsNothing);
    expect(find.byKey(const Key('gui-minh-chung-OWNER_DEPOSIT')), findsNothing);
  });

  testWidgets('màn 6: lỗi hiện ngay dưới đúng khối vừa bấm', (t) async {
    t.view.physicalSize = const Size(430, 2600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await pumpApp(t, CocXacNhanThueScreen(journeyId: 9, api: _JourneyGia()));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.byKey(const Key('gui-minh-chung-OWNER_DEPOSIT')));
    await t.pump();
    expect(
      find.byKey(const Key('loi-minh-chung-OWNER_DEPOSIT')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('loi-minh-chung-APP_DEPOSIT')), findsNothing);
  });

  testWidgets('màn 6: có tài khoản thì hiện số + nội dung chuyển khoản', (
    t,
  ) async {
    t.view.physicalSize = const Size(430, 2600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await pumpApp(
      t,
      CocXacNhanThueScreen(
        journeyId: 9,
        api: _JourneyGia(
          tk: const PlatformPaymentAccount(
            isConfigured: true,
            bankName: 'Ngân hàng TMCP Kỹ thương Việt Nam (Techcombank)',
            accountNumber: '1903 6789 0123',
            accountHolder: 'CONG TY CO PHAN VUA NHA',
            transferPrefix: 'Coc Vua Nha',
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('1903 6789 0123'), findsOneWidget);
    expect(find.textContaining('Coc Vua Nha - Phạm Minh Tuấn'), findsOneWidget);
  });

  testWidgets('màn 6: hiện và mở được ảnh hợp đồng cùng minh chứng cọc', (
    t,
  ) async {
    t.view.physicalSize = const Size(430, 2800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final coMinhChung = RentalJourney.fromMap({
      ..._hoSoMauMap(),
      'contract': {
        'urls': ['/uploads/hop-dong-1.jpg'],
        'note': null,
        'submitted_at': '2026-09-25T09:00:00',
      },
      'payments': [
        {
          'kind': 'APP_DEPOSIT',
          'amount': 5000000,
          'status': 'SUBMITTED',
          'proof_urls': ['/uploads/coc-vua-nha.jpg'],
          'submitted_at': '2026-09-25T10:00:00',
        },
        {
          'kind': 'OWNER_DEPOSIT',
          'amount': 5000000,
          'status': 'SUBMITTED',
          'proof_urls': ['/uploads/coc-chu-nha.jpg'],
          'submitted_at': '2026-09-25T10:05:00',
        },
      ],
    });
    await pumpApp(
      t,
      CocXacNhanThueScreen(journeyId: 9, api: _JourneyGia(hoSo: coMinhChung)),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('coc-hop-dong-minh-chung')), findsOneWidget);
    expect(find.byKey(const Key('coc-hop-dong-anh-0')), findsOneWidget);
    expect(find.byKey(const Key('coc-APP_DEPOSIT-anh-0')), findsOneWidget);
    expect(find.byKey(const Key('coc-OWNER_DEPOSIT-anh-0')), findsOneWidget);
    expect(
      t.widget<InkWell>(find.byKey(const Key('coc-hop-dong-anh-0'))).onTap,
      isNotNull,
    );
  });
}
