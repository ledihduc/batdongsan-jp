import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/sale_link_api.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/models/building_model.dart';
import 'package:house_booking/features/guest/sale/link_sale_screen.dart';

/// Luật của màn này: **phải tra mã và thấy sale là ai TRƯỚC khi liên kết**.
/// Liên kết mở quyền cho người lạ chạm vào phòng của mình.
class _ApiGia extends SaleLinkApi {
  const _ApiGia({this.sale, this.noTraMa = false});

  final SaleTomTat? sale;
  final bool noTraMa;

  @override
  Future<List<BuildingModel>> toaCuaToi() async => [
    _toa(10, 'Toà A'),
    _toa(20, 'Toà B'),
  ];

  @override
  Future<SaleTomTat> traMa(String code, {required int buildingId}) async {
    if (noTraMa) throw Exception('không tìm thấy');
    return sale!;
  }

  @override
  Future<LienKet> lienKet(String code, {required int buildingId}) async =>
      const LienKet(
        id: 1,
        saleId: 9,
        ownerId: 2,
        tenDoiPhuong: 'Sale A',
        trangThai: 'active',
      );
}

class _PickerApi extends _ApiGia {
  _PickerApi({
    this.empty = false,
    this.failLoading = false,
    this.pendingPreview,
    this.failLink = false,
  }) : super(
         sale: const SaleTomTat(saleId: 9, ten: 'Trần Nga', daLienKet: false),
       );

  final bool empty;
  bool failLoading;
  final bool failLink;
  final Completer<SaleTomTat>? pendingPreview;
  final previews = <(String, int)>[];
  final links = <(String, int)>[];

  @override
  Future<List<BuildingModel>> toaCuaToi() async {
    if (failLoading) throw Exception('offline');
    return empty ? [] : super.toaCuaToi();
  }

  @override
  Future<SaleTomTat> traMa(String code, {required int buildingId}) async {
    previews.add((code, buildingId));
    return pendingPreview != null ? pendingPreview!.future : sale!;
  }

  @override
  Future<LienKet> lienKet(String code, {required int buildingId}) async {
    links.add((code, buildingId));
    if (failLink) throw ApiException(409, 'Toà nhà đã có sale.');
    return super.lienKet(code, buildingId: buildingId);
  }
}

