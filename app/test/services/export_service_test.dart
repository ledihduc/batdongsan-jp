/// Unit tests for ExportService.
///
/// Uses MockClient from `package:http/testing.dart` to avoid real network calls.
/// Injects a real temp directory via [ExportService.tempDirProvider] to avoid
/// needing to mock the path_provider platform interface.
///
/// Covers: requestReauth success/401/400; downloadTt200 success/403/422 + progress.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:house_booking/features/host/analytics/services/export_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

http.Response _jsonResponse(int status, Map<String, dynamic> body,
    [Map<String, String>? extraHeaders]) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      ...?extraHeaders,
    },
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('export_svc_test_');
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  ExportService makeService(http.Client client) => ExportService(
        httpClient: client,
        tempDirProvider: () async => tempDir,
      );

  // -------------------------------------------------------------------------
  // requestReauth
  // -------------------------------------------------------------------------

  group('ExportService.requestReauth', () {
    test('200 → returns reauth_token string', () async {
      final client = MockClient((_) async => _jsonResponse(200, {
            'reauth_token': 'jwt-abc',
            'expires_at': '2026-06-29T12:05:00Z',
          }));
      final token = await makeService(client).requestReauth('good-password');
      expect(token, equals('jwt-abc'));
    });

    test('401 → throws WrongPasswordException', () async {
      final client = MockClient(
          (_) async => _jsonResponse(401, {'detail': 'Invalid password'}));
      await expectLater(
        makeService(client).requestReauth('bad-pass'),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    test('400 → throws ExportApiException', () async {
      final client = MockClient(
          (_) async => _jsonResponse(400, {'detail': 'Missing credentials'}));
      await expectLater(
        makeService(client).requestReauth(''),
        throwsA(isA<ExportApiException>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // downloadTt200
  // -------------------------------------------------------------------------

  group('ExportService.downloadTt200', () {
    test('200 → returns ExportResult with file on disk, version, hash',
        () async {
      final bytes = List<int>.filled(64, 0x50);
      final client = MockClient((_) async => http.Response.bytes(
            bytes,
            200,
            headers: {
              'content-type':
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              'content-disposition':
                  'attachment; filename="so-ke-toan-host-2026-06-v1.xlsx"',
              'x-export-version': '1',
              'x-export-hash': 'deadbeef',
            },
          ));

      final result = await makeService(client).downloadTt200(
        period: '2026-06',
        reauthToken: 'tok',
      );

      expect(result.version, equals('1'));
      expect(result.hash, equals('deadbeef'));
      expect(result.fileName, equals('so-ke-toan-host-2026-06-v1.xlsx'));
      expect(File(result.filePath).existsSync(), isTrue);
    });

    test('403 → throws ReauthRequiredException', () async {
      final client = MockClient(
          (_) async => _jsonResponse(403, {'detail': 'Reauth required'}));
      await expectLater(
        makeService(client).downloadTt200(
            period: '2026-06', reauthToken: 'expired-tok'),
        throwsA(isA<ReauthRequiredException>()),
      );
    });

    test('422 invalid period → throws ExportApiException', () async {
      final client = MockClient(
          (_) async => _jsonResponse(422, {'detail': 'Invalid period format'}));
      await expectLater(
        makeService(client)
            .downloadTt200(period: 'bad-period', reauthToken: 'tok'),
        throwsA(isA<ExportApiException>()),
      );
    });

    test('progress callback fires 0.0 → 0.5 → 1.0 in order', () async {
      final bytes = List<int>.filled(32, 0x50);
      final client = MockClient((_) async => http.Response.bytes(
            bytes,
            200,
            headers: {
              'content-type':
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              'content-disposition': 'attachment; filename="file.xlsx"',
              'x-export-version': '2',
              'x-export-hash': 'hash2',
            },
          ));

      final progress = <double>[];
      await makeService(client).downloadTt200(
        period: '2026-06',
        reauthToken: 'tok',
        onProgress: progress.add,
      );

      expect(progress, containsAllInOrder([0.0, 0.5, 1.0]));
    });
  });
}
