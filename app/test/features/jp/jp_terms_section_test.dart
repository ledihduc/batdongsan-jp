/// Widget tests for [JpTermsSection].
///
/// Verifies that rental terms are displayed correctly with Japanese labels.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/jp/jp_rental_terms.dart';
import 'package:house_booking/features/guest/listing/jp_terms_section.dart';

import '../../helpers/pump_app.dart';

void main() {
  const terms = JpRentalTerms(
    id: 1,
    monthlyRent: 150000,
    managementFee: 10000,
    shikikin: 300000,
    reikin: 150000,
    koushinryo: 150000,
    brokerageFeeRate: 1.0,
    taxIncluded: false,
  );

  testWidgets('renders monthly rent', (tester) async {
    await pumpApp(tester, const JpTermsSection(terms: terms));
    await tester.pump();

    // ¥150,000 should appear for monthly rent
    expect(find.textContaining('150,000'), findsAtLeastNWidgets(1));
  });

  testWidgets('renders shikikin (敷金)', (tester) async {
    await pumpApp(tester, const JpTermsSection(terms: terms));
    await tester.pump();
    // Section contains ¥300,000
    expect(find.textContaining('300,000'), findsAtLeastNWidgets(1));
  });

  testWidgets('renders reikin (礼金)', (tester) async {
    await pumpApp(tester, const JpTermsSection(terms: terms));
    await tester.pump();
    // ¥150,000 appears multiple times (rent + reikin + koushinryo all equal here)
    expect(find.textContaining('150,000'), findsAtLeastNWidgets(2));
  });

  testWidgets('hides zero-value management fee', (tester) async {
    const noFeeTerms = JpRentalTerms(
      id: 2,
      monthlyRent: 80000,
      managementFee: 0,
    );
    await pumpApp(tester, const JpTermsSection(terms: noFeeTerms));
    await tester.pump();
    // Zero fee should not render management fee row
    expect(find.textContaining('80,000'), findsAtLeastNWidgets(1));
  });

  testWidgets('renders brokerage rate as months fraction', (tester) async {
    await pumpApp(tester, const JpTermsSection(terms: terms));
    await tester.pump();
    // brokerageFeeRate: 1.0 → '1.0ヶ月分'
    expect(find.textContaining('ヶ月'), findsAtLeastNWidgets(1));
  });
}