BuildingModel _toa(int id, String name) => BuildingModel(
  id: id,
  hostId: 2,
  name: name,
  address: '',
  city: '',
  district: '',
  ward: '',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<void> _chonToa(WidgetTester t, [String ten = 'Toà A']) async {
  await t.tap(find.byType(DropdownButtonFormField<int>));
  await t.pumpAndSettle();
  await t.tap(find.text(ten).last);
  await t.pumpAndSettle();
}

Future<void> _dung(WidgetTester t, SaleLinkApi api) async {
  await t.pumpWidget(MaterialApp(home: LinkSaleScreen(api: api)));
  await t.pumpAndSettle();
}

void main() {
  const sale = SaleTomTat(saleId: 9, ten: 'Trần Nga', daLienKet: false);

  testWidgets('chưa nhập đủ mã thì nút Tìm sale tắt', (t) async {
    await _dung(t, const _ApiGia(sale: sale));
    final nut = t.widget<InkWell>(
      find
          .ancestor(of: find.text('Tìm sale'), matching: find.byType(InkWell))
          .first,
    );
    expect(nut.onTap, isNull);
  });

  testWidgets('tra mã xong mới hiện nút liên kết, kèm tên sale', (t) async {
    await _dung(t, const _ApiGia(sale: sale));
    // Trước khi tra: không có nút liên kết nào.
    expect(find.textContaining('Liên kết với Trần Nga'), findsNothing);

    await _chonToa(t);
    await t.enterText(find.byType(TextField), 'SL-8K4D2Q');
    await t.pumpAndSettle();
    await t.tap(find.text('Tìm sale'));
    await t.pumpAndSettle();

    expect(find.text('Trần Nga'), findsOneWidget);
    expect(find.text('Liên kết với Trần Nga'), findsOneWidget);
  });

  testWidgets('đủ mã nhưng chưa chọn toà thì không tra được', (t) async {
    await _dung(t, const _ApiGia(sale: sale));
    await t.enterText(find.byType(TextField), 'SL-8K4D2Q');
    await t.pumpAndSettle();
    final nut = t.widget<InkWell>(
      find
          .ancestor(of: find.text('Tìm sale'), matching: find.byType(InkWell))
          .first,
    );
    expect(nut.onTap, isNull);
  });

  testWidgets('đổi toà hoặc mã thì phải tra sale lại', (t) async {
    await _dung(t, const _ApiGia(sale: sale));
    await _chonToa(t);
    await t.enterText(find.byType(TextField), 'SL-8K4D2Q');
    await t.pumpAndSettle();
    await t.tap(find.text('Tìm sale'));
    await t.pumpAndSettle();
    expect(find.text('Trần Nga'), findsOneWidget);
    await _chonToa(t, 'Toà B');
    expect(find.text('Trần Nga'), findsNothing);
    await t.tap(find.text('Tìm sale'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'SL-ZZZZZZ');
    await t.pumpAndSettle();
    expect(find.text('Trần Nga'), findsNothing);
  });

  testWidgets('mã sai thì báo lỗi, không hiện nút liên kết', (t) async {
    await _dung(t, const _ApiGia(noTraMa: true));
    await _chonToa(t);
    await t.enterText(find.byType(TextField), 'SL-ZZZZZZ');
    await t.pumpAndSettle();
    await t.tap(find.text('Tìm sale'));
    await t.pumpAndSettle();
    expect(find.textContaining('Không tra được mã'), findsOneWidget);
    // 'Liên kết với sale' là tiêu đề màn — chỉ được có đúng nó, không có nút.
    expect(find.textContaining('Liên kết với'), findsOneWidget);
    expect(find.text('Liên kết với sale'), findsOneWidget);
  });

  testWidgets('đã liên kết rồi thì không cho bấm lần nữa', (t) async {
    await _dung(
      t,
      const _ApiGia(
        sale: SaleTomTat(saleId: 9, ten: 'Trần Nga', daLienKet: true),
      ),
    );
    await _chonToa(t);
    await t.enterText(find.byType(TextField), 'SL-8K4D2Q');
    await t.pumpAndSettle();
    await t.tap(find.text('Tìm sale'));
    await t.pumpAndSettle();
    expect(
      find.text('Toà nhà này đã liên kết với sale này rồi.'),
      findsOneWidget,
    );
    expect(find.textContaining('Liên kết với Trần Nga'), findsNothing);
  });

  testWidgets('chưa có toà thì hướng dẫn tạo hoặc nhận bàn giao', (t) async {
    final api = _PickerApi(empty: true);
    await _dung(t, api);
    expect(find.textContaining('Bạn chưa có toà nhà'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    await t.enterText(find.byType(TextField), 'SL-ABC234');
    await t.pumpAndSettle();
    await t.tap(find.text('Tìm sale'));
    expect(api.previews, isEmpty);
  });

  testWidgets('tải toà lỗi có thể thử lại rồi chọn toà', (t) async {
    final api = _PickerApi(failLoading: true);
    await _dung(t, api);
    expect(find.textContaining('Không tải được toà nhà'), findsOneWidget);
    api.failLoading = false;
    await t.tap(find.text('Thử lại'));
    await t.pumpAndSettle();
    await _chonToa(t, 'Toà B');
    expect(find.textContaining('Không tải được toà nhà'), findsNothing);
  });

  testWidgets('đang tra thì khoá mã và toà, chỉ gửi một yêu cầu', (t) async {
    final pending = Completer<SaleTomTat>();
    final api = _PickerApi(pendingPreview: pending);
    await _dung(t, api);
    await _chonToa(t, 'Toà B');
    await t.enterText(find.byType(TextField), 'SL-ABC234');
    await t.pumpAndSettle();
    await t.tap(find.text('Tìm sale'));
    await t.pump();
    expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
      t
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .onChanged,
      isNull,
    );
    expect(api.previews, [('SL-ABC234', 20)]);
    pending.complete(sale);
    await t.pumpAndSettle();
    expect(find.text('Liên kết với Trần Nga'), findsOneWidget);
    expect(t.widget<TextField>(find.byType(TextField)).enabled, isTrue);
  });

  testWidgets('xác nhận gửi đúng mã và toà đã xem, trả kết quả thành công', (
    t,
  ) async {
    final api = _PickerApi();
    bool? result;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => LinkSaleScreen(api: api)),
                );
              },
              child: const Text('Mở liên kết'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Mở liên kết'));
    await t.pumpAndSettle();
    await _chonToa(t, 'Toà B');
    await t.enterText(find.byType(TextField), 'sl-abc234');
    await t.pumpAndSettle();
    await t.tap(find.text('Tìm sale'));
    await t.pumpAndSettle();
    expect(api.links, isEmpty);
    await t.ensureVisible(find.text('Liên kết với Trần Nga'));
    await t.tap(find.text('Liên kết với Trần Nga'));
    await t.pumpAndSettle();
    expect(api.previews, [('SL-ABC234', 20)]);
    expect(api.links, [('SL-ABC234', 20)]);
    expect(result, isTrue);
    expect(find.text('Đã liên kết với Trần Nga'), findsOneWidget);
  });

  testWidgets('xung đột liên kết hiện lỗi và giữ toà đã chọn', (t) async {
    final api = _PickerApi(failLink: true);
    await _dung(t, api);
    await _chonToa(t, 'Toà B');
    await t.enterText(find.byType(TextField), 'SL-ABC234');
    await t.pumpAndSettle();
    await t.tap(find.text('Tìm sale'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Liên kết với Trần Nga'));
    await t.tap(find.text('Liên kết với Trần Nga'));
    await t.pumpAndSettle();
    expect(find.text('Toà nhà đã có sale.'), findsOneWidget);
    expect(find.text('Toà B'), findsOneWidget);
    expect(api.links, [('SL-ABC234', 20)]);
  });
}
