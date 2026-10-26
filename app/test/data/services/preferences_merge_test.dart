/// Test khoá lỗ hổng "merge prefs trộn nhầm trên trình duyệt DÙNG CHUNG".
///
/// Bối cảnh: prefs khách lưu ở localStorage KHÔNG gắn chủ sở hữu; trước đây
/// logout không xoá và mergeOnLogin union vô điều kiện → prefs người A dính vào
/// tài khoản B. Bản vá: clearLocal() khi logout + đóng dấu owner + gate merge.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:house_booking/data/models/user_preferences.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Kho lưu trữ giả trong RAM thay flutter_secure_storage.
  final store = <String, String>{};

  setUp(() {
    store.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
        final key = args['key'] as String? ?? '';
        switch (call.method) {
          case 'read':
            return store[key];
          case 'write':
            store[key] = args['value'] as String;
            return null;
          case 'delete':
            store.remove(key);
            return null;
          case 'readAll':
            return Map<String, String>.from(store);
          case 'deleteAll':
            store.clear();
            return null;
          default:
            return null;
        }
      },
    );
  });

  /// MockClient ghi lại request; trả prefs server rỗng cho GET/PUT.
  ({ApiClient api, List<http.Request> sent}) buildApi() {
    final sent = <http.Request>[];
    final client = MockClient((req) async {
      sent.add(req);
      return http.Response(
        jsonEncode({
          'preferences': {
            'interests': const [],
            'provinces': const [],
            'service_slugs': const [],
            'default_world': 'realestate',
          }
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    return (api: ApiClient(client: client), sent: sent);
  }

  bool sentMergePut(List<http.Request> sent) => sent.any((r) =>
      r.method == 'PUT' &&
      r.url.path == '/api/me/preferences' &&
      (jsonDecode(r.body) as Map)['merge'] == true);

  test('clearLocal xoá prefs → getLocal trả mặc định', () async {
    final p = PreferencesService.instance;
    await p.saveLocal(const UserPreferences(
        interests: ['rent'], provinces: ['01'], defaultWorld: 'construction'));
    expect((await p.getLocal()).isEmpty, isFalse);

    await p.clearLocal();
    final after = await p.getLocal();
    expect(after.isEmpty, isTrue);
    expect(after.defaultWorld, 'realestate');
    expect(store.containsKey('pref_owner'), isFalse);
  });

  test('mergeOnLogin: prefs KHÁCH (owner vắng) → CÓ đẩy merge + đóng dấu owner',
      () async {
    final p = PreferencesService.instance;
    final t = buildApi();
    p.apiClientForTest = t.api;

    await p.saveLocal(const UserPreferences(interests: ['rent']));
    await p.mergeOnLogin(7);

    expect(sentMergePut(t.sent), isTrue,
        reason: 'prefs khách phải được hợp nhất vào tài khoản');
    expect(store['pref_owner'], '7');
  });

  test('mergeOnLogin: prefs của tài khoản KHÁC (owner=2) → KHÔNG đẩy merge',
      () async {
    final p = PreferencesService.instance;
    final t = buildApi();
    p.apiClientForTest = t.api;

    await p.saveLocal(const UserPreferences(interests: ['rent']));
    store['pref_owner'] = '2'; // prefs sót của tài khoản 2 chưa xoá

    await p.mergeOnLogin(1);

    expect(sentMergePut(t.sent), isFalse,
        reason: 'KHÔNG được trộn prefs của tài khoản 2 vào tài khoản 1');
    expect(store['pref_owner'], '1', reason: 'đóng dấu lại theo người vừa vào');
  });
}
