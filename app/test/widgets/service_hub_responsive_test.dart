import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/features/onboarding/service_hub_screen.dart';

import '../helpers/pump_app.dart';

/// Bố cục trang chủ trên MÀN HÌNH ĐIỆN THOẠI.
///
/// Hai thứ được canh:
///   1. Bốn ô hành động phải BẰNG NHAU. Trước đây mỗi ô cao theo nhãn của nó,
///      nên trên máy hẹp "Mua bán · Cho thuê" xuống hai dòng và cao hơn hẳn
///      "Dịch vụ" — bốn ô so le, nhìn như lỗi hiển thị.
///   2. Không tràn ngang (RenderFlex overflow) ở bề rộng nhỏ. 320dp là màn hẹp
///      nhất còn gặp thật (iPhone SE đời đầu, Android giá rẻ).
const _beRongMay = <double>[320, 360, 390, 430];

Future<void> _dungOBeRong(WidgetTester tester, double w, Widget man) async {
  tester.view.physicalSize = Size(w, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await pumpApp(tester, man);
  await tester.pump();
}

/// Kích thước các ô hành động đỏ — lấy theo KHOÁ chứ không đoán theo kích
/// thước: màn hình còn nhiều InkWell khác (ô tìm kiếm, thẻ người bán…).
List<Size> _coCacO(WidgetTester tester, List<String> nhan) {
  return [
    for (final n in nhan)
      if (find.byKey(ValueKey('hubAction_$n')).evaluate().isNotEmpty)
        tester.getSize(find.byKey(ValueKey('hubAction_$n'))),
  ];
}

const _nhanTrangChu = [
  'Mua bán · Cho thuê',
  'Đăng tin nhu cầu',
  'Thông tin và quy hoạch',
  'Dịch vụ',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  group('Trang chủ — 4 ô hành động', () {
    for (final w in _beRongMay) {
      testWidgets('${w.toInt()}dp: bốn ô CAO BẰNG NHAU', (tester) async {
        await _dungOBeRong(tester, w, const ServiceHubScreen());

        final co = _coCacO(tester, _nhanTrangChu);
        expect(co.length, 4, reason: 'phải tìm được đủ 4 ô hành động');
        final cao = co.map((s) => s.height).toSet();
        expect(cao.length, 1,
            reason: 'các ô cao khác nhau: ${co.map((s) => s.height)}');
      });

      testWidgets('${w.toInt()}dp: hai ô cùng hàng RỘNG BẰNG NHAU',
          (tester) async {
        await _dungOBeRong(tester, w, const ServiceHubScreen());

        final co = _coCacO(tester, _nhanTrangChu);
        expect(co[0].width, co[1].width);
        expect(co[2].width, co[3].width);
      });

      testWidgets('${w.toInt()}dp: không tràn ngang', (tester) async {
        await _dungOBeRong(tester, w, const ServiceHubScreen());
        expect(tester.takeException(), isNull);
      });
    }
  });

}
