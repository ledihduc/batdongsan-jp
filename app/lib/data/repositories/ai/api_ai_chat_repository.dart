/// `POST /api/ai/chat` qua [ApiClient] (plan 20261027-1102 Phase 10, AC13).
///
/// Timeout đặt ở đây, không sửa `ApiClient` (ảnh hưởng toàn app). 75 s > hạn lượt chat
/// phía backend (60 s) để client nhận được JSON 504 thay vì tự cắt trước.
/// `ApiClient` tự gắn `Authorization: Bearer` khi đã đăng nhập.
library;

import 'dart:async';

import 'package:house_booking/data/models/ai/ai_chat_models.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/domain/repositories/ai/i_ai_chat_repository.dart';

class ApiAiChatRepository implements IAiChatRepository {
  const ApiAiChatRepository({ApiClient? client, this.timeout = const Duration(seconds: 75)})
      : _client = client ?? const ApiClient();

  final ApiClient _client;
  final Duration timeout;

  @override
  Future<AiChatReply> send(List<AiChatTurn> history, {String lang = 'ja'}) async {
    final response = await _client.post(
      '/api/ai/chat',
      body: {
        'messages': history.map((t) => t.toJson()).toList(),
        'lang': lang,
      },
    ).timeout(timeout);
    return AiChatReply.fromJson(response);
  }
}
