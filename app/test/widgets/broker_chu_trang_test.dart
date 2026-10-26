import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/widgets/fb_post_card.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/features/guest/broker/broker_profile_screen.dart';
import 'package:house_booking/features/guest/home/widgets/home_map_preview.dart';

import '../helpers/pump_app.dart';

/// Chế độ CHỦ TRANG: cùng một trang khách thấy, mọc thêm nút sửa cạnh từng
/// khối.
///
/// Điều phải giữ: khách xem trang người khác KHÔNG bao giờ thấy nút sửa. Chỉ
/// một cờ `laChuTrang` ngăn giữa hai bản, nên nó cần test cả hai phía.
Map<String, dynamic> _hoSo({String? bio}) => {
  'id': 7,
  'name': 'Lê Quang Vinh',
  'avatar_path': null,
  'bio': bio,
  'cover_path': null,
  'rating': 4.8,
  'review_count': 6,
  'verified': true,
  'trusted': true,
  'listing_count': 0,
  'years_active': 4,
  'area_count': 3,
  'deal_count': 3,
  'specialties': <String>[],
  'main_areas': <String>[],
  'avg_response_hours': 0.5,
  'response_sample': 6,
  'verified_review_count': 6,
  'seller_kind': 'broker',
};

HouseModel _tin({
  int id = 11,
  String status = 'published',
  bool pinned = false,
  int likeCount = 0,
  int commentCount = 0,
  String title = 'Căn hộ 2PN Thủ Đức',
}) => HouseModel(
  id: id,
  hostId: 7,
  title: title,
  description: '',
  categoryId: 1,
  price: 7000000,
  area: 55,
  address: '1 Võ Văn Ngân',
  city: 'TP.HCM',
  district: 'Thủ Đức',
  bedrooms: 2,
  bathrooms: 1,
  status: status,
  pinned: pinned,
  likeCount: likeCount,
  commentCount: commentCount,
);

