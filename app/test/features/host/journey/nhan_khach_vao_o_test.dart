import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/features/host/journey/xac_nhan_coc_chu_nha_screen.dart';

import '../../../helpers/pump_app.dart';

/// CHỦ NHÀ NHẬN KHÁCH VÀO Ở (23/09/2026).
///
/// Điều phải giữ:
///   * đủ hợp đồng + hai minh chứng cọc thì chủ nhà có nút chốt — không phải
///     ngồi chờ khách mở app (trước đây chỉ khách mới bấm được);
///   * bấm xong màn nói rõ PHÒNG đã sang "đang thuê", kèm số hợp đồng — không
///     dừng ở câu "hồ sơ hoàn tất" trong khi sổ phòng vẫn báo trống;
///   * chưa đủ giấy thì không vẽ nút, để khỏi bấm vào rồi ăn 409.
class _ApiGia extends RentalJourneyApi {
  _ApiGia({required this.hoSo, this.sauKhiChot});

  final Map<String, dynamic> hoSo;
  final Map<String, dynamic>? sauKhiChot;
  int soLanChot = 0;

  @override
  Future<RentalJourney> detail(int id) async =>
      RentalJourney.fromMap(soLanChot == 0 ? hoSo : (sauKhiChot ?? hoSo));

  @override
  Future<RentalJourney> confirm(int id) async {
    soLanChot++;
    return RentalJourney.fromMap(sauKhiChot ?? hoSo);
  }
}

Map<String, dynamic> _hoSo({
  List<String> actions = const [],
  Map<String, dynamic>? hopDong,
  String status = 'DEPOSITS_PENDING',
}) => {
  'id': 9,
  'appointment_id': 42,
  'status': status,
  'viewer_role': 'owner',
  'subject': {'title': 'Phòng P101 · An Cư Home', 'image': null},
  'participants': {
    'customer': {'id': 1, 'name': 'Phạm Minh Tuấn'},
    'sale': {'id': 2, 'name': 'Nguyễn Thị Mai'},
    'owner': {'id': 3, 'name': 'Trần Văn Hùng'},
  },
  'appointment': {'date': '2026-09-22', 'time': '09:00', 'status': 'completed'},
  'contract': {
    'urls': ['/uploads/hd.pdf'],
    'note': null,
    'submitted_at': null,
  },
  'hop_dong_da_ky': hopDong,
  'total_deposit': 10000000,
  'payments': [
    {
      'kind': 'OWNER_DEPOSIT',
      'amount': 5000000,
      'status': 'SUBMITTED',
      'proof_urls': ['/uploads/coc.jpg'],
      'submitted_at': '2026-09-23T08:00:00',
      'acknowledged_at': '2026-09-23T08:30:00',
    },
  ],
  'available_actions': actions,
  'created_at': '2026-09-22T09:00:00',
  'updated_at': '2026-09-23T09:00:00',
};

Future<_ApiGia> _mo(WidgetTester t, _ApiGia api) async {
  t.view.physicalSize = const Size(430, 2600);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await pumpApp(t, XacNhanCocChuNhaScreen(journeyId: 9, api: api));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
  return api;
}

void main() {
  testWidgets('đủ giấy: chủ nhà có nút Nhận khách vào ở', (t) async {
    await _mo(t, _ApiGia(hoSo: _hoSo(actions: const ['CONFIRM_RENTAL'])));
    expect(find.byKey(const Key('chu-nhan-khach-vao-o')), findsOneWidget);
    expect(find.text('Cọc & nhận khách'), findsOneWidget);
  });

  testWidgets('chưa đủ giấy: không vẽ nút chốt', (t) async {
    await _mo(t, _ApiGia(hoSo: _hoSo()));
    expect(find.byKey(const Key('chu-nhan-khach-vao-o')), findsNothing);
  });

  testWidgets('bấm chốt: gọi confirm và nói rõ phòng đang thuê', (t) async {
    final api = await _mo(
      t,
      _ApiGia(
        hoSo: _hoSo(actions: const ['CONFIRM_RENTAL']),
        sauKhiChot: _hoSo(
          status: 'COMPLETED',
          hopDong: const {
            'id': 77,
            'trang_thai': 'active',
            'tu': '2026-09-23',
            'den': '2027-09-23',
            'gia_thue': 8000000,
            'tien_coc': 8000000,
            'phong': 'P101',
            'dang_o': true,
          },
        ),
      ),
    );
    await t.tap(find.byKey(const Key('chu-nhan-khach-vao-o')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));

    expect(api.soLanChot, 1);
    expect(find.text('Khách đã vào ở — phòng P101 đang thuê'), findsOneWidget);
    expect(find.textContaining('Hợp đồng #77'), findsOneWidget);
    // Đã chốt rồi thì không còn nút bấm lần hai.
    expect(find.byKey(const Key('chu-nhan-khach-vao-o')), findsNothing);
  });

  testWidgets('chủ nhà thấy cùng hợp đồng và ảnh cọc trong hồ sơ', (t) async {
    await _mo(t, _ApiGia(hoSo: _hoSo(actions: const ['CONFIRM_RENTAL'])));
    expect(find.byKey(const Key('chu-hop-dong-anh-0')), findsOneWidget);
    expect(find.byKey(const Key('chu-OWNER_DEPOSIT-anh-0')), findsOneWidget);
    expect(find.text('Hợp đồng & cọc'), findsOneWidget);
  });
}
