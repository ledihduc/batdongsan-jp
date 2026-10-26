/// Route-level redirect guards keyed on [DisplayedRole].
///
/// Each guard returns:
///  * `null` — allow navigation
///  * a String — redirect target (usually `/` or `/login`)
///
/// Guards are a UX barrier only. Backend must re-verify every request; router
/// guards prevent accidental leakage, not privilege escalation.
///
/// See docs/role-model.md — the access matrix drives these functions.
library;

import 'package:house_booking/core/models/displayed_role.dart';

/// Path prefixes claimed by each shell. Kept as constants so tests can share.
const String kHostPrefix = '/host';
const String kAdminPrefix = '/admin';
const String kOperatorPrefix = '/operator';
const String kTenantPrefix = '/tenant';

String? guardHostRoutes({
  required String location,
  required DisplayedRole role,
  required bool isAuthenticated,
}) {
  if (!_matchesPrefix(location, kHostPrefix)) return null;
  if (!isAuthenticated) return '/login';
  return role.canAccessHost ? null : '/';
}

String? guardAdminRoutes({
  required String location,
  required DisplayedRole role,
  required bool isAuthenticated,
}) {
  if (!_matchesPrefix(location, kAdminPrefix)) return null;
  if (!isAuthenticated) return '/login';
  return role.canAccessAdmin ? null : '/';
}

String? guardOperatorRoutes({
  required String location,
  required DisplayedRole role,
  required bool isAuthenticated,
}) {
  if (!_matchesPrefix(location, kOperatorPrefix)) return null;
  if (!isAuthenticated) return '/login';
  return role.canAccessOperator ? null : '/';
}

/// Tenant guard — always redirects to `/` until backend U2 lands (tenant JWT
/// endpoint). Once U2 is live, tenant users authenticate via deep-link and
/// [DisplayedRole.tenant] passes this guard.
String? guardTenantRoutes({
  required String location,
  required DisplayedRole role,
  required bool isAuthenticated,
}) {
  if (!_matchesPrefix(location, kTenantPrefix)) return null;
  if (!isAuthenticated) return '/login';
  return role.canAccessTenant ? null : '/';
}

/// Post-login destination based on the highest role the user occupies.
///
/// Used by the router when an authenticated user hits `/login` — kick them to
/// the correct home instead of re-showing the login form.
String defaultHomeFor(DisplayedRole role) {
  switch (role) {
    case DisplayedRole.admin:
      return '/admin';
    case DisplayedRole.operator_:
      return '/operator';
    case DisplayedRole.tenant:
      return '/tenant';
    case DisplayedRole.host:
    case DisplayedRole.guest:
      return '/';
  }
}

/// Matches `path == prefix` OR `path == prefix + '/...'`.
///
/// Does NOT match `/hostess`, `/host-tools` — those would slip past a naive
/// `startsWith` check and let hostile routes bypass the guard.
bool _matchesPrefix(String path, String prefix) =>
    path == prefix || path.startsWith('$prefix/');
