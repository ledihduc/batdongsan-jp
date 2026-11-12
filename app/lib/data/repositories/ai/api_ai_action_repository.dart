/// `GET/POST /api/ai/actions/{token}` qua [ApiClient] (plan 20261027-1102 Phase 11, AC14).
///
/// `ApiClient` tự gắn `Authorization: Bearer` khi đã đăng nhập (confirm bắt buộc JWT).
/// Timeout đặt ở đây, không sửa `ApiClient` (ảnh hưởng toàn app).
library;

import 'dart:async';

import 'package:house_booking/data/models/ai/ai_pending_action_models.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/domain/repositories/ai/i_ai_action_repository.dart';

class ApiAiActionRepository implements IAiActionRepository {
  const ApiAiActionRepository({ApiClient? client, this.timeout = const Duration(seconds: 20)})
      : _client = client ?? const ApiClient();

  final ApiClient _client;
  final Duration timeout;

  @override
  Future<AiPendingPreview> preview(String token, {String lang = 'ja'}) async {
    final response = await _client
        .get('/api/ai/actions/${Uri.encodeComponent(token)}', queryParameters: {'lang': lang})
        .timeout(timeout);
    return AiPendingPreview.fromJson(response);
  }

  @override
  Future<AiConfirmResult> confirm(String token) async {
    final response = await _client.post('/api/ai/actions/${Uri.encodeComponent(token)}/confirm').timeout(timeout);
    return AiConfirmResult.fromJson(response);
  }
}
