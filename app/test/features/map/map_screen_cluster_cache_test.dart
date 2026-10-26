import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/features/map/map_screen.dart';
import 'package:house_booking/providers/house_provider.dart';

import '../../helpers/pump_app.dart';

/// Bộ nhớ đệm cụm ghim của bản đồ nhà.
///
/// Màn này dựng lại rất thường xuyên (chọn ghim, mở chú giải, tải thêm tin) nên
/// phải có đệm. Nhưng đệm sai khoá thì bản đồ hiện ghim của dữ liệu CŨ mà không
/// có lỗi nào báo — người dùng lọc xong thấy y hệt lúc trước, tưởng bộ lọc hỏng.
///
/// Khoá cũ chỉ gồm (zoom, SỐ LƯỢNG tin, bộ lọc loại). Đổi bộ lọc/tìm kiếm gần
/// như luôn trả về đúng một trang 20 tin → cùng số lượng → đệm coi là "không
/// đổi". Đó là ca dưới đây.
class _HouseProviderGia extends HouseProvider {
  _HouseProviderGia(this._ds);

  List<HouseModel> _ds;

  @override
  List<HouseModel> get houses => _ds;

  @override
  bool get isLoading => false;

  void doiKetQua(List<HouseModel> moi) {
    _ds = moi;
    notifyListeners();
  }
}

HouseModel _nha(int id, double lat, double lng) => HouseModel(
      id: id,
      hostId: 1,
      title: 'Nhà $id',
      description: '',
      categoryId: 1,
      price: 1000000,
      area: 50,
      address: 'a',
      city: 'X',
      district: 'y',
      latitude: lat,
      longitude: lng,
      bedrooms: 1,
      bathrooms: 1,
      transactionType: 'rent',
    );

List<LatLng> _diemGhim(WidgetTester t) {
  final lop = t.widgetList<MarkerLayer>(find.byType(MarkerLayer)).first;
  final diem = lop.markers.map((m) => m.point).toList()
    ..sort((a, b) => a.latitude.compareTo(b.latitude));
  return diem;
}

Future<void> _mo(WidgetTester t, _HouseProviderGia hp) async {
  await pumpApp(
    t,
    const MapScreen(embedded: true),
    extraProviders: [ChangeNotifierProvider<HouseProvider>.value(value: hp)],
  );
  await t.pump();
  await t.pump();
}

void main() {
  testWidgets('đổi kết quả tìm kiếm với CÙNG số tin → ghim phải đổi theo',
      (t) async {
    // Hai tập cách nhau cả nghìn km nhưng cùng độ dài — đúng hình dạng của
    // "đổi bộ lọc, vẫn ra một trang 20 tin".
    final hp = _HouseProviderGia([
      _nha(1, 10.77, 106.70), // TP.HCM
      _nha(2, 21.03, 105.85), // Hà Nội
    ]);
    await _mo(t, hp);

    final truoc = _diemGhim(t);
    expect(truoc, hasLength(2));
    expect(truoc.first.latitude, closeTo(10.77, 0.01));

    hp.doiKetQua([
      _nha(3, 16.05, 108.20), // Đà Nẵng
      _nha(4, 12.24, 109.19), // Nha Trang
    ]);
    await t.pump();
    await t.pump();

    final sau = _diemGhim(t);
    expect(sau, hasLength(2));
    expect(
      sau.first.latitude,
      closeTo(12.24, 0.01),
      reason: 'bản đồ đang giữ ghim của kết quả tìm kiếm CŨ',
    );
    expect(sau.last.latitude, closeTo(16.05, 0.01));
  });

  testWidgets('cùng đúng tập tin đó → dùng lại cụm đã tính (không dựng lại)',
      (t) async {
    final ds = [_nha(1, 10.77, 106.70), _nha(2, 21.03, 105.85)];
    final hp = _HouseProviderGia(ds);
    await _mo(t, hp);

    final truoc = _diemGhim(t);
    hp.doiKetQua(ds); // cùng tham chiếu — chỉ là một lượt notifyListeners
    await t.pump();
    await t.pump();

    expect(_diemGhim(t), truoc);
  });

  testWidgets('bớt tin đi thì ghim cũng bớt', (t) async {
    final hp = _HouseProviderGia([
      _nha(1, 10.77, 106.70),
      _nha(2, 21.03, 105.85),
    ]);
    await _mo(t, hp);
    expect(_diemGhim(t), hasLength(2));

    hp.doiKetQua([_nha(1, 10.77, 106.70)]);
    await t.pump();
    await t.pump();

    expect(_diemGhim(t), hasLength(1));
  });
}
