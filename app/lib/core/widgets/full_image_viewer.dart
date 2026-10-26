import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

/// Xem ảnh toàn màn hình: chạm hai lần để phóng, kéo để dời, vuốt sang ảnh kế.
///
/// Bản trước dùng `InteractiveViewer` trần — phóng được bằng chụm hai ngón
/// nhưng KHÔNG có chạm-hai-lần (thao tác mà ai cũng thử đầu tiên) và không đi
/// được sang ảnh khác. Với app bất động sản, xem ảnh là việc chính của người
/// mua, nên hai thiếu sót đó không phải chuyện thẩm mỹ.
class FullImageViewer extends StatefulWidget {
  const FullImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.heroTag,
  });

  /// Một hoặc nhiều ảnh. Nhiều ảnh → vuốt ngang để chuyển.
  final List<String> imageUrls;
  final int initialIndex;
  final String? heroTag;

  @override
  State<FullImageViewer> createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<FullImageViewer> {
  late final PageController _ctrl = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _sang(int buoc) {
    final moi = (_index + buoc).clamp(0, widget.imageUrls.length - 1);
    if (moi == _index) return;
    _ctrl.animateToPage(
      moi,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _nutChuyen({
    required bool trai,
    required bool hien,
    required VoidCallback onTap,
  }) {
    return Positioned(
      left: trai ? 8 : null,
      right: trai ? null : 8,
      top: 0,
      bottom: 0,
      child: Center(
        // Vẫn giữ chỗ khi ở ảnh đầu/cuối để nút bên kia không nhảy sang chỗ
        // khác — chỉ làm mờ và vô hiệu hoá.
        child: AnimatedOpacity(
          opacity: hien ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: IgnorePointer(
            ignoring: !hien,
            child: Material(
              color: Colors.black.withValues(alpha: 0.45),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    trai ? Icons.chevron_left : Icons.chevron_right,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nhieu = widget.imageUrls.length > 1;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            // Trên WEB, PageView mặc định KHÔNG nhận kéo bằng chuột (chỉ chạm),
            // nên bộ ảnh mở trên máy tính sẽ không vuốt sang ảnh kế được. Khai
            // báo lại danh sách thiết bị kéo mới mở được đường đó.
            child: ScrollConfiguration(
              behavior: const _KeoBangChuot(),
              child: PhotoViewGallery.builder(
                pageController: _ctrl,
                itemCount: widget.imageUrls.length,
                onPageChanged: (i) => setState(() => _index = i),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                builder: (_, i) => PhotoViewGalleryPageOptions(
                  imageProvider: CachedNetworkImageProvider(
                    widget.imageUrls[i],
                  ),
                  // covered * 3: đủ để đọc số nhà, biển hiệu trong ảnh chụp xa.
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  // Hero CHỈ gắn cho ảnh mở đầu: gắn cho mọi trang sẽ có nhiều
                  // widget trùng tag cùng lúc và Flutter ném lỗi.
                  heroAttributes:
                      (widget.heroTag != null && i == widget.initialIndex)
                      ? PhotoViewHeroAttributes(tag: widget.heroTag!)
                      : null,
                ),
                loadingBuilder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white24),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          // Nút lùi/tới. Trên WEB, PhotoView giành lấy cử chỉ kéo để dời ảnh
          // nên chuột kéo ngang KHÔNG sang được ảnh kế (điện thoại vuốt vẫn
          // được). Hai nút này là lối đi chắc chắn cho cả hai loại thiết bị,
          // và cũng rõ ràng hơn cho người không biết là vuốt được.
          if (nhieu) ...[
            _nutChuyen(trai: true, hien: _index > 0, onTap: () => _sang(-1)),
            _nutChuyen(
              trai: false,
              hien: _index < widget.imageUrls.length - 1,
              onTap: () => _sang(1),
            ),
          ],
          if (nhieu) ...[
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: Text(
                '${_index + 1}/${widget.imageUrls.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 0,
              right: 0,
              child: Center(
                child: SmoothPageIndicator(
                  controller: _ctrl,
                  count: widget.imageUrls.length,
                  effect: const WormEffect(
                    dotWidth: 7,
                    dotHeight: 7,
                    spacing: 5,
                    activeDotColor: Colors.white,
                    dotColor: Colors.white30,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mở [FullImageViewer] cho MỘT ảnh. No-op nếu url null/rỗng — placeholder rỗng
/// không được biến thành một màn đen trống.
void showFullImage(BuildContext context, String? url, {String? heroTag}) {
  if (url == null || url.trim().isEmpty) return;
  showImageGallery(context, [url], heroTag: heroTag);
}

/// Mở bộ ảnh, bắt đầu từ [initialIndex].
void showImageGallery(
  BuildContext context,
  List<String> urls, {
  int initialIndex = 0,
  String? heroTag,
}) {
  final sach = urls.where((u) => u.trim().isNotEmpty).toList();
  if (sach.isEmpty) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => FullImageViewer(
        imageUrls: sach,
        initialIndex: initialIndex.clamp(0, sach.length - 1),
        heroTag: heroTag,
      ),
    ),
  );
}

/// Cho phép kéo bằng CHUỘT và TOUCHPAD, không chỉ ngón tay.
class _KeoBangChuot extends MaterialScrollBehavior {
  const _KeoBangChuot();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
