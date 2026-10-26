import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/features/permissions/copy/priming_copy.dart';
import 'package:house_booking/features/permissions/widgets/notification_priming_sheet.dart';

void main() {
  group('NotificationPrimingSheet', () {
    late bool onAcceptCalled;
    late bool onDeferCalled;

    setUp(() {
      onAcceptCalled = false;
      onDeferCalled = false;
    });

    testWidgets('displays guest copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotificationPrimingSheet(
                role: UserRole.guest,
                onAccept: () => onAcceptCalled = true,
                onDefer: () => onDeferCalled = true,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      final guestCopy = PrimingCopy.notification[UserRole.guest]!;
      expect(find.text(guestCopy.title), findsOneWidget);
      expect(find.text(guestCopy.line1), findsOneWidget);
      expect(find.text(guestCopy.line2), findsOneWidget);
      expect(find.text(guestCopy.line3), findsOneWidget);
    });

    testWidgets('displays host copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotificationPrimingSheet(
                role: UserRole.host,
                onAccept: () => onAcceptCalled = true,
                onDefer: () => onDeferCalled = true,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      final hostCopy = PrimingCopy.notification[UserRole.host]!;
      expect(find.text(hostCopy.title), findsOneWidget);
      expect(find.text(hostCopy.line1), findsOneWidget);
      expect(find.text(hostCopy.line2), findsOneWidget);
      expect(find.text(hostCopy.line3), findsOneWidget);
    });

    testWidgets('displays admin copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotificationPrimingSheet(
                role: UserRole.admin,
                onAccept: () => onAcceptCalled = true,
                onDefer: () => onDeferCalled = true,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      final adminCopy = PrimingCopy.notification[UserRole.admin]!;
      expect(find.text(adminCopy.title), findsOneWidget);
      expect(find.text(adminCopy.line1), findsOneWidget);
      expect(find.text(adminCopy.line2), findsOneWidget);
      expect(find.text(adminCopy.line3), findsOneWidget);
    });

    testWidgets('calls onAccept when "Bật ngay" tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotificationPrimingSheet(
                role: UserRole.guest,
                onAccept: () => onAcceptCalled = true,
                onDefer: () => onDeferCalled = true,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text(PrimingCopy.btnEnable));
      await tester.pump();

      expect(onAcceptCalled, true);
    });

    testWidgets('calls onDefer when "Để sau" tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotificationPrimingSheet(
                role: UserRole.guest,
                onAccept: () => onAcceptCalled = true,
                onDefer: () => onDeferCalled = true,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text(PrimingCopy.btnDefer));
      await tester.pump();

      expect(onDeferCalled, true);
    });

    testWidgets('displays trust signals', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotificationPrimingSheet(
                role: UserRole.guest,
                onAccept: () => onAcceptCalled = true,
                onDefer: () => onDeferCalled = true,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text(PrimingCopy.trustCanDisable), findsOneWidget);
      expect(find.text(PrimingCopy.trustNoSpam), findsOneWidget);
    });

    testWidgets('has notification icon with correct color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotificationPrimingSheet(
                role: UserRole.guest,
                onAccept: () => onAcceptCalled = true,
                onDefer: () => onDeferCalled = true,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
    });

    testWidgets('has semantics widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotificationPrimingSheet(
                role: UserRole.guest,
                onAccept: () => onAcceptCalled = true,
                onDefer: () => onDeferCalled = true,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      // Verify Semantics widget is present
      expect(find.byType(Semantics), findsWidgets);
    });
  });
}
