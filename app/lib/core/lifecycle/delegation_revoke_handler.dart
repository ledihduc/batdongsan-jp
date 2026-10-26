/// Global handler invoked when the backend returns 401 with
/// `code=DELEGATION_REVOKED`. Wired from main.dart to a widget-tree closure
/// that clears the actor context, refreshes delegation list, and navigates
/// the operator back to `/operator` with a toast.
///
/// See docs/role-model.md — Q1 (Option A) means operator is a delegation
/// scope, not a persistent role. When the owner revokes mid-session the
/// frontend must recover without hard-restarting the app.
library;

typedef DelegationRevokeCallback = void Function();

class DelegationRevokeHandler {
  DelegationRevokeHandler._();

  static DelegationRevokeCallback? _handler;

  /// Register the callback. Passing null clears it (used at dispose).
  static void register(DelegationRevokeCallback? handler) {
    _handler = handler;
  }

  /// Invoked from [ApiClient] when a delegation-revoke response is decoded.
  /// Safe to call from any thread — the handler itself decides how to
  /// marshal onto the UI thread if needed.
  static void trigger() {
    final h = _handler;
    if (h == null) return;
    try {
      h();
    } catch (_) {
      // Non-fatal — the API caller will still see the thrown ApiException
      // and can react locally.
    }
  }
}
