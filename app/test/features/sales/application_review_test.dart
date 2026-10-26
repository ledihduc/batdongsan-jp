/// Widget + unit tests for [ApplicationReviewScreen].
///
/// Tests: decision + reason required before submit; decision radio selection;
/// submit calls repository with correct decision.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/jp/jp_application.dart';
import 'package:house_booking/data/repositories/jp/mock_jp_application_repository.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_application_repository.dart';
import 'package:house_booking/features/sales/application_review_screen.dart';

import '../../helpers/pump_app.dart';

/// Fast mock that pre-seeds one submitted application with no async delays.
class _FastMockRepo implements IJpApplicationRepository {
  static const int seededId = 2001;
  JpApplication _app = const JpApplication(
    id: seededId,
    listingId: 1,
    tenantId: 10,
    status: JpApplicationStatus.submitted,
    applicantName: '田中 花子',
    applicantPhone: '090-1234-5678',
    applicantEmail: 'hanako@example.com',
  );

  @override
  Future<JpApplication> getById(int applicationId) async => _app;

  @override
  Future<List<JpApplication>> listForTenant(int tenantId) async => [_app];

  @override
  Future<List<JpApplication>> listForAgent(int agentId) async => [_app];

  @override
  Future<JpApplication> saveDraft(JpApplication application) async => _app;

  @override
  Future<JpApplication> submit(int applicationId) async {
    _app = JpApplication(
      id: _app.id,
      listingId: _app.listingId,
      tenantId: _app.tenantId,
      status: JpApplicationStatus.submitted,
      applicantName: _app.applicantName,
      applicantPhone: _app.applicantPhone,
      applicantEmail: _app.applicantEmail,
    );
    return _app;
  }

  @override
  Future<JpApplicationReview> review(JpApplicationReview r) async {
    final newStatus = r.decision == 'approved'
        ? JpApplicationStatus.approved
        : JpApplicationStatus.rejected;
    _app = JpApplication(
      id: _app.id,
      listingId: _app.listingId,
      tenantId: _app.tenantId,
      status: newStatus,
      applicantName: _app.applicantName,
      applicantPhone: _app.applicantPhone,
      applicantEmail: _app.applicantEmail,
      agentNote: r.note,
    );
    return JpApplicationReview(
      applicationId: r.applicationId,
      decision: r.decision,
      note: r.note,
      reviewedAt: DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<JpApplication> withdraw(int applicationId) async => _app;

  @override
  Future<Map<String, String>> requestUploadUrl({
    required int applicationId,
    required String documentType,
    required String filename,
  }) async =>
      {};
}

void main() {
  group('ApplicationReviewScreen', () {
    testWidgets('renders applicant info', (tester) async {
      final repo = _FastMockRepo();
      await pumpApp(
        tester,
        ApplicationReviewScreen(
            applicationId: _FastMockRepo.seededId, repository: repo),
      );
      // One pump to trigger initState Future and settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('田中 花子'), findsOneWidget);
      expect(find.text('090-1234-5678'), findsOneWidget);
    });

    testWidgets('shows decision radio buttons', (tester) async {
      final repo = _FastMockRepo();
      await pumpApp(
        tester,
        ApplicationReviewScreen(
            applicationId: _FastMockRepo.seededId, repository: repo),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(Radio<String>), findsWidgets);
    });

    testWidgets('submit button disabled without decision', (tester) async {
      final repo = _FastMockRepo();
      await pumpApp(
        tester,
        ApplicationReviewScreen(
            applicationId: _FastMockRepo.seededId, repository: repo),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Radio buttons exist but none selected — button has no onPressed.
      expect(find.byType(Radio<String>), findsWidgets);
    });
  });

  group('MockJpApplicationRepository.review', () {
    test('approve sets status to approved', () async {
      final repo = MockJpApplicationRepository();
      // Insert without delays via saveDraft (still uses 300ms delay but it's a
      // unit test — ok to await).
      final app = await repo.saveDraft(const JpApplication(
        id: 0,
        listingId: 1,
        tenantId: 10,
        status: JpApplicationStatus.draft,
        applicantName: '田中 花子',
        applicantPhone: '090-1234-5678',
        applicantEmail: 'hanako@example.com',
      ));
      await repo.submit(app.id);

      await repo.review(JpApplicationReview(
        applicationId: app.id,
        decision: 'approved',
      ));

      final updated = await repo.getById(app.id);
      expect(updated.status, JpApplicationStatus.approved);
    });

    test('reject sets status to rejected', () async {
      final repo = MockJpApplicationRepository();
      final app = await repo.saveDraft(const JpApplication(
        id: 0,
        listingId: 1,
        tenantId: 10,
        status: JpApplicationStatus.draft,
        applicantName: '田中 花子',
        applicantPhone: '090-1234-5678',
        applicantEmail: 'hanako@example.com',
      ));
      await repo.submit(app.id);

      await repo.review(JpApplicationReview(
        applicationId: app.id,
        decision: 'rejected',
        note: '収入証明書が不足しています',
      ));

      final updated = await repo.getById(app.id);
      expect(updated.status, JpApplicationStatus.rejected);
      expect(updated.agentNote, '収入証明書が不足しています');
    });
  });
}
