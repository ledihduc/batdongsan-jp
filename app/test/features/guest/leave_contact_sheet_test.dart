/// Test khoá LeaveContactSheet — thu Tên+SĐT gửi lead (không cần login).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_booking/data/services/lead_api.dart';
import 'package:house_booking/features/guest/leads/leave_contact_sheet.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class _FakeLeadApi extends LeadApi {
  const _FakeLeadApi(this._sink);
  final List<Map<String, String?>> _sink;
  @override
  Future<void> submit({
    required String name,
    required String phone,
    required String source,
    String? note,
    String? world,
    String? provinceCode,
  }) async {
    _sink.add({'name': name, 'phone': phone, 'source': source, 'world': world});
  }
}

void main() {
  testWidgets('nhập Tên+SĐT → gửi lead + hiện thành công', (tester) async {
    final sent = <Map<String, String?>>[];
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () => showLeaveContactSheet(ctx,
                  source: 'save_home',
                  world: 'realestate',
                  api: _FakeLeadApi(sent)),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Nguyễn A');
    await tester.enterText(find.byType(TextField).at(1), '0912345678');
    await tester.tap(find.text('Gửi'));
    await tester.pumpAndSettle();

    expect(sent, hasLength(1));
    expect(sent.first['phone'], '0912345678');
    expect(sent.first['source'], 'save_home');
    expect(sent.first['world'], 'realestate');
    // Màn thành công.
    expect(find.text('Đã nhận thông tin!'), findsOneWidget);
  });

  testWidgets('SĐT quá ngắn → báo lỗi, không gửi', (tester) async {
    final sent = <Map<String, String?>>[];
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('vi'),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () => showLeaveContactSheet(ctx,
                  source: 'x', api: _FakeLeadApi(sent)),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'A');
    await tester.enterText(find.byType(TextField).at(1), '123');
    await tester.tap(find.text('Gửi'));
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
  });
}
