import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/reel_model.dart';
import 'package:house_booking/data/services/reel_api.dart';
import 'package:house_booking/features/auth/guest_gate.dart';
import 'package:house_booking/features/guest/reels/reel_composer_screen.dart';
import 'package:house_booking/features/guest/reels/reel_viewer_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';

String reelAbsUrl(String url) =>
    url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';

/// Khối REEL kiểu Facebook — hàng ngang các thẻ dọc 9:16, chèn ở ĐẦU MỌI FEED
/// (BĐS, Thi công, Cộng đồng). Tap → xem toàn màn hình cuộn dọc.
///
/// [category] quyết định nội dung: backend tự gộp reel `all` nên phần nào cũng
/// có reel. Tự ẩn nếu không có reel nào và người dùng chưa đăng nhập.
class ReelBar extends StatefulWidget {
  const ReelBar({
    super.key,
    this.category,
    this.title = 'Reels',
    this.api = const ReelApi(),
  });

  /// Cho phép bơm ReelApi giả trong test. Mặc định là bản thật nên mã
  /// sản phẩm không đổi hành vi — chỉ mở một khe để test không cần mạng.
  final ReelApi api;

  /// null / '' → lấy tất cả. Ví dụ: 'lease', 'build', 'interior'…
  final String? category;
  final String title;

  @override
  State<ReelBar> createState() => _ReelBarState();
}

class _ReelBarState extends State<ReelBar> {
  List<Reel> _reels = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ReelBar old) {
    super.didUpdateWidget(old);
    if (old.category != widget.category) _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.api.list(category: widget.category, limit: 20);
      if (mounted) setState(() => _reels = r);
    } catch (_) {
      if (mounted) setState(() => _reels = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openComposer() async {
    if (!GuestGate.requireAuth(
      context,
      message: 'Đăng nhập để đăng video reel.',
    )) {
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ReelComposerScreen(category: widget.category),
      ),
    );
    // KHÔNG chèn reel vừa tạo vào thanh: duyệt-TRƯỚC nên nó chưa công khai.
    // Tải lại để phản ánh đúng những gì đang thực sự hiển thị.
    if (mounted) _load();
  }

  void _openViewer(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReelViewerScreen(reels: _reels, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Đang tải hoặc rỗng → chỉ hiện ô "Tạo reel" (không để khoảng trống xấu).
    if (_loading) return const SizedBox(height: 0);

    return Container(
      color: HD.paperRaised,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dongTieuDe(),
          // Nhãn cho trình đọc màn hình: dòng tiêu đề ở trên là Text riêng nên
          // vẫn cần gán nhãn cho chính DẢI, không thì người khiếm thị chỉ nghe
          // thấy một dãy ô trống nghĩa.
          Semantics(
            label: widget.title,
            container: true,
            child: SizedBox(
              height: 178,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _reels.length + 1,
                separatorBuilder: (c, i) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  if (i == 0) return _createTile();
                  return _reelTile(_reels[i - 1], i - 1);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tiêu đề khối + lối "Xem tất cả".
  ///
  /// Bản trước bỏ hẳn dòng này (Facebook cũng không gắn nhãn cho dải Reels).
  /// Đưa lại vì ở đây dải nằm LẪN giữa hàng chip lọc và feed tin đăng — không
  /// có nhãn thì bốn ô video 9:16 trông như một hàng ảnh của tin đăng.
  ///
  /// "Xem tất cả" chỉ hiện khi ĐÃ CÓ reel: mời xem tất cả một kho rỗng thì bấm
  /// vào chỉ nhận về màn trắng.
  Widget _dongTieuDe() {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 6, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(l.reelSectionTitle, style: HD.bodyBold(size: 15)),
          ),
          if (_reels.isNotEmpty)
            TextButton(
              onPressed: () => _openViewer(0),
              style: TextButton.styleFrom(
                foregroundColor: HD.accent,
                visualDensity: VisualDensity.compact,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.reelSeeAll, style: HD.body(size: 13)),
                  const Icon(Icons.chevron_right, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Ô đầu tiên: tạo reel mới.
  Widget _createTile() => InkWell(
    onTap: _openComposer,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 100,
      decoration: BoxDecoration(
        color: HD.accentTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: HD.accent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tạo reel',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: HD.accent,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _reelTile(Reel r, int index) => InkWell(
    onTap: () => _openViewer(index),
    borderRadius: BorderRadius.circular(12),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 100,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (r.thumbnailUrl != null && r.thumbnailUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: reelAbsUrl(r.thumbnailUrl!),
                fit: BoxFit.cover,
                memCacheWidth: 220,
                placeholder: (_, _) => Container(color: HD.paperSunken),
                errorWidget: (_, _, _) => Container(color: HD.paperSunken),
              )
            else
              Container(color: HD.paperSunken),
            // Lớp phủ tối để chữ nổi.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
            ),
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 22,
              ),
            ),
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    r.caption.isEmpty ? r.authorName : r.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.favorite,
                        size: 10,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${r.likeCount}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
