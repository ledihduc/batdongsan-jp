/// Một bong bóng chat AI (câu hỏi bên phải, trả lời bên trái + thẻ tin) và bong bóng đang chờ (Phase 10).
/// Phase 11: trả lời kèm thẻ xác nhận action ghi + thẻ mời đăng nhập.
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/domain/repositories/ai/i_ai_action_repository.dart';
import 'package:house_booking/features/ai_chat/ai_chat_controller.dart';
import 'package:house_booking/features/ai_chat/widgets/ai_chat_login_prompt.dart';
import 'package:house_booking/features/ai_chat/widgets/ai_chat_pending_card.dart';
import 'package:house_booking/features/ai_chat/widgets/ai_chat_listing_card.dart';

class AiChatBubbleView extends StatelessWidget {
  const AiChatBubbleView({super.key, required this.bubble, required this.onOpenListing, this.actionRepository});

  final AiChatBubble bubble;
  final void Function(int listingId) onOpenListing;
  final IAiActionRepository? actionRepository;

  @override
  Widget build(BuildContext context) {
    final mine = bubble.role == 'user';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: HD.s4),
          padding: const EdgeInsets.all(HD.s12),
          decoration: BoxDecoration(
            color: mine ? HD.accentTint : HD.paperRaised,
            border: Border.all(color: HD.hairline),
            borderRadius: BorderRadius.circular(HD.r12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(bubble.text, style: const TextStyle(color: HD.ink)),
              for (final card in bubble.listings)
                AiChatListingCard(card: card, onTap: () => onOpenListing(card.listingId)),
              for (final p in bubble.pendingActions)
                AiChatPendingCard(key: ValueKey(p.token), pending: p, repository: actionRepository),
              if (bubble.loginRequired) const AiChatLoginPrompt(),
            ],
          ),
        ),
      ),
    );
  }
}

class AiChatLoadingBubble extends StatelessWidget {
  const AiChatLoadingBubble({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      key: const Key('ai-chat-loading'),
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: HD.s8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: HD.s16, height: HD.s16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: HD.s8),
            Text(label, style: const TextStyle(color: HD.inkMuted)),
          ],
        ),
      ),
    );
  }
}
