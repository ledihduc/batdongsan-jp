import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/content_actions_sheet.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/widgets/fb_post_card.dart';
import 'package:house_booking/data/models/community_category.dart';
import 'package:house_booking/data/models/social_post_model.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Nhãn thời gian tương đối kiểu Facebook: "Vừa xong" · "12 phút" · "3 giờ" ·
/// "2 ngày". Dùng chung cho card bài đăng và bình luận.
String socialTimeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
  if (diff.inHours < 24) return '${diff.inHours} giờ';
  if (diff.inDays < 7) return '${diff.inDays} ngày';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} tuần';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} tháng';
  return '${(diff.inDays / 365).floor()} năm';
}

/// Thẻ bài đăng trên Bảng tin — bố cục kiểu Facebook: header (avatar/tên/giờ),
/// nội dung, lưới ảnh, hàng đếm like/comment, và 3 nút hành động.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    this.onDelete,
    this.onEdit,
    this.isSaved = false,
    this.onToggleSave,
    this.showCategory = true,
    this.onBlocked,
  });

  final SocialPost post;
  final VoidCallback onLike;
  final VoidCallback onComment;

  /// Chỉ có khi người xem là tác giả (hoặc admin) → hiện menu xoá.
  final VoidCallback? onDelete;

  /// Chỉ có khi người xem là tác giả → hiện menu sửa bài.
  final VoidCallback? onEdit;

  /// Bài đã được lưu chưa — đổi nhãn "Lưu"/"Bỏ lưu" trong menu ⋯.
  final bool isSaved;

  /// Bỏ trống nếu màn hình chưa hỗ trợ lưu → mục Lưu bị ẩn.
  final Future<void> Function()? onToggleSave;

  /// Ẩn chip category khi feed đã cố định 1 khối (đỡ lặp nhãn).
  final bool showCategory;

  /// Gọi sau khi người xem chặn tác giả bài — để feed làm mới/ẩn bài.
  final VoidCallback? onBlocked;

  @override
  Widget build(BuildContext context) {
    // Khung/nhịp/hàng nút do [FbPostCard] lo — dùng chung với card tin BĐS để
    // ba feed trông như MỘT sản phẩm. Phần riêng của bài cộng đồng (lưới ảnh
    // thích ứng, chip khối) vẫn giữ ở tệp này.
    return FbPostCard(
      authorName: post.authorName,
      avatarUrl: post.authorAvatar,
      subtitle: _dongPhu(context),
      badge: showCategory ? _categoryChip() : null,
      body: post.content,
      media: post.images.isNotEmpty ? _imageGrid() : null,
      likeCount: post.likeCount,
      commentCount: post.commentCount,
      liked: post.likedByMe,
      onLike: onLike,
      onComment: onComment,
      onShare: onComment,
      onMore: () => ContentActionsSheet.show(
        context,
        targetType: ContentTargetType.post,
        targetId: post.id,
        isSaved: isSaved,
        onToggleSave: onToggleSave,
        isOwner: onEdit != null || onDelete != null,
        onEdit: onEdit,
        onDelete: onDelete,
        authorId: post.userId,
        onBlocked: onBlocked,
      ),
    );
  }

  /// "3 giờ · 📍 Quận 7 · đã chỉnh sửa" — dòng nhỏ dưới tên, đúng vị trí FB.
  String _dongPhu(BuildContext context) {
    final l = AppLocalizations.of(context);
    final phan = [socialTimeAgo(post.createdAt)];
    // Địa danh người dùng nhập ở form — hiện lại để không "nuốt" dữ liệu vị trí.
    final loc = post.locationText;
    if (loc != null && loc.trim().isNotEmpty) phan.add('📍 ${loc.trim()}');
    if (post.isEdited) phan.add(l.postCardEdited);
    return phan.join(' · ');
  }

  /// Chip nhãn khối (category) — màu theo khối, kiểu Facebook group tag.
  Widget _categoryChip() {
    final cat = communityCategoryOf(post.category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cat.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(HD.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cat.icon, size: 12, color: cat.color),
          const SizedBox(width: 4),
          Text(
            post.categoryName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cat.color,
            ),
          ),
        ],
      ),
    );
  }

  /// Lưới ảnh thích ứng: 1 ảnh full, 2 ảnh chia đôi, 3 ảnh (1 lớn + 2 nhỏ),
  /// ≥4 dạng 2×2 với lớp phủ "+N" ở ô cuối.
  Widget _imageGrid() {
    final imgs = post.images;
    if (imgs.length == 1) {
      return _img(imgs[0], aspect: 4 / 3);
    }
    if (imgs.length == 2) {
      return Row(
        children: [
          Expanded(child: _img(imgs[0], aspect: 1)),
          const SizedBox(width: 2),
          Expanded(child: _img(imgs[1], aspect: 1)),
        ],
      );
    }
    if (imgs.length == 3) {
      return Row(
        children: [
          Expanded(flex: 2, child: _img(imgs[0], aspect: 1)),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                _img(imgs[1], aspect: 1),
                const SizedBox(height: 2),
                _img(imgs[2], aspect: 1),
              ],
            ),
          ),
        ],
      );
    }
    // ≥4 ảnh: lưới 2×2, ô thứ 4 phủ "+N" nếu còn dư.
    final extra = imgs.length - 4;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _img(imgs[0], aspect: 1)),
            const SizedBox(width: 2),
            Expanded(child: _img(imgs[1], aspect: 1)),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(child: _img(imgs[2], aspect: 1)),
            const SizedBox(width: 2),
            Expanded(child: _img(imgs[3], aspect: 1, overlayMore: extra)),
          ],
        ),
      ],
    );
  }

  Widget _img(String url, {required double aspect, int overlayMore = 0}) {
    return AspectRatio(
      aspectRatio: aspect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: HD.paperSunken),
            errorWidget: (_, __, ___) => Container(
              color: HD.paperSunken,
              child: const Icon(
                Icons.broken_image_outlined,
                color: HD.inkMuted,
              ),
            ),
          ),
          if (overlayMore > 0)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              alignment: Alignment.center,
              child: Text(
                '+$overlayMore',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
