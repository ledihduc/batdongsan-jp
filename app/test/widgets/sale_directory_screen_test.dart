import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/host_public_api.dart';
import 'package:house_booking/features/guest/broker/sale_directory_screen.dart';

class _FakeApi extends HostPublicApi {
  _FakeApi();

  final queries = <String>[];

  @override
  Future<PublicSalePage> sales({
    String query = '',
    int limit = 50,
    int offset = 0,
  }) async {
    queries.add(query);
    if (query == 'missing@hotmail.com') {
      return const PublicSalePage(items: [], total: 0);
    }
    return const PublicSalePage(
      total: 1,
      items: [
        {
          'id': 74,
          'name': 'Sale Demo',
          'bio': 'Tư vấn thuê nhà',
          'service_areas': ['Ba Đình'],
          'listing_count': 0,
          'verified': true,
        },
      ],
    );
  }
}

void main() {
  testWidgets('hiện toàn bộ Sale và tìm được bằng email', (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(MaterialApp(home: SaleDirectoryScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Tìm Sale'), findsWidgets);
    expect(find.text('Sale Demo'), findsOneWidget);
    expect(find.text('Chưa có tin công khai'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'sale@hotmail.com');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(api.queries, ['', 'sale@hotmail.com']);
    expect(find.text('Sale Demo'), findsOneWidget);
  });

  testWidgets('email không tồn tại có hướng dẫn rõ ràng', (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(MaterialApp(home: SaleDirectoryScreen(api: api)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'missing@hotmail.com');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Không tìm thấy Sale phù hợp'), findsOneWidget);
    expect(
      find.text('Hãy kiểm tra lại email và nhập đầy đủ địa chỉ.'),
      findsOneWidget,
    );
  });
}
