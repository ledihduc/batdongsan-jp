/// Smoke test cấp ứng dụng — app có DỰNG được và vẽ khung hình đầu không.
///
/// Thay cho test "Counter increments" mặc định của Flutter: app này chưa bao
/// giờ có counter, nên test đó fail từ ngày khởi tạo dự án và chẳng canh gì cả.
///
/// Test ở đây tuy nông nhưng canh đúng loại sự cố tệ nhất: lỗi lúc khởi động
/// (provider thiếu, router cấu hình sai, cast null trong `initState`) — thứ
/// khiến người dùng thấy màn hình trắng và không một test đơn vị nào bắt được.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/main.dart';

void main() {
  setUpAll(() {
    // main.dart bình thường gọi các kênh nền tảng (lưu trữ an toàn, thông báo).
    // Trong test không có nền tảng thật → trả rỗng thay vì để ném lỗi.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'readAll' ? <String, String>{} : null,
    );
  });

  testWidgets('app dựng được và vẽ khung hình đầu (không FCM)', (tester) async {
    await tester.pumpWidget(const MyApp(fcmAvailable: false));
    await tester.pump();

    // Dựng được cây widget = qua được initState của toàn bộ provider + router.
    expect(find.byType(MaterialApp), findsOneWidget);
    // Và không có lỗi nào bị nuốt trong lúc dựng.
    expect(tester.takeException(), isNull);
  });

  testWidgets('app dựng được khi Firebase KHÔNG khả dụng hay có', (tester) async {
    // Máy Huawei / thiếu cấu hình → fcmAvailable=false. Nhánh này phải chạy
    // được y như nhánh có Firebase, nếu không cả dòng máy đó mở app là trắng.
    for (final fcm in [false, true]) {
      await tester.pumpWidget(MyApp(fcmAvailable: fcm));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'fcmAvailable=$fcm');
    }
  });
}
