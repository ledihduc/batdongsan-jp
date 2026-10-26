import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/sale_link_api.dart';
import 'package:house_booking/data/services/host_public_api.dart';

void main() {
  test(
    'sale directory sends name or exact email query and parses total',
    () async {
      late http.Request sent;
      final api = HostPublicApi(
        client: ApiClient(
          client: MockClient((req) async {
            sent = req;
            return http.Response(
              jsonEncode({
                'sales': [
                  {'id': 74, 'name': 'Sale Demo', 'listing_count': 0},
                ],
                'total': 1,
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      final page = await api.sales(query: ' sale@hotmail.com ');
      expect(page.total, 1);
      expect(page.items.single['id'], 74);
      expect(sent.url.path, '/api/hosts/sales');
      expect(sent.url.queryParameters, {
        'q': 'sale@hotmail.com',
        'limit': '50',
        'offset': '0',
      });
    },
  );

  test(
    'preview and create send selected building and parse its name',
    () async {
      final sent = <http.Request>[];
      final api = SaleLinkApi(
        client: ApiClient(
          client: MockClient((req) async {
            sent.add(req);
            return http.Response(
              jsonEncode({
                'id': 1,
                'sale_id': 9,
                'owner_id': 2,
                'building_id': 42,
                'building_name': 'Toà B',
                'ten': 'Sale A',
                'ten_doi_phuong': 'Sale A',
                'status': 'active',
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      final preview = await api.traMa('SL-ABC234', buildingId: 42);
      final link = await api.lienKet('SL-ABC234', buildingId: 42);
      expect(preview.buildingId, 42);
      expect(link.buildingName, 'Toà B');
      expect(sent.map((r) => r.url.path), [
        '/api/owner-links/resolve-code',
        '/api/owner-links',
      ]);
      for (final req in sent) {
        expect(jsonDecode(req.body), {'code': 'SL-ABC234', 'building_id': 42});
      }
    },
  );

  test(
    'building picker requests only owned buildings through query parameters',
    () async {
      late http.Request sent;
      final api = SaleLinkApi(
        client: ApiClient(
          client: MockClient((req) async {
            sent = req;
            return http.Response('[]', 200);
          }),
        ),
      );
      expect(await api.toaCuaToi(), isEmpty);
      expect(sent.url.path, '/api/host/buildings');
      expect(sent.url.queryParameters, {'owned_only': 'true'});
    },
  );

  test('legacy link without building remains readable', () {
    final link = LienKet.fromMap({'id': 3, 'status': 'active'});
    expect(link.buildingId, isNull);
    expect(link.buildingName, isNull);
  });
}
