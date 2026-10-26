/// Widget tests for [JpPostalCodeField].
///
/// Verifies:
/// - Entering 7 digits triggers an API call to /api/jp/address/lookup
/// - Successful response calls [onAddressResolved]
/// - ApiException (404) shows an error, calls [onError]
/// - Partial input (< 7 digits) does not trigger API call
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/widgets/jp_postal_code_field.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Fake ApiClient subclasses
// ---------------------------------------------------------------------------

/// Returns a successful address for any postal code.
class _SuccessApiClient extends ApiClient {
  String? lastPostalCode;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    lastPostalCode = queryParameters?['postal_code'] as String?;
    return {
      'postal_code': lastPostalCode ?? '',
      'prefecture': '東京都',
      'city': '渋谷区',
      'town': '道玄坂',
    };
  }
}

/// Always throws ApiException(404) to simulate unknown postal code.
class _NotFoundApiClient extends ApiClient {
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    throw ApiException(404, 'Not found');
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps [widget] in a minimal MaterialApp with localization support.
Widget _wrap(Widget widget) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ja'),
    home: Scaffold(body: widget),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JpPostalCodeField', () {
    testWidgets('entering 7 digits triggers API call and calls onAddressResolved',
        (tester) async {
      final api = _SuccessApiClient();
      JpAddress? resolvedAddress;

      await tester.pumpWidget(_wrap(
        JpPostalCodeField(
          apiClient: api,
          onAddressResolved: (addr) => resolvedAddress = addr,
        ),
      ));

      // Enter 7 digits (formatted as 123-4567 by the formatter).
      await tester.enterText(find.byType(TextFormField), '1234567');
      await tester.pump();

      // Wait for debounce (300ms) + API round-trip.
      await tester.pump(const Duration(milliseconds: 400));

      expect(api.lastPostalCode, '1234567');
      expect(resolvedAddress, isNotNull);
      expect(resolvedAddress!.prefecture, '東京都');
      expect(resolvedAddress!.city, '渋谷区');
    });

    testWidgets('partial input (6 digits) does NOT trigger API call',
        (tester) async {
      final api = _SuccessApiClient();
      JpAddress? resolvedAddress;

      await tester.pumpWidget(_wrap(
        JpPostalCodeField(
          apiClient: api,
          onAddressResolved: (addr) => resolvedAddress = addr,
        ),
      ));

      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.pump(const Duration(milliseconds: 400));

      expect(api.lastPostalCode, isNull);
      expect(resolvedAddress, isNull);
    });

    testWidgets('404 response calls onError', (tester) async {
      final api = _NotFoundApiClient();
      String? errorMessage;

      await tester.pumpWidget(_wrap(
        JpPostalCodeField(
          apiClient: api,
          onAddressResolved: (_) {},
          onError: (msg) => errorMessage = msg,
        ),
      ));

      await tester.enterText(find.byType(TextFormField), '0000000');
      await tester.pump(const Duration(milliseconds: 400));

      expect(errorMessage, isNotNull);
      expect(errorMessage, contains('見つかりません'));
    });
  });
}