Future<void> _dung(
  WidgetTester t, {
  required bool laChuTrang,
  String? bio,
  VoidCallback? onMoCaiDat,
  List<HouseModel> tin = const [],
  Future<bool> Function(int)? xoaTinLoader,
}) async {
  t.view.physicalSize = const Size(500, 2600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await pumpApp(
    t,
    BrokerProfileScreen(
      userId: 7,
      laChuTrang: laChuTrang,
      onMoCaiDat: onMoCaiDat,
      xoaTinLoader: xoaTinLoader,
      profileLoader: (_) async => _hoSo(bio: bio),
      listingsLoader: (_) async => tin,
      reviewsLoader: (_) async => const [],
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('khách xem trang người khác → KHÔNG có nút sửa nào', (t) async {
    await _dung(t, laChuTrang: false, bio: 'Sáu năm cho thuê căn hộ.');
    expect(find.byType(DsEditChip), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
    // Dòng liên hệ là ghi chú CHO CHỦ TRANG, khách không cần đọc lại.
    expect(find.textContaining('Khách chỉ nhắn được'), findsNothing);
  });

  testWidgets('chủ trang → nút sửa cạnh danh tính, liên hệ và giới thiệu', (
    t,
  ) async {
    await _dung(t, laChuTrang: true, bio: 'Sáu năm cho thuê căn hộ.');
    expect(find.byType(DsEditChip), findsNWidgets(3));
  });

  testWidgets('chủ trang KHÔNG có thanh nổi dưới đáy', (t) async {
    await _dung(t, laChuTrang: true, bio: 'x');
    final sc = t.widget<Scaffold>(find.byType(Scaffold).first);
    expect(sc.bottomNavigationBar, isNull);
  });

  testWidgets('dòng liên hệ nói đúng khách đang thấy đường nào', (t) async {
    await _dung(t, laChuTrang: true, bio: 'x');
    // Hồ sơ mẫu không có phone lẫn zalo (backend bỏ hẳn khoá khi tắt).
    expect(find.text('Khách chỉ nhắn được trong app'), findsOneWidget);
  });

  testWidgets('chủ trang, bio trống → vẫn vẽ khối để có chỗ bấm thêm', (
    t,
  ) async {
    await _dung(t, laChuTrang: true);
    expect(find.text('Giới thiệu'), findsOneWidget);
    expect(find.textContaining('Chưa có giới thiệu'), findsOneWidget);
  });

  testWidgets('khách, bio trống → không vẽ khối rỗng', (t) async {
    await _dung(t, laChuTrang: false);
    expect(find.text('Giới thiệu'), findsNothing);
  });

  testWidgets('bánh răng mở màn tài khoản — cài đặt/đăng xuất không mất', (
    t,
  ) async {
    var mo = 0;
    await _dung(t, laChuTrang: true, onMoCaiDat: () => mo++);
    await t.tap(find.byIcon(Icons.settings_outlined));
    await t.pumpAndSettle();
    expect(mo, 1);
  });

  testWidgets('trang cá nhân không còn lối Chuyển chế độ', (t) async {
    await _dung(t, laChuTrang: true, bio: 'x');
    expect(find.text('Chuyển chế độ'), findsNothing);
    expect(find.byTooltip('Chuyển chế độ'), findsNothing);
    expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
  });

  testWidgets('chủ trang KHÔNG thấy nút tự nhắn mình', (t) async {
    await _dung(t, laChuTrang: true, bio: 'x');
    expect(find.textContaining('Nhắn cho'), findsNothing);
  });

  // ── Sửa TẠI CHỖ ────────────────────────────────────────────────────────────

  testWidgets('bấm Sửa cạnh tên → ô chữ biến thành ô nhập ngay đó', (t) async {
    await _dung(t, laChuTrang: true, bio: 'x');
    expect(find.byType(TextField), findsNothing);

    await t.tap(find.byTooltip('Sửa tên'));
    await t.pumpAndSettle();

    // Ô nhập nạp sẵn tên hiện tại — không bắt gõ lại từ đầu.
    final o = t.widget<TextField>(find.byType(TextField));
    expect(o.controller!.text, 'Lê Quang Vinh');
    expect(find.byTooltip('Lưu'), findsOneWidget);
    expect(find.byTooltip('Huỷ'), findsOneWidget);
  });

  testWidgets('Huỷ trả về chữ, không đụng gì tới hồ sơ', (t) async {
    await _dung(t, laChuTrang: true, bio: 'x');
    await t.tap(find.byTooltip('Sửa tên'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Tên gõ dở');
    await t.tap(find.byTooltip('Huỷ'));
    await t.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Lê Quang Vinh'), findsOneWidget);
    expect(find.text('Tên gõ dở'), findsNothing);
  });

  testWidgets('tên rỗng thì chặn tại chỗ, không gọi API', (t) async {
    await _dung(t, laChuTrang: true, bio: 'x');
    await t.tap(find.byTooltip('Sửa tên'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '   ');
    await t.tap(find.byTooltip('Lưu'));
    await t.pump();

    // Vẫn ở chế độ sửa — trang cá nhân không tên là một thẻ không có ai.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Tên không được để trống'), findsOneWidget);
  });

  testWidgets('bấm Sửa cạnh giới thiệu → ô nhập nhiều dòng + Lưu/Huỷ', (
    t,
  ) async {
    await _dung(t, laChuTrang: true, bio: 'Sáu năm cho thuê căn hộ.');
    await t.tap(find.byTooltip('Sửa giới thiệu'));
    await t.pumpAndSettle();

    final o = t.widget<TextField>(find.byType(TextField));
    expect(o.controller!.text, 'Sáu năm cho thuê căn hộ.');
    expect(o.maxLines, 6);
    expect(find.text('Lưu'), findsOneWidget);
    expect(find.text('Huỷ'), findsOneWidget);
    // Chip "Sửa" ẩn đi khi đang mở ô nhập — bấm lần hai không có nghĩa gì.
    expect(find.byTooltip('Sửa giới thiệu'), findsNothing);
  });

  testWidgets('bio trống vẫn sửa tại chỗ được', (t) async {
    await _dung(t, laChuTrang: true);
    await t.tap(find.byTooltip('Sửa giới thiệu'));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('chủ trang có nút đổi ảnh; khách thì không', (t) async {
    await _dung(t, laChuTrang: true, bio: 'x');
    expect(find.byTooltip('Đổi ảnh đại diện'), findsOneWidget);

    await _dung(t, laChuTrang: false, bio: 'x');
    expect(find.byTooltip('Đổi ảnh đại diện'), findsNothing);
  });

  // ── Quản lý tin ngay trên bài ─────────────────────────────────────────────

  testWidgets('chủ trang: mỗi bài có menu ⋯; khách thì không', (t) async {
    await _dung(t, laChuTrang: true, bio: 'x', tin: [_tin()]);
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);

    await _dung(t, laChuTrang: false, bio: 'x', tin: [_tin()]);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
  });

  testWidgets('menu ⋯ đủ 6 mục, KHÔNG có "nhân bản"', (t) async {
    await _dung(t, laChuTrang: true, bio: 'x', tin: [_tin()]);
    await t.tap(find.byIcon(Icons.more_horiz));
    await t.pumpAndSettle();
    for (final m in [
      'Chỉnh sửa bài đăng',
      'Ghim bài đăng',
      'Xem thống kê',
      'Chia sẻ bài đăng',
      'Ẩn bài đăng',
      'Xoá bài đăng',
    ]) {
      expect(find.text(m), findsOneWidget, reason: m);
    }
    expect(find.textContaining('Nhân bản'), findsNothing);
  });

  testWidgets('tin đã ghim → mục đổi thành "Bỏ ghim"', (t) async {
    await _dung(t, laChuTrang: true, bio: 'x', tin: [_tin(pinned: true)]);
    await t.tap(find.byIcon(Icons.more_horiz));
    await t.pumpAndSettle();
    expect(find.text('Bỏ ghim bài đăng'), findsOneWidget);
    expect(find.text('Ghim bài đăng'), findsNothing);
  });

  testWidgets('tin đang ẩn → mục đổi thành "Hiện lại"', (t) async {
    await _dung(
      t,
      laChuTrang: true,
      bio: 'x',
      tin: [_tin(status: 'hidden')],
    );
    await t.tap(find.byIcon(Icons.more_horiz));
    await t.pumpAndSettle();
    expect(find.text('Hiện lại bài đăng'), findsOneWidget);
  });

  testWidgets('huỷ ở hộp xác nhận thì KHÔNG xoá', (t) async {
    var goi = 0;
    await _dung(
      t,
      laChuTrang: true,
      bio: 'x',
      tin: [_tin()],
      xoaTinLoader: (_) async {
        goi++;
        return true;
      },
    );
    await t.tap(find.byIcon(Icons.more_horiz));
    await t.pumpAndSettle();
    await t.tap(find.text('Xoá bài đăng'));
    await t.pumpAndSettle();
    expect(find.text('Xoá tin này?'), findsOneWidget);
    await t.tap(find.text('Hủy'));
    await t.pumpAndSettle();
    expect(goi, 0);
  });

  testWidgets('xác nhận xoá thì gọi đúng id của bài', (t) async {
    int? nhan;
    await _dung(
      t,
      laChuTrang: true,
      bio: 'x',
      tin: [_tin(id: 42)],
      xoaTinLoader: (id) async {
        nhan = id;
        return true;
      },
    );
    await t.tap(find.byIcon(Icons.more_horiz));
    await t.pumpAndSettle();
    await t.tap(find.text('Xoá bài đăng'));
    await t.pumpAndSettle();
    await t.tap(find.text('Xoá'));
    await t.pumpAndSettle();
    expect(nhan, 42);
  });

  testWidgets('chip "Quản lý tin đăng" cũ đã biến mất', (t) async {
    await _dung(t, laChuTrang: true, bio: 'x', tin: [_tin()]);
    expect(find.byTooltip('Quản lý tin đăng'), findsNothing);
  });

  // ── Thêm tin ──────────────────────────────────────────────────────────────

  testWidgets('chủ trang chưa có tin nào → vẫn thấy mục + nút Thêm tin', (
    t,
  ) async {
    await _dung(t, laChuTrang: true, bio: 'x');
    expect(find.text('Thêm tin'), findsOneWidget);
    expect(find.textContaining('Chưa có tin nào'), findsOneWidget);
  });

  testWidgets('khách không có tin → không vẽ mục tin đăng', (t) async {
    await _dung(t, laChuTrang: false, bio: 'x');
    expect(find.text('Thêm tin'), findsNothing);
    expect(find.textContaining('Chưa có tin nào'), findsNothing);
  });

  // ── Nhãn trạng thái ───────────────────────────────────────────────────────

  testWidgets('tin đang ẩn có nhãn; tin đang đăng thì không', (t) async {
    await _dung(
      t,
      laChuTrang: true,
      bio: 'x',
      tin: [
        _tin(id: 1, status: 'hidden'),
        _tin(id: 2),
      ],
    );
    expect(find.text('Đang ẩn'), findsOneWidget);
    expect(find.text('Chờ duyệt'), findsNothing);
  });

  testWidgets('khách KHÔNG thấy nhãn trạng thái', (t) async {
    await _dung(
      t,
      laChuTrang: false,
      bio: 'x',
      tin: [_tin(id: 1, status: 'hidden')],
    );
    expect(find.text('Đang ẩn'), findsNothing);
  });

  // ── Tin đăng cư xử như một bài viết ───────────────────────────────────────

  testWidgets('card có hàng Thích · Bình luận · Chia sẻ như bài viết', (
    t,
  ) async {
    await _dung(t, laChuTrang: false, bio: 'x', tin: [_tin()]);
    expect(find.text('Thích'), findsOneWidget);
    expect(find.text('Bình luận'), findsOneWidget);
    expect(find.text('Chia sẻ'), findsOneWidget);
    // "Chi tiết" chuyển lên dưới dòng giá, không mất đi.
    expect(find.text('Chi tiết'), findsOneWidget);
  });

  testWidgets('tin đã ghim nổi lên đầu danh sách', (t) async {
    await _dung(
      t,
      laChuTrang: true,
      bio: 'x',
      tin: [
        _tin(id: 1, title: 'Tin thường'),
        _tin(id: 2, pinned: true, title: 'Tin đã ghim'),
      ],
    );
    final cards = t
        .widgetList<FbPostCard>(find.byType(FbPostCard))
        .map((c) => c.body)
        .toList();
    expect(cards, ['Tin đã ghim', 'Tin thường']);
  });

  // ── BÌA LUÔN LÀ BẢN ĐỒ ────────────────────────────────────────────────────
  //
  // Trước đây chưa có tin nào thì bìa đổ về gradient đỏ trơn, rồi tự biến thành
  // bản đồ sau tin đầu tiên — cùng một người mà hai trang trông khác hẳn nhau.

  testWidgets('chưa có tin nào bìa VẪN là bản đồ', (t) async {
    await _dung(t, laChuTrang: true);
    expect(find.byType(HomeMapPreview), findsWidgets);
  });

  testWidgets('khách xem trang người khác cũng thấy bản đồ', (t) async {
    await _dung(t, laChuTrang: false);
    expect(find.byType(HomeMapPreview), findsWidgets);
  });
}
