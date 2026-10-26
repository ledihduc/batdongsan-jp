import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/features/map/utils/marker_cluster.dart';

/// Gom ghim trên bản đồ.
///
/// Điều dễ sai nhất là gom theo khoảng cách ĐỘ thay vì khoảng cách PIXEL: khi đó
/// cùng một cặp toạ độ sẽ gom/không gom giống hệt nhau ở mọi mức zoom, tức là
/// không giải quyết được đúng cái đang hỏng (pin đè nhau khi zoom xa).
HouseModel _nha(int id, double? lat, double? lng) => HouseModel(
      id: id,
      hostId: 1,
      title: 'Nhà $id',
      description: '',
      categoryId: 1,
      price: 1,
      area: 1,
      address: 'a',
      city: 'HCM',
      district: 'q1',
      latitude: lat,
      longitude: lng,
      bedrooms: 1,
      bathrooms: 1,
      transactionType: 'rent',
    );

void main() {
  test('danh sách rỗng → không có cụm nào', () {
    expect(clusterPins(const [], zoom: 10), isEmpty);
  });

  test('hai điểm sát nhau: zoom xa gom 1 cụm, zoom gần tách thành 2', () {
    // Cách nhau 0.005° ≈ 550m: ở zoom 10 chỉ là ~4px (đè khít nhau), ở zoom 15
    // là ~116px — vượt ô lưới 72px nên phải tách.
    final houses = [
      _nha(1, 10.7769, 106.7009),
      _nha(2, 10.7819, 106.7009),
    ];

    final xa = clusterPins(houses, zoom: 10);
    expect(xa, hasLength(1));
    expect(xa.first.houses, hasLength(2));
    expect(xa.first.isSingle, isFalse);

    final gan = clusterPins(houses, zoom: 15);
    expect(gan, hasLength(2));
    expect(gan.every((c) => c.isSingle), isTrue);
  });

  test('từ zoom $kClusterMaxZoom trở lên thì KHÔNG gom nữa', () {
    // Hai tin trùng khít toạ độ — ở zoom cao vẫn phải là 2 pin riêng để người
    // dùng đọc được giá từng tin.
    final houses = [
      _nha(1, 10.7769, 106.7009),
      _nha(2, 10.7769, 106.7009),
    ];
    expect(clusterPins(houses, zoom: kClusterMaxZoom), hasLength(2));
    expect(clusterPins(houses, zoom: 8), hasLength(1));
  });

  test('bỏ qua tin thiếu toạ độ', () {
    final out = clusterPins(
      [_nha(1, null, null), _nha(2, 10.0, 106.0)],
      zoom: 12,
    );
    expect(out, hasLength(1));
    expect(out.first.first.id, 2);
  });

  test('tâm cụm nằm giữa các tin nó đại diện', () {
    final out = clusterPins(
      [_nha(1, 10.0, 106.0), _nha(2, 10.002, 106.0)],
      zoom: 9,
    );
    expect(out, hasLength(1));
    expect(out.first.center.latitude, closeTo(10.001, 1e-9));
  });

  test('cụm đông tin xếp trước — marker không nhảy giữa các lần rebuild', () {
    final houses = [
      _nha(1, 10.0, 106.0),
      _nha(2, 10.0005, 106.0),
      _nha(3, 10.0006, 106.0),
      // Xa hẳn → cụm riêng 1 tin.
      _nha(4, 12.0, 108.0),
    ];
    final out = clusterPins(houses, zoom: 13);
    expect(out.first.houses.length, greaterThanOrEqualTo(out.last.houses.length));
  });
}
