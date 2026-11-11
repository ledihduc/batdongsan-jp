/// Chat AI tìm nhà cho cả bản jp và vn (plan 20261027-1102 Phase 10, D19). Route: /ai-chat.
/// Provider: none — [AiChatController] riêng của màn. API: POST /api/ai/chat.
///
/// Tách hẳn chat người–người (`ChatProvider`/`ChatScreen`). Gửi `lang` = ngôn ngữ giao diện.
/// Lịch sử chỉ trong bộ nhớ màn, không lưu máy.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:house_booking/core/config/feature_flags.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/repositories/ai/api_ai_chat_repository.dart';
import 'package:house_booking/domain/repositories/ai/i_ai_chat_repository.dart';
import 'package:house_booking/features/ai_chat/ai_chat_controller.dart';
import 'package:house_booking/features/ai_chat/widgets/ai_chat_bubble_view.dart';
import 'package:house_booking/features/ai_chat/widgets/ai_chat_empty_state.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key, this.repository, this.onOpenListing, this.japan});

  final IAiChatRepository? repository;
  final void Function(int listingId)? onOpenListing;

  /// Thị trường của gợi ý; `null` ⇒ `FeatureFlags.isJapan` (tham số để test cả 2 thị trường).
  final bool? japan;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  AiChatController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= AiChatController(
      widget.repository ?? const ApiAiChatRepository(),
      lang: Localizations.localeOf(context).languageCode,
    )..addListener(_scrollToEnd);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _send([String? text]) {
    final q = (text ?? _input.text).trim();
    if (q.isEmpty) return;
    _input.clear();
    _controller!.send(q);
  }

  void _open(int id) {
    final cb = widget.onOpenListing;
    cb != null ? cb(id) : context.push('/house/$id');
  }

  String _errorText(AppLocalizations l, AiChatErrorKind? kind) => switch (kind) {
        AiChatErrorKind.timeout => l.aiChatErrorTimeout,
        AiChatErrorKind.rateLimited => l.aiChatErrorRateLimited,
        AiChatErrorKind.server => l.aiChatErrorServer,
        _ => l.aiChatErrorNetwork,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = _controller!;
    return Scaffold(
      appBar: AppBar(title: Text(l.aiChatTitle)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final loading = c.status == AiChatStatus.loading;
            return Column(
              children: [
                Expanded(
                  child: c.bubbles.isEmpty && !loading
                      ? AiChatEmptyState(japan: widget.japan ?? FeatureFlags.isJapan, onPick: _send)
                      : ListView(
                          controller: _scroll,
                          padding: const EdgeInsets.all(HD.s16),
                          children: [
                            for (final b in c.bubbles) AiChatBubbleView(bubble: b, onOpenListing: _open),
                            if (loading) AiChatLoadingBubble(label: l.aiChatThinking),
                          ],
                        ),
                ),
                if (c.status == AiChatStatus.error) _ErrorBar(text: _errorText(l, c.errorKind), retry: l.aiChatRetry, onRetry: c.retry),
                _InputBar(controller: _input, hint: l.aiChatInputHint, sendLabel: l.aiChatSend, enabled: !loading, onSend: _send),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  const _ErrorBar({required this.text, required this.retry, required this.onRetry});

  final String text;
  final String retry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        color: HD.negativeTint,
        padding: const EdgeInsets.symmetric(horizontal: HD.s16, vertical: HD.s8),
        child: Row(children: [
          const Icon(Icons.error_outline, color: HD.negative),
          const SizedBox(width: HD.s8),
          Expanded(child: Text(text, style: const TextStyle(color: HD.negative))),
          DsButton(label: retry, variant: DsButtonVariant.ghost, size: DsButtonSize.compact, onPressed: onRetry),
        ]),
      );
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.hint, required this.sendLabel,
      required this.enabled, required this.onSend});

  final TextEditingController controller;
  final String hint;
  final String sendLabel;
  final bool enabled;
  final ValueChanged<String?> onSend;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(HD.s12, HD.s8, HD.s12, HD.s12),
        child: Row(children: [
          Expanded(
            child: DsTextField(
              controller: controller,
              hint: hint,
              enabled: enabled,
              maxLines: 4,
              minLines: 1,
              maxLength: 2000,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(null),
            ),
          ),
          const SizedBox(width: HD.s8),
          IconButton(
            key: const Key('ai-chat-send'),
            tooltip: sendLabel,
            onPressed: enabled ? () => onSend(null) : null,
            icon: const Icon(Icons.send_rounded, color: HD.accent),
          ),
        ]),
      );
}
