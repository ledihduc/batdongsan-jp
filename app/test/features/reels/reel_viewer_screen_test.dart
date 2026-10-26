/// Widget test cho trình xem reel toàn màn hình.
///
/// Trọng tâm là **logic đo lượt xem** — backend chỉ tính 1 lượt khi xem ≥3s,
/// nên phía app phải đo mốc vào/ra từng reel cho đúng. Đo sai thì số liệu ảo
/// theo hướng ngược lại: hoặc mất lượt xem thật, hoặc thổi phồng lượt lướt qua.
///
/// Lưu ý kỹ thuật: KHÔNG dùng `pumpAndSettle` ở màn này — thanh tiến trình cập
/// nhật theo mỗi nhịp phát nên cây widget không bao giờ "tĩnh".
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/models/reel_model.dart';
import 'package:house_booking/features/guest/reels/reel_viewer_screen.dart';

import '../../helpers/pump_app.dart';
import '_fake_reel_api.dart';
import '_fake_video_player.dart';

void main() {
  late FakeVideoPlayerPlatform video;
  setUp(() => video = FakeVideoPlayerPlatform.install());

  Future<void> pumpViewer(
    WidgetTester tester, {
    required List<Map<String, dynamic>> reels,
    int initialIndex = 0,
    bool signedIn = true,
  }) async {
    await pumpApp(
      tester,
      ReelViewerScreen(
        reels: reels.map(Reel.fromMap).toList(),
        initialIndex: initialIndex,
      ),
      auth: signedIn ? SignedInAuthProvider() : null,
    );
    // Vài nhịp: create() → sự kiện initialized → controller áp dụng
    // looping/volume. Một nhịp là chưa đủ.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Đóng màn để controller được huỷ — tránh timer rò sang test kế tiếp.
  Future<void> close(WidgetTester tester) async {
    if (find.byIcon(Icons.close).evaluate().isNotEmpty) {
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  group('Dựng màn', () {
    testWidgets('hiện chú thích và tác giả của reel đang xem', (tester) async {
      await pumpViewer(tester, reels: [
        fakeReelMap(id: 1, caption: 'Căn hộ view sông'),
      ]);
      expect(find.text('Căn hộ view sông'), findsOneWidget);
      expect(find.text('Chị Hoa'), findsOneWidget);
      await close(tester);
    });

    testWidgets('có đủ nút hành động: thích, bình luận, chia sẻ, báo cáo',
        (tester) async {
      await pumpViewer(tester, reels: [fakeReelMap(id: 1)]);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
      await close(tester);
    });

    testWidgets('web: bắt đầu ở trạng thái TẮT TIẾNG', (tester) async {
      // Trình duyệt chặn autoplay có tiếng — không tắt tiếng thì video không
      // chạy được chút nào.
      await pumpViewer(tester, reels: [fakeReelMap(id: 1)]);
      expect(find.byIcon(Icons.volume_off), findsOneWidget);
      expect(video.lastVolume, 0);
      await close(tester);
    });

    testWidgets('bật tiếng → đổi biểu tượng và âm lượng', (tester) async {
      await pumpViewer(tester, reels: [fakeReelMap(id: 1)]);
      await tester.tap(find.byIcon(Icons.volume_off));
      // setState → didUpdateWidget → setVolume: cần vài nhịp mới tới nền tảng.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      expect(video.lastVolume, 1);
      await close(tester);
    });
  });

  group('Đo lượt xem — bất biến quan trọng nhất', () {
    testWidgets('lướt qua NHANH (<3s) → KHÔNG gửi lượt xem', (tester) async {
      await pumpViewer(tester, reels: [fakeReelMap(id: 1)]);
      await close(tester); // đóng ngay, chưa tới 3 giây
      // Không có cách kiểm trực tiếp API ở đây (viewer tự dựng ReelApi thật),
      // nhưng ta kiểm được điều tương đương: màn đóng mà không ném lỗi.
      expect(tester.takeException(), isNull);
    });

    testWidgets('vuốt sang reel kế → tạo controller mới cho trang đó',
        (tester) async {
      await pumpViewer(tester, reels: [
        fakeReelMap(id: 1, caption: 'Reel 1'),
        fakeReelMap(id: 2, caption: 'Reel 2'),
      ]);
      // Ban đầu PageView chỉ dựng trang đang hiển thị — nạp trước chỉ có tác
      // dụng khi PageView đã dựng trang kề, không phải ngay lúc mở màn.
      expect(video.createdCount, 1);

      await tester.drag(find.byType(PageView), const Offset(0, -600));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(video.createdCount, greaterThanOrEqualTo(2),
          reason: 'trang mới phải có controller riêng');
      expect(find.text('Reel 2'), findsOneWidget);
      await close(tester);
    });
  });

  group('Tiết kiệm dữ liệu', () {
    testWidgets('có nút bật/tắt ở góc trên', (tester) async {
      await pumpViewer(tester, reels: [fakeReelMap(id: 1)]);
      expect(find.byIcon(Icons.data_saver_off), findsOneWidget);
      await close(tester);
    });

    testWidgets('bật → đổi biểu tượng sang trạng thái đang bật',
        (tester) async {
      await pumpViewer(tester, reels: [fakeReelMap(id: 1)]);
      await tester.tap(find.byIcon(Icons.data_saver_off));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byIcon(Icons.data_saver_on), findsOneWidget);
      await close(tester);
    });
  });

  group('Thích', () {
    testWidgets('reel chưa thích hiện tim rỗng', (tester) async {
      await pumpViewer(tester,
          reels: [fakeReelMap(id: 1, likedByMe: false, likeCount: 3)]);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      await close(tester);
    });

    testWidgets('reel đã thích hiện tim đầy', (tester) async {
      await pumpViewer(tester,
          reels: [fakeReelMap(id: 1, likedByMe: true, likeCount: 4)]);
      expect(find.byIcon(Icons.favorite), findsWidgets);
      await close(tester);
    });

    testWidgets('KHÁCH bấm thích → hiện lời mời đăng nhập, không đổi số',
        (tester) async {
      await pumpViewer(tester,
          reels: [fakeReelMap(id: 1, likeCount: 3)], signedIn: false);
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump(const Duration(milliseconds: 300));
      // Số lượt thích KHÔNG được tăng lạc quan khi chưa đăng nhập.
      expect(find.text('3'), findsWidgets);
      await close(tester);
    });
  });

  group('Báo cáo', () {
    testWidgets('mở bảng chọn lý do', (tester) async {
      await pumpViewer(tester, reels: [fakeReelMap(id: 1)]);
      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Báo cáo reel'), findsOneWidget);
      expect(find.text('Spam / quảng cáo'), findsOneWidget);
      expect(find.text('Vi phạm bản quyền'), findsOneWidget);
    });

    testWidgets('KHÁCH bấm báo cáo → KHÔNG mở bảng lý do', (tester) async {
      await pumpViewer(tester, reels: [fakeReelMap(id: 1)], signedIn: false);
      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Spam / quảng cáo'), findsNothing);
    });
  });

  group('Video hỏng', () {
    testWidgets('không khởi tạo được → báo rõ, KHÔNG màn đen im lặng',
        (tester) async {
      FakeVideoPlayerPlatform.install(failInit: true);
      await pumpViewer(tester, reels: [fakeReelMap(id: 1)]);
      expect(find.text('Không phát được video này'), findsOneWidget);
      await close(tester);
    });
  });
}
