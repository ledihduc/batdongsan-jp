/// Interface for JP 入居申込 (tenant application) data access.
library;

import 'package:house_booking/data/models/jp/jp_application.dart';

abstract interface class IJpApplicationRepository {
  /// Fetch a single application by its ID.
  Future<JpApplication> getById(int applicationId);

  /// Fetch all applications submitted by the current tenant.
  Future<List<JpApplication>> listForTenant(int tenantId);

  /// Fetch pending applications for the agent's assigned listings.
  Future<List<JpApplication>> listForAgent(int agentId);

  /// Save (create or update) a draft application.
  ///
  /// The wizard persists each step as a partial update. If [id] is null,
  /// a new draft is created on the server.
  Future<JpApplication> saveDraft(JpApplication application);

  /// Submit a completed application (transitions from draft to submitted).
  Future<JpApplication> submit(int applicationId);

  /// Agent records a decision on an application.
  Future<JpApplicationReview> review(JpApplicationReview review);

  /// Tenant withdraws a submitted application.
  Future<JpApplication> withdraw(int applicationId);

  /// Request an upload URL for a document.
  ///
  /// Returns a map containing `upload_url` (presigned PUT URL) and
  /// `storage_key` to include in the [JpDocumentRef].
  Future<Map<String, String>> requestUploadUrl({
    required int applicationId,
    required String documentType,
    required String filename,
  });
}
