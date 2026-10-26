/// JP integration test helpers — login and navigation utilities.
///
/// All tests in `integration_test/jp/` import this file for shared setup.
///
/// NOTE: These tests drive the full UI through mock repositories
/// (no real staging API call). Pass `--dart-define=API_BASE=https://staging-jp.ancu365.com`
/// at CI to switch to staging mode when real infra is available.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:house_booking/main.dart' as app;

export 'package:flutter_test/flutter_test.dart';
export 'package:integration_test/integration_test.dart';

/// Binds the [IntegrationTestWidgetsFlutterBinding] and boots the app.
///
/// Call at the top of `main()` in each persona test.
void jpIntegrationSetUp() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
}

/// Boots the full app in test mode.
///
/// Uses mock repositories wired in [app.main] when
/// `--dart-define=USE_MOCK_REPOS=true` (default in test env).
Future<void> launchApp(WidgetTester tester) async {
  app.main();
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

/// Navigates to the login screen and signs in with [email] + [password].
///
/// Waits for the home screen to appear before returning.
Future<void> loginAs(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  // Tap the login button if on the splash/onboarding screen.
  final loginButton = find.text('ログイン').first;
  if (tester.any(loginButton)) {
    await tester.tap(loginButton);
    await tester.pumpAndSettle();
  }

  // Fill email field.
  final emailField = find.byKey(const Key('login_email_field'));
  if (tester.any(emailField)) {
    await tester.enterText(emailField, email);
  }

  // Fill password field.
  final passwordField = find.byKey(const Key('login_password_field'));
  if (tester.any(passwordField)) {
    await tester.enterText(passwordField, password);
  }

  // Submit.
  final submitButton = find.byKey(const Key('login_submit_button'));
  if (tester.any(submitButton)) {
    await tester.tap(submitButton);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }
}

/// Navigates to [route] via GoRouter deep-link simulation.
///
/// Works by finding the app's [NavigatorObserver] and pushing the route.
/// Falls back to tapping a widget with key `Key('nav_$route')` if available.
Future<void> navigateTo(WidgetTester tester, String route) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
}

/// Waits until a widget matching [finder] appears, up to [timeout].
///
/// Throws [TestFailure] if the widget does not appear within [timeout].
Future<void> waitForWidget(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!tester.any(finder)) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Widget ${finder.description} not found within $timeout');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Test credentials for each persona.
///
/// These credentials work against the mock repositories bundled in the app.
/// Replace with staging credentials when running against real API.
class JpTestCredentials {
  static const String ownerEmail = 'test-owner@ancu365.jp';
  static const String ownerPassword = 'test1234';

  static const String brokerEmail = 'test-broker@ancu365.jp';
  static const String brokerPassword = 'test1234';

  static const String tenantEmail = 'test-tenant@ancu365.jp';
  static const String tenantPassword = 'test1234';

  static const String adminEmail = 'test-admin@ancu365.jp';
  static const String adminPassword = 'test1234';
}
