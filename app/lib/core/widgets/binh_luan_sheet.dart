import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/auth/guest_gate.dart';
import 'package:house_booking/l10n/app_localizations.dart';

String _abs(String url) =>
    url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';

typedef NapBinhLuan = Future<List<Map<String, dynamic>>> Function();
typedef GuiBinhLuan = Future<void> Function(String noiDung, {int? parentId});
typedef XoaBinhLuan = Future<void> Function(int commentId);

/// Bình luận — bottom-sheet kéo được, hỗ trợ trả lời 1 cấp.
///
/// Backend trả danh sách PHẲNG kèm `parent_id`; ở đây dựng lại thành gốc +
/// replies. Giữ 1 cấp hiển thị (reply của reply vẫn gắn dưới gốc) cho dễ đọc
/// trên màn hình hẹp.
///
/// Nhận BA HÀM thay vì một api cụ thể: reel và tin nhà dùng hai endpoint khác
/// nhau nhưng cùng một cây bình luận (`social_comments`), nên nhân đôi 375
/// dòng giao diện chỉ để đổi đường dẫn là lãng phí — và hai bản sao sẽ lệch
/// nhau ở lần sửa thứ nhất.
class BinhLuanSheet extends StatefulWidget {
  const BinhLuanSheet({
    super.key,
    required this.nap,
    required this.gui,
    required this.xoa,
    this.onCountChanged,
  });

  final NapBinhLuan nap;
  final GuiBinhLuan gui;
  final XoaBinhLuan xoa;
  final ValueChanged<int>? onCountChanged;

  @override
  State<BinhLuanSheet> createState() => _BinhLuanSheetState();
}

class _BinhLuanSheetState extends State<BinhLuanSheet> {
  final _input = TextEditingController();

  List<Map<String, dynamic>> _all = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  // Đang trả lời bình luận nào (null = bình luận gốc).
  int? _replyTo;
  String _replyToName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cs = await widget.nap();
      if (!mounted) return;
      setState(() {
        _all = cs;
        _loading = false;
      });
      widget.onCountChanged?.call(cs.length);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = AppLocalizations.of(context).reelCmtLoadFailed;
        });
      }
    }
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    if (!GuestGate.requireAuth(context, message: l.reelCmtLoginToComment)) {
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.gui(text, parentId: _replyTo);
      _input.clear();
      _replyTo = null;
      _replyToName = '';
      await _load();
    } catch (e) {
      if (mounted) {
        AppFeedback.error(
          context,
          '$e'.contains('429') ? l.reelCmtRateLimited : l.reelCmtSendFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.reelCmtDeleteTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: HD.negative),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.reelCmtDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.xoa((c['id'] as num).toInt());
      await _load();
    } catch (_) {
      if (mounted) AppFeedback.error(context, l.reelCmtDeleteFailed);
    }
  }

  /// Gốc (parent_id == null) theo thứ tự cũ→mới, mỗi gốc kèm replies của nó.
  List<(Map<String, dynamic>, List<Map<String, dynamic>>)> get _threads {
    final roots = _all.where((c) => c['parent_id'] == null).toList();
    return [
      for (final r in roots)
        (
          r,
          _all.where((c) => c['parent_id'] == r['id']).toList(growable: false),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            // Tay nắm kéo
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: HD.hairlineStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              l.reelCmtCountLabel(_all.length),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: HD.ink,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: HD.hairline),

            Expanded(child: _body()),

            if (_replyTo != null)
              Container(
                width: double.infinity,
                color: HD.accentTint,
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.reelCmtReplyingTo(_replyToName),
                        style: const TextStyle(fontSize: 12, color: HD.ink),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() {
                        _replyTo = null;
                        _replyToName = '';
                      }),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 18, color: HD.inkSoft),
                      ),
                    ),
                  ],
                ),
              ),

            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: l.reelCmtInputHint,
                          counterText: '',
                          isDense: true,
                          filled: true,
                          fillColor: HD.paper,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send, color: HD.accent),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: HD.inkMuted)),
      );
    }
    if (_all.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            AppLocalizations.of(context).reelCmtEmpty,
            textAlign: TextAlign.center,
            style: const TextStyle(color: HD.inkMuted),
          ),
        ),
      );
    }
    final threads = _threads;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: threads.length,
      itemBuilder: (_, i) {
        final (root, replies) = threads[i];
        return Column(
          children: [
            _tile(root),
            for (final r in replies) _tile(r, indent: true),
          ],
        );
      },
    );
  }

  Widget _tile(Map<String, dynamic> c, {bool indent = false}) {
    final l = AppLocalizations.of(context);
    final deleted = (c['is_deleted'] as bool?) ?? false;
    final name = (c['author_name'] as String?) ?? l.reelCmtDefaultUser;
    final avatar = c['author_avatar'] as String?;
    return Padding(
      padding: EdgeInsets.fromLTRB(indent ? 48 : 16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: indent ? 13 : 16,
            backgroundColor: HD.accentTint,
            backgroundImage: (avatar != null && avatar.isNotEmpty)
                ? CachedNetworkImageProvider(_abs(avatar))
                : null,
            child: (avatar != null && avatar.isNotEmpty)
                ? null
                : Icon(Icons.person, size: indent ? 14 : 18, color: HD.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: HD.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  deleted
                      ? l.reelCmtDeletedComment
                      : ((c['content'] as String?) ?? ''),
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: deleted ? HD.inkMuted : HD.inkSoft,
                    fontStyle: deleted ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                if (!deleted) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Chỉ cho trả lời ở cấp gốc — tránh cây quá sâu trên màn hẹp.
                      if (!indent)
                        _link(l.reelCmtReply, () {
                          setState(() {
                            _replyTo = (c['id'] as num).toInt();
                            _replyToName = name;
                          });
                        }),
                      if (!indent) const SizedBox(width: 16),
                      _link(l.reelCmtDelete, () => _delete(c)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _link(String label, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        color: HD.inkMuted,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
