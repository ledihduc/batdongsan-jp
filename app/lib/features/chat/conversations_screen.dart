import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/widgets/empty_state.dart';
import 'package:house_booking/data/models/chat_message_model.dart';
import 'package:house_booking/features/chat/chat_screen.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/chat_provider.dart';
import 'package:house_booking/core/widgets/ds.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user != null) {
        Provider.of<ChatProvider>(context, listen: false)
            .fetchConversations(user.id!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cp = Provider.of<ChatProvider>(context);
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;

    return Scaffold(
      // TODO(phase-05a): Widget-title AppBar not migrated (DsAppBar.title is String-only; title is a Row with online badge)
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Tin nhắn',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cp.isConnected
                    ? HD.positive.withOpacity(0.15)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: cp.isConnected
                          ? HD.positive
                          : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    cp.isConnected ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 10,
                      color: cp.isConnected
                          ? HD.positive
                          : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => user == null
            ? Future.value()
            : cp.fetchConversations(user.id!),
        child: cp.conversations.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'Chưa có cuộc trò chuyện',
                    subtitle:
                        'Vào chi tiết phòng và nhấn "Nhắn tin với chủ nhà" để bắt đầu.',
                  ),
                ],
              )
            : ListView.separated(
                itemCount: cp.conversations.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 72),
                itemBuilder: (_, i) => _tile(cp.conversations[i]),
              ),
      ),
    );
  }

  Widget _tile(ConversationModel c) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              peerId: c.peerId,
              peerName: c.peerName,
              peerAvatar: c.peerAvatar,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: HD.accentTint,
                  backgroundImage: c.peerAvatar.isNotEmpty
                      ? CachedNetworkImageProvider(c.peerAvatar)
                      : null,
                  child: c.peerAvatar.isEmpty
                      ? const Icon(Icons.person, size: 24)
                      : null,
                ),
                if (c.online)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: HD.positive,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Tên + last message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    c.peerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(
                      fontWeight:
                          c.unread > 0 ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14,
                      color: HD.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.lastBody,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(
                      color: c.unread > 0
                          ? HD.ink
                          : HD.inkMuted,
                      fontWeight:
                          c.unread > 0 ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Time + badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _relative(c.lastAt),
                  style: const TextStyle(
                      fontSize: 11, color: HD.inkMuted),
                ),
                const SizedBox(height: 6),
                if (c.unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 16),
                    decoration: BoxDecoration(
                      color: HD.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      c.unread > 99 ? '99+' : '${c.unread}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _relative(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes}p';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${t.day}/${t.month}';
  }
}
