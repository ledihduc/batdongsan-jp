import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/config/feature_flags.dart';
import 'package:house_booking/core/telemetry/telemetry_service.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/login_account_type.dart';
import 'package:house_booking/data/repositories/api_auth_repository.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/session_service.dart';
import 'package:house_booking/features/auth/login_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/auth_provider.dart';

import '../../helpers/login_test_support.dart';

const _picker = ValueKey('login-account-picker');
const _submit = ValueKey('login-submit');
const _guest = ValueKey('login-guest-browse');
const _close = ValueKey('login-account-picker-close');

Future<GoRouter> _pumpLogin(
  WidgetTester tester,
  AuthProvider auth, {
  String locale = 'vi',
  Size size = const Size(440, 1100),
  double textScale = 1,
  bool rootGate = false,
  bool startAtHome = false,
  bool redirectOnAuth = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: rootGate || startAtHome ? '/' : '/login',
    refreshListenable: auth,
    redirect: (_, state) =>
        redirectOnAuth && auth.isAuthenticated && state.uri.path == '/login'
        ? auth.loginLocation
        : null,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, state) => Consumer<AuthProvider>(
          builder: (_, currentAuth, _) =>
              rootGate && !currentAuth.isAuthenticated
              ? const LoginScreen(coLoiThoat: false)
              : Scaffold(
                  body: Text(
                    'HOME:${state.uri.queryParameters['tab'] ?? 'home'}',
                  ),
                ),
        ),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/admin',
        builder: (_, _) => const Scaffold(body: Text('ADMIN')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        Provider<TelemetryService>.value(value: TelemetryService()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, LoginAccountType type) async {
  await _tap(tester, find.byKey(_picker));
  await _tap(tester, find.byKey(ValueKey('login-role-${type.name}')));
}

Future<void> _credentials(
  WidgetTester tester, {
  String identifier = 'login@example.com',
}) async {
  await tester.enterText(find.byType(TextFormField).first, identifier);
  await tester.enterText(find.byType(TextFormField).last, ' pass123 ');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    mockLoginStorage();
    await SessionService.instance.clear();
  });

  AuthProvider makeAuth(Future<http.Response> Function(http.Request) handler) {
    final auth = AuthProvider(
      repository: ApiAuthRepository(
        client: ApiClient(client: MockClient(handler)),
      ),
    );
    addTearDown(auth.dispose);
    return auth;
  }

  testWidgets('a role is required before any login request', (tester) async {
    var calls = 0;
    final auth = makeAuth((_) async {
      calls++;
      return loginResponse(loginUserPayload());
    });
    await _pumpLogin(tester, auth);
    final l = AppLocalizations.of(tester.element(find.byType(LoginScreen)));
    await _credentials(tester);
    await _tap(tester, find.byKey(_submit));
    expect(find.text(l.loginAccountTypeRequired), findsOneWidget);
    expect(calls, 0);
    expect(auth.isAuthenticated, isFalse);
  });

  for (final type in LoginAccountType.values) {
    testWidgets(
      '${type.name} submits the selected role and opens its destination',
      (tester) async {
        Map<String, dynamic>? sent;
        final auth = makeAuth((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return loginResponse(
            loginUserPayload(
              role: type == LoginAccountType.admin ? 'admin' : 'guest',
              allowed: ['customer', type.name],
            ),
          );
        });
        final router = await _pumpLogin(tester, auth, redirectOnAuth: true);
        await _select(tester, type);
        final identifier = type == LoginAccountType.customer
            ? '0912345678'
            : 'login@example.com';
        await _credentials(tester, identifier: ' $identifier ');
        await _tap(tester, find.byKey(_submit));
        expect(sent, {
          'dinh_danh': identifier,
          'password': ' pass123 ',
          'login_account_type': type.name,
        });
        expect(auth.isAuthenticated, isTrue);
        expect(
          router.routeInformationProvider.value.uri.toString(),
          type.homeLocation,
        );
        expect(find.byType(LoginScreen), findsNothing);
      },
    );
  }

  testWidgets('closing the picker preserves the current selection', (
    tester,
  ) async {
    final auth = makeAuth((_) async => loginResponse(loginUserPayload()));
    await _pumpLogin(tester, auth);
    await _select(tester, LoginAccountType.owner);
    await _tap(tester, find.byKey(_picker));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('login-role-owner')),
        matching: find.byIcon(Icons.radio_button_checked),
      ),
      findsOneWidget,
    );
    await _tap(tester, find.byKey(_close));
    final l = AppLocalizations.of(tester.element(find.byType(LoginScreen)));
    expect(find.text(l.loginRoleOwner), findsOneWidget);
    expect(find.byType(DsBottomSheet), findsNothing);
    expect(auth.isAuthenticated, isFalse);
  });

  testWidgets(
    'role denial stays on login with a translated error and no token',
    (tester) async {
      final auth = makeAuth(
        (_) async => http.Response(
          jsonEncode({
            'error': {'code': 'HTTP_403', 'message': 'Role denied'},
          }),
          403,
        ),
      );
      final router = await _pumpLogin(tester, auth, locale: 'en');
      final l = AppLocalizations.of(tester.element(find.byType(LoginScreen)));
      await _select(tester, LoginAccountType.admin);
      await _credentials(tester);
      await _tap(tester, find.byKey(_submit));
      expect(find.text(l.loginAccountTypeMismatch), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(auth.isAuthenticated, isFalse);
      expect(await SessionService.instance.getToken(), isNull);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'login@example.com',
      );
      await _select(tester, LoginAccountType.customer);
      expect(find.text(l.loginAccountTypeMismatch), findsNothing);
    },
  );

  testWidgets(
    'pending login disables credentials, role changes and repeated submit',
    (tester) async {
      final pending = Completer<http.Response>();
      var calls = 0;
      final auth = makeAuth((_) {
        calls++;
        return pending.future;
      });
      await _pumpLogin(tester, auth);
      await _select(tester, LoginAccountType.customer);
      await _credentials(tester);
      await tester.ensureVisible(find.byKey(_submit));
      await tester.tap(find.byKey(_submit));
      await tester.pump();
      expect(auth.isLoading, isTrue);
      expect(tester.widget<InkWell>(find.byKey(_picker)).onTap, isNull);
      expect(tester.widget<DsButton>(find.byKey(_submit)).onPressed, isNull);
      for (final field in tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      )) {
        expect(field.enabled, isFalse);
      }
      await tester.tap(find.byKey(_submit));
      await tester.pump();
      expect(calls, 1);
      pending.complete(loginResponse(loginUserPayload()));
      await tester.pumpAndSettle();
      expect(find.text('HOME:home'), findsOneWidget);
    },
  );

  testWidgets('the no-exit root login gate has no guest escape', (
    tester,
  ) async {
    final auth = makeAuth((_) async => loginResponse(loginUserPayload()));
    await _pumpLogin(tester, auth, rootGate: true);
    expect(find.byKey(_guest), findsNothing);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
    await _select(tester, LoginAccountType.customer);
    await _credentials(tester);
    await _tap(tester, find.byKey(_submit));
    expect(find.text('HOME:home'), findsOneWidget);
  });

  for (final useGoRouter in [false, true]) {
    testWidgets(
      'successful login closes a route pushed with ${useGoRouter ? 'GoRouter' : 'Navigator'}',
      (tester) async {
        final auth = makeAuth((_) async => loginResponse(loginUserPayload()));
        final router = await _pumpLogin(
          tester,
          auth,
          startAtHome: true,
          redirectOnAuth: true,
        );
        if (useGoRouter) {
          router.push('/login');
        } else {
          Navigator.of(
            tester.element(find.text('HOME:home')),
          ).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
        }
        await tester.pumpAndSettle();
        await _select(tester, LoginAccountType.customer);
        await _credentials(tester);
        await _tap(tester, find.byKey(_submit));
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.text('HOME:home'), findsOneWidget);
        expect(auth.isAuthenticated, isTrue);
      },
    );
  }

  if (FeatureFlags.guestBrowse) {
    for (final pushed in [false, true]) {
      testWidgets(
        'guest access leaves ${pushed ? 'Navigator-pushed' : 'direct'} login',
        (tester) async {
          final auth = makeAuth((_) async => loginResponse(loginUserPayload()));
          await _pumpLogin(tester, auth, startAtHome: pushed);
          if (pushed) {
            Navigator.of(tester.element(find.text('HOME:home'))).push(
              MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
            );
            await tester.pumpAndSettle();
          }
          await _tap(tester, find.byKey(_guest));
          expect(find.byType(LoginScreen), findsNothing);
          expect(find.text('HOME:home'), findsOneWidget);
          expect(auth.isAuthenticated, isFalse);
        },
      );
    }
  }

  for (final locale in ['vi', 'en', 'zh']) {
    testWidgets(
      '$locale login and picker fit a narrow screen with large text',
      (tester) async {
        final auth = makeAuth((_) async => loginResponse(loginUserPayload()));
        await _pumpLogin(
          tester,
          auth,
          locale: locale,
          size: const Size(320, 640),
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
        await _tap(tester, find.byKey(_picker));
        expect(tester.takeException(), isNull);
        await _tap(tester, find.byKey(const ValueKey('login-role-admin')));
        await tester.ensureVisible(find.byKey(_submit));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
