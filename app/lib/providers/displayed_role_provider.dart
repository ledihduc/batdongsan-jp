/// Computes [DisplayedRole] from AuthProvider (auth role) and
/// DelegationProvider (active operator delegations) with priority:
///
///   admin > operator (if hasActiveDelegation) > host > guest
///
/// Tenant is a separate axis (tenant JWT claim, backend U2) — until U2 lands
/// this provider never returns [DisplayedRole.tenant].
///
/// See docs/role-model.md for the full derivation matrix.
library;

import 'package:flutter/foundation.dart';
import 'package:house_booking/core/models/displayed_role.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/providers/delegation_provider.dart';

class DisplayedRoleProvider with ChangeNotifier {
  DisplayedRoleProvider({
    required AuthProvider auth,
    required DelegationProvider delegation,
  })  : _auth = auth,
        _delegation = delegation,
        _current = _compute(auth, delegation) {
    _auth.addListener(_onDepChanged);
    _delegation.addListener(_onDepChanged);
  }

  AuthProvider _auth;
  DelegationProvider _delegation;
  DisplayedRole _current;

  DisplayedRole get current => _current;

  /// True when >1 displayed role is available (drives conditional persona
  /// toggle per Q10 lock). Admins never see toggle (Q3), so we exclude them.
  bool get hasMultipleRolesAvailable {
    final role = _auth.currentUser?.role;
    if (role == 'admin') return false;
    final hasDelegation = _delegation.myDelegationsAsOperator
        .any((d) => d.isActive);
    if (hasDelegation) return true;
    return role == 'host';
  }

  /// Called by ProxyProvider when the dependency instance is swapped (rare —
  /// providers are singletons in this app). Kept for correctness.
  void updateDeps({
    required AuthProvider auth,
    required DelegationProvider delegation,
  }) {
    if (!identical(_auth, auth)) {
      _auth.removeListener(_onDepChanged);
      _auth = auth;
      _auth.addListener(_onDepChanged);
    }
    if (!identical(_delegation, delegation)) {
      _delegation.removeListener(_onDepChanged);
      _delegation = delegation;
      _delegation.addListener(_onDepChanged);
    }
    _recompute();
  }

  void _onDepChanged() => _recompute();

  void _recompute() {
    final next = _compute(_auth, _delegation);
    if (next != _current) {
      _current = next;
      notifyListeners();
    }
  }

  static DisplayedRole _compute(
    AuthProvider auth,
    DelegationProvider delegation,
  ) {
    final role = auth.currentUser?.role;
    final hasActiveDelegation = delegation.myDelegationsAsOperator
        .any((d) => d.isActive);
    return derive(
      authRole: role,
      hasActiveDelegation: hasActiveDelegation,
      hasTenantJwt: false, // U2 deferred
    );
  }

  /// Pure derivation — exposed for unit tests and for future callers that
  /// have the primitives without provider instances.
  ///
  /// Priority: admin > operator (delegation) > host > guest.
  /// Tenant JWT (U2) → tenant, but only when auth role is guest and no
  /// active delegation (matches role-model.md derivation matrix row 5).
  static DisplayedRole derive({
    required String? authRole,
    required bool hasActiveDelegation,
    required bool hasTenantJwt,
  }) {
    if (authRole == null) return DisplayedRole.guest;
    if (authRole == 'admin') return DisplayedRole.admin;
    if (hasActiveDelegation) return DisplayedRole.operator_;
    if (authRole == 'host') return DisplayedRole.host;
    if (hasTenantJwt) return DisplayedRole.tenant;
    return DisplayedRole.guest;
  }

  @override
  void dispose() {
    _auth.removeListener(_onDepChanged);
    _delegation.removeListener(_onDepChanged);
    super.dispose();
  }
}
