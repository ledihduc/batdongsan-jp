/// NotificationProvider — nhịp hỏi thông báo phải NGỪNG khi không ai nhìn.
///
/// Bối cảnh đo được (log NPM 19/07/2026): `/api/notifications` là endpoint bị
/// gọi nhiều thứ nhì (844 lượt) trong khi app chưa có người dùng thật nào —
/// một tab để quên vẫn hỏi mỗi 30 giây suốt ngày.
///
/// Lưu ý quan trọng cho người sửa sau: KHÔNG được thay polling bằng WebSocket.
/// Kênh `/ws` hiện chỉ chở sự kiện chat (`chat:new`, `chat:read`); backend chưa
/// đẩy thông báo qua đó. Bỏ polling là mất thông báo.
///
/// Các test dưới đây ĐẾM số lần gọi mạng thật sự chứ không chỉ kiểm "không
/// ném" — nếu ai đó gỡ phần theo dõi vòng đời, số đếm sẽ sai ngay.
library;

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/providers/notification_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ApiClient đính token vào header nên MỌI lời gọi đều chờ
  // flutter_secure_storage. Kênh nền tảng thật không chạy trong fakeAsync —
  // không giả lập thì await treo và test đếm được 0 lời gọi, dễ tưởng nhầm là
  // polling đã ngừng. Trả null = chưa đăng nhập, đủ để request đi tiếp.
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

  /// Provider dùng client giả, kèm bộ đếm số lần gọi `/api/notifications`.
  ({NotificationProvider p, List<String> calls}) build() {
    final calls = <String>[];
    final client = MockClient((req) async {
      calls.add(req.url.path);
      return http.Response(
        '{"notifications": [], "unread": 0}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    return (
      p: NotificationProvider(api: ApiClient(client: client)),
      calls: calls,
    );
  }

  const nhip = Duration(seconds: 30);

  group('Đang hiển thị thì vẫn hỏi định kỳ', () {
    test('chạy 3 nhịp → gọi mạng 3 lần', () {
      fakeAsync((async) {
        final t = build();
        t.p.startPolling(1);
        t.calls.clear(); // bỏ qua lần nạp đầu nếu có

        async.elapse(nhip * 3);
        expect(t.calls.length, 3,
            reason: 'mỗi nhịp 30s phải gọi /api/notifications đúng 1 lần');
        expect(t.calls.every((p) => p == '/api/notifications'), isTrue);

        t.p.stopPolling();
      });
    });
  });

  group('Bị ẩn thì NGỪNG hẳn', () {
    test('ẩn rồi chờ 5 nhịp → KHÔNG gọi mạng lần nào', () {
      fakeAsync((async) {
        final t = build();
        t.p.startPolling(1);
        t.p.didChangeAppLifecycleState(AppLifecycleState.paused);
        t.calls.clear();

        async.elapse(nhip * 5);
        expect(t.calls, isEmpty,
            reason: 'tab bị ẩn mà vẫn hỏi là đúng lỗi đang sửa');

        t.p.stopPolling();
      });
    });

    test('hidden và inactive cũng ngừng, không chỉ paused', () {
      for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive]) {
        fakeAsync((async) {
          final t = build();
          t.p.startPolling(1);
          t.p.didChangeAppLifecycleState(s);
          t.calls.clear();
          async.elapse(nhip * 3);
          expect(t.calls, isEmpty, reason: 'trạng thái $s phải làm ngừng');
          t.p.stopPolling();
        });
      }
    });
  });

  group('Quay lại thì bù ngay, không đợi hết nhịp', () {
    test('resumed gọi NGAY một lần rồi mới chạy tiếp theo nhịp', () {
      fakeAsync((async) {
        final t = build();
        t.p.startPolling(1);
        t.p.didChangeAppLifecycleState(AppLifecycleState.paused);
        async.elapse(nhip * 4); // vắng mặt một lúc
        t.calls.clear();

        t.p.didChangeAppLifecycleState(AppLifecycleState.resumed);
        async.flushMicrotasks();
        expect(t.calls.length, 1,
            reason: 'phải bù ngay khoảng vừa ngừng, không để user chờ 30s');

        async.elapse(nhip * 2);
        expect(t.calls.length, 3, reason: 'sau đó chạy lại theo nhịp');

        t.p.stopPolling();
      });
    });

    test('resumed hai lần liên tiếp KHÔNG tạo hai timer chồng nhau', () {
      // Nếu chồng timer thì mỗi nhịp sẽ gọi 2 lần — đúng loại rò rỉ khó thấy.
      fakeAsync((async) {
        final t = build();
        t.p.startPolling(1);
        t.p.didChangeAppLifecycleState(AppLifecycleState.resumed);
        t.p.didChangeAppLifecycleState(AppLifecycleState.resumed);
        async.flushMicrotasks();
        t.calls.clear();

        async.elapse(nhip * 2);
        expect(t.calls.length, 2, reason: 'chồng timer sẽ cho 4 thay vì 2');

        t.p.stopPolling();
      });
    });
  });

  group('Dọn dẹp', () {
    test('stopPolling thì im hẳn', () {
      fakeAsync((async) {
        final t = build();
        t.p.startPolling(1);
        t.p.stopPolling();
        t.calls.clear();
        async.elapse(nhip * 5);
        expect(t.calls, isEmpty);
      });
    });

    test('sau stopPolling, vòng đời đổi cũng KHÔNG hồi sinh polling', () {
      // Đăng xuất rồi mà tab sáng lại vẫn gọi API là rò rỉ phiên.
      fakeAsync((async) {
        final t = build();
        t.p.startPolling(1);
        t.p.stopPolling();
        t.p.didChangeAppLifecycleState(AppLifecycleState.resumed);
        async.flushMicrotasks();
        t.calls.clear();
        async.elapse(nhip * 3);
        expect(t.calls, isEmpty);
      });
    });

    test('startPolling hai lần không nhân đôi nhịp', () {
      fakeAsync((async) {
        final t = build();
        t.p.startPolling(1);
        t.p.startPolling(2); // đổi tài khoản
        t.calls.clear();
        async.elapse(nhip * 2);
        expect(t.calls.length, 2, reason: 'timer cũ phải bị huỷ');
        t.p.stopPolling();
      });
    });
  });
}
