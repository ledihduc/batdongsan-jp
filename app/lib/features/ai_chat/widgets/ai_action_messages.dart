/// Văn bản kết quả / lỗi của xác nhận action AI, dùng chung màn link và thẻ chat (Phase 11, F-3, F-4).
library;

import 'package:house_booking/features/ai_chat/ai_action_confirm_controller.dart';
import 'package:house_booking/l10n/app_localizations.dart';

String aiConfirmDoneText(AppLocalizations l, String action) => switch (action) {
      'save_favorite' => l.aiConfirmDoneFavorite,
      'request_viewing' => l.aiConfirmDoneViewing,
      _ => l.aiConfirmDoneGeneric,
    };

String aiConfirmErrorText(AppLocalizations l, AiConfirmErrorKind? kind) => switch (kind) {
      AiConfirmErrorKind.notFound => l.aiConfirmErrorNotFound,
      AiConfirmErrorKind.used => l.aiConfirmErrorUsed,
      AiConfirmErrorKind.expired => l.aiConfirmErrorExpired,
      AiConfirmErrorKind.forbidden => l.aiConfirmErrorForbidden,
      AiConfirmErrorKind.invalid => l.aiConfirmErrorInvalid,
      _ => l.aiChatErrorNetwork,
    };
