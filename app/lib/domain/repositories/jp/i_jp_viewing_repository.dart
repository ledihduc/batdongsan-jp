/// Interface for JP 内見 (viewing) data access.
library;

import 'package:house_booking/data/models/jp/jp_viewing.dart';

abstract interface class IJpViewingRepository {
  /// Tenant creates a viewing request with up to 3 proposed slots.
  Future<JpViewing> create({
    required int listingId,
    required List<JpViewingSlot> proposedSlots,
    String? message,
  });

  /// Fetch a viewing by its ID.
  Future<JpViewing> getById(int viewingId);

  /// Fetch viewings for the current tenant.
  Future<List<JpViewing>> listForTenant(int tenantId);

  /// Fetch incoming viewing requests for the agent's assigned listings.
  Future<List<JpViewing>> listForAgent(int agentId);

  /// Agent confirms one of the proposed slots.
  Future<JpViewing> confirmSlot({
    required int viewingId,
    required JpViewingSlot slot,
  });

  /// Agent or tenant rejects/cancels a viewing request.
  Future<JpViewing> cancel(int viewingId);
}
