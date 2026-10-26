import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/widgets/composer_kit.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/data/models/community_category.dart';
import 'package:house_booking/data/models/social_post_model.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/social_api.dart';
import 'package:house_booking/l10n/app_localizations.dart';

/// Ảnh trong composer: có thể là ảnh MỚI chọn (bytes, chưa upload) hoặc ảnh CŨ
/// đã có URL (chế độ sửa bài). Khi đăng: upload ảnh mới, giữ nguyên URL cũ.
class _ComposerImage {
  final Uint8List? bytes; // ảnh mới
  final String? name;
  final String? url; // ảnh cũ (đã upload)
  const _ComposerImage.picked(this.bytes, this.name) : url = null;
  const _ComposerImage.existing(this.url) : bytes = null, name = null;
  bool get isExisting => url != null;
}

/// Soạn / sửa bài Cộng đồng kiểu Facebook: nội dung + nhiều ảnh + chọn khối
/// (category) + địa danh. Trả về [SocialPost] vừa tạo/sửa qua Navigator.pop.
class PostComposerScreen extends StatefulWidget {
  const PostComposerScreen({
    super.key,
    this.editPost,
    this.lockedCategory,
    this.initialCategory,
    this.provinceCode,
    this.districtCode,
    this.wardSlug,
    this.initialLocationText,
  });

  /// Chế độ sửa: truyền bài cần sửa (category & địa danh giữ nguyên phía server).
  final SocialPost? editPost;

  /// Khoá category (đăng từ trong 1 khối) — người dùng không đổi được.
  final String? lockedCategory;

  /// Pre-chọn category (tab Cộng đồng) — người dùng vẫn đổi được.
  final String? initialCategory;

  final String? provinceCode;
  final String? districtCode;
  final String? wardSlug;
  final String? initialLocationText;

  bool get isEdit => editPost != null;

  @override
  State<PostComposerScreen> createState() => _PostComposerScreenState();
}

class _PostComposerScreenState extends State<PostComposerScreen> {
  final _controller = TextEditingController();
  final _locationController = TextEditingController();
  final _picker = ImagePicker();
  final _api = SocialApi();
  final List<_ComposerImage> _images = [];
  String? _category; // key khối đang chọn
  bool _submitting = false;

  static const _maxImages = 10;

