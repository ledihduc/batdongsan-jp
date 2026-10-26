import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/telemetry/analytics_service.dart';
import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/providers/auth_provider.dart';

/// Role-based access guard for host/admin/operator/tenant destructive actions
/// and screen-level gating.
///
/// Phase 01 scope — 3-role auth model (guest/host/admin). Operator/tenant
/// gated via `AuthProvider.currentUser.role` string check. Phase 03 will
/// upgrade this to `DisplayedRole` enum + `DisplayedRoleProvider`.
///
/// Not a security barrier — backend must re-verify all destructive endpoints.
class RoleGuard {
  const RoleGuard._();

  /// Returns true if the current user may perform host-level actions
  /// (own listings, contracts, buildings, delegate). Admin inherits host powers.
  static bool canHost(UserModel? user) {
    if (user == null) return false;
    return user.role == 'host' || user.role == 'admin';
  }

  /// Returns true if the current user is admin.
  static bool canAdmin(UserModel? user) {
    return user?.role == 'admin';
  }

  /// Reads [AuthProvider] from [context] without listening and applies [canHost].
  static bool canHostFromContext(BuildContext context) {
    return canHost(context.read<AuthProvider>().currentUser);
  }

  /// Reads [AuthProvider] from [context] without listening and applies [canAdmin].
  static bool canAdminFromContext(BuildContext context) {
    return canAdmin(context.read<AuthProvider>().currentUser);
  }

  /// Guards a destructive action. Returns true if allowed, or shows a snackbar
  /// and returns false when the user lacks host role.
  ///
  /// Prefer this over inline `if (role != 'host') return;` patterns to keep
  /// the denial UX and audit trail consistent.
  static bool enforceHost(
    BuildContext context, {
    String action = 'thực hiện thao tác này',
    VoidCallback? onDenied,
  }) {
    final user = context.read<AuthProvider>().currentUser;
    if (canHost(user)) return true;
    _logDenied(action: action, user: user, required: 'host');
    _showDenied(context, action);
    onDenied?.call();
    return false;
  }

  static void _showDenied(BuildContext context, String action) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Bạn không có quyền $action'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void _logDenied({
    required String action,
    required UserModel? user,
    required String required,
  }) {
    AnalyticsService.instance.logEvent('permission_denied', props: {
      'action': action,
      'user_role': user?.role ?? 'anonymous',
      'required_role': required,
    });
  }
}

/// Thrown by provider-layer methods when the caller lacks the required role.
///
/// Provider-level defense-in-depth — Phase 01 wraps destructive provider
/// methods (deleteHouse, deleteBuilding, contract terminate/transfer) with
/// this check even though backend re-verifies.
class PermissionDeniedException implements Exception {
  final String action;
  final String requiredRole;
  final String? actualRole;

  const PermissionDeniedException({
    required this.action,
    required this.requiredRole,
    this.actualRole,
  });

  @override
  String toString() =>
      'PermissionDeniedException: $action requires role=$requiredRole '
      '(actual=${actualRole ?? "anonymous"})';
}

/// Wraps a screen and hides it behind a fallback UI when the current user
/// doesn't have host access. Used for guest-facing deep-links to host-only
/// routes (`/post-house`, `/my-listings`).
///
/// Not a security barrier — the underlying route is still reachable if the
/// widget tree is bypassed. Backend authz is authoritative.
class RoleGuardWidget extends StatelessWidget {
  final Widget child;
  final bool requireAdmin;
  final String deniedTitle;
  final String deniedMessage;
  final String? deniedCtaLabel;
  final VoidCallback? onDeniedCta;

  const RoleGuardWidget({
    super.key,
    required this.child,
    this.requireAdmin = false,
    this.deniedTitle = 'Cần quyền chủ nhà',
    this.deniedMessage =
        'Bạn cần là chủ nhà để truy cập tính năng này. '
        'Đăng tin đầu tiên để tự động nâng cấp.',
    this.deniedCtaLabel,
    this.onDeniedCta,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final allowed = requireAdmin
        ? RoleGuard.canAdmin(user)
        : RoleGuard.canHost(user);

    if (allowed) return child;

    return Scaffold(
      appBar: AppBar(title: Text(deniedTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 56),
              const SizedBox(height: 16),
              Text(
                deniedTitle,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                deniedMessage,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (deniedCtaLabel != null && onDeniedCta != null) ...[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onDeniedCta,
                  child: Text(deniedCtaLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
