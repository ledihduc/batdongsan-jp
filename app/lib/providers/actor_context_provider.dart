/// Actor context provider — tracks which delegation context is currently active.
///
/// CRITICAL INVARIANT: This provider is NEVER persisted to SharedPreferences or
/// SecureStorage. It is request-scoped and resets on every cold-start.
/// See AC-15, NFR-07, TL-8 in the delegation plan.
///
/// The ApiClient interceptor reads [currentDelegationId] on every request.
/// When non-null it injects `X-Acting-As-Delegation-Id: <uuid>` into headers.
library;

import 'package:flutter/foundation.dart';
import 'package:house_booking/data/models/operator_delegation_model.dart';

/// Holds the current "acting-as" operator delegation context.
///
/// Usage:
/// ```dart
/// final actor = context.read<ActorContextProvider>();
/// actor.enterContext(delegation);
/// actor.clear();
/// ```
class ActorContextProvider with ChangeNotifier {
  OperatorDelegationModel? _currentDelegation;

  /// The delegation ID to inject as `X-Acting-As-Delegation-Id` header.
  /// Null = user operates as themselves (no delegation context).
  String? get currentDelegationId => _currentDelegation?.id;

  /// Full delegation model for UI rendering (owner name, overlay banner, etc.).
  OperatorDelegationModel? get currentDelegation => _currentDelegation;

  /// True when operator is currently acting on behalf of an owner.
  bool get isActingAs => _currentDelegation != null;

  /// The owner's display name for the acting-as banner.
  String get actingAsOwnerName =>
      _currentDelegation?.ownerName ?? 'Chủ nhà';

  /// Enter delegation context. Sets delegation and notifies all listeners.
  /// ApiClient interceptor picks this up automatically on next request.
  ///
  /// Does NOT write to any persistent storage — request-scoped only (AC-15).
  void enterContext(OperatorDelegationModel delegation) {
    _currentDelegation = delegation;
    notifyListeners();
  }

  /// Clear delegation context. Called on:
  /// - User taps "Thoát" in acting-as banner
  /// - Hardware back to operator portfolio
  /// - 401 DELEGATION_REVOKED received (ApiClient clears via this method)
  /// - App cold start (default state is already null, explicit clear for mid-session use)
  void clear() {
    if (_currentDelegation == null) return;
    _disposeAllContextCaches();
    _currentDelegation = null;
    notifyListeners();
  }

  /// Update the cached delegation model — used when backend returns updated
  /// state (e.g. pause/resume changes delegation.status).
  void refresh(OperatorDelegationModel updated) {
    if (_currentDelegation?.id != updated.id) return;
    _currentDelegation = updated;
    notifyListeners();
  }

  /// Dispose all cached delegation-specific state on context exit.
  /// Prevents stale owner data from leaking after context switch (R7 mitigation).
  void _disposeAllContextCaches() {
    // Currently no separate caches — future: image cache eviction per owner.
    // Kept as explicit hook for R7 risk mitigation.
  }
}