  @override
  void initState() {
    super.initState();
    final ep = widget.editPost;
    if (ep != null) {
      _controller.text = ep.content;
      _category = ep.category;
      _images.addAll(ep.images.map((u) => _ComposerImage.existing(u)));
      _locationController.text = ep.locationText ?? '';
    } else {
      _category = widget.lockedCategory ?? widget.initialCategory;
      _locationController.text = widget.initialLocationText ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _locationController.dispose();
    super.dispose();
  }

  bool get _categoryLocked => widget.isEdit || widget.lockedCategory != null;

  bool get _canSubmit =>
      !_submitting &&
      _category != null &&
      (_controller.text.trim().isNotEmpty || _images.isNotEmpty);

  /// Thoát composer. Có nội dung dở thì HỎI — đổi back thành ✕ làm nguy cơ mất
  /// bài tăng lên (✕ đọc như "bỏ đi"), nên phải chặn nhầm lẫn.
  Future<void> _thoat() async {
    final coNoiDung = _controller.text.trim().isNotEmpty || _images.isNotEmpty;
    if (!coNoiDung) {
      if (mounted) Navigator.maybePop(context);
      return;
    }
    final l = AppLocalizations.of(context);
    final boDi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.composerDiscardTitle),
        content: Text(l.composerDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.composerKeepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: HD.negative),
            child: Text(l.composerDiscard),
          ),
        ],
      ),
    );
    if (boDi == true && mounted) Navigator.pop(context);
  }

  Future<void> _pickImages() async {
    if (_images.length >= _maxImages) return;
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 80);
      if (picked.isEmpty) return;
      for (final XFile f in picked) {
        if (_images.length >= _maxImages) break;
        final bytes = await f.readAsBytes();
        _images.add(_ComposerImage.picked(bytes, f.name));
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).composerPickImageFailed),
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    // _canSubmit đã bao gồm điều kiện có khối; nhánh kiểm _category riêng ở
    // đây trước kia là CODE CHẾT (không bao giờ chạy tới).
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    try {
      // Giữ URL ảnh cũ, upload ảnh mới.
      // Chụp BẢN SAO: người dùng vẫn có thể xoá ảnh trong lúc upload chạy
      // (mỗi ảnh một await) -> lặp trực tiếp trên _images sẽ đăng lên tập ảnh
      // khác với thứ tự đang thấy, hoặc văng lỗi chỉ số.
      final anh = List<_ComposerImage>.of(_images);
      final urls = <String>[];
      for (final img in anh) {
        if (img.isExisting) {
          urls.add(img.url!);
        } else {
          urls.add(await _api.uploadImage(img.bytes!, img.name ?? 'image.jpg'));
        }
      }
      final content = _controller.text.trim();
      final SocialPost post;
      if (widget.isEdit) {
        post = await _api.editPost(
          postId: widget.editPost!.id,
          content: content,
          images: urls,
        );
      } else {
        post = await _api.createPost(
          content: content,
          images: urls,
          category: _category!,
          provinceCode: widget.provinceCode,
          districtCode: widget.districtCode,
          wardSlug: widget.wardSlug,
          locationText: _locationController.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, post);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).composerPostFailed),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paperRaised,
      appBar: DsAppBar(
        title: widget.isEdit ? l.composerEditTitle : l.composerCreateTitle,
        background: HD.paperRaised,
        // Đóng bằng ✕ như FB: composer là việc "làm rồi thoát", không phải một
        // trang trong mạch điều hướng nên mũi tên back gây hiểu nhầm là quay lui.
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: _thoat,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  HD.s16,
                  HD.s12,
                  HD.s16,
                  HD.s16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _hangTacGia(),
                    const SizedBox(height: HD.s12),
                    _hangChip(),
                    const SizedBox(height: HD.s8),
                    // Vùng viết là NHÂN VẬT CHÍNH: không viền, chữ to, và cao
                    // tối thiểu bằng ~1/4 màn để không bị các thành phần phụ
                    // đẩy xuống dưới nếp gấp như bản cũ (minLines cứng = 4).
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.sizeOf(context).height * 0.22,
                      ),
                      child: TextField(
                        controller: _controller,
                        autofocus: !widget.isEdit,
                        maxLines: null,
                        maxLength: 5000,
                        onChanged: (_) => setState(() {}),
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(fontSize: 18, height: 1.45),
                        decoration: InputDecoration(
                          hintText: l.composerContentHint,
                          hintStyle: const TextStyle(
                            fontSize: 18,
                            color: HD.inkMuted,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          counterText: '',
                        ),
                      ),
                    ),
                    if (_images.isNotEmpty) _imagePreviewGrid(),
                  ],
                ),
              ),
            ),
            _attachBar(),
          ],
        ),
      ),
    );
  }

  /// Hàng "ai đang đăng" — avatar + tên. Bản cũ KHÔNG hề có: người dùng soạn
  /// bài mà không thấy mình đăng dưới danh nghĩa nào, trong khi app có 2 persona
  /// (khách thuê / chủ nhà) và bài sẽ hiện kèm tên ở feed.
  Widget _hangTacGia() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final ten = (user?.name ?? '').trim();
    return ComposerAuthorRow(
      ten: ten.isEmpty ? AppLocalizations.of(context).profPersonal : ten,
      avatarUrl: user?.avatarPath,
    );
  }

  /// Hàng chip thuộc tính bài (khối · vị trí) — thay cho khối `Wrap` 6 chip và
  /// ô nhập vị trí có viền của bản cũ. Hai thứ đó chiếm gần nửa màn TRƯỚC ô
  /// soạn thảo, đẩy nội dung — thứ người ta tới đây để viết — xuống dưới.
  /// Chip hiện GIÁ TRỊ ĐANG CHỌN, bấm mới mở danh sách đầy đủ.
  Widget _hangChip() {
    final l = AppLocalizations.of(context);
    final cat = _category == null ? null : communityCategoryOf(_category);
    final viTri = _locationController.text.trim();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(
            icon: cat?.icon ?? Icons.grid_view_rounded,
            nhan: cat?.label ?? l.composerSelectCategoryLabel,
            mau: cat?.color,
            chon: cat != null,
            // Khoá khi đăng từ trong khối / khi sửa bài → hiện nhưng không bấm.
            onTap: _categoryLocked ? null : _moChonKhoi,
            khoa: _categoryLocked,
          ),
          // Chế độ SỬA: server giữ nguyên địa danh nên không cho đổi — nhưng
          // vẫn PHẢI hiện (dạng khoá) khi bài có vị trí, nếu không người dùng
          // tưởng vị trí đã bị xoá mất.
          if (!widget.isEdit || viTri.isNotEmpty) ...[
            const SizedBox(width: HD.s8),
            _chip(
              icon: Icons.location_on_outlined,
              nhan: viTri.isEmpty ? l.composerLocationHint : viTri,
              chon: viTri.isNotEmpty,
              onTap: widget.isEdit ? null : _moNhapViTri,
              khoa: widget.isEdit,
            ),
          ],
        ],
      ),
    );
  }

  /// Chip pill kiểu FB: viền mảnh khi chưa chọn, nền nhạt màu khối khi đã chọn.
  Widget _chip({
    required IconData icon,
    required String nhan,
    required bool chon,
    VoidCallback? onTap,
    Color? mau,
    bool khoa = false,
  }) {
    final mauChinh = chon ? (mau ?? HD.accent) : HD.inkSoft;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HD.rPill),
      child: Container(
        // 40px chiều cao + padding → vùng chạm đạt chuẩn tối thiểu.
        // 44px = ngưỡng vùng chạm tối thiểu (Apple HIG). 40 là chưa đạt.
        constraints: const BoxConstraints(minHeight: 44, maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: HD.s12),
        decoration: BoxDecoration(
          color: chon ? mauChinh.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(HD.rPill),
          border: Border.all(
            color: chon ? mauChinh.withValues(alpha: 0.35) : HD.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: mauChinh),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                nhan,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // Chữ KHÔNG lấy màu khối: khối màu vàng (warning) trên nền
                // trắng chỉ đạt ~1.9:1, không đọc nổi. Màu chỉ ở icon + viền.
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: chon ? HD.ink : HD.inkSoft,
                ),
              ),
            ),
            if (onTap != null && !chon)
              const Padding(
                padding: EdgeInsets.only(left: HD.s4),
                child: Icon(Icons.expand_more, size: 18, color: HD.inkSoft),
              ),
            // Khoá mà trông y hệt chip bấm được thì người dùng tưởng app hỏng.
            if (khoa)
              const Padding(
                padding: EdgeInsets.only(left: HD.s4),
                child: Icon(Icons.lock_outline, size: 14, color: HD.inkMuted),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _moChonKhoi() async {
    final l = AppLocalizations.of(context);
    final chon = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HD.paperRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(HD.r12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(HD.s16),
              child: Text(
                l.composerSelectCategoryLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: HD.ink,
                ),
              ),
            ),
            // PHẢI cuộn được: 7 khối × 56px + tiêu đề ≈ 450px, trên máy thấp
            // hoặc khi xoay ngang là tràn (vạch đen-vàng) mà không kéo nổi.
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in kCommunityCategories)
                    ListTile(
                      leading: Icon(c.icon, color: c.color),
                      title: Text(
                        c.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: c.key == _category
                          ? const Icon(Icons.check, color: HD.accent)
                          : null,
                      onTap: () => Navigator.pop(ctx, c.key),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (chon != null && mounted) setState(() => _category = chon);
  }

  Future<void> _moNhapViTri() async {
    final l = AppLocalizations.of(context);
    final tam = TextEditingController(text: _locationController.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.composerLocationHint),
        content: TextField(
          controller: tam,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.composerSave),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() => _locationController.text = tam.text.trim());
    }
    tam.dispose();
  }

  Widget _imagePreviewGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: HD.s12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: _images.length,
      itemBuilder: (context, i) {
        final img = _images[i];
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(HD.r8),
              child: img.isExisting
                  ? CachedNetworkImage(imageUrl: img.url!, fit: BoxFit.cover)
                  : Image.memory(img.bytes!, fit: BoxFit.cover),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: () => setState(() => _images.removeAt(i)),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Thanh đáy dùng chung: thẻ đính kèm + NÚT ĐĂNG.
  /// Nút chuyển từ app bar xuống đây — web mobile thì ngón cái ở dưới, và đó
  /// cũng là bố cục composer của Facebook.
  Widget _attachBar() {
    final l = AppLocalizations.of(context);
    final hetCho = _images.length >= _maxImages;
    return ComposerActionBar(
      actions: [
        ComposerAction(
          icon: Icons.photo_library_outlined,
          mau: HD.positive,
          nhan: l.composerPhotos,
          phu: l.composerImagesCount(_images.length, _maxImages),
          onTap: hetCho ? null : _pickImages,
        ),
      ],
      nhanNutChinh: widget.isEdit ? l.composerSave : l.composerPost,
      onSubmit: _canSubmit ? _submit : null,
      dangGui: _submitting,
    );
  }
}
