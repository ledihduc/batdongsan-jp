/// `ApiJpListingRepository`: hợp đồng JSON với backend `/api/jp/listings` (Phase 10, F-1/F-2).
///
/// JSON lấy nguyên từ backend local (listing 1 + 1 phần tử trang tìm kiếm) để bắt lệch tên trường.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:house_booking/data/repositories/jp/api_jp_listing_repository.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_listing_repository.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

const _detail = {
  'listing_id': 1,
  'title': '[SBY-OK1] 渋谷 1LDK 南向きマンション',
  'rental_terms': {
    'id': 1, 'monthly_rent': 120000, 'management_fee': 10000, 'shikikin_months': 1.0,
    'reikin_months': 0.0, 'hoshoukin_months': null, 'koushinryo_months': null,
    'brokerage_fee_rate': null, 'guarantee_company_fee': null, 'tax_included': true,
  },
  'property_info': {
    'id': 1, 'layout': '1LDK', 'floor_area_m2': 38.5, 'structure': 'RC', 'building_year': 2015,
    'floor_number': 5, 'orientation': 'S', 'available_from': null,
  },
  'transit_accesses': [
    {
      'id': 1, 'listing_id': 1,
      'station': {
        'id': 1, 'name': '渋谷', 'name_kana': '', 'line_name': '山手線', 'line_id': 1,
        'prefecture_name': '東京都', 'latitude': 35.658, 'longitude': 139.7016,
      },
      'walk_minutes': 5,
    },
  ],
  'description': '渋谷駅から徒歩5分',
  'image_urls': [],
  'host_name': 'デモ不動産',
  'prefecture': '東京都',
  'city': '渋谷区',
  'address': '渋谷区神南1丁目',
  'is_published': true,
};

const _searchPage = {
  'items': [
    {
      'listing_id': 24, 'title': '下北沢 シェアハウス 個室', 'monthly_rent': 70000, 'layout': '1K',
      'floor_area_m2': 22.5, 'nearest_station_name': '下北沢', 'nearest_station_walk_min': 5,
      'thumbnail_url': null, 'city': '世田谷区', 'is_published': true,
    },
  ],
  'total': 36,
};

ApiJpListingRepository _repo(Object body, void Function(http.Request) onRequest) =>
    ApiJpListingRepository(
      client: ApiClient(
        client: MockClient((req) async {
          onRequest(req);
          return http.Response(jsonEncode(body), 200, headers: _json);
        }),
      ),
    );

void main() {
  test('api_jp_listing_repository_get_by_id_backend_json_parses_nested_fields', () async {
    // Arrange
    late http.Request sent;
    final repo = _repo(_detail, (r) => sent = r);
    // Act
    final l = await repo.getById(1);
    // Assert
    expect(sent.url.path, '/api/jp/listings/1');
    expect(l.listingId, 1);
    expect(l.rentalTerms.monthlyRent, 120000);
    expect(l.propertyInfo.layout, '1LDK');
    expect(l.propertyInfo.floorAreaM2, 38.5);
    expect(l.transitAccesses.single.station.name, '渋谷');
    expect(l.nearestStation?.walkMinutes, 5);
  });

  test('api_jp_listing_repository_search_backend_json_parses_summary_items', () async {
    // Arrange
    final repo = _repo(_searchPage, (_) {});
    // Act
    final items = await repo.search(const JpListingSearchParams());
    // Assert
    expect(items, hasLength(1));
    expect(items.single.listingId, 24);
    expect(items.single.monthlyRent, 70000);
    expect(items.single.nearestStationName, '下北沢');
    expect(items.single.nearestStationWalkMin, 5);
  });

  test('api_jp_listing_repository_search_filters_sends_backend_query_names', () async {
    // Arrange
    late http.Request sent;
    final repo = _repo(_searchPage, (r) => sent = r);
    // Act
    await repo.search(const JpListingSearchParams(layouts: ['1K', '1LDK'], maxRent: 150000, maxWalkMinutes: 10));
    // Assert
    final q = sent.url.queryParameters;
    expect(sent.url.path, '/api/jp/listings');
    expect(q['layouts'], '1K,1LDK');
    expect(q['max_rent'], '150000');
    expect(q['max_walk_min'], '10');
  });

  test('api_jp_listing_repository_get_by_id_404_throws_api_exception', () async {
    // Arrange
    final repo = ApiJpListingRepository(
      client: ApiClient(client: MockClient((_) async => http.Response('{"detail":"not found"}', 404, headers: _json))),
    );
    // Act + Assert
    await expectLater(repo.getById(999), throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)));
  });
}
