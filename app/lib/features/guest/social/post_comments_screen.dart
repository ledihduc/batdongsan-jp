import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:house_booking/features/auth/guest_gate.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/widgets/content_actions_sheet.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/data/models/social_comment_model.dart';
import 'package:house_booking/data/models/social_post_model.dart';
import 'package:house_booking/data/services/social_api.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/social_feed_provider.dart';
import 'package:house_booking/features/guest/social/widgets/post_card.dart';

/// Màn bình luận kiểu Facebook: bài đăng ở đầu, cây bình luận lồng NHIỀU CẤP
/// (comment → reply → reply...), ô nhập ghim đáy. Trả lời 1 bình luận bằng nút
/// "Trả lời" → input hiển thị mục tiêu đang trả lời.
class PostCommentsScreen extends StatefulWidget {
  const PostCommentsScreen({super.key, required this.post});

  final SocialPost post;

  @override
  State<PostCommentsScreen> createState() => _PostCommentsScreenState();
}

class _PostCommentsScreenState extends State<PostCommentsScreen> {
  final _api = SocialApi();
  final _controller = TextEditingController();
  final _inputFocus = FocusNode();
  final List<SocialComment> _flat = [];

  bool _loading = true;
  bool _sending = false;
  String? _error;
  SocialComment? _replyTo;

  // Cấp thụt lề tối đa (sâu hơn giữ nguyên thụt như FB để không tràn màn hình).
  static const _maxIndent = 3;
  static const _indentStep = 28.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // Sau khi chặn tác giả một bình luận: tải lại để ẩn bình luận của họ.
  void _reloadAfterBlock() => _load();

  Future<void> _load() async {
    final l = AppLocalizations.of(context);
    try {
      final rows = await _api.fetchComments(widget.post.id, limit: 300);
      setState(() {
        _flat
          ..clear()
          ..addAll(rows);
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = l.postCmtErrorLoad;
        _loading = false;
      });
    }
  }

  void _startReply(SocialComment target) {
    setState(() => _replyTo = target);
    _inputFocus.requestFocus();
  }

