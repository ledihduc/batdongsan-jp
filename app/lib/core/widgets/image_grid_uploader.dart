import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/theme/design_tokens.dart';

/// 1 ảnh trong lưới upload — hoặc ảnh MỚI chọn (bytes) đang/đã upload, hoặc ảnh
/// CŨ (chỉ có url, khi sửa). Ảnh ở index 0 của list = ẢNH BÌA.
class UploadImage {
  Uint8List? bytes; // null nếu là ảnh cũ (đã có url)
  String name;
  String? url; // URL sau upload (hoặc URL cũ khi sửa)
  bool uploading;
  bool failed;
  UploadImage({
    this.bytes,
    this.name = '',
    this.url,
    this.uploading = false,
    this.failed = false,
  });

  UploadImage.existing(this.url)
      : bytes = null,
        name = '',
        uploading = false,
        failed = false;
}

typedef ImageUploadFn = Future<String> Function(
    List<int> bytes, String filename);

/// Lưới upload nhiều ảnh dùng CHUNG: chọn nhiều ảnh, upload từng ảnh (spinner/
/// thử lại), xoá, ĐẶT ẢNH BÌA (đưa lên đầu). Danh sách [images] do CHA sở hữu để
/// đọc lại URL khi submit. Bìa = images.first (khớp cách showcase/gallery đọc
/// `images.first`).
class ImageGridUploader extends StatefulWidget {
  const ImageGridUploader({
    super.key,
    required this.images,
    required this.uploadFn,
    this.maxImages = 10,
    this.onChanged,
    this.crossAxisCount = 3,
  });

  final List<UploadImage> images;
  final ImageUploadFn uploadFn;
  final int maxImages;
  final VoidCallback? onChanged;
  final int crossAxisCount;

  @override
  State<ImageGridUploader> createState() => _ImageGridUploaderState();
}

class _ImageGridUploaderState extends State<ImageGridUploader> {
  final _picker = ImagePicker();

  String _abs(String url) =>
      url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';

  void _notify() {
    // Guard chung: _pick/_upload có await → có thể chạy sau khi màn bị pop.
    if (!mounted) return;
    setState(() {});
    widget.onChanged?.call();
  }

  Future<void> _pick() async {
    final remaining = widget.maxImages - widget.images.length;
    if (remaining <= 0) return;
    try {
      final files = await _picker.pickMultiImage(
          maxWidth: 1600, imageQuality: 80, limit: remaining);
      if (files.isEmpty) return;
      for (final f in files) {
        final bytes = await f.readAsBytes();
        final img =
            UploadImage(bytes: bytes, name: f.name, uploading: true);
        widget.images.add(img);
        _notify();
        _upload(img);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không chọn được ảnh')));
      }
    }
  }

  Future<void> _upload(UploadImage img) async {
    try {
      final url = await widget.uploadFn(img.bytes!, img.name);
      img
        ..url = url
        ..uploading = false
        ..failed = false;
    } catch (_) {
      img
        ..uploading = false
        ..failed = true;
    }
    if (mounted) _notify();
  }

  void _retry(UploadImage img) {
    img
      ..uploading = true
      ..failed = false;
    _notify();
    _upload(img);
  }

  void _remove(UploadImage img) {
    widget.images.remove(img);
    _notify();
  }

  void _makeCover(UploadImage img) {
    widget.images.remove(img);
    widget.images.insert(0, img);
    _notify();
  }

  void _menu(UploadImage img, int index) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HD.paper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (index != 0)
            ListTile(
              leading: const Icon(Icons.star_outline, color: HD.accent),
              title: const Text('Đặt làm ảnh bìa'),
              onTap: () {
                Navigator.pop(context);
                _makeCover(img);
              },
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: HD.negative),
            title: const Text('Xoá ảnh'),
            onTap: () {
              Navigator.pop(context);
              _remove(img);
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images;
    final showAdd = imgs.length < widget.maxImages;
    final count = imgs.length + (showAdd ? 1 : 0);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        crossAxisSpacing: HD.s8,
        mainAxisSpacing: HD.s8,
        childAspectRatio: 1,
      ),
      itemCount: count,
      itemBuilder: (context, i) {
        if (showAdd && i == imgs.length) return _addTile();
        return _tile(imgs[i], i);
      },
    );
  }

  Widget _addTile() {
    return GestureDetector(
      onTap: _pick,
      child: Container(
        decoration: BoxDecoration(
          color: HD.paperSunken,
          borderRadius: BorderRadius.circular(HD.r8),
          border: Border.all(color: HD.hairline),
        ),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_a_photo_outlined, color: HD.inkMuted),
              const SizedBox(height: 4),
              Text('Thêm ảnh', style: HD.caption(color: HD.inkMuted)),
            ]),
      ),
    );
  }

  Widget _tile(UploadImage img, int index) {
    return GestureDetector(
      onLongPress: () => _menu(img, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HD.r8),
        child: Stack(fit: StackFit.expand, children: [
          // Ảnh: mới (bytes) hoặc cũ (url).
          if (img.bytes != null)
            Image.memory(img.bytes!, fit: BoxFit.cover)
          else if (img.url != null)
            CachedNetworkImage(
                imageUrl: _abs(img.url!),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: HD.paperSunken))
          else
            Container(color: HD.paperSunken),
          if (img.uploading)
            Container(
              color: Colors.black45,
              child: const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))),
            ),
          if (img.failed)
            GestureDetector(
              onTap: () => _retry(img),
              child: Container(
                color: Colors.black54,
                child: const Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(Icons.refresh, color: Colors.white, size: 20),
                      Text('Thử lại',
                          style: TextStyle(color: Colors.white, fontSize: 11)),
                    ])),
              ),
            ),
          // Badge ảnh bìa.
          if (index == 0)
            Positioned(
              left: 4,
              top: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: HD.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Ảnh bìa',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          // Nút xoá.
          Positioned(
            right: 2,
            top: 2,
            child: GestureDetector(
              onTap: () => _remove(img),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
