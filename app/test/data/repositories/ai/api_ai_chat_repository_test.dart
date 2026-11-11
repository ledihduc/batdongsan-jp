/// `ApiAiChatRepository`: parse câu trả lời + thẻ tin, timeout phía client, lỗi HTTP (Phase 10, AC13).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:house_booking/data/models/ai/ai_chat_models.dart';
import 'package:house_booking/data/repositories/ai/api_ai_chat_repository.dart';
import 'package:house_booking/data/services/api_client.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

void main() {
  test('api_ai_chat_repository_success_parses_reply_and_listings', () async {
    // Arrange
    late Map<String, dynamic> sent;
    final mock = MockClient((req) async {
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'reply': '3件です',
          'listings': [
            {'listing_id': 7, 'title': 't', 'price': 120000, 'currency': 'JPY', 'layout': '1LDK',
             'area_m2': 30, 'station_name': '渋谷', 'walk_min': 8},
          ],
          'tool_rounds': 1,
          'tool_calls': [],
          'model': 'm',
        }),
        200,
        headers: _json,
      );
    });
    final repo = ApiAiChatRepository(client: ApiClient(client: mock));
    // Act
    final r = await repo.send(const [AiChatTurn(role: 'user', content: '渋谷')], lang: 'en');
    // Assert
    expect(r.reply, '3件です');
    expect(r.listings.single.listingId, 7);
    expect(r.listings.single.currency, 'JPY');
    expect(r.listings.single.areaM2, 30.0);
    expect(r.listings.single.walkMin, 8);
    expect(r.toolRounds, 1);
    expect(sent['lang'], 'en');
    expect(sent['messages'], [
      {'role': 'user', 'content': '渋谷'},
    ]);
  });

  test('api_ai_chat_repository_slow_response_throws_timeout', () async {
    // Arrange
    final mock = MockClient((req) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response('{}', 200, headers: _json);
    });
    final repo = ApiAiChatRepository(
      client: ApiClient(client: mock),
      timeout: const Duration(milliseconds: 10),
    );
    // Act + Assert
    await expectLater(
      repo.send(const [AiChatTurn(role: 'user', content: 'x')]),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('api_ai_chat_repository_429_throws_api_exception_with_status', () async {
    // Arrange
    final mock = MockClient((req) async => http.Response(
          jsonEncode({'error': {'code': 'RATE_LIMITED', 'message': 'slow down'}}),
          429,
          headers: _json,
        ));
    final repo = ApiAiChatRepository(client: ApiClient(client: mock));
    // Act + Assert
    await expectLater(
      repo.send(const [AiChatTurn(role: 'user', content: 'x')]),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 429)),
    );
  });
}
