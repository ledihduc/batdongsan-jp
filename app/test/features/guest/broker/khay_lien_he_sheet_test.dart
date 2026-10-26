import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/sale_lien_he_api.dart';
import 'package:house_booking/features/guest/broker/khay_lien_he_sheet.dart';

import '../../../helpers/pump_app.dart';

/// Tài khoản KHÁCH mở khay liên hệ: server trả 403. Trước đây khay vẫn vẽ
/// form, gõ xong bấm Lưu mới báo "Yêu cầu thất bại" (24/09/2026).
class _Api403 extends SaleLienHeApi {
  @override
  Future<LienHeCongKhai> xem() async =>
      throw ApiException(403, 'Chỉ tài khoản người bán mới có trang công khai');
}

void main() {
  testWidgets('tài khoản khách: nói rõ chỉ dành cho Sale, không vẽ form', (
    t,
  ) async {
    await pumpApp(t, Scaffold(body: KhayLienHeSheet(api: _Api403())));
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('lien-he-chi-danh-cho-sale')), findsOneWidget);
    expect(find.text('Lưu'), findsNothing);
  });
}
