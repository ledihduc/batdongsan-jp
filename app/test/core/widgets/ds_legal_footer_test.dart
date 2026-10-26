/// Widget tests for [DsLegalFooter].
///
/// Verifies all 5 required JP legal links are rendered.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/widgets/ds_legal_footer.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('DsLegalFooter', () {
    testWidgets('renders all 5 required JP legal links (vi locale)', (tester) async {
      // pumpApp defaults to vi locale; legal text values come from ARB.
      // 特定商取引法に基づく表記 is kept as-is (proper Japanese legal term) in all locales.
      await pumpApp(tester, const DsLegalFooter());
      await tester.pumpAndSettle();

      // 特定商取引法に基づく表記 — kept as JP text in all locales (legal proper name).
      expect(find.text('特定商取引法に基づく表記'), findsOneWidget);

      // legalFooterTerms in vi locale.
      expect(find.text('Điều khoản sử dụng'), findsOneWidget);

      // legalFooterPrivacy in vi locale.
      expect(find.text('Chính sách bảo mật'), findsOneWidget);

      // legalFooterAppiRequest in vi locale.
      expect(find.text('Yêu cầu công khai APPI'), findsOneWidget);

      // legalFooterOperator in vi locale.
      expect(find.text('Thông tin công ty'), findsOneWidget);
    });

    testWidgets('renders copyright notice', (tester) async {
      await pumpApp(tester, const DsLegalFooter());
      await tester.pumpAndSettle();

      // Copyright text should be present.
      expect(
        find.textContaining('Synora'),
        findsWidgets,
      );
    });

    testWidgets('renders without error inside Scaffold', (tester) async {
      // Smoke test: DsLegalFooter must not throw when mounted in a real Scaffold.
      await pumpApp(tester, const DsLegalFooter());
      await tester.pumpAndSettle();

      // No exception = test passes.
      expect(tester.takeException(), isNull);
    });
  });
}
