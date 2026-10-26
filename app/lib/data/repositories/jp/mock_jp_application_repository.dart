/// Mock implementation of [IJpApplicationRepository].
///
/// In-memory store; resets on app restart.
library;

import 'package:house_booking/data/models/jp/jp_application.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_application_repository.dart';

class MockJpApplicationRepository implements IJpApplicationRepository {
  MockJpApplicationRepository();

  final List<JpApplication> _store = [];
  int _nextId = 2001;

  @override
  Future<JpApplication> getById(int applicationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _store.firstWhere(
      (a) => a.id == applicationId,
      orElse: () => throw Exception('Application $applicationId not found'),
    );
  }

  @override
  Future<List<JpApplication>> listForTenant(int tenantId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _store.where((a) => a.tenantId == tenantId).toList();
  }

  @override
  Future<List<JpApplication>> listForAgent(int agentId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _store
        .where((a) =>
            a.status == JpApplicationStatus.submitted ||
            a.status == JpApplicationStatus.underReview)
        .toList();
  }

  @override
  Future<JpApplication> saveDraft(JpApplication application) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (application.id == 0) {
      final draft = JpApplication(
        id: _nextId++,
        listingId: application.listingId,
        tenantId: application.tenantId,
        status: JpApplicationStatus.draft,
        applicantName: application.applicantName,
        applicantPhone: application.applicantPhone,
        applicantEmail: application.applicantEmail,
        employer: application.employer,
        guarantor: application.guarantor,
        emergencyContact: application.emergencyContact,
        documents: application.documents,
        message: application.message,
        createdAt: DateTime.now().toIso8601String(),
      );
      _store.add(draft);
      return draft;
    }
    final idx = _store.indexWhere((a) => a.id == application.id);
    if (idx == -1) throw Exception('Application ${application.id} not found');
    _store[idx] = application;
    return application;
  }

  @override
  Future<JpApplication> submit(int applicationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final idx = _store.indexWhere((a) => a.id == applicationId);
    if (idx == -1) throw Exception('Application $applicationId not found');
    final updated = JpApplication(
      id: _store[idx].id,
      listingId: _store[idx].listingId,
      tenantId: _store[idx].tenantId,
      status: JpApplicationStatus.submitted,
      applicantName: _store[idx].applicantName,
      applicantPhone: _store[idx].applicantPhone,
      applicantEmail: _store[idx].applicantEmail,
      employer: _store[idx].employer,
      guarantor: _store[idx].guarantor,
      emergencyContact: _store[idx].emergencyContact,
      documents: _store[idx].documents,
      message: _store[idx].message,
      createdAt: _store[idx].createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _store[idx] = updated;
    return updated;
  }

  @override
  Future<JpApplicationReview> review(JpApplicationReview r) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final idx = _store.indexWhere((a) => a.id == r.applicationId);
    if (idx != -1) {
      final newStatus = r.decision == 'approved'
          ? JpApplicationStatus.approved
          : JpApplicationStatus.rejected;
      _store[idx] = JpApplication(
        id: _store[idx].id,
        listingId: _store[idx].listingId,
        tenantId: _store[idx].tenantId,
        status: newStatus,
        applicantName: _store[idx].applicantName,
        applicantPhone: _store[idx].applicantPhone,
        applicantEmail: _store[idx].applicantEmail,
        employer: _store[idx].employer,
        guarantor: _store[idx].guarantor,
        emergencyContact: _store[idx].emergencyContact,
        documents: _store[idx].documents,
        agentNote: r.note,
        updatedAt: DateTime.now().toIso8601String(),
        createdAt: _store[idx].createdAt,
      );
    }
    return JpApplicationReview(
      applicationId: r.applicationId,
      decision: r.decision,
      note: r.note,
      reviewedAt: DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<JpApplication> withdraw(int applicationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final idx = _store.indexWhere((a) => a.id == applicationId);
    if (idx == -1) throw Exception('Application $applicationId not found');
    final updated = JpApplication(
      id: _store[idx].id,
      listingId: _store[idx].listingId,
      tenantId: _store[idx].tenantId,
      status: JpApplicationStatus.withdrawn,
      applicantName: _store[idx].applicantName,
      applicantPhone: _store[idx].applicantPhone,
      applicantEmail: _store[idx].applicantEmail,
      createdAt: _store[idx].createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _store[idx] = updated;
    return updated;
  }

  @override
  Future<Map<String, String>> requestUploadUrl({
    required int applicationId,
    required String documentType,
    required String filename,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // Stub — real env uses Supabase presigned URL.
    return {
      'upload_url': 'https://mock-storage.local/upload/$documentType/$filename',
      'storage_key': 'jp-apps/$applicationId/$documentType/$filename',
    };
  }
}
