import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/core/config/brand.dart';
import 'package:house_booking/features/onboarding/service_hub_screen.dart';

import '../helpers/pump_app.dart';

/// Trang chủ tổng hợp dịch vụ: phải dựng được KHÔNG cần mạng (mọi lời gọi API
/// hỏng chỉ làm ẩn mục đó), và KHÔNG còn nút chờ "Bỏ qua"/"Vào ứng dụng" —
/// đây là màn home nằm trong tab, không phải màn chắn lối vào.
void main() {
  testWidgets('dựng được khi API lỗi — hiện logo + 4 ô hành động',
      (tester) async {
    await pumpApp(tester, const ServiceHubScreen());
    await tester.pump(); // để _load() hoàn tất (mọi future lỗi → rỗng)

    // Logo là RichText hai mảnh (Brand.logoPart1 + logoPart2) → tìm theo span,
    // không phải find.text. Đọc từ `Brand` để đổi tên thương hiệu không làm
    // đỏ test.
    expect(
      find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == Brand.name.replaceAll(' ', '')),
      findsOneWidget,
    );
    expect(find.text('Mua bán · Cho thuê'), findsOneWidget);
    expect(find.text('Đăng tin nhu cầu'), findsOneWidget);
    expect(find.text('Thông tin và quy hoạch'), findsOneWidget);
    expect(find.text('Dịch vụ'), findsOneWidget);
  });

  testWidgets('KHÔNG còn nút "Bỏ qua" / "Vào ứng dụng"', (tester) async {
    await pumpApp(tester, const ServiceHubScreen());
    await tester.pump();

    expect(find.text('Bỏ qua'), findsNothing);
    expect(find.text('Vào ứng dụng'), findsNothing);
  });

  testWidgets('ô "Đăng tin nhu cầu" chuyển sang tab Tin tức', (tester) async {
    // Trước đây ô này mở màn "Bạn muốn đăng gì?" được push lên navigator GỐC,
    // nên màn đó nổi trên MỌI tab: bấm về Trang chủ vẫn thấy nó đè lên. Nay ô
    // chỉ đổi tab, việc đăng tin đi bằng nút trong màn Mua bán · Cho thuê.
    var sangTinTuc = 0;
    await pumpApp(tester, ServiceHubScreen(onOpenNews: () => sangTinTuc++));
    await tester.pump();

    await tester.tap(find.text('Đăng tin nhu cầu'));
    await tester.pump();

    expect(sangTinTuc, 1);
  });
}
