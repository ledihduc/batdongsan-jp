/// `ApiAiActionRepository`: xem trước + xác nhận action ghi AI (Phase 11, AC14). JSON theo schema backend Phase 09.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:house_booking/data/repositories/ai/api_ai_action_repository.dart';
import 'package:house_booking/data/services/api_client.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
final _tok = 'T' * 43;

ApiAiActionRepository _repo(int status, Object body, void Function(http.Request) seen) =>
    ApiAiActionRepository(
      client: ApiClient(
        client: MockClient((req) async {
          seen(req);
          return http.Response(jsonEncode(body), status, headers: _json);
        }),
      ),
    );

void main() {
  test('api_ai_action_repository_confirm_posts_and_parses_result', () async {
    // Arrange
    late http.Request seen;
    final repo = _repo(200, {'status': 'executed', 'action': 'save_favorite', 'result': {'created': true}}, (r) => seen = r);
    // Act
    final r = await repo.confirm(_tok);
    // Assert
    expect(seen.method, 'POST');
    expect(seen.url.path, '/api/ai/actions/$_tok/confirm');
    expect(r.status, 'executed');
    expect(r.action, 'save_favorite');
    expect(r.result['created'], true);
  });

  test('api_ai_action_repository_preview_parses_listing_and_params', () async {
    // Arrange
    late http.Request seen;
    final repo = _repo(200, {
      'action': 'request_viewing',
      'title': '内見を申し込む',
      'description': '内見を申し込みます',
      'params': {'listing_id': 1, 'slots': ['2026-10-29T11:00:00+09:00']},
      'listing': {'listing_id': 1, 'title': '渋谷 1LDK', 'price': 120000, 'currency': 'JPY', 'layout': '1LDK'},
      'status': 'pending',
      'expires_at': '2026-10-28T03:15:00Z',
      'owner_bound': true,
    }, (r) => seen = r);
    // Act
    final p = await repo.preview(_tok, lang: 'vi');
    // Assert
    expect(seen.method, 'GET');
    expect(seen.url.path, '/api/ai/actions/$_tok');
    expect(seen.url.queryParameters['lang'], 'vi');
    expect(p.action, 'request_viewing');
    expect(p.listing?.title, '渋谷 1LDK');
    expect(p.listing?.currency, 'JPY');
    expect(p.listing?.price, 120000);
    expect(p.params['slots'], isA<List<dynamic>>());
    expect(p.expiresAt, DateTime.utc(2026, 10, 28, 3, 15));
    expect(p.ownerBound, isTrue);
  });

  test('api_ai_action_repository_preview_without_listing_parses_null_listing', () async {
    // Arrange
    final repo = _repo(200, {
      'action': 'save_favorite', 'title': 'お気に入りに保存', 'description': '', 'params': {},
      'listing': null, 'status': 'pending', 'expires_at': '2026-10-28T03:15:00Z', 'owner_bound': false,
    }, (_) {});
    // Act
    final p = await repo.preview(_tok);
    // Assert
    expect(p.listing, isNull);
    expect(p.ownerBound, isFalse);
  });

  test('api_ai_action_repository_410_throws_api_exception_with_status', () async {
    // Arrange
    final repo = _repo(410, {'detail': {'code': 'expired', 'message': 'this confirmation has expired'}}, (_) {});
    // Act + Assert
    await expectLater(repo.preview(_tok), throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 410)));
  });
}
