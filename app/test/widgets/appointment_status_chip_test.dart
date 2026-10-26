/// Widget tests for AppointmentStatusChip — verify all 7 statuses render
/// with the right label + icon, default to a sane fallback for unknowns.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/features/guest/booking/widgets/appointment_status_chip.dart';
import 'package:house_booking/l10n/app_localizations.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      // Chip giờ đọc AppLocalizations; ghim locale 'vi' để nhãn khớp assertion.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('AppointmentStatusChip', () {
    testWidgets('pending → "Chờ duyệt" with pending_actions icon',
        (tester) async {
      await _pump(tester, const AppointmentStatusChip(status: 'pending'));
      expect(find.text('Chờ duyệt'), findsOneWidget);
      expect(find.byIcon(Icons.pending_actions), findsOneWidget);
    });

    testWidgets('approved → "Đã duyệt"', (tester) async {
      await _pump(tester, const AppointmentStatusChip(status: 'approved'));
      expect(find.text('Đã duyệt'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('completed → "Hoàn thành"', (tester) async {
      await _pump(tester, const AppointmentStatusChip(status: 'completed'));
      expect(find.text('Hoàn thành'), findsOneWidget);
      expect(find.byIcon(Icons.task_alt), findsOneWidget);
    });

    testWidgets('cancelled → "Đã hủy"', (tester) async {
      await _pump(tester, const AppointmentStatusChip(status: 'cancelled'));
      // Chính tả phải khớp CHÍNH XÁC widget: app dùng "hủy" (dấu trên u), giống
      // màn Lịch sử đặt lịch cùng luồng. "huỷ" là chuỗi Unicode KHÁC.
      expect(find.text('Đã hủy'), findsOneWidget);
    });

    testWidgets('rejected → "Bị từ chối"', (tester) async {
      await _pump(tester, const AppointmentStatusChip(status: 'rejected'));
      expect(find.text('Bị từ chối'), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);
    });

    testWidgets('locked → "Đã chốt phòng"', (tester) async {
      await _pump(tester, const AppointmentStatusChip(status: 'locked'));
      expect(find.text('Đã chốt phòng'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('lost → "Đã có người chốt"', (tester) async {
      await _pump(tester, const AppointmentStatusChip(status: 'lost'));
      expect(find.text('Đã có người chốt'), findsOneWidget);
    });

    testWidgets('unknown status → fall back to raw status text',
        (tester) async {
      await _pump(tester, const AppointmentStatusChip(status: 'wibble'));
      expect(find.text('wibble'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('large size renders larger icon than normal', (tester) async {
      await _pump(
        tester,
        const AppointmentStatusChip(
          status: 'pending',
          size: AppointmentChipSize.large,
        ),
      );
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.pending_actions));
      expect(iconWidget.size, 18.0);
    });
  });
}
