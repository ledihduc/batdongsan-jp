import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/widgets/composer_kit.dart';
import 'package:house_booking/data/services/reel_api.dart';

/// Tạo reel: chọn video từ thư viện → upload → chú thích + khối → đăng.
///
/// Ảnh bìa: MVP chưa trích khung hình (cần ffmpeg/native) → để trống, FE hiện
/// nền tối + nút play; có thể bổ sung thumbnail sau.
class ReelComposerScreen extends StatefulWidget {
  const ReelComposerScreen({
    super.key,
    this.category,
    this.api = const ReelApi(),
  });

  /// Cho phép bơm ReelApi giả trong test. Mặc định là bản thật nên mã
  /// sản phẩm không đổi hành vi — chỉ mở một khe để test không cần mạng.
  final ReelApi api;

  /// Khối mặc định (theo feed mở composer). null → 'all'.
  final String? category;

  @override
  State<ReelComposerScreen> createState() => _ReelComposerScreenState();
}

class _ReelComposerScreenState extends State<ReelComposerScreen> {
  static const _cats = <String>[
    'all',
    'lease',
    'industrial',
    'design',
    'build',
    'interior',
  ];

  final _caption = TextEditingController();
  late String _cat = _cats.contains(widget.category) ? widget.category! : 'all';

  String? _uploadId;
  String? _fileName;
  bool _uploading = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final l = AppLocalizations.of(context);
    setState(() => _error = null);
    try {
      final file = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 90),
      );
      if (file == null) return;
      setState(() {
        _uploading = true;
        _fileName = file.name;
      });
      final bytes = await file.readAsBytes();
      final id = await widget.api.uploadReelVideo(bytes, file.name);
      if (!mounted) return;
      setState(() {
        _uploadId = id;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = '$e'.contains('413')
            ? l.reelCompErrVideoTooLarge
            : l.reelCompErrUploadFailed;
      });
    }
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (_uploadId == null) {
      setState(() => _error = l.reelCompErrNoVideo);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.api.create(
        uploadId: _uploadId!,
        caption: _caption.text.trim(),
        category: _cat,
      );
      if (!mounted) return;
      // Duyệt-TRƯỚC: reel vào hàng đợi, KHÔNG hiện ngay → báo rõ cho user,
      // tránh hiểu nhầm "đăng xong mà không thấy đâu".
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.hourglass_top, color: HD.accent, size: 40),
          title: Text(l.reelCompSentTitle),
          content: Text(l.reelCompSentBody, textAlign: TextAlign.center),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: HD.accent),
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.reelCompGotIt),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = '$e'.contains('429')
              ? l.reelCompErrRateLimit
              : l.reelCompErrSubmitFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ready = _uploadId != null && !_uploading;
    String catLabel(String key) => switch (key) {
      'lease' => l.reelCompCatLease,
      'industrial' => l.reelCompCatIndustrial,
      'design' => l.reelCompCatDesign,
      'build' => l.reelCompCatBuild,
      'interior' => l.reelCompCatInterior,
      _ => l.reelCompCatAll,
    };
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: l.reelCompTitle,
        // Đóng bằng ✕ như FB — composer là việc "làm rồi thoát".
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      // Nút đăng chuyển từ app bar xuống thanh đáy dùng chung — đồng bộ với 2
      // màn soạn kia và thuận ngón cái hơn trên web mobile.
      bottomNavigationBar: ComposerActionBar(
        actions: const [],
        nhanNutChinh: l.reelCompPost,
        onSubmit: ready ? _submit : null,
        dangGui: _submitting,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Ô chọn video
          InkWell(
            onTap: _uploading ? null : _pickVideo,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: HD.paperRaised,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _uploadId != null ? HD.positive : HD.hairline,
                ),
              ),
              alignment: Alignment.center,
              child: _uploading
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 10),
                        Text(
                          l.reelCompUploading,
                          style: const TextStyle(color: HD.inkSoft),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _uploadId != null
                              ? Icons.check_circle_outline
                              : Icons.video_library_outlined,
                          size: 44,
                          color: _uploadId != null ? HD.positive : HD.accent,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _uploadId != null
                              ? l.reelCompUploaded(_fileName ?? 'video')
                              : l.reelCompPickVideo,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: HD.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.reelCompLimits,
                          style: const TextStyle(
                            color: HD.inkMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _caption,
            maxLines: 3,
            maxLength: 300,
            decoration: InputDecoration(
              labelText: l.reelCompCaption,
              hintText: l.reelCompCaptionHint,
              filled: true,
              fillColor: HD.paperRaised,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.reelCompShowIn,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: HD.ink,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in _cats)
                ChoiceChip(
                  selected: _cat == key,
                  label: Text(catLabel(key)),
                  onSelected: (_) => setState(() => _cat = key),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: HD.negative)),
          ],
        ],
      ),
    );
  }
}
