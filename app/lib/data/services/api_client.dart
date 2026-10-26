import 'dart:convert';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/lifecycle/delegation_revoke_handler.dart';
import 'package:house_booking/core/lifecycle/session_expired_handler.dart';
import 'package:house_booking/data/services/session_service.dart';
import 'package:http/http.dart' as http;

// Delegation actor-context header injection (Phase 07 — TL-8 decision).
// ActorContextProvider is accessed via a global accessor to avoid threading
// BuildContext through every repository call. This is a deliberate trade-off:
// the provider is app-scoped, non-persisted, and only lives in memory.
// The accessor is set once from main.dart after the provider is registered.
// ignore: avoid_function_typed_parameter_types
String? Function()? _actingAsDelegationIdAccessor;

class ApiException implements Exception {
  final int statusCode;
  final String message;

  /// Optional machine-readable error code from backend (e.g. 'DELEGATION_REVOKED').
  final String? code;

  ApiException(this.statusCode, this.message, {this.code});

  bool get isUnauthorized => statusCode == 401;

  /// True when a delegation was paused/terminated while the operator was
  /// mid-session. UI must clear ActorContextProvider and redirect (AC-16b).
  bool get isDelegationRevoked =>
      isUnauthorized && code == 'DELEGATION_REVOKED';

  @override
  String toString() => message;
}

/// Wire the ActorContextProvider into the ApiClient header interceptor.
/// Must be called once after the provider is registered in MultiProvider.
/// See main.dart — called in MyApp.initState.
void wireActorContextToApiClient(String? Function() delegationIdAccessor) {
  _actingAsDelegationIdAccessor = delegationIdAccessor;
}

class ApiClient {
  /// [client] chỉ dùng trong TEST để bơm `http.Client` giả.
  ///
  /// Mặc định `null` → mỗi lời gọi tự tạo rồi đóng một client, đúng như
  /// `http.get/post/...` vẫn làm từ trước. Hành vi ở môi trường thật KHÔNG đổi.
  const ApiClient({http.Client? client}) : _client = client;

  final http.Client? _client;

  /// Chạy [fn] với client được bơm, hoặc với client dùng-một-lần rồi đóng.
  Future<T> _send<T>(Future<T> Function(http.Client c) fn) async {
    final injected = _client;
    if (injected != null) return fn(injected);
    final c = http.Client();
    try {
      return await fn(c);
    } finally {
      c.close();
    }
  }

  Uri _uri(String path, [Map<String, dynamic>? queryParameters]) {
    final base = Uri.parse(ApiConfig.baseUrl);
    final filteredQuery = <String, String>{};

    queryParameters?.forEach((key, value) {
      if (value != null) {
        filteredQuery[key] = value.toString();
      }
    });

    return base.replace(
      path: path,
      queryParameters: filteredQuery.isEmpty ? null : filteredQuery,
    );
  }

  Future<Map<String, String>> _headers({bool jsonBody = false}) async {
    final headers = <String, String>{};
    if (jsonBody) headers['Content-Type'] = 'application/json';
    final token = await SessionService.instance.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    // Delegation actor-context header (TL-8 — Phase 07).
    // Injected only when ActorContextProvider has an active delegation context.
    // NOT persisted — cleared on every cold start (AC-15, NFR-07).
    final delegationId = _actingAsDelegationIdAccessor?.call();
    if (delegationId != null && delegationId.isNotEmpty) {
      headers['X-Acting-As-Delegation-Id'] = delegationId;
    }
    return headers;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final headers = await _headers();
    final response = await _send(
      (c) => c.get(_uri(path, queryParameters), headers: headers),
    );
    return _decode(response);
  }

  /// `get` kèm header riêng (vd `X-Ekyc-Token` của link eKYC). Tách hàm thay
  /// vì thêm tham số vào `get`: nhiều lớp giả trong test ghi đè `get`.
  Future<Map<String, dynamic>> getVoiHeader(
    String path,
    Map<String, String> extraHeaders,
  ) async {
    final headers = await _headers()..addAll(extraHeaders);
    final response = await _send((c) => c.get(_uri(path), headers: headers));
    return _decode(response);
  }

