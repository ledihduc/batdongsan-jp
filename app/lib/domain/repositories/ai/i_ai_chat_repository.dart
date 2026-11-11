/// Hợp đồng gửi một lượt chat AI (plan 20261027-1102 Phase 10).
library;

import 'package:house_booking/data/models/ai/ai_chat_models.dart';

abstract interface class IAiChatRepository {
  /// Gửi toàn bộ [history] (lượt cuối là câu hỏi của người dùng) + [lang] giao diện.
  ///
  /// Ném `TimeoutException` khi quá hạn phía client, `ApiException` khi backend trả lỗi.
  Future<AiChatReply> send(List<AiChatTurn> history, {String lang = 'ja'});
}
