/// Unit tests for HouseModel v2 fields (D1, D3, D4, D10 from listing-v2 plan).
///
/// Covers:
/// - Backend field parsing (transaction_type, is_trusted, trusted_at,
///   ward_slug, ward_slug_legacy).
/// - Default values when absent from the map.
/// - Derived getters (isForRent/isForSale/priceLabel/pricePeriodSuffix).
/// - Post-D3 default status = 'published'.
/// - toMap round-trip preserves new fields.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/house_model.dart';

// ────────────────────────────────────────────────────────────────────────────
// Fixtures
// ────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _baseMap({
  Map<String, dynamic> overrides = const {},
}) {
  final base = <String, dynamic>{
    'id': 1,
    'host_id': 10,
    'title': 'Căn hộ cho thuê',
    'description': 'Full nội thất',
    'category_id': 2,
    'price': 3_500_000,
    'area': 25.0,
    'address': '12 Phố Huế',
    'city': 'Hà Nội',
    'district': 'Hai Bà Trưng',
    'bedrooms': 1,
    'bathrooms': 1,
    'status': 'published',
    'created_at': '2026-07-01T10:00:00.000Z',
  };
  return {...base, ...overrides};
}

// ────────────────────────────────────────────────────────────────────────────
// Tests
// ────────────────────────────────────────────────────────────────────────────

void main() {
  _hangPhongTests();
  group('HouseModel v2 — new fields fromMap', () {
    test('parses transaction_type=sale', () {
      final h = HouseModel.fromMap(_baseMap(overrides: {
        'transaction_type': 'sale',
      }));
      expect(h.transactionType, equals('sale'));
      expect(h.isForSale, isTrue);
      expect(h.isForRent, isFalse);
    });

    test('parses transaction_type=rent', () {
      final h = HouseModel.fromMap(_baseMap(overrides: {
        'transaction_type': 'rent',
      }));
      expect(h.transactionType, equals('rent'));
      expect(h.isForRent, isTrue);
      expect(h.isForSale, isFalse);
    });

    test('parses is_trusted=true with trusted_at', () {
      final h = HouseModel.fromMap(_baseMap(overrides: {
        'is_trusted': true,
        'trusted_at': '2026-07-02T09:30:00.000Z',
      }));
      expect(h.isTrusted, isTrue);
      expect(h.trustedAt, isNotNull);
      expect(h.trustedAt!.toIso8601String(), contains('2026-07-02'));
    });

    test('parses ward_slug and ward_slug_legacy', () {
      final h = HouseModel.fromMap(_baseMap(overrides: {
        'ward_slug': 'phuong-ba-dinh-ha-noi',
        'ward_slug_legacy': 'phuong-truc-bach-hoan-kiem-ha-noi',
      }));
      expect(h.wardSlug, equals('phuong-ba-dinh-ha-noi'));
      expect(h.wardSlugLegacy, equals('phuong-truc-bach-hoan-kiem-ha-noi'));
    });
  });

  group('HouseModel v2 — defaults when absent from map', () {
    test('transaction_type defaults to rent', () {
      final h = HouseModel.fromMap(_baseMap());
      expect(h.transactionType, equals('rent'));
    });

    test('is_trusted defaults to false', () {
      final h = HouseModel.fromMap(_baseMap());
      expect(h.isTrusted, isFalse);
    });

    test('trusted_at defaults to null when absent', () {
      final h = HouseModel.fromMap(_baseMap());
      expect(h.trustedAt, isNull);
    });

    test('ward_slug + ward_slug_legacy default to null', () {
      final h = HouseModel.fromMap(_baseMap());
      expect(h.wardSlug, isNull);
      expect(h.wardSlugLegacy, isNull);
    });

    test('status defaults to published (D3 auto-publish)', () {
      // Simulate legacy API response without a status field — new default.
      final map = _baseMap();
      map.remove('status');
      final h = HouseModel.fromMap(map);
      expect(h.status, equals('published'));
    });

    test('constructor default status = published', () {
      final h = HouseModel(
        hostId: 1,
        title: 't',
        description: 'd',
        categoryId: 1,
        price: 1,
        area: 1,
        address: 'a',
        city: 'c',
        district: 'd',
        bedrooms: 0,
        bathrooms: 0,
      );
      expect(h.status, equals('published'));
      expect(h.transactionType, equals('rent'));
      expect(h.isTrusted, isFalse);
    });
  });

  group('HouseModel v2 — derived getters', () {
    test('priceLabel is Giá bán when transaction_type=sale', () {
      final h = HouseModel.fromMap(_baseMap(overrides: {
        'transaction_type': 'sale',
      }));
      expect(h.priceLabel, equals('Giá bán'));
      expect(h.pricePeriodSuffix, equals(''));
    });

    test('priceLabel is Giá thuê when transaction_type=rent', () {
      final h = HouseModel.fromMap(_baseMap(overrides: {
        'transaction_type': 'rent',
      }));
      expect(h.priceLabel, equals('Giá thuê'));
      expect(h.pricePeriodSuffix, equals('/tháng'));
    });
  });

  group('HouseModel v2 — toMap round-trip', () {
    test('preserves transaction_type/is_trusted/ward_slug', () {
      final map = _baseMap(overrides: {
        'transaction_type': 'sale',
        'is_trusted': true,
        'ward_slug': 'phuong-ba-dinh-ha-noi',
        'ward_slug_legacy': 'phuong-truc-bach-hoan-kiem-ha-noi',
      });
      final h = HouseModel.fromMap(map);
      final out = h.toMap();
      expect(out['transaction_type'], equals('sale'));
      expect(out['is_trusted'], isTrue);
      expect(out['ward_slug'], equals('phuong-ba-dinh-ha-noi'));
      expect(out['ward_slug_legacy'], equals('phuong-truc-bach-hoan-kiem-ha-noi'));
    });

    test('omits ward slugs from toMap when null', () {
      final h = HouseModel.fromMap(_baseMap());
      final out = h.toMap();
      expect(out.containsKey('ward_slug'), isFalse);
      expect(out.containsKey('ward_slug_legacy'), isFalse);
    });

    test('toMap always includes status (server owns the field on PUT — see H1 fix)', () {
      // NOTE: `api_house_repository.updateHouse` strips this field from PUT
      // bodies (H1 belt-and-suspenders). The toMap contract itself still
      // includes status for POST + local reads.
      final h = HouseModel.fromMap(_baseMap());
      expect(h.toMap()['status'], equals('published'));
    });
  });
}

