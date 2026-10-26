import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:house_booking/core/config/env.dart';

/// Gửi crash/error của Flutter về backend `/api/client-logs` để pipeline
/// self-heal xử lý chung với lỗi backend.
///
/// Nguyên tắc:
/// - Fire-and-forget: không bao giờ throw, không chặn UI.
/// - Chống loop: lỗi phát sinh TRONG lúc report bị nuốt.
/// - Throttle + dedupe: tối đa [_maxPerSession] báo cáo, không lặp cùng chữ ký.
/// - Cắt gọn stack (server vẫn redact PII lần nữa).
/// - Chỉ bật khi có backend (web/mobile) — no-op nếu gửi lỗi.
class ErrorReporter {
  ErrorReporter._();

  static const int _maxPerSession = 50;
  static const int _maxStackChars = 6000;

  static int _sent = 0;
  static bool _reporting = false;
  static final Set<String> _seen = <String>{};

  static String get _endpoint => '${Env.apiBaseUrl}/api/client-logs';

  /// Báo cáo một lỗi. An toàn để gọi từ FlutterError.onError / zone handler.
  static void report(
    Object error,
    StackTrace? stack, {
    String? route,
    String level = 'error',
    Map<String, Object?> context = const {},
  }) {
    // Chặn đệ quy: nếu đang report mà lại lỗi thì bỏ qua.
    if (_reporting || _sent >= _maxPerSession) return;

    final type = error.runtimeType.toString();
    final message = error.toString();
    final sig = '$type|${message.hashCode}';
    if (!_seen.add(sig)) return; // đã gửi lỗi giống hệt trong session

    _reporting = true;
    _sent++;

    final stackStr = stack?.toString() ?? '';
    final payload = <String, Object?>{
      'level': level,
      'message': message.length > 1000 ? message.substring(0, 1000) : message,
      'error_type': type,
      'stack': stackStr.length > _maxStackChars
          ? stackStr.substring(0, _maxStackChars)
          : stackStr,
      'route': route,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'context': context,
    };

    // unawaited: không chặn. Bắt mọi lỗi mạng, không để rò ra ngoài.
    unawaited(_post(payload).whenComplete(() => _reporting = false));
  }

  static Future<void> _post(Map<String, Object?> payload) async {
    try {
      await http
          .post(
            Uri.parse(_endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Nuốt hoàn toàn — reporter không được phép gây lỗi thứ cấp.
    }
  }
}
