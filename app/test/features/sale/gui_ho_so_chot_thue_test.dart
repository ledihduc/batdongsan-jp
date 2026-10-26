import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/features/sale/gui_ho_so_chot_thue_screen.dart';

import '../../helpers/pump_app.dart';

/// Sale nộp minh chứng cọc HỘ khách (24/09/2026). Trước đây ảnh "xác nhận cọc"
/// bị gộp vào tệp hợp đồng → hồ sơ thiếu hai minh chứng, không ai chốt được.
Map<String, dynamic> _hoSo({List<Map<String, dynamic>> payments = const []}) =>
    {
      'id': 6,
      'appointment_id': 50,
      'status': 'CONTRACT_READY',
      'viewer_role': 'sale',
      'subject': {'title': 'Phòng DH-102', 'image': null},
      'participants': {
        'customer': {'id': 73, 'name': 'Khách Demo'},
        'sale': {'id': 74, 'name': 'Sale Demo'},
        'owner': {'id': 75, 'name': 'Chủ Demo'},
      },
      'contract': {
        'urls': ['/uploads/hd.png'],
        'note': 'Ngày cọc 24/09/2026',
        'submitted_at': '2026-09-24T13:43:30',
      },
      'total_deposit': 3000000,
      'payments': payments,
      'available_actions': [
        'UPLOAD_CONTRACT',
        'SUBMIT_APP_DEPOSIT',
        'SUBMIT_OWNER_DEPOSIT',
      ],
      'created_at': '2026-09-24T09:00:00',
      'updated_at': '2026-09-24T13:43:30',
    };

class _Api extends RentalJourneyApi {
  _Api(this.map);

  final Map<String, dynamic> map;

  @override
  Future<RentalJourney> detail(int id) async => RentalJourney.fromMap(map);
}

void main() {
  testWidgets('đã gửi hợp đồng → hiện ô nộp hộ từng khoản cọc', (t) async {
    t.view.physicalSize = const Size(430, 2200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpApp(t, GuiHoSoChotThueScreen(journeyId: 6, api: _Api(_hoSo())));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Bổ sung ảnh còn thiếu'), findsOneWidget);
    expect(find.byKey(const Key('sale-anh-coc-APP_DEPOSIT')), findsOneWidget);
    expect(find.byKey(const Key('sale-anh-coc-OWNER_DEPOSIT')), findsOneWidget);
    // Chưa chọn ảnh thì nút gửi tắt.
    final nut = t.widget<OutlinedButton>(find.byKey(const Key('sale-nop-coc')));
    expect(nut.onPressed, isNull);
  });

  testWidgets('khoản đã có minh chứng thì báo đã có, không mời tải lại', (
    t,
  ) async {
    t.view.physicalSize = const Size(430, 2200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpApp(
      t,
      GuiHoSoChotThueScreen(
        journeyId: 6,
        api: _Api(
          _hoSo(
            payments: [
              {
                'kind': 'APP_DEPOSIT',
                'amount': 1500000,
                'status': 'SUBMITTED',
                'proof_urls': ['/uploads/ck.png'],
                'submitted_at': '2026-09-24T14:00:00',
              },
            ],
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('sale-APP_DEPOSIT-anh-0')), findsOneWidget);
    expect(find.byKey(const Key('sale-anh-coc-APP_DEPOSIT')), findsNothing);
    expect(find.byKey(const Key('sale-anh-coc-OWNER_DEPOSIT')), findsOneWidget);
  });
}
