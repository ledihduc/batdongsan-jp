import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('house_booking.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    String path;
    if (kIsWeb) {
      path = filePath;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
    }

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE users ADD COLUMN birthday TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN bio TEXT');
      await db.execute('ALTER TABLE users ADD COLUMN id_number TEXT');
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const integerType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';
    const realNullable = 'REAL';

    // 1. Users Table
    await db.execute('''
      CREATE TABLE users (
        id $idType,
        name $textType,
        email TEXT NOT NULL UNIQUE,
        password_hash $textType,
        phone $textNullable,
        avatar_path $textNullable,
        role $textType, -- 'admin', 'host', 'guest'
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at $textType,
        birthday $textNullable,
        bio $textNullable,
        id_number $textNullable
      )
    ''');

    // 2. Categories Table
    await db.execute('''
      CREATE TABLE categories (
        id $idType,
        name $textType,
        icon $textNullable
      )
    ''');

    // 3. Amenities Table
    await db.execute('''
      CREATE TABLE amenities (
        id $idType,
        name $textType,
        icon $textNullable
      )
    ''');

    // 4. Houses Table
    await db.execute('''
      CREATE TABLE houses (
        id $idType,
        host_id $integerType,
        title $textType,
        description $textType,
        category_id $integerType,
        price $realType,
        area $realType,
        address $textType,
        city $textType,
        district $textType,
        latitude $realNullable,
        longitude $realNullable,
        bedrooms $integerType,
        bathrooms $integerType,
        status $textType DEFAULT 'pending', -- 'pending', 'approved', 'rejected', 'hidden'
        created_at $textType,
        FOREIGN KEY (host_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE RESTRICT
      )
    ''');

    // 5. House Images Table
    await db.execute('''
      CREATE TABLE house_images (
        id $idType,
        house_id $integerType,
        image_path $textType,
        is_primary INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (house_id) REFERENCES houses (id) ON DELETE CASCADE
      )
    ''');

    // 6. House Amenities Table (Many-to-Many relation)
    await db.execute('''
      CREATE TABLE house_amenities (
        house_id $integerType,
        amenity_id $integerType,
        PRIMARY KEY (house_id, amenity_id),
        FOREIGN KEY (house_id) REFERENCES houses (id) ON DELETE CASCADE,
        FOREIGN KEY (amenity_id) REFERENCES amenities (id) ON DELETE CASCADE
      )
    ''');

    // 7. Bookings Table
    await db.execute('''
      CREATE TABLE bookings (
        id $idType,
        house_id $integerType,
        guest_id $integerType,
        booking_date $textType, -- YYYY-MM-DD
        booking_time $textType, -- HH:MM
        message $textNullable,
        status $textType DEFAULT 'pending', -- 'pending', 'approved', 'rejected', 'completed', 'cancelled'
        created_at $textType,
        FOREIGN KEY (house_id) REFERENCES houses (id) ON DELETE CASCADE,
        FOREIGN KEY (guest_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 8. Wishlists Table
    await db.execute('''
      CREATE TABLE wishlists (
        id $idType,
        guest_id $integerType,
        house_id $integerType,
        created_at $textType,
        FOREIGN KEY (guest_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (house_id) REFERENCES houses (id) ON DELETE CASCADE,
        UNIQUE(guest_id, house_id)
      )
    ''');

    // 9. Reviews Table
    await db.execute('''
      CREATE TABLE reviews (
        id $idType,
        house_id $integerType,
        guest_id $integerType,
        rating $realType, -- 1.0 to 5.0
        comment $textNullable,
        created_at $textType,
        FOREIGN KEY (house_id) REFERENCES houses (id) ON DELETE CASCADE,
        FOREIGN KEY (guest_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Seed default data
    await _seedData(db);
  }

  Future _seedData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // 1. Seed Users (1 Admin, 1 Host, 1 Guest)
    // admin@housebooking.com / admin123
    await db.insert('users', {
      'name': 'Hệ thống Admin',
      'email': 'admin@housebooking.com',
      'password_hash': 'admin123', // In real app, this should be hashed
      'phone': '0901234567',
      'avatar_path':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDA_WfcEH2-Kpcu_TCOc8VVqD-1xzu3nsNZJa59qS7PJSD4mOSLVanWtcEwvJ0kyHy7alLq9JbZhODEQJkS-Z1eA7rjHGaJz6ikKbQfWnzYwH1gyIDeBh-eXmB17X04L11vvlFMTQIcusjwX1moco1O_wSFYnTiBMOcXHCLw_cCbSFFEhpUlJ-V8rzbOf2ZKdLKANpZVJIxWcQjiff0x4shSTrG0GO1R4awzlhAFcMpS6Y7rh0KxnXeld7NyUBme6XBGS0_vow0a8R1',
      'role': 'admin',
      'is_active': 1,
      'created_at': now,
    });

    // host@housebooking.com / host123
    final hostId = await db.insert('users', {
      'name': 'Nguyễn Minh Anh',
      'email': 'host@housebooking.com',
      'password_hash': 'host123',
      'phone': '0988888888',
      'avatar_path':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCLpT6YeMuUdu5WFkEppTKWzasFtKw5ES6unKfz-qkzwg5vg1YMP4Kxbzbg_TEwu9fbwoHc_4G8NntkIoYCoJGSqDcoptXZbDl2gY4nCnzTAL3nyMUAqMAlwWYQ3IOtM-It5VbuUoChdVfXOI1o5AMHxK3zczkBcnAr1e8ZXEs2SR2WMVvvi9Qr2foYsXnlL3BbqCl0L4g8v7QMzDPcaOGfuLYgxClEOBJbNaEtC_-Q4eNVRaPahQBGR3Pjy3iTY8nDV50I8UnTYOK0',
      'role': 'host',
      'is_active': 1,
      'created_at': now,
    });

    // guest@housebooking.com / guest123
    final guestId = await db.insert('users', {
      'name': 'Lê Văn Nam',
      'email': 'guest@housebooking.com',
      'password_hash': 'guest123',
      'phone': '0977777777',
      'avatar_path':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDuZileqWUUeT02elpgsnzU5uC5dnzW8OTXDCXfc5phkMqvFRlwiVwmoFZTO5niKRWrB1fI2zcWBpSamb1BAm9C4uZwkTrEdFCFK2F0zNQ2VEP0T2Wpxe1h0gRsGcsnC0fulP2b2xrBu9myk3Tw3LEjYyNyPtxJkj8hJ3wGm7AKkapdNZrTeZLkVE6KPZ3knpltr1_5hOfpdWdhM1Cq_UlsrTx_LhwiCz9gDsFZqqK6bspOkDiAt3OBkw8llIzX0qLUDJ48UqAgZNYV',
      'role': 'guest',
      'is_active': 1,
      'created_at': now,
    });

    // 2. Seed Categories
    await db.insert('categories', {'name': 'Căn hộ', 'icon': 'apartment'});
    final catHouse = await db.insert('categories', {
      'name': 'Nhà phố',
      'icon': 'home',
    });
    final catVilla = await db.insert('categories', {
      'name': 'Biệt thự',
      'icon': 'villa',
    });
    final catPenthouse = await db.insert('categories', {
      'name': 'Penthouse',
      'icon': 'holiday_village',
    });
    final catStudio = await db.insert('categories', {
      'name': 'Studio',
      'icon': 'deck',
    });

    // 3. Seed Amenities
    final amWifi = await db.insert('amenities', {
      'name': 'Wifi 5G',
      'icon': 'wifi',
    });
    final amPool = await db.insert('amenities', {
      'name': 'Hồ bơi vô cực',
      'icon': 'pool',
    });
    final amGym = await db.insert('amenities', {
      'name': 'Phòng Gym',
      'icon': 'fitness_center',
    });
    final amParking = await db.insert('amenities', {
      'name': 'Bãi đỗ xe',
      'icon': 'local_parking',
    });
    final amAC = await db.insert('amenities', {
      'name': 'Điều hòa trung tâm',
      'icon': 'ac_unit',
    });
    final amSecurity = await db.insert('amenities', {
      'name': 'An ninh 24/7',
      'icon': 'security',
    });

    // 4. Seed Houses (Matching the Stitch project)
    // House 1: Skyline Serenity Penthouse
    final house1Id = await db.insert('houses', {
      'host_id': hostId,
      'title': 'Skyline Serenity Penthouse',
      'description':
          'Tọa lạc tại vị trí kim cương của Quận 1, Skyline Penthouse mang đến không gian sống đẳng cấp với tầm nhìn 360 độ ra toàn cảnh thành phố. Căn hộ được thiết kế theo phong cách hiện đại tối giản, nội thất nhập khẩu từ Châu Âu, tối ưu hóa ánh sáng tự nhiên và luồng không khí. Lý tưởng cho các chuyên gia và gia đình tìm kiếm một không gian sống yên tĩnh nhưng vẫn đầy đủ tiện nghi ngay giữa lòng đô thị náo nhiệt.',
      'category_id': catPenthouse,
      'price': 25000000.0,
      'area': 120.0,
      'address': '15 Lê Thánh Tôn, Bến Nghé, Quận 1',
      'city': 'TP. Hồ Chí Minh',
      'district': 'Quận 1',
      'latitude': 10.7797,
      'longitude': 106.7042,
      'bedrooms': 3,
      'bathrooms': 2,
      'status': 'approved',
      'created_at': now,
    });

    // House 2: Green Garden Townhouse
    final house2Id = await db.insert('houses', {
      'host_id': hostId,
      'title': 'Green Garden Townhouse',
      'description':
          'Căn nhà phố xinh đẹp phong cách hiện đại với khu vườn xanh nhỏ trước cửa và mặt tiền ốp gỗ sang trọng. Chụp ảnh tươi sáng, sạch sẽ, không gian thoáng đãng tạo cảm giác bình yên, thích hợp cho một hộ gia đình trẻ muốn thuê ở lâu dài tại khu vực Thảo Điền.',
      'category_id': catHouse,
      'price': 18000000.0,
      'area': 95.0,
      'address': 'Nguyễn Văn Hưởng, Thảo Điền, Quận 2',
      'city': 'TP. Hồ Chí Minh',
      'district': 'Quận 2',
      'bedrooms': 2,
      'bathrooms': 2,
      'status': 'approved',
      'created_at': now,
    });

    // House 3: Urban Loft Studio
    final house3Id = await db.insert('houses', {
      'host_id': hostId,
      'title': 'Urban Loft Studio',
      'description':
          'Căn hộ Studio trần cao ấm cúng, thiết kế theo phong cách công nghiệp (Industrial Chic) kết hợp Scandinavian tối giản. Gạch mộc cổ kính, cửa sổ lớn đón trọn ánh nắng chiều, không gian thiết kế cực kỳ thông minh tạo sự rộng rãi và sang trọng.',
      'category_id': catStudio,
      'price': 12000000.0,
      'area': 45.0,
      'address': 'Đội Cấn, Ba Đình',
      'city': 'Hà Nội',
      'district': 'Ba Đình',
      'bedrooms': 1,
      'bathrooms': 1,
      'status': 'approved',
      'created_at': now,
    });

    // House 4: The Azure Infinity Villa
    final house4Id = await db.insert('houses', {
      'host_id': hostId,
      'title': 'The Azure Infinity Villa',
      'description':
          'Biệt thự siêu hiện đại với bể bơi vô cực riêng và boong tàu gỗ rộng rãi. Kiến trúc góc cạnh hình khối hiện đại với những mảng tường trắng tinh khôi và cửa kính lớn kịch trần. Không gian sống đẳng cấp nhất, yên tĩnh và hoàn toàn biệt lập.',
      'category_id': catVilla,
      'price': 45000000.0,
      'area': 350.0,
      'address': 'Bán đảo Sơn Trà',
      'city': 'Đà Nẵng',
      'district': 'Sơn Trà',
      'bedrooms': 4,
      'bathrooms': 4,
      'status': 'approved',
      'created_at': now,
    });

    // 5. Seed House Images (Using the exact URLs from downloaded screens)
    // House 1 Images
    await db.insert('house_images', {
      'house_id': house1Id,
      'image_path':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuC9H3UlXDcJlYAlSnvIPXQUhLYYn7dNgts5Xsqa7Qh_Yuir72dnxLfuk5-Qqlw4bIDE-5w9KbZ6Vup2DfsxbqxY6BcSdRPmwiv_WjMOV5SFuHYZs0qqEDmGeJvSIy6vb3KBQ58nTcW9QJ1ttUMIwOO-yMyqr3xhcIkl5p5EbK2L5c2BblU1LhvU3kqs9kTJmppxLZdT8DnhB4eaTi8ndcSDinxMvnd10b6FmqD5TKfye5TPxw3C29M7RzglFlhnqOZzz0H3GZk_0sZA',
      'is_primary': 1,
    });
    await db.insert('house_images', {
      'house_id': house1Id,
      'image_path':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDPMMdEsHR2XQGXg1naRRbsU6A_RToHS4j_MI-ATc5si_2BgUoj5OyzLKSXTDJWy2pUelmi4OELU2ekVGzXHkb5NwxJg1RHQkwnlThTlXSu_ia299ViMdswTgsdAOBX32F9mj2W0mZHvqbH9h5hAs_j_cIUDknGUz-SNjk35IvpTch6vrpSxyouIV6RPiTu3XBPj3w5J2f-5mNf9Gzo369CYLgTdQVjLCfiaij7cCRj6HYPJJHwgMFKkl7ugtV0amhS659jvFy7CzB9',
      'is_primary': 0,
    });

    // House 2 Images
    await db.insert('house_images', {
      'house_id': house2Id,
      'image_path':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCo9ck7-TKBEQgHQFHhXBKBWAeX68Pccw1GkUWLAF9LDA6D2W7srvONe9RTFOacgSD3XR4O_ykSCzlQBF67-MrOF0_j-ARlXA7hnkEwM6KOx0y7HOPMJRfqeo-F-X3EYV_G6Ju7dV2V4Otj9gJOzdbWdVUxkUVX-cJtZqDVmEwUcJ-vp7Gy3DoNuR8Lk4t3j5hAg6m94DI-SyuDZMBI_A8QS7lVBcYyD9XFD0Aam3qSPSKcWT_Xcwokb8JfbAJL03NQAbLpOqR81kyU',
      'is_primary': 1,
    });

    // House 3 Images
    await db.insert('house_images', {
      'house_id': house3Id,
      'image_path':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuD_CPd6jTgS_E-CXLxzs3oJYwe9FjYtkhDEnQPFQLrD9RMPk8-LXzYo0jHYJHXToXemwuUJDaRY6Ur2loDNORUK77zxRHB8L4IeIhjs-0syMq5_8bATw5gEBav6-lm9FIBcRtf0vrUeu2iSnLacqgxcntJdb0BFrIt7SuF4SfFxWK6XCLCNME6ggFmLg6oWdOsopmxfOw0QHQyJ0fbZq3JJgozdTFKQj_v6YWgPmzKZmNLq2314ummf0TeXbJBDLuLjgQF89X-IDfEE',
      'is_primary': 1,
    });

    // House 4 Images
    await db.insert('house_images', {
      'house_id': house4Id,
      'image_path':
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAPo2fnsI0C7LQsfY55bJ_ILP4s3hRfSHCEqdwIMeH7ph30xagGROgV-IckaBG6ahAtDFKE1boKVLkQm_4LsD3TSjNDZdCedM1rjoMd6g_IN_rInO8m-BzjwKAwrB0ZPK-rdeerTQj-hxKXZrvfa7YW1_wCdwWApnFDvfWcStjTLgRti9srikuAVxlwHBM_yDNDMR-JJV1-jcb-4LbT98Tz4H0WQnVvY_wLnd3VG0xcUWyUA2GOtnjuUlRRNwcL9EgGYoMhpzZ6hlOx',
      'is_primary': 1,
    });

    // 6. Seed House Amenities
    await db.insert('house_amenities', {
      'house_id': house1Id,
      'amenity_id': amWifi,
    });
    await db.insert('house_amenities', {
      'house_id': house1Id,
      'amenity_id': amPool,
    });
    await db.insert('house_amenities', {
      'house_id': house1Id,
      'amenity_id': amGym,
    });
    await db.insert('house_amenities', {
      'house_id': house1Id,
      'amenity_id': amParking,
    });
    await db.insert('house_amenities', {
      'house_id': house1Id,
      'amenity_id': amAC,
    });
    await db.insert('house_amenities', {
      'house_id': house1Id,
      'amenity_id': amSecurity,
    });

    await db.insert('house_amenities', {
      'house_id': house2Id,
      'amenity_id': amWifi,
    });
    await db.insert('house_amenities', {
      'house_id': house2Id,
      'amenity_id': amParking,
    });

    await db.insert('house_amenities', {
      'house_id': house3Id,
      'amenity_id': amWifi,
    });
    await db.insert('house_amenities', {
      'house_id': house3Id,
      'amenity_id': amAC,
    });

    await db.insert('house_amenities', {
      'house_id': house4Id,
      'amenity_id': amPool,
    });
    await db.insert('house_amenities', {
      'house_id': house4Id,
      'amenity_id': amGym,
    });
    await db.insert('house_amenities', {
      'house_id': house4Id,
      'amenity_id': amSecurity,
    });

    // 7. Seed Bookings
    // Approved booking
    await db.insert('bookings', {
      'house_id': house3Id,
      'guest_id': guestId,
      'booking_date': '2023-10-12',
      'booking_time': '09:00 - 10:00',
      'message': 'Tôi muốn xem nhà để quyết định thuê luôn.',
      'status': 'approved',
      'created_at': now,
    });

    // Completed booking
    await db.insert('bookings', {
      'house_id': house2Id,
      'guest_id': guestId,
      'booking_date': '2023-10-05',
      'booking_time': '16:00 - 17:00',
      'message': 'Tôi cần xem hướng nắng.',
      'status': 'completed',
      'created_at': now,
    });
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
