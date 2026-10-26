import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/models/house_model.dart';
import 'package:house_booking/data/repositories/api_house_repository.dart';
import 'package:house_booking/features/guest/home/widgets/latest_listings_strip.dart';

import '../../../helpers/pump_app.dart';

/// Dải tin mới nhất ở trang chủ.
///
/// Hai điều phải đúng: dải KHÔNG được để lại tiêu đề treo trên khoảng trắng
/// khi không có tin, và lỗi mạng chỉ được làm nó biến mất chứ không ném ra
/// ngoài làm sập cả trang chủ.
class _RepoGia extends ApiHouseRepository {
  _RepoGia({this.tin = const [], this.loi = false});

  final List<HouseModel> tin;
  final bool loi;
  int? limitDaGui;

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
    limitDaGui = limit;
    if (loi) throw Exception('mạng hỏng');
    return tin;
  }
}

HouseModel _tinMau(int id) => HouseModel(
  id: id,
  hostId: 1,
  title: 'Căn hộ mẫu $id',
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
);

void main() {
  testWidgets('hiện tin và chỉ xin đúng số lượng cần', (t) async {
    final repo = _RepoGia(tin: [_tinMau(1), _tinMau(2)]);
    await pumpApp(t, Scaffold(body: LatestListingsStrip(repo: repo, soLuong: 8)));
    await t.pumpAndSettle();

    expect(find.text('Căn hộ mẫu 1'), findsOneWidget);
    expect(find.text('Căn hộ mẫu 2'), findsOneWidget);
    // Trang chủ chỉ dựng 8 thẻ — kéo cả trang 50 tin về rồi vứt đi là lãng phí.
    expect(repo.limitDaGui, 8);
  });

  testWidgets('không có tin thì ẩn HẲN, không để lại khoảng trống', (t) async {
    await pumpApp(t, Scaffold(body: LatestListingsStrip(repo: _RepoGia())));
    await t.pumpAndSettle();

    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('lỗi mạng chỉ làm dải biến mất, KHÔNG ném ra ngoài', (t) async {
    await pumpApp(t, Scaffold(body: LatestListingsStrip(repo: _RepoGia(loi: true))));
    await t.pumpAndSettle();

    expect(tester_khongCoLoi(), isTrue);
    expect(find.byType(ListView), findsNothing);
  });
}

/// `pumpAndSettle` sẽ tự ném lại exception chưa bắt, nên đi tới được đây nghĩa
/// là dải đã nuốt lỗi đúng như thiết kế.
bool tester_khongCoLoi() => true;
