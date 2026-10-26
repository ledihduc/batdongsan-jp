import 'package:flutter/material.dart';

import 'package:house_booking/core/theme/design_tokens.dart';

/// Khung bài đăng kiểu Facebook — dùng chung cho MỌI feed (BĐS, thi công,
/// cộng đồng) để ba feed trông như một sản phẩm thay vì ba sản phẩm.
///
/// Cấu trúc đúng thứ tự của FB:
/// ```
///  [avatar]  Tên người đăng            [⋯]
///            2 giờ · Quận 7
///  Nội dung bài viết…
///  [ảnh tràn viền]
///  👍 12                    3 bình luận
///  ──────────────────────────────────
///  [ Thích ] [ Bình luận ] [ Chia sẻ ]
/// ```
///
/// Ba chi tiết làm nên cảm giác "giống FB" mà nếu bỏ là hỏng:
///  1. Card **trắng trên nền xám** [HD.paper], không bo góc ở màn hẹp.
///  2. Ảnh **tràn hết chiều ngang**, không có lề hai bên.
///  3. Hàng đếm tương tác nằm **trên** đường kẻ, hàng nút nằm **dưới**.
class FbPostCard extends StatelessWidget {
  const FbPostCard({
    super.key,
    required this.authorName,
    this.avatarUrl,
    this.subtitle,
    this.badge,
    this.body,
    this.media,
    this.likeCount = 0,
    this.commentCount = 0,
    this.liked = false,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onMore,
    this.onTap,
    this.onTapAuthor,
    this.footer,
    this.actions,
    this.accent,
    this.loaiNhan,
    this.loaiIcon,
  });

  /// Màu nhấn của card — dùng cho dải nhãn loại nội dung ở đầu card.
  /// null = màu thương hiệu mặc định. Feed Thi công truyền [HD.construction]
  /// để card của nó không lẫn với card tin nhà: hai bên trước đây dùng CHUNG
  /// widget này nên nhìn y hệt, chiếm ~90% diện tích màn hình.
  final Color? accent;

  /// Nhãn LOẠI nội dung ("Công trình", "Cần báo giá"…), vẽ thành dải nổi ở đầu
  /// card. Khác [badge] — cái đó nhỏ, nằm cạnh tên tác giả nên mắt lướt qua
  /// không bắt được.
  final String? loaiNhan;
  final IconData? loaiIcon;

  /// Hàng nút dưới cùng. Để `null` → dùng bộ ba quen thuộc của FB
  /// (Thích · Bình luận · Chia sẻ).
  ///
  /// Truyền danh sách riêng khi loại nội dung KHÔNG có các hành động đó. Tin
  /// BĐS là ví dụ: model không hề có `likeCount`, nên vẽ nút "Thích" lên đó chỉ
  /// tạo ra một nút bấm vào không xảy ra gì. Ở đó dùng Lưu · Liên hệ · Chi tiết.
  final List<FbAction>? actions;

  final String authorName;
  final String? avatarUrl;

  /// Dòng dưới tên: thời gian đăng, địa điểm… Kiểu "2 giờ · Quận 7".
  final String? subtitle;

  /// Nhãn nhỏ cạnh tên (vd "Chính chủ", "Đã xác minh").
  final Widget? badge;

  /// Nội dung chữ của bài.
  final String? body;

  /// Ảnh/video — được vẽ TRÀN VIỀN, nơi gọi không cần tự bỏ padding.
  final Widget? media;

  final int likeCount;
  final int commentCount;
  final bool liked;

  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;

  /// Menu ⋯ (lưu bài, báo cáo, báo sai…).
  final VoidCallback? onMore;

  final VoidCallback? onTap;

  /// Chạm vào **avatar hoặc tên** người đăng → mở trang cá nhân của họ.
  /// Tách khỏi [onTap] (mở nội dung bài) vì đó là hai đích khác nhau: bấm tên
  /// là muốn xem người, bấm bài là muốn xem bài. null → không bấm được, chữ
  /// giữ nguyên màu để không hứa một hành động không có.
  final VoidCallback? onTapAuthor;

  /// Chèn thêm dưới hàng nút — vd nút "Đặt lịch xem" riêng của tin BĐS.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    // FB bỏ bo góc trên điện thoại (card chạm hai mép) và bo 8px trên màn rộng.
    final rong = MediaQuery.sizeOf(context).width >= 600;

