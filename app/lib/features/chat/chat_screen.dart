import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/data/models/chat_message_model.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/chat_provider.dart';
import 'package:house_booking/core/config/feature_flags.dart';
import 'package:house_booking/core/widgets/ds.dart';
// JP market (Phase 01): preset reply chips for chintai chat flows.
import 'package:house_booking/features/chat/jp_quick_reply_chips.dart';

class ChatScreen extends StatefulWidget {
  final int peerId;
  final String peerName;
  final String peerAvatar;
  final int? houseId; // optional context khi mở từ HouseDetail
  // Đính kèm TIN đăng dạng THẺ (ảnh nhỏ + tiêu đề + giá) ghim đầu chat khi mở
  // từ trang tin — thay cho việc dán link thô.
  final String? houseTitle;
  final String? houseImage;
  final double? housePrice;

  const ChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.peerAvatar = '',
    this.houseId,
    this.houseTitle,
    this.houseImage,
    this.housePrice,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cp = Provider.of<ChatProvider>(context, listen: false);
      await cp.loadHistory(widget.peerId);
      await cp.markRead(widget.peerId);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final body = _inputCtrl.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    final cp = Provider.of<ChatProvider>(context, listen: false);
    try {
      await cp.sendMessage(
        peerId: widget.peerId,
        body: body,
        houseId: widget.houseId,
      );
      _inputCtrl.clear();
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メッセージの送信に失敗しました')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Thẻ TIN đăng ghim đầu chat (ảnh nhỏ + tiêu đề + giá) — thay cho dán link.
  /// Tap → mở trang chi tiết tin.
  Widget _listingCard(BuildContext context) {
    return InkWell(
      onTap: widget.houseId == null
          ? null
          : () => context.push('/house/${widget.houseId}'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: HD.paperRaised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: HD.hairline),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: (widget.houseImage != null &&
                      widget.houseImage!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: widget.houseImage!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          Container(color: HD.paperSunken))
                  : Container(
                      color: HD.paperSunken,
                      child: const Icon(Icons.home_work_outlined,
                          color: HD.inkMuted)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('この物件について相談中',
                      style: HD.caption(color: HD.inkMuted)),
                  Text(widget.houseTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: HD.ink)),
                  if (widget.housePrice != null)
                    Text(PriceFormat.compact(widget.housePrice!),
                        style: const TextStyle(
                            color: HD.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                ]),
          ),
          const Icon(Icons.chevron_right, color: HD.inkMuted),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cp = Provider.of<ChatProvider>(context);
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final myId = user?.id ?? 0;
    final messages = cp.messagesWith(widget.peerId);

    // auto-scroll khi có message mới
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      // TODO(phase-05a): Widget-title AppBar not migrated (DsAppBar.title is String-only; title is a Row with avatar + status)
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: HD.accentTint,
              backgroundImage: widget.peerAvatar.isNotEmpty
                  ? CachedNetworkImageProvider(widget.peerAvatar)
                  : null,
              child: widget.peerAvatar.isEmpty
                  ? const Icon(Icons.person, size: 18)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.peerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    cp.isConnected ? 'オンライン' : '接続中...',
                    style: TextStyle(
                      fontSize: 11,
                      color: cp.isConnected
                          ? HD.positive
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (widget.houseTitle != null && widget.houseTitle!.isNotEmpty)
            _listingCard(context),
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'まだメッセージがありません — 最初のメッセージを送りましょう！',
                        style: TextStyle(color: HD.inkMuted),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final m = messages[i];
                      final isMe = m.senderId == myId;
                      final showTimeGap = i == 0 ||
                          messages[i].createdAt
                                  .difference(messages[i - 1].createdAt)
                                  .inMinutes >
                              10;
                      return Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (showTimeGap) _timeChip(m.createdAt),
                          _bubble(m, isMe),
                        ],
                      );
                    },
                  ),
          ),
          // JP market (Phase 01): quick-reply preset chips for chintai chat.
          // Inserts selected preset text into the compose field.
          if (FeatureFlags.isJapan)
            JpQuickReplyChips(
              onSelect: (text) {
                _inputCtrl.text = text;
                _inputCtrl.selection = TextSelection.collapsed(
                  offset: text.length,
                );
              },
            ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessageModel m, bool isMe) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      decoration: BoxDecoration(
        color: isMe ? HD.accent : HD.accentSoft,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(isMe ? 14 : 2),
          bottomRight: Radius.circular(isMe ? 2 : 14),
        ),
      ),
      child: Text(
        m.body,
        style: TextStyle(
          color: isMe ? Colors.white : HD.ink,
          fontSize: 13.5,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _timeChip(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final today = DateTime.now();
    final isToday =
        t.year == today.year && t.month == today.month && t.day == today.day;
    final label = isToday ? '$h:$m' : '${t.day}/${t.month} $h:$m';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, color: HD.inkMuted),
        ),
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: HD.accentTint)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'メッセージを入力...',
                  filled: true,
                  fillColor: HD.paperSunken,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Material(
              color: Theme.of(context).colorScheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sending ? null : _send,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send,
                          color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
