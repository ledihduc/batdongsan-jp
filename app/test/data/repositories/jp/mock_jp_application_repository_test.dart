/// Unit tests for [MockJpApplicationRepository].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/jp/jp_application.dart';
import 'package:house_booking/data/repositories/jp/mock_jp_application_repository.dart';

JpApplication _makeApp({int id = 0}) => JpApplication(
      id: id,
      listingId: 9001,
      tenantId: 1,
      status: JpApplicationStatus.draft,
      applicantName: '山田 太郎',
      applicantPhone: '090-0000-0001',
      applicantEmail: 'taro@example.com',
    );

void main() {
  late MockJpApplicationRepository repo;

  setUp(() {
    repo = MockJpApplicationRepository();
  });

  test('saveDraft() with id=0 creates new application', () async {
    final app = await repo.saveDraft(_makeApp());
    expect(app.id, isPositive);
    expect(app.status, equals(JpApplicationStatus.draft));
  });

  test('getById() returns created application', () async {
    final created = await repo.saveDraft(_makeApp());
    final fetched = await repo.getById(created.id);
    expect(fetched.id, equals(created.id));
    expect(fetched.applicantName, equals('山田 太郎'));
  });

  test('submit() transitions status to submitted', () async {
    final created = await repo.saveDraft(_makeApp());
    final submitted = await repo.submit(created.id);
    expect(submitted.status, equals(JpApplicationStatus.submitted));
  });

  test('review() with approved sets approved status', () async {
    final created = await repo.saveDraft(_makeApp());
    await repo.submit(created.id);
    final review = await repo.review(JpApplicationReview(
      applicationId: created.id,
      decision: 'approved',
      note: '問題なし',
    ));
    expect(review.decision, equals('approved'));

    final updated = await repo.getById(created.id);
    expect(updated.status, equals(JpApplicationStatus.approved));
  });

  test('review() with rejected sets rejected status', () async {
    final created = await repo.saveDraft(_makeApp());
    await repo.submit(created.id);
    await repo.review(JpApplicationReview(
      applicationId: created.id,
      decision: 'rejected',
    ));
    final updated = await repo.getById(created.id);
    expect(updated.status, equals(JpApplicationStatus.rejected));
  });

  test('withdraw() transitions to withdrawn', () async {
    final created = await repo.saveDraft(_makeApp());
    await repo.submit(created.id);
    final withdrawn = await repo.withdraw(created.id);
    expect(withdrawn.status, equals(JpApplicationStatus.withdrawn));
  });

  test('requestUploadUrl() returns upload_url and storage_key', () async {
    final created = await repo.saveDraft(_makeApp());
    final result = await repo.requestUploadUrl(
      applicationId: created.id,
      documentType: 'id_card',
      filename: 'test.pdf',
    );
    expect(result['upload_url'], isNotNull);
    expect(result['storage_key'], isNotNull);
  });

  test('listForAgent() returns submitted/under_review applications', () async {
    final a = await repo.saveDraft(_makeApp());
    await repo.submit(a.id);
    final list = await repo.listForAgent(501);
    expect(list.any((app) => app.status == JpApplicationStatus.submitted), isTrue);
  });

  test('getById() throws when not found', () async {
    expect(() => repo.getById(99999), throwsA(isA<Exception>()));
  });
}
