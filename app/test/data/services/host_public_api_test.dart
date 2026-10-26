/// Unit test cho HostPublicApi — tầng ánh xạ HTTP của hồ sơ môi giới công khai.
///
/// Trọng tâm: đúng đường dẫn/tham số, và payload thiếu trường KHÔNG làm nổ app
/// (backend đổi tên field là chuyện xảy ra thật).
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/host_public_api.dart';

void main() {
  ({HostPublicApi api, List<http.Request> sent}) build(Object body) {
    final sent = <http.Request>[];
    final client = MockClient((req) async {
      sent.add(req);
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    return (api: HostPublicApi(client: ApiClient(client: client)), sent: sent);
  }

  group('featured', () {
    test('gọi đúng /api/hosts/featured kèm limit', () async {
      final t = build({'hosts': []});
      await t.api.featured(limit: 8);
      expect(t.sent.single.url.path, '/api/hosts/featured');
      expect(t.sent.single.url.queryParameters['limit'], '8');
    });

    test('thiếu hẳn "hosts" → danh sách rỗng, không nổ', () async {
      final t = build({});
      expect(await t.api.featured(), isEmpty);
    });

    test('ánh xạ đúng bản ghi', () async {
      final t = build({
        'hosts': [
          {'id': 7, 'name': 'Chị Lan', 'trusted': true, 'listing_count': 3},
        ]
      });
      final r = await t.api.featured();
      expect(r.single['id'], 7);
      expect(r.single['name'], 'Chị Lan');
      expect(r.single['trusted'], true);
    });
  });

  group('profile', () {
    test('gọi đúng /api/hosts/{id}', () async {
      final t = build({'id': 12, 'name': 'A'});
      final r = await t.api.profile(12);
      expect(t.sent.single.url.path, '/api/hosts/12');
      expect(r['name'], 'A');
    });
  });
}
