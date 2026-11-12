/// Hợp đồng xem trước / xác nhận action ghi AI (plan 20261027-1102 Phase 11).
///
/// Dùng chung cho màn link `/ai-confirm/:token` (MCP) và thẻ xác nhận trong chat ⇒ một đường gọi confirm.
library;

import 'package:house_booking/data/models/ai/ai_pending_action_models.dart';

abstract interface class IAiActionRepository {
  /// Xem trước, không ghi gì. [lang] = ngôn ngữ giao diện (tiêu đề/mô tả action theo ngôn ngữ).
  Future<AiPendingPreview> preview(String token, {String lang = 'ja'});

  /// Thực thi dưới danh tính người đang đăng nhập (Bearer). Lỗi ⇒ `ApiException` (404/403/409/410/422).
  Future<AiConfirmResult> confirm(String token);
}
