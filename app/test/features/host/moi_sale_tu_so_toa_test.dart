import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/building_model.dart';
import 'package:house_booking/features/host/property/providers/building_provider.dart';
import 'package:house_booking/features/host/property/screens/building_list_screen.dart';
import 'package:provider/provider.dart';

import '../../helpers/pump_app.dart';

/// SỔ TOÀ NHÀ của chủ nhà: cái mã hiện ở đây phải là mã SALE nhập được.
///
/// Bug thật (09/09/2026): mỗi dòng toà in `claim_code` kèm nhãn **"Mã bàn
/// giao"**. Chủ nhà tự dựng "Tòa A", đọc nhãn đó, chép `F7DU3ZUR` gửi cho sale.
/// Sale nhập vào màn "Nhận toà từ chủ nhà" và nhận *"Mã không đúng hoặc đã
/// được dùng."* — vì màn đó tra `ma_moi_sale`, mã đúng là `U7AZV3ZS`.
///
/// Hai mã tám ký tự, cùng bảng chữ, ngược chiều nhau:
///   `claim_code`  → ai nhập cũng thành CHỦ SỞ HỮU toà
///   `ma_moi_sale` → ai nhập cũng thành SALE PHỤ TRÁCH
///
/// Nên màn này không in mã nào cả: nó mở hộp thoại sinh `ma_moi_sale`.
class _ProviderGia extends BuildingProvider {
  _ProviderGia(this._ds);

  final List<BuildingModel> _ds;

  @override
  List<BuildingModel> get buildings => _ds;

  @override
  bool get isLoading => false;

  @override
  String? get error => null;

  @override
  Future<void> fetchBuildings() async {}
}

BuildingModel _toa({
  required int id,
  required String ten,
  int? saleId,
  String? claimCode = 'F7DU3ZUR',
}) => BuildingModel(
  id: id,
  hostId: 62,
  saleId: saleId,
  name: ten,
  address: 'Thượng Lý',
  city: 'Tp Hải Phòng',
  district: 'Hồng Bàng',
  ward: '',
  claimCode: claimCode,
  createdAt: DateTime(2026, 9, 9),
  updatedAt: DateTime(2026, 9, 9),
);

Future<void> _dung(WidgetTester t, List<BuildingModel> ds) async {
  t.view.physicalSize = const Size(500, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await pumpApp(
    t,
    // Màn này CỐ Ý không có Scaffold — nó sống nhúng trong tab của chủ nhà.
    ChangeNotifierProvider<BuildingProvider>.value(
      value: _ProviderGia(ds),
      child: const Scaffold(body: BuildingListScreen()),
    ),
    auth: SignedInAuthProvider(id: 62, ten: 'Vũ Đình Văn'),
  );
  await t.pump();
}

void main() {
  testWidgets('KHÔNG in mã bàn giao ra danh sách nữa', (t) async {
    await _dung(t, [_toa(id: 6, ten: 'Tòa A')]);
    // Nhãn cũ và mã thật đều phải biến mất — đó là chìa khoá của chính toà này.
    expect(find.textContaining('Mã bàn giao'), findsNothing);
    expect(find.textContaining('F7DU3ZUR'), findsNothing);
  });

  testWidgets('toà CHƯA có sale → hiện lối mời sale', (t) async {
    await _dung(t, [_toa(id: 6, ten: 'Tòa A')]);
    expect(find.text('Mời sale'), findsOneWidget);
  });

  testWidgets('toà ĐÃ có sale → không mời nữa ở danh sách', (t) async {
    // Vẫn mời thêm được từ sổ phòng của toà (một toà nhiều sale là hợp lệ);
    // danh sách chỉ nhắc việc còn thiếu.
    await _dung(t, [_toa(id: 5, ten: 'Toà Hoa Sữa', saleId: 58)]);
    expect(find.text('Mời sale'), findsNothing);
  });

  testWidgets('bấm mời sale → mở hộp thoại MÃ MỜI, không phải mã bàn giao', (
    t,
  ) async {
    await _dung(t, [_toa(id: 6, ten: 'Tòa A')]);
    await t.tap(find.text('Mời sale'));
    await t.pump();
    expect(find.text('Mời sale phụ trách'), findsOneWidget);
  });

  testWidgets('nhiều toà → mỗi toà tự quyết hiện hay không', (t) async {
    await _dung(t, [
      _toa(id: 6, ten: 'Tòa A'),
      _toa(id: 5, ten: 'Toà Hoa Sữa', saleId: 58),
      _toa(id: 4, ten: 'Toà S1.05', saleId: 58),
    ]);
    expect(find.text('Mời sale'), findsOneWidget);
  });
}
