/// Repo action giả cho test màn xác nhận / thẻ chat (Phase 11): preview/confirm trả hoặc ném theo cấu hình.
library;

import 'dart:async';

import 'package:house_booking/data/models/ai/ai_pending_action_models.dart';
import 'package:house_booking/domain/repositories/ai/i_ai_action_repository.dart';

class FakeAiActionRepository implements IAiActionRepository {
  FakeAiActionRepository({this.previewResult, this.previewError, this.confirmResult, this.confirmError, this.confirmGate});

  final AiPendingPreview? previewResult;
  Object? previewError; // đổi được giữa chừng để thử "thử lại"
  final AiConfirmResult? confirmResult;
  Object? confirmError;

  /// Có ⇒ `confirm` chờ tới khi hoàn tất (để thử bấm 2 lần khi đang gửi).
  final Completer<void>? confirmGate;

  int confirmCalls = 0;
  final List<String> previewLangs = [];

  @override
  Future<AiPendingPreview> preview(String token, {String lang = 'ja'}) async {
    previewLangs.add(lang);
    if (previewError != null) throw previewError!;
    return previewResult!;
  }

  @override
  Future<AiConfirmResult> confirm(String token) async {
    confirmCalls++;
    if (confirmGate != null) await confirmGate!.future;
    if (confirmError != null) throw confirmError!;
    return confirmResult!;
  }
}

final tok = 'T' * 43;

AiPendingPreview favoritePreview({AiPendingListing? listing}) => AiPendingPreview(
      action: 'save_favorite',
      title: 'お気に入りに保存',
      description: '',
      params: const {'listing_id': 1},
      listing: listing ?? const AiPendingListing(listingId: 1, title: '[SBY-OK1] 渋谷1LDK', price: 120000, currency: 'JPY', layout: '1LDK'),
      status: 'pending',
      expiresAt: DateTime.utc(2026, 10, 28, 3, 15),
      ownerBound: true,
    );

const favoriteDone = AiConfirmResult(status: 'executed', action: 'save_favorite', result: {'created': true});
