import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/data/services/session_service.dart';

// ---------------------------------------------------------------------------
// Domain errors
// ---------------------------------------------------------------------------

/// Thrown when password is incorrect (401 from /api/auth/reauth).
class WrongPasswordException implements Exception {
  const WrongPasswordException();

  @override
  String toString() => 'Mật khẩu không đúng';
}

/// Thrown when re-auth token is missing or invalid on export endpoint (403).
class ReauthRequiredException implements Exception {
  const ReauthRequiredException();

  @override
  String toString() => 'Yêu cầu xác thực lại';
}

/// Thrown on unexpected HTTP errors from export endpoints.
class ExportApiException implements Exception {
  const ExportApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'Export lỗi $statusCode: $message';
}

// ---------------------------------------------------------------------------
// Result model
// ---------------------------------------------------------------------------

/// Holds the local file path and metadata returned by the export endpoint.
class ExportResult {
  const ExportResult({
    required this.filePath,
    required this.version,
    required this.hash,
    required this.fileName,
  });

  final String filePath;
  final String version;
  final String hash;
  final String fileName;
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// HTTP service for TT200 Excel export operations.
///
/// Uses the existing `http` package (matching ApiClient pattern) and
/// `path_provider` to write the xlsx bytes to a temp file.
///
/// [tempDirProvider] is injectable for testing — defaults to
/// `getTemporaryDirectory()` from `path_provider`.
class ExportService {
  ExportService({
    http.Client? httpClient,
    Future<Directory> Function()? tempDirProvider,
  })  : _http = httpClient ?? http.Client(),
        _tempDirProvider = tempDirProvider ?? getTemporaryDirectory;

  final http.Client _http;
  final Future<Directory> Function() _tempDirProvider;

  /// Releases the underlying HTTP client.
  ///
  /// Must be called when [ExportService] is removed from the Provider tree.
  /// The [Provider] in `main.dart` wires this via its `dispose` callback.
  void dispose() {
    _http.close();
  }

  Uri _uri(String path) {
    final base = Uri.parse(ApiConfig.baseUrl);
    return base.replace(path: path);
  }

  Future<Map<String, String>> _authHeaders({
    bool jsonBody = false,
    String? reauthToken,
  }) async {
    final headers = <String, String>{};
    if (jsonBody) headers['Content-Type'] = 'application/json';

    final token = await SessionService.instance.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (reauthToken != null) {
      headers['X-Reauth-Token'] = reauthToken;
    }
    return headers;
  }

  // ---------------------------------------------------------------------------
  // Re-authentication
  // ---------------------------------------------------------------------------

  /// Sends password to `/api/auth/reauth` and returns a short-lived reauth JWT.
  ///
  /// Throws [WrongPasswordException] on 401.
  /// Throws [ExportApiException] on other non-2xx responses.
  Future<String> requestReauth(String password) async {
    final response = await _http.post(
      _uri('/api/auth/reauth'),
      headers: await _authHeaders(jsonBody: true),
      body: jsonEncode({'password': password}),
    );

    if (response.statusCode == 401) throw const WrongPasswordException();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = _errorMessage(response);
      throw ExportApiException(response.statusCode, msg);
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return body['reauth_token'] as String;
  }

  // ---------------------------------------------------------------------------
  // TT200 download
  // ---------------------------------------------------------------------------

  /// POSTs to `/api/host/analytics/export/tt200` and streams bytes to a temp file.
  ///
  /// Every call creates a new immutable version row on the backend — there is
  /// no idempotent path. The `force_new_version` field has been removed from
  /// the API contract (see Phase 09 Fix #1).
  ///
  /// [onProgress] receives values in [0.0, 1.0] as bytes arrive (best-effort —
  /// requires Content-Length header; otherwise fires 0.0 at start and 1.0 at end).
  ///
  /// Throws [ReauthRequiredException] on 403.
  /// Throws [ExportApiException] on other non-2xx.
  Future<ExportResult> downloadTt200({
    required String period,
    required String reauthToken,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.0);

    final response = await _http.post(
      _uri('/api/host/analytics/export/tt200'),
      headers: await _authHeaders(jsonBody: true, reauthToken: reauthToken),
      body: jsonEncode({
        'period': period,
      }),
    );

    if (response.statusCode == 403) throw const ReauthRequiredException();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = _errorMessage(response);
      throw ExportApiException(response.statusCode, msg);
    }

    onProgress?.call(0.5);

    // Parse metadata from response headers.
    final version = response.headers['x-export-version'] ?? '1';
    final hash = response.headers['x-export-hash'] ?? '';
    final fileName = _parseFileName(
      response.headers['content-disposition'],
      fallback: 'so-ke-toan-$period.xlsx',
    );

    // Write bytes to temp directory.
    final tmpDir = await _tempDirProvider();
    final file = File('${tmpDir.path}/$fileName');
    await file.writeAsBytes(response.bodyBytes, flush: true);

    onProgress?.call(1.0);

    return ExportResult(
      filePath: file.path,
      version: version,
      hash: hash,
      fileName: fileName,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  String _errorMessage(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return (body['detail'] as String?) ??
          (body['message'] as String?) ??
          'Yêu cầu thất bại';
    } catch (_) {
      return 'Yêu cầu thất bại (${response.statusCode})';
    }
  }

  /// Extracts filename from a Content-Disposition header value.
  ///
  /// E.g. `attachment; filename="so-ke-toan-host-2026-06-v1.xlsx"` → filename.
  static String _parseFileName(String? header, {required String fallback}) {
    if (header == null) return fallback;
    // Try filename= (handles both quoted and unquoted forms).
    final match =
        RegExp(r'filename="?([^;"]+)"?', caseSensitive: false).firstMatch(header);
    if (match != null) return match.group(1)!.trim();
    return fallback;
  }
}
