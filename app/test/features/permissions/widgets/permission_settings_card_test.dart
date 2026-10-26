import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/features/permissions/copy/priming_copy.dart';
import 'package:house_booking/features/permissions/widgets/permission_settings_card.dart';

void main() {
  group('PermissionSettingsCard', () {
    late bool onTapEnableCalled;

    setUp(() {
      onTapEnableCalled = false;
    });

    testWidgets('displays notification title when kind is notification',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PermissionSettingsCard(
                kind: PermissionKind.notification,
                isGranted: false,
                onTapEnable: () => onTapEnableCalled = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text(PrimingCopy.settingsNotifTitle), findsOneWidget);
    });

    testWidgets('displays camera title when kind is camera', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PermissionSettingsCard(
                kind: PermissionKind.camera,
                isGranted: false,
                onTapEnable: () => onTapEnableCalled = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text(PrimingCopy.settingsCameraTitle), findsOneWidget);
    });

    testWidgets('notification icon displayed when kind is notification',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PermissionSettingsCard(
                kind: PermissionKind.notification,
                isGranted: false,
                onTapEnable: () => onTapEnableCalled = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
    });

    testWidgets('camera icon displayed when kind is camera', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PermissionSettingsCard(
                kind: PermissionKind.camera,
                isGranted: false,
                onTapEnable: () => onTapEnableCalled = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
    });

    testWidgets('calls onTapEnable when card tapped and disabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PermissionSettingsCard(
                kind: PermissionKind.notification,
                isGranted: false,
                onTapEnable: () => onTapEnableCalled = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(onTapEnableCalled, true);
    });

    testWidgets('does not call onTapEnable when card tapped and enabled',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PermissionSettingsCard(
                kind: PermissionKind.notification,
                isGranted: true,
                onTapEnable: () => onTapEnableCalled = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(onTapEnableCalled, false);
    });

    testWidgets('displays Card widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PermissionSettingsCard(
                kind: PermissionKind.notification,
                isGranted: false,
                onTapEnable: () => onTapEnableCalled = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('has semantics widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PermissionSettingsCard(
                kind: PermissionKind.notification,
                isGranted: false,
                onTapEnable: () => onTapEnableCalled = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('granted card renders without error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PermissionSettingsCard(
                kind: PermissionKind.notification,
                isGranted: true,
                onTapEnable: () => onTapEnableCalled = true,
              ),
            ),
          ),
        ),
      );

      // Verify card is rendered
      expect(find.byType(PermissionSettingsCard), findsOneWidget);
    });
  });
}