/// TIN NGẮN HẠN NEO HẠNG PHÒNG (backend 0130).
///
/// Điều phải giữ: tin theo hạng KHÔNG có `source_room_id` (không thuộc phòng
/// nào), và `loai_phong_id` phải đi ngược lên server khi đăng — thiếu nó thì
/// server trả 422 và người đăng chỉ thấy "đăng không được".
void _hangPhongTests() {
  group('Hạng phòng (0130)', () {
    test('đọc loai_phong_id + khối hang_phong', () {
      final h = HouseModel.fromMap(
        _baseMap(
          overrides: {
            'loai_phong_id': 5,
            'hang_phong': {
              'id': 5,
              'ten': 'Deluxe hướng biển',
              'so_phong': 4,
              'suc_chua': 2,
              'gia_qua_dem': 350000,
              'toa': {'id': 9, 'ten': 'Homestay Biển Xanh'},
            },
          },
        ),
      );
      expect(h.loaiPhongId, 5);
      expect(h.hangPhong!['ten'], 'Deluxe hướng biển');
      expect(h.hangPhong!['so_phong'], 4);
      expect((h.hangPhong!['toa'] as Map)['ten'], 'Homestay Biển Xanh');
      // Tin theo hạng không neo phòng lẻ.
      expect(h.sourceRoomId, isNull);
    });

    test('tin thường không có hai trường này', () {
      final h = HouseModel.fromMap(_baseMap());
      expect(h.loaiPhongId, isNull);
      expect(h.hangPhong, isNull);
    });

    test('toMap gửi loai_phong_id khi đăng tin theo hạng', () {
      final h = HouseModel.fromMap(
        _baseMap(overrides: {'loai_phong_id': 5}),
      );
      expect(h.toMap()['loai_phong_id'], 5);
      // Tin thường không được gửi khoá rỗng — server phân biệt "không có" với
      // "có mà null" khi suy pipeline của tin.
      expect(
        HouseModel.fromMap(_baseMap()).toMap().containsKey('loai_phong_id'),
        isFalse,
      );
    });
  });
}