  /// `put` kèm header riêng — xem [getVoiHeader].
  Future<Map<String, dynamic>> putVoiHeader(
    String path,
    Map<String, dynamic> body,
    Map<String, String> extraHeaders,
  ) async {
    final headers = await _headers(jsonBody: true)..addAll(extraHeaders);
    final response = await _send(
      (c) => c.put(_uri(path), headers: headers, body: jsonEncode(body)),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = await _headers(jsonBody: true);
    if (extraHeaders != null) headers.addAll(extraHeaders);
    final response = await _send(
      (c) => c.post(
        _uri(path),
        headers: headers,
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final headers = await _headers(jsonBody: true);
    final response = await _send(
      (c) => c.put(
        _uri(path),
        headers: headers,
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = await _headers(jsonBody: true);
    if (extraHeaders != null) headers.addAll(extraHeaders);
    final response = await _send(
      (c) => c.patch(
        _uri(path),
        headers: headers,
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final headers = await _headers();
    final response = await _send(
      (c) => c.delete(_uri(path, queryParameters), headers: headers),
    );
    return _decode(response);
  }

  /// Upload ảnh dạng base64. Trả về URL tuyệt đối có thể dùng cho Image.network.
  Future<String> uploadImage(List<int> bytes, String filename) async {
    final result = await post(
      '/api/upload',
      body: {'filename': filename, 'data': base64Encode(bytes)},
    );
    final url = result['url'] as String;
    return url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';
  }

  /// Fetch a JSON array endpoint. Returns the raw decoded list.
  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final headers = await _headers();
    final response = await _send(
      (c) => c.get(_uri(path, queryParameters), headers: headers),
    );
    return _decodeList(response);
  }

  /// Fetch raw bytes for a binary/streaming endpoint (e.g. CSV export).
  /// Returns the response body. Throws [ApiException] on non-2xx.
  Future<List<int>> getBytes(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final headers = await _headers();
    final response = await _send(
      (c) => c.get(_uri(path, queryParameters), headers: headers),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw ApiException(
      response.statusCode,
      'Tải về thất bại (${response.statusCode})',
    );
  }

  /// POST + decode a JSON array response. Used when the endpoint accepts a body
  /// but returns `list[T]` (e.g. /invoices/generate-batch).
  Future<List<dynamic>> postList(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final headers = await _headers(jsonBody: true);
    final response = await _send(
      (c) => c.post(
        _uri(path),
        headers: headers,
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
    return _decodeList(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.bodyBytes.isEmpty
        ? ''
        : utf8.decode(response.bodyBytes);
    // ignore: inference_failure_on_function_invocation
    final dynamic decoded = body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      // 204 No Content or empty body
      return <String, dynamic>{};
    }

    final Map<String, dynamic> errData = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    final errorCode = _errorCode(errData);
    final errorMsg = _errorMessage(errData);
    // Fire the global delegation-revoke handler BEFORE throwing so the UI
    // clears actor context + navigates back to /operator regardless of
    // whether the individual caller catches this ApiException.
    if (response.statusCode == 401 && errorCode == 'DELEGATION_REVOKED') {
      DelegationRevokeHandler.trigger();
    } else if (response.statusCode == 401) {
      _baoHetPhien(response);
    }
    throw ApiException(response.statusCode, errorMsg, code: errorCode);
  }

  List<dynamic> _decodeList(http.Response response) {
    final body = response.bodyBytes.isEmpty
        ? ''
        : utf8.decode(response.bodyBytes);
    // ignore: inference_failure_on_function_invocation
    final dynamic decoded = body.isEmpty ? <dynamic>[] : jsonDecode(body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is List<dynamic>) return decoded;
      return <dynamic>[];
    }

    final errMsg = decoded is Map<String, dynamic>
        ? _errorMessage(decoded)
        : 'Yêu cầu thất bại';
    if (response.statusCode == 401) _baoHetPhien(response);
    throw ApiException(response.statusCode, errMsg);
  }

  // Production uses {error: {code, message}}, while legacy endpoints and
  // FastAPI validation may return a string, object or list in `detail`.
  String _errorMessage(Map<String, dynamic> data) {
    final detail = data['detail'];
    final error = data['error'];
    for (final value in [
      detail,
      data['message'],
      if (error is Map) error['message'],
      if (detail is Map) detail['message'],
    ]) {
      if (value is String && value.isNotEmpty) return value;
    }
    return 'Yêu cầu thất bại';
  }

  String? _errorCode(Map<String, dynamic> data) {
    final error = data['error'];
    final detail = data['detail'];
    final code =
        data['code'] ??
        (error is Map ? error['code'] : null) ??
        (detail is Map ? detail['code'] : null);
    return code is String ? code : null;
  }

  /// Báo "phiên đã hết hạn" cho tầng ứng dụng — TRỪ chính các endpoint đăng
  /// nhập/đăng ký: 401 ở đó nghĩa là "sai mật khẩu", không phải "hết phiên".
  /// Nhầm hai ca này sẽ đá người dùng ra khỏi màn đăng nhập ngay khi họ gõ sai
  /// mật khẩu một lần.
  static void _baoHetPhien(http.Response response) {
    final path = response.request?.url.path ?? '';
    if (path.contains('/api/auth/login') ||
        path.contains('/api/auth/register')) {
      return;
    }
    SessionExpiredHandler.trigger();
  }
}
