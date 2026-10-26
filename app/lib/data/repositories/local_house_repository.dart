import 'package:house_booking/data/database/database_helper.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/domain/repositories/i_house_repository.dart';

class LocalHouseRepository implements IHouseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<List<HouseModel>> getHouses({
    String? query,
    int? categoryId,
    double? minPrice,
    double? maxPrice,
    double? minArea,
    double? maxArea,
    String? status,
    int? limit,
    int? offset,
    int? hostId,
    String? transactionType,
    String? wardSlug,
    bool? isTrusted,
    // Tìm kiếm nâng cao (0071) — local/offline bỏ qua các filter này.
    List<int>? categoryIds,
    List<String>? directions,
    int? minBedrooms,
    double? minRating,
    int? minQualityStar,
    List<String>? amenities,
    String? sort,
    // 0074 — bản LOCAL (SQLite offline) chưa lưu nhóm danh mục nên tham số này
    // được nhận cho khớp interface rồi BỎ QUA; lọc nhóm chỉ có khi online.
    String? group,
  }) async {
    final db = await _dbHelper.database;

    // Base query joining houses with category and host
    String rawQuery = '''
      SELECT h.*, c.name as category_name, u.name as host_name, u.avatar_path as host_avatar, u.phone as host_phone
      FROM houses h
      JOIN categories c ON h.category_id = c.id
      JOIN users u ON h.host_id = u.id
      WHERE h.status = 'approved'
    ''';

    List<dynamic> args = [];

    if (query != null && query.isNotEmpty) {
      rawQuery +=
          ' AND (h.title LIKE ? OR h.description LIKE ? OR h.city LIKE ? OR h.district LIKE ? OR h.address LIKE ?)';
      final searchPattern = '%$query%';
      args.addAll([
        searchPattern,
        searchPattern,
        searchPattern,
        searchPattern,
        searchPattern,
      ]);
    }

    if (categoryId != null) {
      rawQuery += ' AND h.category_id = ?';
      args.add(categoryId);
    }

    if (minPrice != null) {
      rawQuery += ' AND h.price >= ?';
      args.add(minPrice);
    }

    if (maxPrice != null) {
      rawQuery += ' AND h.price <= ?';
      args.add(maxPrice);
    }

    if (minArea != null) {
      rawQuery += ' AND h.area >= ?';
      args.add(minArea);
    }

    if (maxArea != null) {
      rawQuery += ' AND h.area <= ?';
      args.add(maxArea);
    }

    if (transactionType != null) {
      rawQuery += ' AND h.transaction_type = ?';
      args.add(transactionType);
    }

    if (wardSlug != null) {
      rawQuery += ' AND h.ward_slug = ?';
      args.add(wardSlug);
    }

    if (isTrusted != null) {
      rawQuery += ' AND h.is_trusted = ?';
      args.add(isTrusted ? 1 : 0);
    }

    rawQuery += ' ORDER BY h.created_at DESC';

    final List<Map<String, dynamic>> maps = await db.rawQuery(rawQuery, args);
    List<HouseModel> houses = [];

    for (var map in maps) {
      final houseId = map['id'] as int;

      // Load images
      final List<Map<String, dynamic>> imgMaps = await db.query(
        'house_images',
        where: 'house_id = ?',
        whereArgs: [houseId],
        orderBy: 'is_primary DESC',
      );
      final images = imgMaps.map((e) => e['image_path'] as String).toList();

      // Load amenities
      final List<Map<String, dynamic>> amenityMaps = await db.rawQuery(
        '''
        SELECT a.name 
        FROM house_amenities ha
        JOIN amenities a ON ha.amenity_id = a.id
        WHERE ha.house_id = ?
      ''',
        [houseId],
      );
      final amenities = amenityMaps.map((e) => e['name'] as String).toList();

      houses.add(HouseModel.fromMap(map, images: images, amenities: amenities));
    }

    return houses;
  }

  @override
  Future<HouseModel?> getHouseById(int id) async {
    final db = await _dbHelper.database;

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT h.*, c.name as category_name, u.name as host_name, u.avatar_path as host_avatar, u.phone as host_phone
      FROM houses h
      JOIN categories c ON h.category_id = c.id
      JOIN users u ON h.host_id = u.id
      WHERE h.id = ?
    ''',
      [id],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;

    // Load images
    final List<Map<String, dynamic>> imgMaps = await db.query(
      'house_images',
      where: 'house_id = ?',
      whereArgs: [id],
      orderBy: 'is_primary DESC',
    );
    final images = imgMaps.map((e) => e['image_path'] as String).toList();

    // Load amenities
    final List<Map<String, dynamic>> amenityMaps = await db.rawQuery(
      '''
      SELECT a.name 
      FROM house_amenities ha
      JOIN amenities a ON ha.amenity_id = a.id
      WHERE ha.house_id = ?
    ''',
      [id],
    );
    final amenities = amenityMaps.map((e) => e['name'] as String).toList();

    return HouseModel.fromMap(map, images: images, amenities: amenities);
  }

  @override
  Future<({String? token, String? status})> createHouse(
    HouseModel house,
  ) async {
    try {
      final db = await _dbHelper.database;

      await db.transaction((txn) async {
        final houseId = await txn.insert('houses', house.toMap());

        // Insert images
        for (int i = 0; i < house.images.length; i++) {
          await txn.insert('house_images', {
            'house_id': houseId,
            'image_path': house.images[i],
            'is_primary': i == 0 ? 1 : 0,
          });
        }

        // Link amenities (assuming amenities list contains amenity IDs or we look them up)
        for (var amenityName in house.amenities) {
          final List<Map<String, dynamic>> amRes = await txn.query(
            'amenities',
            where: 'name = ?',
            whereArgs: [amenityName],
          );
          if (amRes.isNotEmpty) {
            final amenityId = amRes.first['id'] as int;
            await txn.insert('house_amenities', {
              'house_id': houseId,
              'amenity_id': amenityId,
            });
          }
        }
      });
      return (token: null, status: null);
    } catch (e) {
      print('Create house error: $e');
      rethrow;
    }
  }

  @override
  Future<bool> updateHouse(HouseModel house) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'houses',
        house.toMap(),
        where: 'id = ?',
        whereArgs: [house.id],
      );
      return true;
    } catch (e) {
      print('Update house error: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteHouse(int id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete('houses', where: 'id = ?', whereArgs: [id]);
      return true;
    } catch (e) {
      print('Delete house error: $e');
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await _dbHelper.database;
    return await db.query('categories');
  }

  @override
  Future<List<Map<String, dynamic>>> getAmenities() async {
    final db = await _dbHelper.database;
    return await db.query('amenities');
  }
}
