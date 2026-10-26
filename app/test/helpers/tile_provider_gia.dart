import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:house_booking/features/map/widgets/base_map_tile_layer.dart';

/// Nguồn tile cho WIDGET TEST: trả một ô trong suốt từ bộ nhớ, KHÔNG đụng mạng.
///
/// Hai lý do:
///  1. Provider thật (`CancellableNetworkTileProvider`) chạy trên dio, và dio
///     tạo một `Timer` cho mỗi request. Trong widget test thời gian là giả và
///     request không bao giờ xong, nên timer còn treo lúc kết thúc test →
///     `flutter_test` ném "Pending timers" và MỌI test có bản đồ đều đỏ, dù
///     sản phẩm không hỏng gì.
///  2. Test không được phụ thuộc vào việc máy chạy test có mạng hay không.
class TileProviderGia extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_oTrongSuot);
}

/// Bật cho toàn phiên test. Gọi từ `pumpApp`/`pumpAppRaw` nên mọi test dựng
/// bản đồ đều được che sẵn, kể cả test viết sau này.
void dungTileGiaChoTest() {
  taoProviderTile = TileProviderGia.new;
}

/// PNG 1×1 hoàn toàn trong suốt (68 byte) — ô nền không vẽ gì đè lên ghim.
final Uint8List _oTrongSuot = Uint8List.fromList(const [
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, //
  0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, //
  0, 0, 0, 11, 73, 68, 65, 84, 120, 156, 99, 96, 0, 2, 0, 0, //
  5, 0, 1, 122, 94, 171, 63, 0, 0, 0, 0, 73, 69, 78, 68, 174, //
  66, 96, 130,
]);
