import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/data/repositories/api_house_repository.dart';
import 'package:house_booking/features/guest/home/widgets/home_map_preview.dart';

import '../../../helpers/pump_app.dart';

/// Bản đồ xem trước ở trang chủ.
///
/// Thứ dễ hỏng nhất KHÔNG phải chuyện vẽ đúng ghim, mà là hai cái bẫy:
///   1. Bản đồ tương tác nằm trong trang cuộn dọc sẽ ăn mất thao tác cuộn.
///   2. Tâm bản đồ rơi về một toạ độ cứng ở tỉnh khác khi chưa có vị trí.
class _RepoGia extends ApiHouseRepository {
  _RepoGia(this._nha);
  final List<HouseModel> _nha;

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
    List<int>? categoryIds,
    List<String>? directions,
    int? minBedrooms,
    double? minRating,
    int? minQualityStar,
    List<String>? amenities,
    String? sort,
    String? group,
    double? nearLat,
    double? nearLng,
    double? radiusKm,
  }) async =>
      _nha;
}

HouseModel _nha(int id, double? lat, double? lng) => HouseModel(
      id: id,
      hostId: 1,
      title: 'Nhà $id',
      description: '',
      categoryId: 1,
      price: 1,
      area: 1,
      address: 'a',
      city: 'Thanh Hóa',
      district: 'q1',
      latitude: lat,
      longitude: lng,
      bedrooms: 1,
      bathrooms: 1,
      transactionType: 'rent',
    );

void main() {
  testWidgets('KHOÁ mọi cử chỉ — không được ăn thao tác cuộn của trang',
      (t) async {
    await pumpApp(
      t,
      HomeMapPreview(repo: _RepoGia([_nha(1, 19.8, 105.8)])),
    );
    await t.pumpAndSettle();

    final map = t.widget<FlutterMap>(find.byType(FlutterMap));
    expect(
      map.options.interactionOptions.flags,
      InteractiveFlag.none,
      reason: 'bản đồ trong trang cuộn PHẢI khoá cử chỉ',
    );
  });

  testWidgets('canh theo chính các tin đang hiện khi chưa có vị trí',
      (t) async {
    await pumpApp(
      t,
      HomeMapPreview(
        repo: _RepoGia([_nha(1, 20.0, 105.0), _nha(2, 20.2, 105.4)]),
      ),
    );
    await t.pumpAndSettle();

    final map = t.widget<FlutterMap>(find.byType(FlutterMap));
    // Trung bình hai điểm, KHÔNG phải toạ độ mặc định ở Sài Gòn.
    expect(map.options.initialCenter.latitude, closeTo(20.1, 0.001));
    expect(map.options.initialCenter.longitude, closeTo(105.2, 0.001));
  });

  testWidgets('bỏ qua tin thiếu toạ độ, không nổ', (t) async {
    await pumpApp(
      t,
      HomeMapPreview(
        repo: _RepoGia([_nha(1, null, null), _nha(2, 21.0, 105.8)]),
      ),
    );
    await t.pumpAndSettle();

    final map = t.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialCenter.latitude, closeTo(21.0, 0.001));
  });

  testWidgets('zoom RỘNG để thấy cả vùng, không phải zoom sát', (t) async {
    await pumpApp(t, HomeMapPreview(repo: _RepoGia([_nha(1, 19.8, 105.8)])));
    await t.pumpAndSettle();

    final map = t.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialZoom, lessThanOrEqualTo(12));
  });

  testWidgets('có nút định vị để người dùng CHỦ ĐỘNG cấp quyền', (t) async {
    // Không tự bật hộp thoại xin quyền khi mở app; nút này là lối để người
    // dùng tự yêu cầu, và cũng là lúc DUY NHẤT được phép hỏi.
    await pumpApp(t, HomeMapPreview(repo: _RepoGia([_nha(1, 19.8, 105.8)])));
    await t.pumpAndSettle();

    expect(find.byIcon(Icons.my_location), findsOneWidget);
  });

  testWidgets('bản đồ dùng MapController — không kẹt ở initialCenter',
      (t) async {
    // flutter_map đọc initialCenter đúng một lần. Không có controller thì lấy
    // được vị trí sau đó cũng không dời khung nhìn được, trông y như hỏng.
    await pumpApp(t, HomeMapPreview(repo: _RepoGia([_nha(1, 19.8, 105.8)])));
    await t.pumpAndSettle();

    final map = t.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.mapController, isNotNull);
  });

  testWidgets('có nút phóng to / thu nhỏ — bù cho việc khoá cử chỉ',
      (t) async {
    await pumpApp(t, HomeMapPreview(repo: _RepoGia([_nha(1, 19.8, 105.8)])));
    await t.pumpAndSettle();

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
  });

  testWidgets('bấm + thì zoom TĂNG thật', (t) async {
    await pumpApp(t, HomeMapPreview(repo: _RepoGia([_nha(1, 19.8, 105.8)])));
    await t.pumpAndSettle();

    final map = t.widget<FlutterMap>(find.byType(FlutterMap));
    final z0 = map.mapController!.camera.zoom;

    await t.tap(find.byIcon(Icons.add));
    await t.pumpAndSettle();

    expect(map.mapController!.camera.zoom, greaterThan(z0));
  });

  testWidgets('có nút mở rộng và chú thích đủ bốn loại', (t) async {
    await pumpApp(t, HomeMapPreview(repo: _RepoGia([_nha(1, 19.8, 105.8)])));
    await t.pumpAndSettle();

    expect(find.text('Mở rộng'), findsOneWidget);
    for (final nhan in ['Ngắn hạn', 'Dài hạn', 'Kinh doanh', 'Bán']) {
      expect(find.text(nhan), findsOneWidget, reason: 'thiếu chú thích $nhan');
    }
  });

  testWidgets('không có tin nào thì báo rõ, không để dải trống', (t) async {
    await pumpApp(t, HomeMapPreview(repo: _RepoGia(const [])));
    await t.pumpAndSettle();

    expect(find.text('Chưa có tin nào có toạ độ'), findsOneWidget);
  });
}
