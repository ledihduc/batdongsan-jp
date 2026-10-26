import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:house_booking/data/models/login_account_type.dart';
import 'package:house_booking/data/models/user_model.dart';
import 'package:house_booking/data/repositories/api_auth_repository.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/session_service.dart';
import 'package:house_booking/data/services/user_prefs_service.dart';
import 'package:house_booking/providers/auth_provider.dart';

import '../../helpers/login_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, String> storage;
  setUp(() async {
    storage = mockLoginStorage();
    await SessionService.instance.clear();
  });

  for (final type in LoginAccountType.values) {
    test(
      'login as ${type.name}: request, session and landing agree before notification',
      () async {
        Map<String, dynamic>? sent;
        final client = MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return loginResponse(
            loginUserPayload(
              role: type == LoginAccountType.admin ? 'admin' : 'guest',
              allowed: ['customer', type.name],
            ),
          );
        });
        final auth = AuthProvider(
          repository: ApiAuthRepository(client: ApiClient(client: client)),
        );
        addTearDown(auth.dispose);
        final observed = <String>[];
        auth.addListener(() {
          if (auth.isAuthenticated) {
            observed.add(
              '${auth.loginLocation}|${storage['last_active_mode']}',
            );
          }
        });
        expect(
          await auth.login('0912345678', ' password ', accountType: type),
          isTrue,
        );
        expect(sent, {
          'dinh_danh': '0912345678',
          'password': ' password ',
          'login_account_type': type.name,
        });
        final destination = switch (type) {
          LoginAccountType.customer => '/',
          LoginAccountType.sale || LoginAccountType.owner => '/?tab=activity',
          LoginAccountType.admin => '/admin',
        };
        expect(observed, ['$destination|${type.name}']);
        expect(
          auth.currentUser!.role,
          type == LoginAccountType.admin ? 'admin' : 'guest',
        );
        expect(await SessionService.instance.getToken(), 'test-session-token');
      },
    );
  }

  test(
    'old-server mismatch cannot save token or establish a session',
    () async {
      final client = MockClient((_) async => loginResponse(loginUserPayload()));
      final auth = AuthProvider(
        repository: ApiAuthRepository(client: ApiClient(client: client)),
      );
      addTearDown(auth.dispose);
      expect(
        await auth.login(
          'login@example.com',
          'password',
          accountType: LoginAccountType.admin,
        ),
        isFalse,
      );
      expect(auth.accountTypeMismatch, isTrue);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.loginAccountType, isNull);
      expect(await SessionService.instance.getToken(), isNull);
      expect(storage['last_active_mode'], isNull);
    },
  );

  test('server 403 is a role error and never stores a session', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'error': {'code': 'HTTP_403', 'message': 'Role not allowed'},
        }),
        403,
      ),
    );
    final auth = AuthProvider(
      repository: ApiAuthRepository(client: ApiClient(client: client)),
    );
    addTearDown(auth.dispose);
    expect(
      await auth.login(
        'login@example.com',
        'password',
        accountType: LoginAccountType.owner,
      ),
      isFalse,
    );
    expect(auth.accountTypeMismatch, isTrue);
    expect(await SessionService.instance.getToken(), isNull);
  });

  test('legacy callers omit selector and still authenticate', () async {
    final client = MockClient((request) async {
      expect(jsonDecode(request.body), isNot(contains('login_account_type')));
      return loginResponse(loginUserPayload());
    });
    final repo = ApiAuthRepository(client: ApiClient(client: client));
    expect(await repo.login('login@example.com', 'password'), isNotNull);
  });

  test('only one login request can be in flight', () async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final client = MockClient((_) {
      calls++;
      return pending.future;
    });
    final auth = AuthProvider(
      repository: ApiAuthRepository(client: ApiClient(client: client)),
    );
    addTearDown(auth.dispose);
    final first = auth.login(
      'login@example.com',
      'password',
      accountType: LoginAccountType.customer,
    );
    expect(auth.isLoading, isTrue);
    expect(
      await auth.login(
        'login@example.com',
        'password',
        accountType: LoginAccountType.admin,
      ),
      isFalse,
    );
    pending.complete(loginResponse(loginUserPayload()));
    expect(await first, isTrue);
    expect(calls, 1);
    expect(auth.loginAccountType, LoginAccountType.customer);
  });

  test(
    'bootstrap restores customer choice for an owner; logout clears it',
    () async {
      await SessionService.instance.setToken('existing');
      await UserPrefsService.instance.setLastMode('customer');
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'user': loginUserPayload(
              role: 'host',
              accountType: 'owner',
              allowed: ['customer', 'owner'],
            ),
          }),
          200,
        ),
      );
      final auth = AuthProvider(
        repository: ApiAuthRepository(client: ApiClient(client: client)),
      );
      addTearDown(auth.dispose);
      await auth.bootstrap();
      expect(auth.isAuthenticated, isTrue);
      expect(auth.loginAccountType, LoginAccountType.customer);
      expect(auth.loginLocation, '/');
      await auth.logout();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.loginAccountType, isNull);
      expect(await UserPrefsService.instance.getLastMode(), isNull);
      expect(await SessionService.instance.getToken(), isNull);
    },
  );

  test('bootstrap discards a saved role that is no longer allowed', () async {
    await SessionService.instance.setToken('existing');
    await UserPrefsService.instance.setLastMode('admin');
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'user': loginUserPayload(allowed: ['customer']),
        }),
        200,
      ),
    );
    final auth = AuthProvider(
      repository: ApiAuthRepository(client: ApiClient(client: client)),
    );
    addTearDown(auth.dispose);
    await auth.bootstrap();
    expect(auth.loginAccountType, isNull);
    expect(await UserPrefsService.instance.getLastMode(), isNull);
    expect(auth.loginLocation, '/');
  });

  test(
    'refresh drops revoked capability and profile edits retain self capabilities',
    () async {
      var allowed = ['customer', 'sale', 'owner'];
      final client = MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          return loginResponse(loginUserPayload(allowed: allowed));
        }
        return http.Response(
          jsonEncode({'user': loginUserPayload(allowed: allowed)}),
          200,
        );
      });
      final auth = AuthProvider(
        repository: ApiAuthRepository(client: ApiClient(client: client)),
      );
      addTearDown(auth.dispose);
      await auth.login(
        'login@example.com',
        'password',
        accountType: LoginAccountType.owner,
      );
      allowed = ['customer'];
      await auth.refreshCurrentUser();
      expect(auth.loginAccountType, LoginAccountType.customer);
      expect(await UserPrefsService.instance.getLastMode(), 'customer');
      expect(auth.currentUser!.canLoginAs(LoginAccountType.owner), isFalse);
      final model = UserModel.fromMap(
        loginUserPayload(allowed: ['customer', 'sale']),
      );
      expect(
        model.copyWith(name: 'Edited').canLoginAs(LoginAccountType.sale),
        isTrue,
      );
    },
  );

  test(
    'business admin label and untrusted capability list never grant system admin',
    () {
      final model = UserModel.fromMap(
        loginUserPayload(accountType: 'admin', allowed: ['customer', 'admin']),
      );
      expect(model.canLoginAs(LoginAccountType.admin), isFalse);
    },
  );

  test(
    'Activity role changes persist before notification and cannot grant a role',
    () async {
      final client = MockClient(
        (_) async => loginResponse(
          loginUserPayload(allowed: ['customer', 'sale', 'owner']),
        ),
      );
      final auth = AuthProvider(
        repository: ApiAuthRepository(client: ApiClient(client: client)),
      );
      addTearDown(auth.dispose);
      await auth.login(
        'login@example.com',
        'password',
        accountType: LoginAccountType.owner,
      );
      final observed = <String>[];
      auth.addListener(() {
        observed.add(
          '${auth.loginAccountType?.name}|${storage['last_active_mode']}',
        );
      });
      expect(await auth.selectLoginAccountType(LoginAccountType.sale), isTrue);
      expect(auth.loginLocation, '/?tab=activity');
      expect(
        await auth.selectLoginAccountType(LoginAccountType.admin),
        isFalse,
      );
      expect(auth.loginAccountType, LoginAccountType.sale);
      expect(
        await auth.selectLoginAccountType(LoginAccountType.customer),
        isTrue,
      );
      expect(auth.loginLocation, '/');
      expect(observed, ['sale|sale', 'customer|customer']);
    },
  );

  test(
    'legacy /me preserves explicit owner choice through fallback capabilities',
    () async {
      await SessionService.instance.setToken('existing');
      await UserPrefsService.instance.setLastMode('owner');
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'user': loginUserPayload(role: 'host')}),
          200,
        ),
      );
      final auth = AuthProvider(
        repository: ApiAuthRepository(client: ApiClient(client: client)),
      );
      addTearDown(auth.dispose);
      await auth.bootstrap();
      expect(auth.loginAccountType, LoginAccountType.owner);
      expect(auth.loginLocation, '/?tab=activity');
    },
  );

  test('active legacy customer has all business modes but never admin', () {
    final user = UserModel.fromMap(loginUserPayload());
    for (final type in [
      LoginAccountType.customer,
      LoginAccountType.sale,
      LoginAccountType.owner,
    ]) {
      expect(user.canLoginAs(type), isTrue);
    }
    expect(user.canLoginAs(LoginAccountType.admin), isFalse);
    final inactive = UserModel.fromMap({
      ...loginUserPayload(allowed: ['customer', 'sale', 'owner']),
      'is_active': false,
    });
    for (final type in LoginAccountType.values) {
      expect(inactive.canLoginAs(type), isFalse);
    }
  });

  for (final mode in ['customer', 'sale', 'owner']) {
    test('ordinary account restores $mode after application reload', () async {
      await SessionService.instance.setToken('existing');
      await UserPrefsService.instance.setLastMode(mode);
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'user': loginUserPayload()}),
          200,
        ),
      );
      final auth = AuthProvider(
        repository: ApiAuthRepository(client: ApiClient(client: client)),
      );
      addTearDown(auth.dispose);
      await auth.bootstrap();
      expect(auth.loginAccountType?.name, mode);
      expect(storage['last_active_mode'], mode);
      expect(auth.currentUser!.role, 'guest');
      expect(auth.currentUser!.accountType, 'customer');
    });
  }

  for (final error in [
    {
      'detail': [
        {
          'loc': ['body', 'login_account_type'],
          'msg': 'Invalid role',
        },
      ],
    },
    {
      'error': {'code': 'VALIDATION_ERROR', 'message': 'Invalid input'},
    },
  ]) {
    test(
      '422 envelope ${error.keys.first} produces ApiException, not a cast failure',
      () async {
        final client = ApiClient(
          client: MockClient(
            (_) async => http.Response(jsonEncode(error), 422),
          ),
        );
        await expectLater(
          client.post('/api/auth/login', body: {}),
          throwsA(isA<ApiException>()),
        );
      },
    );
  }
}
