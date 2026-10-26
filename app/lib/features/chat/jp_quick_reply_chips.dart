/// JP chat quick-reply preset chips.
///
/// Shows 8 preset Japanese formal messages below the chat composer.
/// Mount in [ChatScreen] when `FeatureFlags.isJapan`.
///
/// Route: n/a (embedded widget in chat composer area).
/// Provider: none — receives [onSelect] callback.
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class JpQuickReplyChips extends StatelessWidget {
  const JpQuickReplyChips({super.key, required this.onSelect});

  /// Called when a preset is tapped. Parent inserts it into the compose field.
  final void Function(String preset) onSelect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final presets = _buildPresets(l);

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (ctx, idx) => _Chip(
          label: presets[idx],
          onTap: () => onSelect(presets[idx]),
        ),
      ),
    );
  }

  static List<String> _buildPresets(AppLocalizations l) => [
        l.jp_chat_greeting_formal,
        l.jp_chat_viewing_confirm,
        l.jp_chat_apology,
        l.jp_chat_available,
        l.jp_slot_confirmed,
        l.jp_viewing_status_confirmed,
        l.jp_submit,
        l.jp_reschedule,
      ];
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: HD.paperSunken,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: HD.hairline),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: HD.inkSoft,
          ),
        ),
      ),
    );
  }
}
