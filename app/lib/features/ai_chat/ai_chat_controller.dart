/// Trạng thái màn chat AI: bong bóng hội thoại, đang chờ, lỗi theo loại, thử lại (Phase 10, AC13).
///
/// Lịch sử chỉ giữ trong bộ nhớ (không lưu máy). Gửi tối đa [maxTurns] lượt gần nhất và tổng
/// ≤ [maxTotalChars] ký tự (khớp trần `backend/app/schemas/ai_chat.py`, vượt ⇒ 422 mãi), mỗi lượt
/// ≤ [maxTurnChars]; lượt đầu luôn là `user` (backend yêu cầu lượt cuối là `user`).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:house_booking/data/models/ai/ai_chat_models.dart';
import 'package:house_booking/data/models/ai/ai_pending_action_models.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/domain/repositories/ai/i_ai_chat_repository.dart';

enum AiChatStatus { idle, loading, error }

enum AiChatErrorKind { timeout, rateLimited, server, network }

class AiChatBubble {
  const AiChatBubble({
    required this.role,
    required this.text,
    this.listings = const [],
    this.pendingActions = const [],
    this.loginRequired = false,
  });

  final String role;
  final String text;
  final List<AiListingCard> listings;

  /// Thẻ chờ xác nhận (Phase 11) — chỉ hiển thị, không gửi lại lên backend trong lịch sử.
  final List<AiPendingAction> pendingActions;
  final bool loginRequired;
}

class AiChatController extends ChangeNotifier {
  AiChatController(this._repo, {this.lang = 'ja'});

  static const maxTurns = 20;

  /// Trần tổng ký tự lịch sử của backend (`MAX_TOTAL_CHARS`). `String.length` đếm UTF-16 ≥ số
  /// code point Python đếm ⇒ cắt theo đây luôn an toàn.
  static const maxTotalChars = 8000;

  /// Trần mỗi lượt của backend (`AiChatMessage.content max_length`); câu trả lời dài bị cắt khi gửi lại.
  static const maxTurnChars = 2000;

  final IAiChatRepository _repo;
  /// Ngôn ngữ gửi kèm mỗi lượt; màn chat cập nhật khi khách đổi ngôn ngữ giữa chừng (Phase 14).
  String lang;
  final List<AiChatBubble> _bubbles = [];
  AiChatStatus _status = AiChatStatus.idle;
  AiChatErrorKind? _errorKind;
  bool _disposed = false;

  List<AiChatBubble> get bubbles => List.unmodifiable(_bubbles);
  AiChatStatus get status => _status;
  AiChatErrorKind? get errorKind => _errorKind;

  /// Thêm câu hỏi rồi gọi backend. Bỏ qua khi rỗng hoặc đang chờ.
  Future<void> send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _status == AiChatStatus.loading) return;
    _bubbles.add(AiChatBubble(role: 'user', text: q));
    await _request();
  }

  /// Gửi lại đúng lịch sử hiện tại (câu hỏi cuối chưa có trả lời), không nhân đôi câu hỏi.
  Future<void> retry() async {
    if (_status != AiChatStatus.error || _bubbles.isEmpty || _bubbles.last.role != 'user') return;
    await _request();
  }

  Future<void> _request() async {
    _status = AiChatStatus.loading;
    _errorKind = null;
    notifyListeners();
    try {
      final reply = await _repo.send(_history(), lang: lang);
      _bubbles.add(AiChatBubble(
        role: 'assistant',
        text: reply.reply,
        listings: reply.listings,
        pendingActions: reply.pendingActions,
        loginRequired: reply.loginRequired,
      ));
      _status = AiChatStatus.idle;
    } catch (e) {
      _errorKind = _kindOf(e);
      _status = AiChatStatus.error;
    }
    // Rời màn khi đang chờ ⇒ controller đã dispose, không được notify nữa.
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<AiChatTurn> _history() {
    var turns = _bubbles
        .map((b) => AiChatTurn(
              role: b.role,
              content: b.text.length > maxTurnChars ? b.text.substring(0, maxTurnChars) : b.text,
            ))
        .toList();
    if (turns.length > maxTurns) turns = turns.sublist(turns.length - maxTurns);
    var total = turns.fold<int>(0, (n, t) => n + t.content.length);
    // Bỏ lượt cũ nhất tới khi vừa trần tổng; luôn giữ lượt cuối (câu hỏi ≤ maxTurnChars).
    while (turns.length > 1 && (total > maxTotalChars || turns.first.role != 'user')) {
      total -= turns.first.content.length;
      turns = turns.sublist(1);
    }
    return turns;
  }

  static AiChatErrorKind _kindOf(Object e) {
    if (e is TimeoutException) return AiChatErrorKind.timeout;
    if (e is ApiException) {
      if (e.statusCode == 429) return AiChatErrorKind.rateLimited;
      if (e.statusCode >= 500) return AiChatErrorKind.server;
    }
    return AiChatErrorKind.network;
  }
}
