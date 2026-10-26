import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/features/permissions/copy/priming_copy.dart';
import 'package:house_booking/features/permissions/widgets/soft_reask_banner.dart';

void main() {
  group('SoftReaskBanner', () {
    late bool onOpenSettingsCalled;
    late bool onDismissCalled;

    setUp(() {
      onOpenSettingsCalled = false;
      onDismissCalled = false;
    });

    testWidgets('displays notification message for notification kind', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoftReaskBanner(
              kind: PermissionKind.notification,
              onOpenSettings: () => onOpenSettingsCalled = true,
              onDismiss: () => onDismissCalled = true,
            ),
          ),
        ),
      );

      expect(find.text(PrimingCopy.softReaskNotif), findsOneWidget);
    });

    testWidgets('displays camera message for camera kind', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoftReaskBanner(
              kind: PermissionKind.camera,
              onOpenSettings: () => onOpenSettingsCalled = true,
              onDismiss: () => onDismissCalled = true,
            ),
          ),
        ),
      );

      expect(find.text(PrimingCopy.softReaskCamera), findsOneWidget);
    });

    testWidgets('calls onOpenSettings when button tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoftReaskBanner(
              kind: PermissionKind.notification,
              onOpenSettings: () => onOpenSettingsCalled = true,
              onDismiss: () => onDismissCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text(PrimingCopy.softReaskOpenSettings));
      await tester.pump();

      expect(onOpenSettingsCalled, true);
    });

    testWidgets('calls onDismiss when dismiss button tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoftReaskBanner(
              kind: PermissionKind.notification,
              onOpenSettings: () => onOpenSettingsCalled = true,
              onDismiss: () => onDismissCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text(PrimingCopy.softReaskDismiss));
      await tester.pump();

      expect(onDismissCalled, true);
    });

    testWidgets('banner hidden after dismiss', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoftReaskBanner(
              kind: PermissionKind.notification,
              onOpenSettings: () => onOpenSettingsCalled = true,
              onDismiss: () => onDismissCalled = true,
            ),
          ),
        ),
      );

      expect(find.text(PrimingCopy.softReaskNotif), findsOneWidget);

      await tester.tap(find.text(PrimingCopy.softReaskDismiss));
      await tester.pump();

      expect(find.text(PrimingCopy.softReaskNotif), findsNothing);
    });

    testWidgets('displays notification icon for notification kind', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoftReaskBanner(
              kind: PermissionKind.notification,
              onOpenSettings: () => onOpenSettingsCalled = true,
              onDismiss: () => onDismissCalled = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
    });

    testWidgets('displays camera icon for camera kind', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoftReaskBanner(
              kind: PermissionKind.camera,
              onOpenSettings: () => onOpenSettingsCalled = true,
              onDismiss: () => onDismissCalled = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.no_photography_outlined), findsOneWidget);
    });

    testWidgets('banner renders without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoftReaskBanner(
              kind: PermissionKind.notification,
              onOpenSettings: () => onOpenSettingsCalled = true,
              onDismiss: () => onDismissCalled = true,
            ),
          ),
        ),
      );

      // Verify banner is rendered
      expect(find.byType(SoftReaskBanner), findsOneWidget);
    });

    testWidgets('has semantics widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SoftReaskBanner(
              kind: PermissionKind.notification,
              onOpenSettings: () => onOpenSettingsCalled = true,
              onDismiss: () => onDismissCalled = true,
            ),
          ),
        ),
      );

      expect(find.byType(Semantics), findsWidgets);
    });
  });
}
