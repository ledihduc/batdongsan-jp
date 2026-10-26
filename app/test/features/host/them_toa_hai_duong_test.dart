/// "+ THÊM TOÀ NHÀ" phải hỏi ĐƯỜNG NÀO trước.
///
/// Hai đường dẫn tới hai trạng thái khác hẳn nhau:
///  * **Có mã của sale** — toà, phòng, có khi cả tin đăng đã dựng sẵn. Nhập mã
///    là nhận lại công việc đó.
///  * **Tự tạo mới** — chưa ai làm gì.
///
/// Trước đây nút này chỉ có đường thứ hai, nên chủ nhà được sale đưa mã cũng
/// phải tự tạo một toà TRÙNG, còn toà thật của sale nằm lại đó mồ côi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/services/moi_sale_api.dart';
import 'package:house_booking/features/host/property/widgets/chon_cach_them_toa.dart';
import 'package:house_booking/features/host/property/widgets/hop_thoai_ma_toa.dart';

import '../../helpers/pump_app.dart';

class _ApiGia extends MoiSaleApi {
  _ApiGia({this.hong = false});
  final String ma = 'ABCD2345';
  final bool hong;
  int soLanSinh = 0;

  @override
  Future<String> sinhMa(int buildingId) async {
    soLanSinh++;
    if (hong) throw Exception('mất mạng');
    return ma;
  }
}

void main() {
  group('chọn cách thêm toà', () {
    testWidgets('hiện ĐỦ hai đường, nói rõ khác nhau ở đâu', (t) async {
      CachThemToa? chon;
      await pumpApp(
        t,
        Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => chon = await chonCachThemToa(ctx),
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('mở'));
      await t.pumpAndSettle();

      expect(find.text('Tôi có mã từ sale'), findsOneWidget);
      expect(find.text('Tự tạo toà mới'), findsOneWidget);
      // Mô tả phải nói ĐƯỢC GÌ, không phải lặp lại tiêu đề.
      expect(find.textContaining('đã dựng sẵn toà và phòng'), findsOneWidget);
      expect(chon, isNull);
    });

    testWidgets('chọn "có mã" trả về đúng nhánh nhapMa', (t) async {
      CachThemToa? chon;
      await pumpApp(
        t,
        Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => chon = await chonCachThemToa(ctx),
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('mở'));
      await t.pumpAndSettle();
      await t.tap(find.text('Tôi có mã từ sale'));
      await t.pumpAndSettle();
      expect(chon, CachThemToa.nhapMa);
    });

    testWidgets('chọn "tự tạo" trả về nhánh tuTao', (t) async {
      CachThemToa? chon;
      await pumpApp(
        t,
        Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => chon = await chonCachThemToa(ctx),
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('mở'));
      await t.pumpAndSettle();
      await t.tap(find.text('Tự tạo toà mới'));
      await t.pumpAndSettle();
      expect(chon, CachThemToa.tuTao);
    });
  });

  group('mã mời sale', () {
    Future<void> dung(WidgetTester t, _ApiGia api) async {
      await pumpApp(
        t,
        Scaffold(
          body: HopThoaiMaMoiSale(buildingId: 7, tenToa: 'Toà Hoa Sữa', api: api),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('hiện mã và nói rõ toà nào', (t) async {
      await dung(t, _ApiGia());
      expect(find.text('ABCD2345'), findsOneWidget);
      expect(find.textContaining('Toà Hoa Sữa'), findsOneWidget);
    });

    testWidgets('nói TRƯỚC rằng mã dùng một lần', (t) async {
      // Không nói thì chủ nhà gửi cho ba người rồi thắc mắc vì sao chỉ một
      // người vào được.
      await dung(t, _ApiGia());
      expect(find.textContaining('dùng một lần'), findsOneWidget);
    });

    testWidgets('có nút chép mã — mã 8 ký tự không ai muốn gõ lại', (t) async {
      await dung(t, _ApiGia());
      expect(find.byTooltip('Chép mã'), findsOneWidget);
    });

    testWidgets('sinh mã hỏng → báo lỗi, KHÔNG hiện ô mã trống', (t) async {
      await dung(t, _ApiGia(hong: true));
      expect(find.text('Không tạo được mã mời.'), findsOneWidget);
      expect(find.byTooltip('Chép mã'), findsNothing);
    });

    testWidgets('chỉ gọi API MỘT lần khi mở', (t) async {
      final api = _ApiGia();
      await dung(t, api);
      expect(api.soLanSinh, 1);
    });
  });
}
