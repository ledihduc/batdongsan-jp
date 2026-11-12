/// Thẻ mời đăng nhập trong chat AI khi backend trả `login_required` (khách gọi action ghi) (Phase 11, F-5).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class AiChatLoginPrompt extends StatelessWidget {
  const AiChatLoginPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: HD.s8),
      child: DsCard(
        padding: const EdgeInsets.all(HD.s12),
        child: Row(children: [
          const Icon(Icons.lock_outline, color: HD.inkMuted),
          const SizedBox(width: HD.s8),
          Expanded(child: Text(l.aiConfirmLoginRequired, style: const TextStyle(color: HD.ink))),
          DsButton(
            label: l.aiConfirmLoginButton,
            size: DsButtonSize.compact,
            onPressed: () => GoRouter.maybeOf(context)?.push('/login'),
          ),
        ]),
      ),
    );
  }
}
