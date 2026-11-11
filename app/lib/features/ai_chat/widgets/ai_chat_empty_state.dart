/// Trạng thái rỗng màn chat AI: tiêu đề + 3 câu hỏi gợi ý theo thị trường (Phase 10, F-4b).
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class AiChatEmptyState extends StatelessWidget {
  const AiChatEmptyState({super.key, required this.japan, required this.onPick});

  final bool japan;
  final ValueChanged<String> onPick;

  static List<String> suggestions(AppLocalizations l, {required bool japan}) => japan
      ? [l.aiChatSuggestionJp1, l.aiChatSuggestionJp2, l.aiChatSuggestionJp3]
      : [l.aiChatSuggestionVn1, l.aiChatSuggestionVn2, l.aiChatSuggestionVn3];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(HD.s20),
      children: [
        const Icon(Icons.smart_toy_outlined, size: HD.s48, color: HD.accent),
        const SizedBox(height: HD.s12),
        Text(l.aiChatEmptyTitle, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: HD.ink)),
        const SizedBox(height: HD.s20),
        // Thẻ bấm được thay vì DsChoiceChip: chip là một hàng cao cố định, câu gợi ý dài
        // (nhất là bản en) tràn ngang trên màn hẹp; thẻ cho chữ xuống dòng.
        for (final s in suggestions(l, japan: japan))
          Padding(
            padding: const EdgeInsets.only(bottom: HD.s8),
            child: DsCard(
              onTap: () => onPick(s),
              padding: const EdgeInsets.symmetric(horizontal: HD.s16, vertical: HD.s12),
              child: Row(children: [
                const Icon(Icons.chat_bubble_outline, size: HD.s16, color: HD.accent),
                const SizedBox(width: HD.s8),
                Expanded(child: Text(s, style: const TextStyle(color: HD.ink))),
              ]),
            ),
          ),
      ],
    );
  }
}
