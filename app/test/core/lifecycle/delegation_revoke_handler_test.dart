/// Verifies [DelegationRevokeHandler] wiring — register/trigger/unregister
/// and that a throwing handler is caught (never leaks to the API caller).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/lifecycle/delegation_revoke_handler.dart';

void main() {
  tearDown(() => DelegationRevokeHandler.register(null));

  test('trigger with no handler is a no-op', () {
    expect(DelegationRevokeHandler.trigger, returnsNormally);
  });

  test('trigger invokes registered handler', () {
    var calls = 0;
    DelegationRevokeHandler.register(() => calls++);
    DelegationRevokeHandler.trigger();
    DelegationRevokeHandler.trigger();
    expect(calls, 2);
  });

  test('register(null) unregisters the handler', () {
    var calls = 0;
    DelegationRevokeHandler.register(() => calls++);
    DelegationRevokeHandler.register(null);
    DelegationRevokeHandler.trigger();
    expect(calls, 0);
  });

  test('a throwing handler does not propagate', () {
    DelegationRevokeHandler.register(() => throw Exception('boom'));
    expect(DelegationRevokeHandler.trigger, returnsNormally);
  });
}
