/// Displayed role — the UI-facing role identity computed from auth role,
/// active delegations, and (when backend U2 lands) tenant JWT claim.
///
/// Separate from `AuthProvider.currentUser.role` (auth persistent identity)
/// and `PersonaMode` (guest↔host UI mode toggle inside GuestShell).
///
/// Priority order when the user has multiple qualifying dimensions:
///   admin > operator (if hasActiveDelegation) > host > guest
///   tenant is a special case — derived from tenant JWT claim only
///
/// See `docs/role-model.md` for the full matrix.
library;

enum DisplayedRole {
  guest,
  host,
  admin,
  // `operator` is reserved by Dart (operator overload keyword) — the trailing
  // underscore is intentional and matches the Phase 03 spec.
  operator_,
  tenant;

  /// Vietnamese label used in UI badges, banners, profile section headers.
  String get vietnameseLabel {
    switch (this) {
      case DisplayedRole.admin:
        return 'Quản trị';
      case DisplayedRole.host:
        return 'Chủ nhà';
      case DisplayedRole.operator_:
        return 'Đại lý quản lý';
      case DisplayedRole.tenant:
        return 'Người thuê';
      case DisplayedRole.guest:
        return 'Khách thuê';
    }
  }

  /// Host-scoped screens (post house, my listings, buildings, contracts,
  /// analytics, billing). Admin inherits host access.
  bool get canAccessHost =>
      this == DisplayedRole.host || this == DisplayedRole.admin;

  /// Admin console — user management, approval decisions, delegation audit.
  bool get canAccessAdmin => this == DisplayedRole.admin;

  /// Operator workspace — acting-as banner, portfolio switcher.
  bool get canAccessOperator => this == DisplayedRole.operator_;

  /// Tenant home — contract view, invoice, report unauthorized.
  bool get canAccessTenant => this == DisplayedRole.tenant;
}
