import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/demand_api.dart';
import 'package:house_booking/features/guest/demand/demand_form_screen.dart';
import 'package:house_booking/features/guest/demand/demand_list_screen.dart';

import '../helpers/pump_app.dart';

/// Tin nhu cầu — màn chọn loại tin · form · danh sách.
///
/// Điều được canh kỹ nhất ở đây là **cửa rẽ nhánh**: bốn nhãn "Cho thuê / Cần
/// bán / Cần thuê / Cần mua" tự nó mơ hồ trong tiếng Việt, và bấm nhầm không
/// phải lỗi nhỏ — người dùng rơi vào form sai hoàn toàn (form tin rao đòi ảnh +
/// địa chỉ, trong khi họ chỉ muốn nói mình đang tìm gì).
Map<String, dynamic> _tin({
  int id = 1,
  String kind = 'rent',
  String status = 'open',
  int ngayConLai = 20,
}) =>
    {
      'id': id,
      'kind': kind,
      'status': status,
      'province_name': 'TP.HCM',
      'category_names': ['Căn hộ'],
      'category_ids': [1],
      'budget_min': 5000000.0,
      'budget_max': 9000000.0,
      'needs': ['parking'],
      'note': 'Cần 2PN gần Q7',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'expires_at': DateTime.now()
          .toUtc()
          .add(Duration(days: ngayConLai))
          .toIso8601String(),
      'author': {'id': 7, 'name': 'Người tìm nhà', 'avatar_path': ''},
    };

DemandApi _apiTra(List<Map<String, dynamic>> rows) => DemandApi(
      client: ApiClient(
        client: MockClient((req) async => http.Response(
              jsonEncode(rows),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            )),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ApiClient đính token vào header nên MỌI lời gọi đều chờ
  // flutter_secure_storage. Kênh nền tảng thật không chạy trong widget test —
  // không giả lập thì `await` treo, danh sách mãi ở trạng thái đang tải và test
  // trông như "không tìm thấy widget" chứ không lộ ra là bị treo.
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

  group('Form nhu cầu', () {
    testWidgets('KHÔNG hỏi số điện thoại và KHÔNG đòi ảnh', (tester) async {
      await pumpApp(tester, const DemandFormScreen(kind: 'rent'));
      await tester.pump();

      // Lý do duy nhất khiến người ta dám đăng nhu cầu là không bị gọi rác.
      expect(find.textContaining('điện thoại'), findsNothing);
      expect(find.textContaining('Ảnh'), findsNothing);
    });

    testWidgets('cần thuê hỏi ngày dọn vào; cần mua hỏi thanh toán',
        (tester) async {
      await pumpApp(tester, const DemandFormScreen(kind: 'rent'));
      await tester.pump();
      expect(find.text('Thời điểm dọn vào'), findsOneWidget);
      expect(find.text('Thanh toán'), findsNothing);

      await pumpApp(tester, const DemandFormScreen(kind: 'buy'));
      await tester.pump();
      expect(find.text('Thanh toán'), findsOneWidget);
      expect(find.text('Thời điểm dọn vào'), findsNothing);
    });

    testWidgets('chưa chọn loại hình thì chặn, không gửi lên server',
        (tester) async {
      var goi = 0;
      final api = DemandApi(
        client: ApiClient(
          client: MockClient((req) async {
            goi++;
            return http.Response('{}', 201);
          }),
        ),
      );
      await pumpApp(tester, DemandFormScreen(kind: 'rent', api: api));
      await tester.pump();

      await tester.tap(find.text('Đăng tin nhu cầu'));
      await tester.pump();

      expect(goi, 0);
      expect(find.text('Hãy chọn ít nhất một loại hình'), findsOneWidget);
    });
  });

  group('Danh sách nhu cầu', () {
    testWidgets('vẽ thẻ tin: loại hình · khoảng giá · số ngày còn lại',
        (tester) async {
      await pumpApp(tester, DemandListScreen(api: _apiTra([_tin()])));
      await tester.pump();
      await tester.pump();

      expect(find.text('Căn hộ — 5 tr – 9 tr'), findsOneWidget);
      expect(find.textContaining('ngày'), findsWidgets);
    });

    testWidgets('danh sách rỗng hiện trạng thái rỗng, không lỗi',
        (tester) async {
      await pumpApp(tester, DemandListScreen(api: _apiTra(const [])));
      await tester.pump();
      await tester.pump();

      expect(find.text('Chưa có tin nhu cầu nào.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('KHÔNG hiện nút đóng/gia hạn trên tin của người khác',
        (tester) async {
      await pumpApp(tester, DemandListScreen(api: _apiTra([_tin()])));
      await tester.pump();
      await tester.pump();

      expect(find.text('Đóng tin'), findsNothing);
      expect(find.text('Gia hạn 30 ngày'), findsNothing);
    });
  });
}
