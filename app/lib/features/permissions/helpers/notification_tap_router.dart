// Routes FCM notification taps to the correct screen via GoRouter.
// Defensive parsing: never trusts raw message.data values.
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';

/// Maps an incoming [RemoteMessage] to a GoRouter destination.
///
/// Called by [NotificationProvider.attachFcm] when the user taps a notification
/// that brings the app to foreground (onMessageOpenedApp stream).
///
/// Deep-link security note: the [id] value from [message.data] is passed
/// as a URL path segment only — it is validated server-side. Client-side we
/// accept any non-null, non-empty string (no SQL or HTML context here).
class NotificationTapRouter {
  NotificationTapRouter._();

  /// Routes based on [message.data['type']] and [message.data['id']].
  ///
  /// Supported types:
  /// - `booking`             → `/host/bookings/:id`
  /// - `chat`                → `/chat/:id`
  /// - `house`               → `/houses/:id`
  /// - `admin_alert`         → `/admin/dashboard`
  /// - `approval_requested`  → `/host/approvals` (Phase 07, AC-29)
  /// - `delegation_invited`  → `/operator/invitations` (Phase 07, AC-01)
  /// - `delegation_paused`   → `/host/delegation/:id` (Phase 07, AC-09)
  /// - anything else         → `/notifications`
  static void route(RemoteMessage message, GoRouter router) {
    final type = _safeString(message.data['type']);
    final id = _safeString(message.data['id']);

    switch (type) {
      case 'booking':
        final dest = (id != null) ? '/host/bookings/$id' : '/notifications';
        router.go(dest);

      case 'chat':
        final dest = (id != null) ? '/chat/$id' : '/notifications';
        router.go(dest);

      case 'house':
        // Use existing route /house/:id (note singular, matches app_router).
        final dest = (id != null) ? '/house/$id' : '/notifications';
        router.go(dest);

      case 'admin_alert':
        router.go('/admin/dashboard');

      // ── Phase 07: Delegation notification types ──────────────────────────
      // Security: delegation_id and approval_id are UUIDs validated server-side.
      // R4 mitigation: if delegation was paused before tap arrives → operator
      // sees DelegationDetailScreen which handles 401 DELEGATION_REVOKED.
      case 'approval_requested':
        // Deep-link to approval inbox. The specific approval row is highlighted
        // by approval_id query param (server returns it in notification payload).
        final approvalId = _safeString(message.data['approval_id']);
        final dest = approvalId != null
            ? '/host/approvals?highlight=$approvalId'
            : '/host/approvals';
        router.go(dest);

      case 'delegation_invited':
        // Operator taps invitation notification → invitation inbox.
        router.go('/operator/invitations');

      case 'delegation_paused':
        // Owner or operator taps pause notification → delegation detail.
        final delegationId = _safeString(message.data['delegation_id']);
        final dest = delegationId != null
            ? '/host/delegation/$delegationId'
            : '/notifications';
        router.go(dest);

      default:
        // Unknown type or null type → fall back to notification list.
        router.go('/notifications');
    }
  }

  /// Safely casts a dynamic map value to String.
  /// Returns null if missing, null, or not a String (never throws).
  static String? _safeString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }
}
