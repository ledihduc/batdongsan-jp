/// Interface for APPI consent + data subject rights operations.
///
/// Backend endpoints: POST /api/jp/consent, GET /api/jp/consent,
/// DELETE /api/jp/consent/:purpose, POST /api/jp/consent/export,
/// POST /api/jp/consent/delete-request.
library;

import 'package:house_booking/features/consent/models/consent_purpose.dart';

abstract interface class IConsentRepository {
  /// Fetch all consent records for the current user.
  Future<List<ConsentRecord>> listConsents();

  /// Grant consent for a list of purposes.
  Future<List<ConsentRecord>> grantConsents(ConsentGrantRequest request);

  /// Revoke consent for a single purpose.
  /// Required purposes cannot be revoked via this method.
  Future<void> revokeConsent(ConsentPurpose purpose);

  /// Request a personal-data export job.
  /// Returns the job ID; caller can poll [getExportStatus] to track progress.
  Future<String> requestExport();

  /// Poll status of an export job.
  /// Returns: 'processing' | 'ready' | 'failed'
  Future<({String status, String? downloadUrl})> getExportStatus(String jobId);

  /// Request personal data deletion (30-day cooling-off applies).
  Future<void> requestDeletion();
}
