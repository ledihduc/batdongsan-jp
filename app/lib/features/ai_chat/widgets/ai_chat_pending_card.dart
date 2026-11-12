/// Thẻ xác nhận action ghi trong chat AI (Phase 11, F-5): cùng tóm tắt + cùng repository với màn link.
///
/// Không tự xác nhận; キャンセル chỉ ẩn thẻ, không gọi mạng (pending tự hết hạn phía backend).
/// Giữ sống khi cuộn khỏi màn (keep-alive) ⇒ thẻ đã huỷ/đã xong không hiện lại nút 確認する (QA M3).
/// Lỗi mạng ⇒ hiện lỗi và giữ nút để bấm lại (QA M2).
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/ai/ai_pending_action_models.dart';
import 'package:house_booking/data/repositories/ai/api_ai_action_repository.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/domain/repositories/ai/i_ai_action_repository.dart';
import 'package:house_booking/features/ai_chat/ai_action_confirm_controller.dart';
import 'package:house_booking/features/ai_chat/widgets/ai_action_messages.dart';
import 'package:house_booking/features/ai_chat/widgets/ai_action_summary_card.dart';
import 'package:house_booking/l10n/app_localizations.dart';

enum _CardState { idle, submitting, done, error, needLogin, hidden }

class AiChatPendingCard extends StatefulWidget {
  const AiChatPendingCard({super.key, required this.pending, this.repository});

  final AiPendingAction pending;
  final IAiActionRepository? repository;

  @override
  State<AiChatPendingCard> createState() => _AiChatPendingCardState();
}

class _AiChatPendingCardState extends State<AiChatPendingCard> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  _CardState _state = _CardState.idle;
  AiConfirmErrorKind? _kind;
  String _action = '';

  Future<void> _confirm() async {
    final retryable = _state == _CardState.error && _kind == AiConfirmErrorKind.network;
    if (_state != _CardState.idle && !retryable) return; // khoá ngay ⇒ bấm 2 lần chỉ gửi 1 lần
    setState(() => _state = _CardState.submitting);
    final repo = widget.repository ?? const ApiAiActionRepository();
    try {
      final r = await repo.confirm(widget.pending.token);
      _action = r.action;
      _state = _CardState.done;
    } catch (e) {
      if (e is ApiException && e.statusCode == 401) {
        _state = _CardState.needLogin;
      } else {
        _kind = AiActionConfirmController.kindOf(e);
        _state = _CardState.error;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_state == _CardState.hidden) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final p = widget.pending;
    final busy = _state == _CardState.submitting;
    final canRetry = _state == _CardState.error && _kind == AiConfirmErrorKind.network;
    return Padding(
      padding: const EdgeInsets.only(top: HD.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AiActionSummaryCard(title: p.title, params: p.params, expiresAt: p.expiresAt),
          const SizedBox(height: HD.s8),
          if (_state == _CardState.error) ...[
            Text(aiConfirmErrorText(l, _kind), style: const TextStyle(color: HD.negative)),
            const SizedBox(height: HD.s8),
          ],
          if (_state == _CardState.idle || busy || canRetry) ...[
            Text(l.aiConfirmWarning, style: const TextStyle(color: HD.negative)),
            const SizedBox(height: HD.s8),
            Wrap(spacing: HD.s8, children: [
              DsButton(label: l.aiConfirmButton, size: DsButtonSize.compact, isLoading: busy, onPressed: busy ? null : _confirm),
              DsButton(
                label: l.aiConfirmCancel,
                size: DsButtonSize.compact,
                variant: DsButtonVariant.ghost,
                onPressed: busy ? null : () => setState(() => _state = _CardState.hidden),
              ),
            ]),
          ],
          if (_state == _CardState.done)
            Text(aiConfirmDoneText(l, _action.isEmpty ? p.action : _action), style: const TextStyle(color: HD.positive)),
          if (_state == _CardState.needLogin) Text(l.aiConfirmLoginRequired, style: const TextStyle(color: HD.ink)),
        ],
      ),
    );
  }
}
