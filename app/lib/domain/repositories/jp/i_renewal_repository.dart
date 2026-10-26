/// Interface for JP lease renewal (更新) operations.
///
/// Backend endpoints: GET /api/jp/renewals/:id,
/// POST /api/jp/renewals/:id/confirm, POST /api/jp/renewals/:id/decline.
library;

import 'package:house_booking/data/models/jp/renewal.dart';

abstract interface class IRenewalRepository {
  /// Fetch a single renewal by ID.
  Future<JpRenewal> getRenewal(int renewalId);

  /// Confirm the renewal — returns updated record.
  Future<JpRenewal> confirmRenewal(int renewalId);

  /// Decline / request renegotiation — returns updated record.
  Future<JpRenewal> declineRenewal(int renewalId);
}
