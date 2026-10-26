/// Widget tests for [JpCheckoutScreen] — tab switching.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/checkout/jp_checkout_screen.dart';
import 'package:house_booking/features/checkout/repositories/mock_payment_repository.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('renders 3 payment tabs', (tester) async {
    final repo = MockPaymentRepository();
    await pumpApp(
      tester,
      JpCheckoutScreen(invoiceId: 1, repository: repo),
    );
    // Wait for invoice to load.
    await tester.pump(const Duration(milliseconds: 300));

    // All 3 tabs should be present.
    expect(find.text('コンビニ'), findsOneWidget);
    expect(find.text('振込'), findsOneWidget);
    expect(find.text('カード'), findsOneWidget);
  });

  testWidgets('switches to bank transfer tab without error', (tester) async {
    final repo = MockPaymentRepository();
    await pumpApp(
      tester,
      JpCheckoutScreen(invoiceId: 1, repository: repo),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('振込'));
    await tester.pumpAndSettle();

    // After tab switch, screen still rendered without crash.
    expect(find.byType(JpCheckoutScreen), findsOneWidget);
  });

  testWidgets('switches to card tab without error', (tester) async {
    final repo = MockPaymentRepository();
    await pumpApp(
      tester,
      JpCheckoutScreen(invoiceId: 1, repository: repo),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('カード'));
    await tester.pumpAndSettle();

    // After tab switch, screen still rendered without crash.
    expect(find.byType(JpCheckoutScreen), findsOneWidget);
  });
}
