import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'package:house_booking/data/models/house_model.dart';

/// Một cụm ghim trên bản đồ. Cụm 1 phần tử vẫn là cụm — nơi gọi tự quyết định
/// vẽ pin giá thật hay bong bóng đếm.
class PinCluster {
  const PinCluster({required this.center, required this.houses});

  final LatLng center;
  final List<HouseModel> houses;

  bool get isSingle => houses.length == 1;
  HouseModel get first => houses.first;
}

/// Zoom từ mức này trở lên thì KHÔNG gom nữa — ở street level pin đã thưa và
/// người dùng cần đọc giá từng tin, gom lại là làm hỏng việc.
const double kClusterMaxZoom = 16;

/// Kích thước ô lưới (pixel màn hình). Pin giá rộng 70px nên ô 72px đảm bảo hai
/// cụm cạnh nhau không đè lên nhau.
const double kClusterCellPx = 72;

/// Gom các tin gần nhau thành cụm theo LƯỚI PIXEL ở mức [zoom] hiện tại.
///
/// Dùng lưới pixel chứ không phải lưới độ (lat/lng) vì "đè nhau" là hiện tượng
/// trên MÀN HÌNH: cùng một khoảng cách độ, ở zoom 6 thì hai pin chồng khít còn ở
/// zoom 15 thì cách nhau nửa màn hình. Chiếu Web Mercator = đúng phép chiếu mà
/// flutter_map dùng nên khoảng cách pixel tính ra khớp với thứ mắt thấy.
///
/// Tin thiếu toạ độ bị bỏ qua. Trả về cụm theo thứ tự ổn định (nhiều tin trước)
/// để marker không nhảy loạn giữa các lần rebuild.
List<PinCluster> clusterPins(
  List<HouseModel> houses, {
  required double zoom,
  double cellPx = kClusterCellPx,
}) {
  final valid = houses
      .where((h) => h.latitude != null && h.longitude != null)
      .toList();
  if (valid.isEmpty) return const [];

  // Không gom ở zoom cao: mỗi tin một cụm.
  if (zoom >= kClusterMaxZoom) {
    return [
      for (final h in valid)
        PinCluster(
          center: LatLng(h.latitude!, h.longitude!),
          houses: [h],
        ),
    ];
  }

  // Số pixel của toàn thế giới ở mức zoom này (tile 256px).
  final worldPx = 256 * math.pow(2, zoom).toDouble();
  final buckets = <String, List<HouseModel>>{};

  for (final h in valid) {
    final p = _project(h.latitude!, h.longitude!, worldPx);
    final gx = (p.dx / cellPx).floor();
    final gy = (p.dy / cellPx).floor();
    buckets.putIfAbsent('$gx:$gy', () => []).add(h);
  }

  final out = <PinCluster>[];
  for (final group in buckets.values) {
    // Tâm cụm = trung bình toạ độ, để bong bóng nằm giữa các tin nó đại diện.
    final lat =
        group.map((h) => h.latitude!).reduce((a, b) => a + b) / group.length;
    final lng =
        group.map((h) => h.longitude!).reduce((a, b) => a + b) / group.length;
    out.add(PinCluster(center: LatLng(lat, lng), houses: group));
  }
  out.sort((a, b) => b.houses.length.compareTo(a.houses.length));
  return out;
}

/// Chiếu lat/lng sang toạ độ pixel Web Mercator (EPSG:3857) trong một thế giới
/// rộng [worldPx] pixel.
_Point _project(double lat, double lng, double worldPx) {
  // Chặn lat ở ±85.05113 — ngoài dải này Mercator phân kỳ (tan → vô cực).
  final clamped = lat.clamp(-85.05112878, 85.05112878);
  final sinLat = math.sin(clamped * math.pi / 180);
  final x = (lng + 180) / 360 * worldPx;
  final y = (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) *
      worldPx;
  return _Point(x, y);
}

class _Point {
  const _Point(this.dx, this.dy);
  final double dx;
  final double dy;
}
