import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Mock HTTP adapter for Dio-based analytics uploader tests.
/// Allows test to configure success/error/timeout responses.
class MockHttpClientAdapter implements HttpClientAdapter {
  MockHttpClientAdapter({
    this.statusCode = 200,
    this.responseBody = '{}',
    this.delay = Duration.zero,
    this.throwError = false,
  });

  int statusCode;
  String responseBody;
  Duration delay;
  bool throwError;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (delay.inMilliseconds > 0) {
      await Future.delayed(delay);
    }

    if (throwError) {
      throw Exception('Mock HTTP error');
    }

    return ResponseBody.fromString(
      responseBody,
      statusCode,
      headers: {'content-type': ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}
