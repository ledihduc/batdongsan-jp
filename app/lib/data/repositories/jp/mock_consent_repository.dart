/// In-memory mock for [IConsentRepository].
///
/// Resets on app restart. Sufficient for FE dev until /api/jp/consent is live.
library;

import 'package:house_booking/domain/repositories/jp/i_consent_repository.dart';
import 'package:house_booking/features/consent/models/consent_purpose.dart';

class MockConsentRepository implements IConsentRepository {
  final List<ConsentRecord> _store = [];
  int _nextId = 1;
  String? _exportJobId;
  bool _exportReady = false;

  @override
  Future<List<ConsentRecord>> listConsents() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_store);
  }

  @override
  Future<List<ConsentRecord>> grantConsents(ConsentGrantRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final granted = <ConsentRecord>[];
    for (final purpose in request.purposes) {
      // Remove any existing record for this purpose then add new one.
      _store.removeWhere((r) => r.purpose == purpose);
      final record = ConsentRecord(
        id: _nextId++,
        purpose: purpose,
        granted: true,
        policyVersion: request.policyVersion,
        grantedAt: DateTime.now().toIso8601String(),
      );
      _store.add(record);
      granted.add(record);
    }
    return granted;
  }

  @override
  Future<void> revokeConsent(ConsentPurpose purpose) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (isConsentPurposeRequired(purpose)) {
      throw Exception('Cannot revoke required consent: $purpose');
    }
    final idx = _store.indexWhere((r) => r.purpose == purpose && r.granted);
    if (idx == -1) return;
    final existing = _store[idx];
    _store[idx] = ConsentRecord(
      id: existing.id,
      purpose: existing.purpose,
      granted: false,
      policyVersion: existing.policyVersion,
      grantedAt: existing.grantedAt,
      revokedAt: DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<String> requestExport() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _exportJobId = 'export-mock-${DateTime.now().millisecondsSinceEpoch}';
    _exportReady = false;
    // Simulate async completion after a delay.
    Future<void>.delayed(const Duration(seconds: 3)).then((_) {
      _exportReady = true;
    });
    return _exportJobId!;
  }

  @override
  Future<({String status, String? downloadUrl})> getExportStatus(
      String jobId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (_exportReady) {
      return (
        status: 'ready',
        downloadUrl: 'https://mock-storage.local/exports/$jobId.zip',
      );
    }
    return (status: 'processing', downloadUrl: null);
  }

  @override
  Future<void> requestDeletion() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // Mock: clear all non-required consents.
    _store.clear();
  }
}
