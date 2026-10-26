/// Widget tests for ExportButton.
///
/// Verifies: tooltip text, icon presence, tapping opens reauth modal.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/telemetry/telemetry_service.dart';
import 'package:house_booking/features/host/analytics/widgets/export_button.dart';
import 'package:house_booking/features/host/analytics/widgets/reauth_modal.dart';
import 'package:house_booking/features/host/analytics/services/export_service.dart';

// ---------------------------------------------------------------------------
// Stub ExportService — reauth always returns a token, download always throws
// to avoid path_provider issues in widget test environment.
// ---------------------------------------------------------------------------

class _AlwaysSuccessReauthService extends ExportService {
  _AlwaysSuccessReauthService() : super();

  @override
  Future<String> requestReauth(String password) async => 'test-token';

  @override
  Future<ExportResult> downloadTt200({
    required String period,
    required String reauthToken,
    void Function(double)? onProgress,
  }) async {
    throw ExportApiException(500, 'test-stub — download not exercised here');
  }
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _buildSubject({ExportService? service}) {
  return MultiProvider(
    providers: [
      Provider<TelemetryService>(create: (_) => TelemetryService()),
      Provider<ExportService>(
        create: (_) => service ?? ExportService(),
        dispose: (_, s) => s.dispose(),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          actions: [
            ExportButton(
              period: '2026-06',
              exportService: service,
            ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ExportButton', () {
    testWidgets('renders file_download icon with correct key', (tester) async {
      await tester.pumpWidget(_buildSubject());
      expect(find.byKey(const Key('export_tt200_btn')), findsOneWidget);
      expect(find.byIcon(Icons.file_download), findsOneWidget);
    });

    testWidgets('tooltip text is "Xuất sổ kế toán (Bản nháp)"', (tester) async {
      await tester.pumpWidget(_buildSubject());

      // Long-press the icon button to show the tooltip.
      final btn = find.byKey(const Key('export_tt200_btn'));
      await tester.longPress(btn);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Xuất sổ kế toán (Bản nháp)'), findsOneWidget);
    });

    testWidgets('tapping button opens ReauthModal', (tester) async {
      await tester.pumpWidget(_buildSubject(
        service: _AlwaysSuccessReauthService(),
      ));

      await tester.tap(find.byKey(const Key('export_tt200_btn')));
      await tester.pumpAndSettle();

      // ReauthModal contains 'Xác thực lại' title.
      expect(find.text('Xác thực lại'), findsOneWidget);
      expect(find.byType(ReauthModal), findsOneWidget);
    });

    testWidgets('pressing Hủy in modal closes modal without proceeding',
        (tester) async {
      await tester.pumpWidget(_buildSubject(
        service: _AlwaysSuccessReauthService(),
      ));

      await tester.tap(find.byKey(const Key('export_tt200_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(ReauthModal), findsOneWidget);

      await tester.tap(find.byKey(const Key('reauth_cancel_btn')));
      await tester.pumpAndSettle();

      // Modal dismissed — no progress dialog.
      expect(find.byType(ReauthModal), findsNothing);
    });
  });
}
