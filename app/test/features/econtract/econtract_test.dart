/// Unit tests for eContract model + widget tests for EcontractSigningScreen.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/econtract/econtract_signing_screen.dart';
import 'package:house_booking/features/econtract/models/econtract.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('Econtract.fromJson', () {
    test('parses pending status', () {
      final json = {
        'id': 1,
        'application_id': 2001,
        'status': 'pending',
        'signing_url':
            'https://app.cloudsign.jp/documents/doc-id/sign',
      };
      final c = Econtract.fromJson(json);
      expect(c.id, 1);
      expect(c.status, EcontractStatus.pending);
      expect(c.signingUrl, isNotNull);
    });

    test('parses signed status', () {
      final json = {
        'id': 2,
        'application_id': 2001,
        'status': 'signed',
        'download_url': 'https://storage.example.com/signed.pdf',
        'signed_at': '2026-10-15T10:00:00Z',
      };
      final c = Econtract.fromJson(json);
      expect(c.status, EcontractStatus.signed);
      expect(c.downloadUrl, isNotNull);
    });

    test('unknown status defaults to pending', () {
      final json = {
        'id': 3,
        'application_id': 2001,
        'status': 'invalid',
      };
      final c = Econtract.fromJson(json);
      expect(c.status, EcontractStatus.pending);
    });

    test('terminal statuses set', () {
      expect(
          kTerminalEcontractStatuses,
          containsAll([
            EcontractStatus.signed,
            EcontractStatus.expired,
            EcontractStatus.cancelled,
          ]));
      expect(kTerminalEcontractStatuses,
          isNot(contains(EcontractStatus.pending)));
    });
  });

  group('EcontractSigningScreen', () {
    testWidgets('renders without error when pending', (tester) async {
      final repo = MockEcontractRepository();
      await pumpApp(
        tester,
        EcontractSigningScreen(econtractId: 1, repository: repo),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Screen renders the signing screen (EcontractSigningScreen present).
      expect(find.byType(EcontractSigningScreen), findsOneWidget);
    });

    testWidgets('shows sign button (DsButton) when pending', (tester) async {
      final repo = MockEcontractRepository();
      await pumpApp(
        tester,
        EcontractSigningScreen(econtractId: 1, repository: repo),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Screen renders with at least one DsButton (sign / open external).
      expect(find.byType(DsButton), findsWidgets);
    });
  });
}
