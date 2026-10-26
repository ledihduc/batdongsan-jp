import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/features/guest/browse/widgets/trade_filter_sheet.dart';

import '../../../helpers/pump_app.dart';

/// Bảng lọc của màn Mua/Bán.
///
/// Hai thứ dễ hỏng nhất, và cũng là hai thứ khiến bản lọc cũ khó dùng:
///   1. Mốc "không giới hạn" bị coi là một tiêu chí đang lọc → nút lọc sáng lên
///      dù thực ra không lọc gì.
///   2. Con số trên nút "Xem N tin" đếm bằng một bộ điều kiện khác với lúc nạp
///      danh sách → nút nói một đằng, kết quả một nẻo.
void main() {
  Future<TradeFilter?> _mo(
    WidgetTester t, {
    TradeFilter initial = const TradeFilter(),
    bool thangTy = false,
    required Future<int> Function(TradeFilter) dem,
  }) async {
    TradeFilter? ketQua;
    await pumpApp(
      t,
      Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              ketQua = await showModalBottomSheet<TradeFilter>(
                context: ctx,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => TradeFilterSheet(
                  initial: initial,
                  dem: dem,
                  thangTy: thangTy,
                ),
              );
            },
            child: const Text('mo'),
          ),
        ),
      ),
    );
    await t.tap(find.text('mo'));
    await t.pumpAndSettle();
    return ketQua;
  }

  group('TradeFilter — đếm tiêu chí', () {
    test('mặc định KHÔNG tính là đang lọc', () {
      expect(const TradeFilter().dangLoc, isFalse);
      expect(const TradeFilter().soTieuChi, 0);
    });

    test('mỗi tiêu chí đặt thêm được đếm đúng một lần', () {
      const f = TradeFilter(
        giaTu: 3000000,
        giaDen: 8000000,
        dienTich: AreaBucket.tu30den50,
        phongNgu: 2,
        sort: 'price_asc',
      );
      // Giá dù có hai đầu vẫn chỉ là MỘT tiêu chí.
      expect(f.soTieuChi, 4);
    });

    test('mốc diện tích dịch ra đúng khoảng số', () {
      const f = TradeFilter(dienTich: AreaBucket.tu50den80);
      expect(f.dienTichTu, 50);
      expect(f.dienTichDen, 80);

      const duoi = TradeFilter(dienTich: AreaBucket.duoi30);
      expect(duoi.dienTichTu, isNull);
      expect(duoi.dienTichDen, 30);

      const tren = TradeFilter(dienTich: AreaBucket.tren80);
      expect(tren.dienTichTu, 80);
      expect(tren.dienTichDen, isNull);
    });
  });

  testWidgets('nút áp dụng hiện SỐ TIN đếm được', (t) async {
    await _mo(t, dem: (_) async => 37);
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();

    expect(find.text('Xem 37 tin'), findsOneWidget);
  });

  testWidgets('không còn tin nào thì KHOÁ nút lại', (t) async {
    await _mo(t, dem: (_) async => 0);
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();

    expect(find.text('Không có tin nào khớp'), findsOneWidget);
    final nut = t.widget<FilledButton>(find.byType(FilledButton));
    expect(nut.onPressed, isNull, reason: 'bấm vào chỉ để nhận danh sách rỗng');
  });

  testWidgets('đổi mốc diện tích thì đếm lại', (t) async {
    var soLanDem = 0;
    await _mo(
      t,
      dem: (_) async {
        soLanDem++;
        return 12;
      },
    );
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();
    final truoc = soLanDem;

    await t.tap(find.text('50 – 80 m²'));
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();

    expect(soLanDem, greaterThan(truoc));
  });

  testWidgets('thang giá đổi đơn vị khi lọc tin BÁN', (t) async {
    await _mo(t, thangTy: true, dem: (_) async => 5);
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();

    // Tin bán tính bằng tỷ, không phải triệu.
    expect(find.textContaining('tỷ'), findsWidgets);
  });

  testWidgets('"Đặt lại" đưa mọi tiêu chí về mặc định', (t) async {
    await _mo(
      t,
      initial: const TradeFilter(phongNgu: 3, dienTich: AreaBucket.tren80),
      dem: (_) async => 9,
    );
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();

    await t.tap(find.text('Đặt lại'));
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();

    await t.tap(find.text('Xem 9 tin'));
    await t.pumpAndSettle();
    // Không còn tiêu chí nào → nút lọc ở màn cha sẽ tắt.
  });

  test('Tiêu chí nâng cao được ĐẾM vào soTieuChi', () {
    // Nếu quên cộng nhóm nâng cao vào đây thì người dùng lọc theo hướng nhà
    // xong nút lọc ở màn cha vẫn xám: danh sách ngắn lại mà không nói vì sao.
    expect(const TradeFilter().soTieuChi, 0);
    expect(const TradeFilter(huongNha: {'east'}).soTieuChi, 1);
    expect(const TradeFilter(chiUyTin: true).soTieuChi, 1);
    expect(const TradeFilter(diemDanhGia: 4).soTieuChi, 1);
    expect(const TradeFilter(saoChatLuong: 5).soTieuChi, 1);
    expect(const TradeFilter(loaiHinh: 3).soTieuChi, 1);
    expect(
      const TradeFilter(
        loaiHinh: 3,
        chiUyTin: true,
        huongNha: {'east', 'west'},
      ).soTieuChi,
      3,
    );
  });

  test('copyWith xoá được loại hình, và hướng nhà thay nguyên tập', () {
    const f = TradeFilter(loaiHinh: 3, huongNha: {'east'});
    expect(f.copyWith(xoaLoaiHinh: true).loaiHinh, isNull);
    // Truyền tập mới phải THAY, không gộp — nếu gộp thì bỏ tick một hướng sẽ
    // không có tác dụng.
    expect(f.copyWith(huongNha: const {'west'}).huongNha, {'west'});
  });

  testWidgets('Mục nâng cao mở SẴN khi bộ lọc vào đã có tiêu chí nâng cao', (
    t,
  ) async {
    await _mo(
      t,
      initial: const TradeFilter(chiUyTin: true),
      dem: (_) async => 4,
    );
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();

    await t.scrollUntilVisible(find.text('Hướng nhà (phong thuỷ)'), 200);
    await t.pumpAndSettle();

    expect(find.text('Hướng nhà (phong thuỷ)'), findsOneWidget);
    expect(find.text('Chỉ hiện nhà uy tín'), findsOneWidget);
  });

  testWidgets('Mục nâng cao ĐÓNG khi chưa lọc gì nâng cao', (t) async {
    await _mo(t, dem: (_) async => 4);
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();

    // Nút nằm cuối danh sách cuộn → phải kéo tới mới dựng.
    await t.scrollUntilVisible(find.text('Lọc nâng cao'), 200);
    await t.pumpAndSettle();

    expect(find.text('Lọc nâng cao'), findsOneWidget);
    expect(find.text('Hướng nhà (phong thuỷ)'), findsNothing);
  });

  test('bán kính KHÔNG được tính là bộ lọc khi chưa có toạ độ', () {
    // Chọn "quanh đây" mà chưa cấp quyền vị trí thì thực tế chưa lọc gì —
    // đếm vào soTieuChi là nút lọc sáng lên trong khi danh sách y nguyên.
    const chuaCo = TradeFilter(khuVuc: KhuVuc.quanhDay, banKinhKm: 5);
    expect(chuaCo.coToaDo, isFalse);
    expect(chuaCo.soTieuChi, 0);

    const daCo = TradeFilter(
      khuVuc: KhuVuc.quanhDay,
      lat: 19.8,
      lng: 105.77,
    );
    expect(daCo.coToaDo, isTrue);
    expect(daCo.soTieuChi, 1);
  });

  test('về "toàn bộ" thì xoá hẳn toạ độ cũ', () {
    const f = TradeFilter(khuVuc: KhuVuc.quanhDay, lat: 19.8, lng: 105.77);
    final ve = f.copyWith(khuVuc: KhuVuc.toanBo, xoaToaDo: true);
    // Giữ lại toạ độ thì lần sau bật "quanh đây" sẽ dùng vị trí của buổi khác.
    expect(ve.lat, isNull);
    expect(ve.coToaDo, isFalse);
  });

  testWidgets('mục Khu vực đứng ĐẦU bảng lọc', (t) async {
    await _mo(t, dem: (_) async => 5);
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();

    expect(find.text('Khu vực tìm kiếm'), findsOneWidget);
    expect(find.text('Quanh đây'), findsOneWidget);
    expect(find.text('Địa danh'), findsOneWidget);
  });

  testWidgets('chạm "Địa danh" thì hiện ô nhập và chip bán kính', (t) async {
    await _mo(t, dem: (_) async => 5);
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();

    await t.tap(find.text('Địa danh'));
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();

    expect(find.text('Bán kính'), findsOneWidget);
    expect(find.text('3 km'), findsWidgets);
  });
}
