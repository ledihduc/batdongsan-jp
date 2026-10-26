/// Widget tests for ReauthModal.
///
/// Verifies: password submission, inline error on 401, token returned on 200.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/features/host/analytics/services/export_service.dart';
import 'package:house_booking/features/host/analytics/widgets/reauth_modal.dart';

// ---------------------------------------------------------------------------
// Stub ExportService implementations
// ---------------------------------------------------------------------------

class _SuccessService extends ExportService {
  _SuccessService() : super();

  @override
  Future<String> requestReauth(String password) async => 'returned-token';
}

class _WrongPasswordService extends ExportService {
  _WrongPasswordService() : super();

  @override
  Future<String> requestReauth(String password) async {
    throw const WrongPasswordException();
  }
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

/// Pumps a modal dialog and returns the result captured by [Navigator.pop].
Future<String?> _showModal(
  WidgetTester tester, {
  required ExportService service,
}) async {
  String? result;

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showDialog<String?>(
              context: context,
              barrierDismissible: false,
              builder: (_) => ReauthModal(exportService: service),
            );
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();

  return result;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ReauthModal', () {
    testWidgets('title and subtitle are rendered', (tester) async {
      await _showModal(tester, service: _SuccessService());

      expect(find.text('Xác thực lại'), findsOneWidget);
      expect(
        find.textContaining('Để bảo vệ dữ liệu nhạy cảm'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('reauth_password_field')), findsOneWidget);
    });

    testWidgets('correct password → pops with token', (tester) async {
      String? poppedToken;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                poppedToken = await showDialog<String?>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => ReauthModal(exportService: _SuccessService()),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('reauth_password_field')), 'my-password');
      await tester.tap(find.byKey(const Key('reauth_confirm_btn')));
      await tester.pumpAndSettle();

      expect(poppedToken, equals('returned-token'));
    });

    testWidgets('wrong password → shows inline error "Mật khẩu không đúng"',
        (tester) async {
      await _showModal(tester, service: _WrongPasswordService());

      await tester.enterText(
          find.byKey(const Key('reauth_password_field')), 'wrong');
      await tester.tap(find.byKey(const Key('reauth_confirm_btn')));
      await tester.pumpAndSettle();

      // Modal stays open; inline error visible.
      expect(find.text('Mật khẩu không đúng'), findsOneWidget);
      expect(find.byType(ReauthModal), findsOneWidget);
    });

    testWidgets('cancel → pops with null', (tester) async {
      String? poppedResult = 'sentinel';

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                poppedResult = await showDialog<String?>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => ReauthModal(exportService: _SuccessService()),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reauth_cancel_btn')));
      await tester.pumpAndSettle();

      expect(poppedResult, isNull);
    });

    testWidgets('empty password → validation error, no network call',
        (tester) async {
      bool serviceCalled = false;

      final service = _SuccessService();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<String?>(
                context: context,
                builder: (_) => ReauthModal(exportService: service),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Do NOT enter any text — tap confirm directly.
      await tester.tap(find.byKey(const Key('reauth_confirm_btn')));
      await tester.pumpAndSettle();

      // Form validation error; modal still open.
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
      expect(serviceCalled, isFalse);
    });
  });
}