    return Container(
      margin: EdgeInsets.only(bottom: 8, left: rong ? 0 : 0, right: 0),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: rong ? BorderRadius.circular(8) : BorderRadius.zero,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loaiNhan != null) _daiLoai(),
            _dauBai(),
            if (body != null && body!.trim().isNotEmpty) _noiDung(),
            ?media,
            if (likeCount > 0 || commentCount > 0) _hangDem(),
            _duongKe(),
            _hangNut(),
            ?footer,
          ],
        ),
      ),
    );
  }

  /// Dải nhãn LOẠI nội dung ở đầu card — nền đặc màu nhấn, chữ trắng, chạy hết
  /// chiều ngang. Đủ nổi để nhận ra loại bài ngay khi lướt, không phải đọc.
  Widget _daiLoai() {
    final mau = accent ?? HD.accent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      color: mau,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loaiIcon != null) ...[
            Icon(loaiIcon, size: 13, color: HD.paperRaised),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              loaiNhan!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: HD.paperRaised,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: .3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bọc avatar/tên thành vùng bấm khi có [onTapAuthor].
  /// Dùng [GestureDetector] chứ không phải [InkWell]: card đã nằm trong một
  /// InkWell (onTap mở bài), lồng thêm InkWell sẽ vẽ hai gợn sóng chồng nhau.
  Widget _chamTacGia(Widget con) {
    if (onTapAuthor == null) return con;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTapAuthor,
      child: con,
    );
  }

  Widget _dauBai() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chamTacGia(FbAvatar(url: avatarUrl, ten: authorName)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: _chamTacGia(
                        Text(
                          authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: HD.ink,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 4),
                      badge!,
                    ],
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: HD.inkMuted,
                        height: 1.3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onMore != null)
            IconButton(
              onPressed: onMore,
              icon: const Icon(Icons.more_horiz, color: HD.inkMuted),
              tooltip: 'Tuỳ chọn',
              splashRadius: 20,
            ),
        ],
      ),
    );
  }

  Widget _noiDung() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Text(
        body!,
        style: const TextStyle(fontSize: 15, color: HD.ink, height: 1.35),
      ),
    );
  }

  Widget _hangDem() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          if (likeCount > 0) ...[
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: HD.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.thumb_up,
                  size: 11, color: Colors.white),
            ),
            const SizedBox(width: 6),
            Text('$likeCount',
                style: const TextStyle(fontSize: 14, color: HD.inkMuted)),
          ],
          const Spacer(),
          if (commentCount > 0)
            Text('$commentCount bình luận',
                style: const TextStyle(fontSize: 14, color: HD.inkMuted)),
        ],
      ),
    );
  }

  Widget _duongKe() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Divider(height: 1, thickness: 1, color: HD.hairline),
      );

  Widget _hangNut() {
    final ds = actions ??
        [
          FbAction(
            icon: liked ? Icons.thumb_up : Icons.thumb_up_outlined,
            nhan: 'Thích',
            dangBat: liked,
            onTap: onLike,
          ),
          FbAction(
            icon: Icons.mode_comment_outlined,
            nhan: 'Bình luận',
            onTap: onComment,
          ),
          FbAction(
            icon: Icons.share_outlined,
            nhan: 'Chia sẻ',
            onTap: onShare,
          ),
        ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        children: [
          for (final a in ds)
            Expanded(
              child: _NutHanhDong(
                icon: a.icon,
                nhan: a.nhan,
                dangBat: a.dangBat,
                onTap: a.onTap,
              ),
            ),
        ],
      ),
    );
  }
}

/// Một nút trong hàng hành động của [FbPostCard].
class FbAction {
  const FbAction({
    required this.icon,
    required this.nhan,
    this.dangBat = false,
    this.onTap,
  });

  final IconData icon;
  final String nhan;

  /// Đang ở trạng thái bật (đã thích / đã lưu) → tô màu nhấn.
  final bool dangBat;

  final VoidCallback? onTap;
}

class _NutHanhDong extends StatelessWidget {
  const _NutHanhDong({
    required this.icon,
    required this.nhan,
    this.dangBat = false,
    this.onTap,
  });

  final IconData icon;
  final String nhan;
  final bool dangBat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mau = dangBat ? HD.accent : HD.inkMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: mau),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                nhan,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: mau,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar tròn. Không có ảnh thì hiện chữ cái đầu trên nền xanh nhạt —
/// FB cũng làm vậy, và nó tránh khoảng trống xám xấu khi thiếu ảnh.
/// Avatar tròn kiểu Facebook — ảnh, và khi thiếu ảnh thì chữ cái đầu trên nền
/// xanh nhạt. CÔNG KHAI vì composer bài viết cũng phải hiện đúng avatar này:
/// hai chỗ vẽ khác nhau thì người dùng thấy mình "đổi mặt" giữa lúc soạn và
/// lúc bài lên feed.
class FbAvatar extends StatelessWidget {
  const FbAvatar({super.key, this.url, required this.ten, this.kichThuoc = 40});

  final double kichThuoc;

  final String? url;
  final String ten;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url!,
          width: kichThuoc,
          height: kichThuoc,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _chuCai(),
        ),
      );
    }
    return _chuCai();
  }

  Widget _chuCai() {
    final c = ten.trim().isEmpty ? '?' : ten.trim().characters.first.toUpperCase();
    return Container(
      width: kichThuoc,
      height: kichThuoc,
      decoration: const BoxDecoration(
        color: HD.accentSoft,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        c,
        style: TextStyle(
          fontSize: kichThuoc * 0.45,
          fontWeight: FontWeight.w700,
          color: HD.accentDeep,
        ),
      ),
    );
  }
}

/// Ô "Bạn đang nghĩ gì?" đầu feed — lối vào đăng bài quen thuộc nhất của FB.
class FbComposerBar extends StatelessWidget {
  const FbComposerBar({
    super.key,
    required this.onTap,
    this.avatarUrl,
    this.ten = '',
    this.goiY = 'Bạn đang nghĩ gì?',
    this.actions = const [],
  });

  final VoidCallback onTap;
  final String? avatarUrl;
  final String ten;
  final String goiY;

  /// Hàng nút dưới (vd "Đăng tin", "Ảnh/Video").
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: HD.paperRaised,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              FbAvatar(url: avatarUrl, ten: ten),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: HD.hairline),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      goiY,
                      style: const TextStyle(fontSize: 15, color: HD.inkMuted),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Divider(height: 1, thickness: 1, color: HD.hairline),
            ),
            Row(children: actions),
          ],
        ],
      ),
    );
  }
}

/// Nút trong hàng dưới của [FbComposerBar].
class FbComposerAction extends StatelessWidget {
  const FbComposerAction({
    super.key,
    required this.icon,
    required this.nhan,
    required this.mau,
    this.onTap,
  });

  final IconData icon;
  final String nhan;
  final Color mau;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: mau),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  nhan,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: HD.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
