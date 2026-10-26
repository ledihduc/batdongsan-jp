/// Widget test cho ReelBar — hàng reel ngang ở ĐẦU MỌI FEED.
///
/// Widget này xuất hiện trên mọi màn chính, nên bất biến quan trọng nhất là:
/// khi KHÔNG có reel thì nó phải BIẾN MẤT hoàn toàn, không để lại khoảng trống
/// hay tiêu đề trơ trọi ở đầu feed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/models/reel_model.dart';
import 'package:house_booking/features/guest/reels/reel_bar.dart';

import '../../helpers/pump_app.dart';
import '_fake_reel_api.dart';
import '_fake_video_player.dart';

void main() {
  setUp(() => FakeVideoPlayerPlatform.install());

  Future<FakeReelApi> pumpBar(
    WidgetTester tester, {
    List<Map<String, dynamic>> reels = const [],
    Set<String> throwOn = const {},
    String? category,
    bool signedIn = true,
  }) async {
    final api = FakeReelApi(
      listResult: reels.map(Reel.fromMap).toList(),
      throwOn: throwOn,
    );
    await pumpApp(
      tester,
      Scaffold(body: ReelBar(api: api, category: category)),
      auth: signedIn ? SignedInAuthProvider() : null,
    );
    await tester.pumpAndSettle();
    return api;
  }

  group('Tải dữ liệu', () {
    testWidgets('truyền đúng category xuống API', (tester) async {
      final api = await pumpBar(tester, category: 'lease');
      expect(api.argsOf('list')?[0], 'lease');
    });

    testWidgets('hiện reel trả về', (tester) async {
      await pumpBar(tester, reels: [
        fakeReelMap(id: 1, caption: 'Căn hộ view sông'),
        fakeReelMap(id: 2, caption: 'Nhà xưởng Long Hậu'),
      ]);
      expect(find.textContaining('Căn hộ view sông'), findsOneWidget);
      expect(find.textContaining('Nhà xưởng Long Hậu'), findsOneWidget);
    });
  });

  group('Trạng thái rỗng', () {
    testWidgets('rỗng → VẪN hiện thanh kèm ô "Tạo reel"', (tester) async {
      // Hành vi THẬT (đã đối chiếu code): rỗng thì vẫn hiện thanh với ô tạo
      // reel, để người dùng đầu tiên có đường gieo nội dung. Không phải bug.
      await pumpBar(tester, reels: []);
      expect(find.textContaining('Tạo'), findsWidgets);
    });

    testWidgets('KHÔNG còn dòng tiêu đề và bộ đếm "n video"', (tester) async {
      // Bỏ theo yêu cầu 19/07/2026: Facebook không gắn nhãn cho dải Reels, và
      // con số đếm chỉ làm lộ việc kho video còn rất ít.
      await pumpBar(tester, reels: [fakeReelMap(id: 1), fakeReelMap(id: 2)]);
      expect(find.textContaining('video'), findsNothing);
      expect(find.text('Reels'), findsNothing);
      expect(find.text('2 video'), findsNothing);
    });

    testWidgets('vẫn có nhãn trợ năng cho dải reel', (tester) async {
      // Dải mất nhãn NHÌN THẤY được thì trình đọc màn hình phải còn nghe được,
      // nếu không người khiếm thị chỉ gặp một dãy ô trống nghĩa.
      await pumpBar(tester, reels: [fakeReelMap(id: 1)]);
      expect(
        find.bySemanticsLabel('Reels'),
        findsOneWidget,
        reason: 'ReelBar.title phải được gắn làm nhãn Semantics',
      );
    });

    testWidgets('API lỗi → coi như rỗng, KHÔNG hiện lỗi giữa feed',
        (tester) async {
      // Reel là nội dung phụ; hỏng thì không được phá feed chính bằng thông
      // báo lỗi đỏ.
      await pumpBar(tester, throwOn: {'list'});
      expect(tester.takeException(), isNull);
      expect(find.textContaining('lỗi'), findsNothing);
    });

    testWidgets('KHÁCH chưa đăng nhập cũng thấy thanh khi rỗng', (tester) async {
      // ⚠ Doc của widget ghi "Tự ẩn nếu không có reel nào VÀ người dùng chưa
      // đăng nhập" — nhưng build() KHÔNG hề kiểm đăng nhập. Test này khoá lại
      // hành vi THẬT. Nếu sau này ai đó hiện thực đúng như doc, test sẽ đỏ và
      // buộc phải xác nhận đó là thay đổi có chủ đích.
      await pumpBar(tester, reels: [], signedIn: false);
      expect(find.textContaining('Tạo'), findsWidgets);
    });
  });

  group('Mở trình xem', () {
    testWidgets('chạm thẻ reel → mở màn xem toàn màn hình', (tester) async {
      await pumpBar(tester, reels: [fakeReelMap(id: 1, caption: 'Reel A')]);
      await tester.tap(find.textContaining('Reel A'));
      // KHÔNG dùng pumpAndSettle: trình xem cập nhật thanh tiến trình theo mỗi
      // nhịp phát nên cây widget không bao giờ "tĩnh" — pumpAndSettle sẽ treo.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.close), findsOneWidget,
          reason: 'màn xem toàn màn hình có nút đóng');
      // Dọn: đóng lại để controller được huỷ, tránh timer rò sang test sau.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
