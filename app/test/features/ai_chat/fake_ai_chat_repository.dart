/// Repo chat giả cho test controller/màn chat (Phase 10): trả lần lượt theo `script`.
///
/// Mỗi phần tử: `AiChatReply` (trả về), `Object` khác (ném ra), hoặc `Completer<AiChatReply>`
/// (chưa xong ⇒ giữ trạng thái đang chờ).
library;

import 'dart:async';

import 'package:house_booking/data/models/ai/ai_chat_models.dart';
import 'package:house_booking/domain/repositories/ai/i_ai_chat_repository.dart';

class FakeAiChatRepository implements IAiChatRepository {
  FakeAiChatRepository([List<Object>? script]) : script = script ?? [];

  final List<Object> script;
  final List<List<AiChatTurn>> calls = [];
  final List<String> langs = [];

  @override
  Future<AiChatReply> send(List<AiChatTurn> history, {String lang = 'ja'}) async {
    calls.add(List.of(history));
    langs.add(lang);
    final step = script.isEmpty ? const AiChatReply(reply: 'ok', listings: [], toolRounds: 0) : script.removeAt(0);
    if (step is AiChatReply) return step;
    if (step is Completer<AiChatReply>) return step.future;
    throw step;
  }
}

const yenCard = AiListingCard(
  listingId: 7,
  title: '渋谷 1LDK',
  price: 120000,
  currency: 'JPY',
  layout: '1LDK',
  stationName: '渋谷',
  walkMin: 8,
);
