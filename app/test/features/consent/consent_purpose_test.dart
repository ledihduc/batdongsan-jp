/// Unit tests for consent purpose model + mock repository.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/repositories/jp/mock_consent_repository.dart';
import 'package:house_booking/features/consent/models/consent_purpose.dart';

void main() {
  group('ConsentPurpose', () {
    test('serviceUse is required; others are optional', () {
      expect(isConsentPurposeRequired(ConsentPurpose.serviceUse), isTrue);
      expect(isConsentPurposeRequired(ConsentPurpose.marketing), isFalse);
      expect(isConsentPurposeRequired(ConsentPurpose.analytics), isFalse);
      expect(
          isConsentPurposeRequired(ConsentPurpose.dataSharingBroker), isFalse);
      expect(
          isConsentPurposeRequired(ConsentPurpose.dataSharingHoshou), isFalse);
    });

    test('wire value round-trips', () {
      for (final p in ConsentPurpose.values) {
        final wire = consentPurposeToWireValue(p);
        final back = consentPurposeFromWireValue(wire);
        expect(back, equals(p));
      }
    });

    test('unknown wire value defaults to serviceUse', () {
      final result = consentPurposeFromWireValue('unknown_purpose');
      expect(result, equals(ConsentPurpose.serviceUse));
    });
  });

  group('ConsentRecord.fromJson', () {
    test('parses correctly', () {
      final json = {
        'id': 42,
        'purpose': 'marketing',
        'granted': true,
        'policy_version': '2026-10',
        'granted_at': '2026-10-01T10:00:00Z',
      };
      final record = ConsentRecord.fromJson(json);
      expect(record.id, 42);
      expect(record.purpose, ConsentPurpose.marketing);
      expect(record.granted, isTrue);
      expect(record.policyVersion, '2026-10');
    });

    test('defaults granted to false when missing', () {
      final record = ConsentRecord.fromJson({
        'id': 1,
        'purpose': 'analytics',
        'policy_version': '2026-10',
      });
      expect(record.granted, isFalse);
    });
  });

  group('MockConsentRepository', () {
    late MockConsentRepository repo;

    setUp(() => repo = MockConsentRepository());

    test('starts empty', () async {
      final list = await repo.listConsents();
      expect(list, isEmpty);
    });

    test('grantConsents adds records', () async {
      final request = ConsentGrantRequest(
        purposes: [ConsentPurpose.serviceUse, ConsentPurpose.marketing],
        policyVersion: '2026-10',
      );
      final granted = await repo.grantConsents(request);
      expect(granted.length, 2);
      expect(granted.every((r) => r.granted), isTrue);

      final all = await repo.listConsents();
      expect(all.length, 2);
    });

    test('revokeConsent sets granted=false for optional purpose', () async {
      await repo.grantConsents(ConsentGrantRequest(
        purposes: [ConsentPurpose.marketing],
        policyVersion: '2026-10',
      ));

      await repo.revokeConsent(ConsentPurpose.marketing);

      final all = await repo.listConsents();
      final marketing = all.firstWhere(
          (r) => r.purpose == ConsentPurpose.marketing);
      expect(marketing.granted, isFalse);
      expect(marketing.revokedAt, isNotNull);
    });

    test('revokeConsent throws for required purpose', () async {
      await expectLater(
        repo.revokeConsent(ConsentPurpose.serviceUse),
        throwsA(isA<Exception>()),
      );
    });

    test('requestExport returns a job ID', () async {
      final jobId = await repo.requestExport();
      expect(jobId, isNotEmpty);
    });

    test('getExportStatus returns processing initially', () async {
      final jobId = await repo.requestExport();
      final result = await repo.getExportStatus(jobId);
      expect(result.status, 'processing');
      expect(result.downloadUrl, isNull);
    });
  });
}
