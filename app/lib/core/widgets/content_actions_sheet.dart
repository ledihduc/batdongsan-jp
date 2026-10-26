import 'package:flutter/material.dart';

import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/report_api.dart';
import 'package:house_booking/data/services/moderation_api.dart';
import 'package:house_booking/features/auth/guest_gate.dart';

/// Loại nội dung mà menu ⋯ đang thao tác.
enum ContentTargetType { house, post, comment }

/// Bottom-sheet cho nút ⋯ trên mỗi bài đăng — cùng bố cục người dùng đã quen
/// ở Facebook: lưu lại, báo cáo vi phạm, báo sai thông tin.
///
/// Vì sao tách "báo cáo vi phạm" và "báo sai thông tin" thành HAI mục:
/// chúng đi hai đường khác hẳn nhau. Báo sai gửi thẳng cho người đăng để họ
/// sửa (giá cũ, đã cho thuê…) — chuyện thường ngày, không ai bị phạt. Báo cáo
/// vi phạm vào hàng đợi quản trị. Gộp một mục sẽ khiến người dùng ngại bấm vì
/// sợ "tố cáo" oan người bán tử tế.
class ContentActionsSheet extends StatelessWidget {
  const ContentActionsSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    this.isSaved = false,
    this.onToggleSave,
    this.isOwner = false,
    this.onEdit,
    this.onDelete,
    this.authorId,
    this.onBlocked,
  });

  final ContentTargetType targetType;
  final int targetId;

  /// Id tác giả nội dung — để hiện "Chặn người này". Bỏ trống thì ẩn nút chặn.
  final int? authorId;

  /// Gọi sau khi chặn thành công, để màn gọi tự ẩn nội dung khỏi danh sách.
  final VoidCallback? onBlocked;

  /// Trạng thái đã lưu — để đổi nhãn giữa "Lưu" và "Bỏ lưu".
  final bool isSaved;

  /// Bỏ trống nếu màn hình chưa hỗ trợ lưu → mục Lưu sẽ bị ẩn.
  final Future<void> Function()? onToggleSave;

  /// Nội dung của chính mình → hiện Sửa/Xoá thay cho Báo cáo.
  final bool isOwner;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  static Future<void> show(
    BuildContext context, {
    required ContentTargetType targetType,
    required int targetId,
    bool isSaved = false,
    Future<void> Function()? onToggleSave,
    bool isOwner = false,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    int? authorId,
    VoidCallback? onBlocked,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: HD.paperRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ContentActionsSheet(
        targetType: targetType,
        targetId: targetId,
        isSaved: isSaved,
        onToggleSave: onToggleSave,
        isOwner: isOwner,
        onEdit: onEdit,
        onDelete: onDelete,
        authorId: authorId,
        onBlocked: onBlocked,
      ),
    );
  }

  String _localizedNoun(AppLocalizations l) => switch (targetType) {
        ContentTargetType.house => l.actionsNounHouse,
        ContentTargetType.comment => l.actionsNounComment,
        ContentTargetType.post => l.actionsNounPost,
      };

  String _reportTargetString() => switch (targetType) {
        ContentTargetType.house => 'house',
        ContentTargetType.comment => 'comment',
        ContentTargetType.post => 'post',
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final noun = _localizedNoun(l);
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
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

        if (onToggleSave != null)
          _tile(
            icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
            label: isSaved ? l.actionsUnsave : l.actionsSaveNoun(noun),
            sub: isSaved ? null : l.actionsSaveSub,
            onTap: () async {
              if (!GuestGate.requireAuth(context,
                  message: l.actionsLoginToSave(noun))) {
                return;
              }
              Navigator.pop(context);
              await onToggleSave!.call();
            },
          ),

        if (isOwner) ...[
          const Divider(height: 1, color: HD.hairline),
          if (onEdit != null)
            _tile(
              icon: Icons.edit_outlined,
              label: l.actionsEdit,
              onTap: () {
                Navigator.pop(context);
                onEdit!.call();
              },
            ),
          if (onDelete != null)
            _tile(
              icon: Icons.delete_outline,
              label: l.actionsDelete,
              color: HD.negative,
              onTap: () {
                Navigator.pop(context);
                onDelete!.call();
              },
            ),
        ] else ...[
          const Divider(height: 1, color: HD.hairline),
          _tile(
            icon: Icons.error_outline,
            label: l.actionsReportWrongInfo,
            sub: l.actionsReportWrongInfoSub,
            onTap: () => _reportFlow(context, wrongInfo: true),
          ),
          _tile(
            icon: Icons.flag_outlined,
            label: l.actionsReportNoun(noun),
            sub: l.actionsReportViolationSub,
            onTap: () => _reportFlow(context, wrongInfo: false),
          ),
          if (authorId != null)
            _tile(
              icon: Icons.block,
              label: l.blockUser,
              sub: l.blockUserSub,
              color: HD.negative,
              onTap: () => _blockFlow(context),
            ),
        ],
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    String? sub,
    Color? color,
    required VoidCallback onTap,
  }) =>
      ListTile(
        leading: Icon(icon, color: color ?? HD.ink),
        title: Text(label,
            style: TextStyle(
                color: color ?? HD.ink,
                fontWeight: FontWeight.w600,
                fontSize: 15)),
        subtitle: sub == null
            ? null
            : Text(sub,
                style: const TextStyle(fontSize: 12, color: HD.inkMuted)),
        onTap: onTap,
      );

  // ── Luồng báo cáo ───────────────────────────────────────────────────────────

  // ── Chặn người dùng (Apple 1.2) ─────────────────────────────────────────────

  Future<void> _blockFlow(BuildContext context) async {
    final l = AppLocalizations.of(context);
    if (!GuestGate.requireAuth(context, message: l.actionsLoginToFeedback)) {
      return;
    }
    final id = authorId;
    if (id == null) return;
    Navigator.pop(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.blockConfirmTitle),
        content: Text(l.blockConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: HD.negative),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.blockAction),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await const ModerationApi().block(id);
      if (!context.mounted) return;
      AppFeedback.success(context, l.blockDone);
      onBlocked?.call();
    } catch (e) {
      if (!context.mounted) return;
      AppFeedback.error(context, l.blockFailed);
    }
  }

  Future<void> _reportFlow(BuildContext context, {required bool wrongInfo}) async {
    final l = AppLocalizations.of(context);
    if (!GuestGate.requireAuth(context, message: l.actionsLoginToFeedback)) {
      return;
    }
    Navigator.pop(context);

    final result = wrongInfo
        ? await _askWrongInfo(context)
        : await _askViolation(context);
    if (result == null || !context.mounted) return;

    try {
      await const ReportApi().report(
        targetType: _reportTargetString(),
        targetId: targetId,
        reason: result.$1,
        detail: result.$2,
      );
      if (!context.mounted) return;
      AppFeedback.success(
        context,
        wrongInfo ? l.actionsFeedbackSent : l.actionsReportSent,
      );
    } catch (e) {
      if (!context.mounted) return;
      AppFeedback.error(
        context,
        '$e'.contains('429') ? l.actionsRateLimited : l.actionsSendFailed,
      );
    }
  }

  /// Báo sai → hỏi sai ở đâu. Ô ghi chú là thứ giúp người đăng sửa được,
  /// nên đặt nó làm trọng tâm chứ không phải danh sách lý do.
  Future<(String, String)?> _askWrongInfo(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.actionsReportWrongInfo),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            l.actionsWrongInfoDesc,
            style: const TextStyle(fontSize: 13, color: HD.inkMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctl,
            maxLines: 3,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: l.actionsWrongInfoHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: HD.accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.actionsSend),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    return ('wrong_info', ctl.text.trim());
  }

  Future<(String, String)?> _askViolation(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final noun = _localizedNoun(l);
    final reasons = <(String, String)>[
      ('scam', l.actionsReasonScam),
      ('spam', l.actionsReasonSpam),
      ('duplicate', l.actionsReasonDuplicate),
      ('inappropriate', l.actionsReasonInappropriate),
      ('other', l.actionsReasonOther),
    ];
    return showModalBottomSheet<(String, String)>(
      context: context,
      backgroundColor: HD.paperRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text(l.actionsReportNoun(noun),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: HD.ink)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(l.actionsChooseReason,
                style: const TextStyle(fontSize: 12, color: HD.inkMuted)),
          ),
          for (final (key, label) in reasons)
            ListTile(
              title: Text(label, style: const TextStyle(color: HD.ink)),
              onTap: () => Navigator.pop(ctx, (key, '')),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
