import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

Map<String, String> mockLoginStorage() {
  final values = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async {
          final args = (call.arguments as Map?) ?? {};
          switch (call.method) {
            case 'read':
              return values[args['key']];
            case 'write':
              values[args['key'] as String] = args['value'] as String;
            case 'delete':
              values.remove(args['key']);
            case 'deleteAll':
              values.clear();
            case 'readAll':
              return Map<String, String>.from(values);
          }
          return null;
        },
      );
  return values;
}

Map<String, dynamic> loginUserPayload({
  String role = 'guest',
  String accountType = 'customer',
  List<String>? allowed,
}) => {
  'id': 1,
  'name': 'Login Test',
  'email': 'login@example.com',
  'phone': '0912345678',
  'avatar_path': '',
  'role': role,
  'account_type': accountType,
  'is_active': true,
  'created_at': '2026-01-01T00:00:00',
  if (allowed != null) 'login_account_types': allowed,
};

http.Response loginResponse(Map<String, dynamic> user) => http.Response(
  jsonEncode({'token': 'test-session-token', 'user': user}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
