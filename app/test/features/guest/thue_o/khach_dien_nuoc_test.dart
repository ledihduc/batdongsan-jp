import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/guest/thue_o/ho_so_thue.dart';
import 'package:house_booking/features/guest/thue_o/khach_dien_nuoc_screen.dart';

import '../../../helpers/pump_app.dart';

/// ĐIỆN NƯỚC phía người thuê — đồng bộ với chủ nhà trên CÙNG một dòng chỉ số.
///
/// Điều phải giữ:
///   * chủ nhà tự ghi số kỳ này → khách KHÔNG bị nói "bạn đã gửi", và không bị
///     nhắc gửi nữa;
///   * bị yêu cầu chụp lại → hiện đúng lời chủ nhà nhắn;
///   * lịch sử nói ai ghi và có ảnh công tơ (ảnh của chủ nhà cũng xem được).
HoSoThue _hs({required Map<String, dynamic> dn, List<Map<String, dynamic>> lichSu = const []}) =>
    HoSoThue({
      'hop_dong': {'id': 5},
      'dien_nuoc': {'thang': '2026-10', ...dn},
      'dien_nuoc_lich_su': lichSu,
    });

void main() {
  testWidgets('chủ nhà đã ghi kỳ này: không báo "bạn đã gửi", lịch sử ghi rõ', (t) async {
    await pumpApp(
      t,
      KhachDienNuocScreen(
        hoSo: _hs(
          dn: {'trang_thai': 'da_duyet', 'nguoi_ghi': 'chu_nha'},
          lichSu: [
            {
              'thang': '2026-10', 'ngay_gui': '2026-10-05', 'trang_thai': 'da_duyet',
              'nguoi_thue_gui': false, 'anh_dien': 'https://x.test/dien.jpg',
            },
          ],
        ),
      ),
    );
    await t.pump();
    expect(find.textContaining('Chủ nhà đã ghi chỉ số kỳ này'), findsOneWidget);
    expect(find.text('Gửi ảnh'), findsNothing);

    await t.tap(find.text('Đã gửi'));
    await t.pump();
    expect(find.text('Chủ nhà ghi'), findsOneWidget);
    expect(find.textContaining('Chủ nhà ghi ngày'), findsOneWidget);
  });

  testWidgets('bị yêu cầu chụp lại: hiện lời nhắn của chủ nhà và nút gửi', (t) async {
    await pumpApp(
      t,
      KhachDienNuocScreen(
        hoSo: _hs(dn: {
          'trang_thai': 'can_chup_lai', 'nguoi_ghi': 'khach', 'ly_do_tra_ve': 'Ảnh mờ',
        }),
      ),
    );
    await t.pump();
    expect(find.text('Chủ nhà nhắn: Ảnh mờ'), findsOneWidget);
    expect(find.text('Gửi ảnh'), findsOneWidget);
  });

  testWidgets('khách tự gửi: vẫn nói "Bạn đã gửi"', (t) async {
    await pumpApp(
      t,
      KhachDienNuocScreen(hoSo: _hs(dn: {'trang_thai': 'cho_duyet', 'nguoi_ghi': 'khach'})),
    );
    await t.pump();
    expect(find.textContaining('Bạn đã gửi chỉ số kỳ này'), findsOneWidget);
  });
}
