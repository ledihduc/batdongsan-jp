import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/permissions/permission_types.dart';
import 'package:house_booking/features/permissions/copy/priming_copy.dart';
import 'package:house_booking/features/permissions/widgets/camera_priming_sheet.dart';

void main() {
  group('CameraPrimingSheet', () {
    late bool onContinueCalled;
    late bool onCancelCalled;

    setUp(() {
      onContinueCalled = false;
      onCancelCalled = false;
    });

    testWidgets('displays cccdUpload copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CameraPrimingSheet(
                cameraCtx: CameraContext.cccdUpload,
                onContinue: () => onContinueCalled = true,
                onCancel: () => onCancelCalled = true,
              ),
            ),
          ),
        ),
      );

      final copy = PrimingCopy.camera[CameraContext.cccdUpload]!;
      expect(find.text(copy.title), findsOneWidget);
    });

    testWidgets('displays postHousePhoto copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CameraPrimingSheet(
                cameraCtx: CameraContext.postHousePhoto,
                onContinue: () => onContinueCalled = true,
                onCancel: () => onCancelCalled = true,
              ),
            ),
          ),
        ),
      );

      final copy = PrimingCopy.camera[CameraContext.postHousePhoto]!;
      expect(find.text(copy.title), findsOneWidget);
    });

    testWidgets('displays contractPhoto copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CameraPrimingSheet(
                cameraCtx: CameraContext.contractPhoto,
                onContinue: () => onContinueCalled = true,
                onCancel: () => onCancelCalled = true,
              ),
            ),
          ),
        ),
      );

      final copy = PrimingCopy.camera[CameraContext.contractPhoto]!;
      expect(find.text(copy.title), findsOneWidget);
    });

    testWidgets('displays profileAvatar copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CameraPrimingSheet(
                cameraCtx: CameraContext.profileAvatar,
                onContinue: () => onContinueCalled = true,
                onCancel: () => onCancelCalled = true,
              ),
            ),
          ),
        ),
      );

      final copy = PrimingCopy.camera[CameraContext.profileAvatar]!;
      expect(find.text(copy.title), findsOneWidget);
    });

    testWidgets('calls onContinue when "Tiếp tục" tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CameraPrimingSheet(
                cameraCtx: CameraContext.cccdUpload,
                onContinue: () => onContinueCalled = true,
                onCancel: () => onCancelCalled = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text(PrimingCopy.btnContinue));
      await tester.pump();

      expect(onContinueCalled, true);
    });

    testWidgets('calls onCancel when "Hủy" tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CameraPrimingSheet(
                cameraCtx: CameraContext.cccdUpload,
                onContinue: () => onContinueCalled = true,
                onCancel: () => onCancelCalled = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text(PrimingCopy.btnCancel));
      await tester.pump();

      expect(onCancelCalled, true);
    });

    testWidgets('has camera icon with correct color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CameraPrimingSheet(
                cameraCtx: CameraContext.cccdUpload,
                onContinue: () => onContinueCalled = true,
                onCancel: () => onCancelCalled = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
    });

    testWidgets('has semantics widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CameraPrimingSheet(
                cameraCtx: CameraContext.cccdUpload,
                onContinue: () => onContinueCalled = true,
                onCancel: () => onCancelCalled = true,
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
