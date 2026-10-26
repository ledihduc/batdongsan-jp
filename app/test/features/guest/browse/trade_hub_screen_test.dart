import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/models/demand_post.dart';
import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/data/repositories/api_house_repository.dart';
import 'package:house_booking/data/services/demand_api.dart';
import 'package:house_booking/features/guest/browse/trade_hub_screen.dart';

import '../../../helpers/pump_app.dart';

/// Màn "Mua bán · Cho thuê" tách hai bên thị trường.
///
/// Điều dễ hỏng nhất: chip nhu cầu phải dịch ĐÚNG sang tham số API. Chip
/// "Ngắn hạn" mà quên gửi transaction_type='rent' thì danh sách sẽ lẫn cả nhà
/// bán — đúng cái lộn xộn mà màn này sinh ra để dẹp.
class _RepoGia extends ApiHouseRepository {
  Map<String, dynamic> thamSo = const {};

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
  }) async {
    thamSo = {
      'transactionType': transactionType,
      'group': group,
      'minBedrooms': minBedrooms,
      'query': query,
    };
    return [
      HouseModel(
        id: 1,
        hostId: 1,
        title: 'Nhà mẫu ven biển',
        description: '',
        categoryId: 1,
        price: 5000000,
        area: 50,
        address: 'a',
        city: 'Thanh Hóa',
        district: 'Sầm Sơn',
        bedrooms: 2,
        bathrooms: 1,
        transactionType: 'rent',
      ),
    ];
  }
}

class _DemandGia extends DemandApi {
  const _DemandGia({this.ghiLai});

  /// Nơi ghi lại tham số lần gọi cuối — const nên phải truyền hộp từ ngoài vào.
  final Map<String, dynamic>? ghiLai;

  @override
  Future<List<DemandPost>> list({
    String? kind,
    String? provinceCode,
    int? categoryId,
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    ghiLai?['kind'] = kind;
    ghiLai?['query'] = query;
    return [
      DemandPost(
        id: 7,
        kind: kind ?? 'buy',
        status: 'open',
        createdAt: DateTime(2026, 1, 1),
        expiresAt: DateTime(2026, 2, 1),
        provinceName: 'Thanh Hóa',
        note: 'Cần căn 2 phòng ngủ gần biển',
      ),
    ];
  }
}

void main() {
  Future<_RepoGia> _mo(WidgetTester t) async {
    final repo = _RepoGia();
    await pumpApp(t, TradeHubScreen(repo: repo, demandApi: const _DemandGia()));
    await t.pumpAndSettle();
    return repo;
  }

  testWidgets('mặc định ở bên TÌM NHÀ, hiện tin đang rao', (t) async {
    await _mo(t);
    expect(find.text('Tìm nhà'), findsOneWidget);
    expect(find.text('Tìm khách'), findsOneWidget);
    expect(find.text('Nhà mẫu ven biển'), findsOneWidget);
  });

  testWidgets('bốn nhu cầu được ghim sẵn thành chip ở bên MUA', (t) async {
    await _mo(t);
    for (final nhan in ['Tất cả', 'Bán', 'Ngắn hạn', 'Dài hạn', 'Kinh doanh']) {
      expect(find.text(nhan), findsOneWidget, reason: 'thiếu chip $nhan');
    }
  });

  testWidgets('chip "Ngắn hạn" dịch đúng sang tham số API', (t) async {
    final repo = await _mo(t);
    await t.tap(find.text('Ngắn hạn'));
    await t.pumpAndSettle();

    expect(repo.thamSo['group'], 'stay_short');
    expect(repo.thamSo['transactionType'], 'rent');
  });

  testWidgets('chip "Bán" lọc theo tin bán, KHÔNG kèm nhóm lưu trú', (t) async {
    final repo = await _mo(t);
    await t.tap(find.text('Bán'));
    await t.pumpAndSettle();

    expect(repo.thamSo['transactionType'], 'sale');
    expect(repo.thamSo['group'], isNull);
  });

  testWidgets('sang bên BÁN thì đổi sang tin NHU CẦU và đổi bộ chip', (
    t,
  ) async {
    await _mo(t);
    await t.tap(find.text('Tìm khách'));
    await t.pumpAndSettle();

    expect(find.text('Cần mua'), findsWidgets);
    expect(find.text('Cần thuê'), findsWidgets);
    // Chip của bên mua phải biến mất — chúng vô nghĩa ở đây.
    expect(find.text('Ngắn hạn'), findsNothing);
    expect(find.textContaining('Cần căn 2 phòng ngủ'), findsOneWidget);
  });

  testWidgets('đổi bên thì lựa chọn chip cũ được đặt lại', (t) async {
    final repo = await _mo(t);
    await t.tap(find.text('Ngắn hạn'));
    await t.pumpAndSettle();
    expect(repo.thamSo['group'], 'stay_short');

    await t.tap(find.text('Tìm khách'));
    await t.pumpAndSettle();
    await t.tap(find.text('Tìm nhà'));
    await t.pumpAndSettle();

    // Về "Tất cả" chứ không giữ lựa chọn cũ của bên kia.
    expect(repo.thamSo['group'], isNull);
    expect(repo.thamSo['transactionType'], isNull);
  });

  testWidgets('gõ vào ô tìm là tự tìm, KHÔNG phải bấm Enter', (t) async {
    final repo = await _mo(t);
    await t.enterText(find.byType(TextField), 'ven biển');
    // Hoãn 350ms rồi mới gọi API — chưa tới hạn thì chưa gọi.
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();

    expect(repo.thamSo['query'], 'ven biển');
  });

  testWidgets('ô tìm ở tab TÌM KHÁCH cũng được gửi lên API', (t) async {
    final ghi = <String, dynamic>{};
    final repo = _RepoGia();
    await pumpApp(
      t,
      TradeHubScreen(
        repo: repo,
        demandApi: _DemandGia(ghiLai: ghi),
      ),
    );
    await t.pumpAndSettle();

    await t.tap(find.text('Tìm khách'));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), 'Thanh Hóa');
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();

    // Trước đây tham số này bị bỏ rơi: gõ gì cũng ra cùng một danh sách.
    expect(ghi['query'], 'Thanh Hóa');
  });

  testWidgets('có lối tắt sang bản đồ ngay cạnh hai tab', (t) async {
    await _mo(t);
    expect(find.text('Bản đồ'), findsOneWidget);
  });

  testWidgets('thẻ tin CÓ toạ độ mới hiện nút xem trên bản đồ', (t) async {
    await _mo(t);
    // Tin mẫu trong _RepoGia không có lat/lng → không được vẽ nút.
    expect(find.byIcon(Icons.place_outlined), findsNothing);
  });

  testWidgets('lối đăng tin nhu cầu nằm ở thanh tiêu đề, KHÔNG phải FAB',
      (t) async {
    await _mo(t);
    expect(find.text('Đăng tin nhu cầu'), findsOneWidget);
    // Màn này không được có FAB riêng: shell đã có sẵn một FAB "Đăng tin" nổi
    // trên mọi màn con push trong tab, thêm cái nữa là hai nút đỏ đè nhau.
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