  void _cancelReply() => setState(() => _replyTo = null);

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    if (!GuestGate.requireAuth(context, message: l.postCmtLoginRequired)) {
      return;
    }
    setState(() => _sending = true);
    final parentId = _replyTo?.id;
    try {
      final comment = await _api.addComment(
        widget.post.id,
        text,
        parentId: parentId,
      );
      _controller.clear();
      setState(() {
        _flat.add(comment);
        _sending = false;
        _replyTo = null;
      });
      if (mounted) {
        context.read<SocialFeedProvider>().bumpCommentCount(widget.post.id, 1);
      }
    } catch (_) {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.postCmtSendFailed)));
      }
    }
  }

  Future<void> _deleteComment(SocialComment c) async {
    final l = AppLocalizations.of(context);
    try {
      await _api.deleteComment(c.id);
      if (mounted) {
        context.read<SocialFeedProvider>().bumpCommentCount(widget.post.id, -1);
      }
      await _load(); // refetch — phản ánh tombstone / mất node chính xác
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.postCmtDeleteFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    return Scaffold(
      backgroundColor: HD.paperRaised,
      appBar: DsAppBar(title: l.postCmtTitle, background: HD.paperRaised),
      body: Column(
        children: [
          Expanded(child: _buildList(currentUserId)),
          _replyBanner(),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _buildList(int? currentUserId) {
    final l = AppLocalizations.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final tree = buildCommentTree(_flat);
    final rows = <Widget>[
      _postHeader(),
      const Divider(height: 1, color: HD.hairline),
    ];
    if (_error != null) {
      rows.add(
        Padding(
          padding: const EdgeInsets.all(HD.s16),
          child: Text(_error!, style: const TextStyle(color: HD.inkMuted)),
        ),
      );
    }
    if (tree.isEmpty && _error == null) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              l.postCmtEmpty,
              style: const TextStyle(color: HD.inkMuted),
            ),
          ),
        ),
      );
    }
    for (final node in tree) {
      _appendNode(rows, node, 0, currentUserId);
    }
    rows.add(const SizedBox(height: HD.s16));
    return ListView(padding: EdgeInsets.zero, children: rows);
  }

  /// Duyệt cây đệ quy → thêm từng bình luận với mức thụt lề theo độ sâu.
  void _appendNode(
    List<Widget> out,
    SocialCommentNode node,
    int depth,
    int? currentUserId,
  ) {
    out.add(_commentTile(node.comment, depth, currentUserId));
    for (final child in node.children) {
      _appendNode(out, child, depth + 1, currentUserId);
    }
  }

  Widget _postHeader() {
    final l = AppLocalizations.of(context);
    final p = widget.post;
    return Padding(
      padding: const EdgeInsets.all(HD.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(p.authorAvatar, 20),
              const SizedBox(width: HD.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: HD.ink,
                      ),
                    ),
                    Text(
                      socialTimeAgo(p.createdAt) +
                          (p.isEdited ? ' · ${l.postCmtEdited}' : ''),
                      style: const TextStyle(fontSize: 12, color: HD.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (p.content.isNotEmpty) ...[
            const SizedBox(height: HD.s12),
            Text(
              p.content,
              style: const TextStyle(fontSize: 15, height: 1.35, color: HD.ink),
            ),
          ],
          if (p.images.isNotEmpty) ...[
            const SizedBox(height: HD.s12),
            ClipRRect(
              borderRadius: BorderRadius.circular(HD.r8),
              child: CachedNetworkImage(
                imageUrl: p.images.first,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
            if (p.images.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l.postCmtMoreImages(p.images.length - 1),
                  style: const TextStyle(fontSize: 12, color: HD.inkMuted),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _commentTile(SocialComment c, int depth, int? currentUserId) {
    final l = AppLocalizations.of(context);
    final indent = (depth.clamp(0, _maxIndent)) * _indentStep;
    final canDelete =
        !c.isDeleted && currentUserId != null && c.userId == currentUserId;
    return Padding(
      padding: EdgeInsets.fromLTRB(HD.s16 + indent, HD.s8, HD.s8, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(c.isDeleted ? null : c.authorAvatar, 16),
          const SizedBox(width: HD.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: (c.isDeleted || canDelete)
                      ? null
                      : () => ContentActionsSheet.show(
                          context,
                          targetType: ContentTargetType.comment,
                          targetId: c.id,
                          authorId: c.userId,
                          onBlocked: _reloadAfterBlock,
                        ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HD.s12,
                      vertical: HD.s8,
                    ),
                    decoration: BoxDecoration(
                      color: HD.paperSunken,
                      borderRadius: BorderRadius.circular(HD.r12),
                    ),
                    child: c.isDeleted
                        ? Text(
                            l.postCmtDeleted,
                            style: const TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: HD.inkMuted,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.authorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: HD.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c.content,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: HD.ink,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                _commentActions(c, canDelete),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentActions(SocialComment c, bool canDelete) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: HD.s12, top: 3),
      child: Row(
        children: [
          Text(
            socialTimeAgo(c.createdAt),
            style: const TextStyle(fontSize: 11, color: HD.inkMuted),
          ),
          if (!c.isDeleted) ...[
            const SizedBox(width: HD.s16),
            GestureDetector(
              onTap: () => _startReply(c),
              child: Text(
                l.postCmtReply,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: HD.inkMuted,
                ),
              ),
            ),
          ],
          if (canDelete) ...[
            const SizedBox(width: HD.s16),
            GestureDetector(
              onTap: () => _deleteComment(c),
              child: Text(
                l.postCmtDelete,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: HD.inkMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _avatar(String? url, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: HD.accentTint,
      backgroundImage: (url != null && url.isNotEmpty)
          ? CachedNetworkImageProvider(url)
          : null,
      child: (url == null || url.isEmpty)
          ? Icon(Icons.person, size: radius, color: HD.accent)
          : null,
    );
  }

  Widget _replyBanner() {
    if (_replyTo == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return Container(
      color: HD.paperSunken,
      padding: const EdgeInsets.symmetric(horizontal: HD.s16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 16, color: HD.inkMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l.postCmtReplyingTo(_replyTo!.authorName),
              style: const TextStyle(fontSize: 12, color: HD.inkMuted),
            ),
          ),
          GestureDetector(
            onTap: _cancelReply,
            child: const Icon(Icons.close, size: 16, color: HD.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    final l = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HD.s12,
          vertical: HD.s8,
        ),
        decoration: const BoxDecoration(
          color: HD.paperRaised,
          border: Border(top: BorderSide(color: HD.hairline)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _inputFocus,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: _replyTo == null
                      ? l.postCmtHint
                      : l.postCmtReplyHint(_replyTo!.authorName),
                  counterText: '',
                  filled: true,
                  fillColor: HD.paperSunken,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: HD.s16,
                    vertical: HD.s8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(HD.rPill),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, color: HD.accent),
              onPressed: _sending ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}
