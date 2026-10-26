/// Widget tests for PeriodSwiper — arrow buttons, label, swipe gesture.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/host/analytics/services/period_helper.dart';
import 'package:house_booking/features/host/analytics/widgets/period_swiper.dart';
import '../helpers/pump_app.dart';

/// Helper that pumps PeriodSwiper with controllable state.
Future<void> _pump(
  WidgetTester tester, {
  required PeriodType period,
  required DateTime anchorDate,
  required DateTime currentPeriodStart,
  required void Function(int) onShift,
}) async {
  // PeriodSwiper ghi telemetry khi người dùng chuyển kỳ → cần Provider.
  await pumpApp(
    tester,
    Scaffold(
      body: PeriodSwiper(
        period: period,
        anchorDate: anchorDate,
        currentPeriodStart: currentPeriodStart,
        onShift: onShift,
        child: const SizedBox(height: 200, width: 400),
      ),
    ),
  );
}

void main() {
  group('PeriodSwiper', () {
    final pastMonth = DateTime(2026, 5, 1);
    final currentMonth = DateTime(2026, 6, 1);

    testWidgets('label shows PeriodHelper.displayLabel for month',
        (tester) async {
      await _pump(
        tester,
        period: PeriodType.month,
        anchorDate: pastMonth,
        currentPeriodStart: currentMonth,
        onShift: (_) {},
      );
      final expected = PeriodHelper.displayLabel(PeriodType.month, pastMonth);
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('label shows PeriodHelper.displayLabel for year',
        (tester) async {
      final pastYear = DateTime(2025, 1, 1);
      final currentYear = DateTime(2026, 1, 1);
      await _pump(
        tester,
        period: PeriodType.year,
        anchorDate: pastYear,
        currentPeriodStart: currentYear,
        onShift: (_) {},
      );
      final expected = PeriodHelper.displayLabel(PeriodType.year, pastYear);
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('left arrow tap triggers onShift(-1)', (tester) async {
      int? lastDelta;
      await _pump(
        tester,
        period: PeriodType.month,
        anchorDate: pastMonth,
        currentPeriodStart: currentMonth,
        onShift: (d) => lastDelta = d,
      );
      await tester.tap(find.byKey(const Key('period_back_btn')));
      await tester.pump();
      expect(lastDelta, -1);
    });

    testWidgets('right arrow tap triggers onShift(+1) when not at current period',
        (tester) async {
      int? lastDelta;
      await _pump(
        tester,
        period: PeriodType.month,
        anchorDate: pastMonth,
        currentPeriodStart: currentMonth,
        onShift: (d) => lastDelta = d,
      );
      await tester.tap(find.byKey(const Key('period_forward_btn')));
      await tester.pump();
      expect(lastDelta, 1);
    });

    testWidgets('right arrow disabled when anchor is at current period',
        (tester) async {
      int? lastDelta;
      await _pump(
        tester,
        period: PeriodType.month,
        anchorDate: currentMonth,
        currentPeriodStart: currentMonth,
        onShift: (d) => lastDelta = d,
      );
      await tester.tap(find.byKey(const Key('period_forward_btn')));
      await tester.pump();
      // Should not have fired since button is disabled
      expect(lastDelta, isNull);
    });

    testWidgets('swipe left (slow drag > 80px) triggers onShift(-1)',
        (tester) async {
      int? lastDelta;
      await _pump(
        tester,
        period: PeriodType.month,
        anchorDate: pastMonth,
        currentPeriodStart: currentMonth,
        onShift: (d) => lastDelta = d,
      );
      // Use slow drag > 80px to trigger displacement-based branch
      final swipeArea = find.byKey(const Key('period_swipe_area'));
      final center = tester.getCenter(swipeArea);
      final gesture = await tester.startGesture(center);
      // Move slowly leftward 90px (above 80px threshold)
      await gesture.moveBy(const Offset(-90, 0));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pump();
      expect(lastDelta, -1);
    });

    testWidgets(
        'swipe right (slow drag > 80px) triggers onShift(+1) when not at current period',
        (tester) async {
      int? lastDelta;
      await _pump(
        tester,
        period: PeriodType.month,
        anchorDate: pastMonth,
        currentPeriodStart: currentMonth,
        onShift: (d) => lastDelta = d,
      );
      final swipeArea = find.byKey(const Key('period_swipe_area'));
      final center = tester.getCenter(swipeArea);
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(90, 0));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pump();
      expect(lastDelta, 1);
    });

    testWidgets('both back and forward buttons exist', (tester) async {
      await _pump(
        tester,
        period: PeriodType.month,
        anchorDate: pastMonth,
        currentPeriodStart: currentMonth,
        onShift: (_) {},
      );
      expect(find.byKey(const Key('period_back_btn')), findsOneWidget);
      expect(find.byKey(const Key('period_forward_btn')), findsOneWidget);
    });
  });
}
