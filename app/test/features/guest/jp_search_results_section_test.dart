/// Khối kết quả tìm kiếm JP ở home: rỗng / thẻ giá yên + ga (Phase 10, F-2).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/jp/jp_listing.dart';
import 'package:house_booking/features/guest/home/widgets/jp_search_results_section.dart';
import 'package:house_booking/l10n/app_localizations.dart';

Future<AppLocalizations> _pump(WidgetTester t, Widget child) async {
  await t.pumpWidget(MaterialApp(
    locale: const Locale('ja'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ));
  await t.pumpAndSettle();
  return AppLocalizations.delegate.load(const Locale('ja'));
}

void main() {
  testWidgets('jp_search_results_section_empty_shows_empty_message', (t) async {
    // Arrange + Act
    final l = await _pump(t, const JpSearchResultsSection(items: [], loading: false));
    // Assert
    expect(find.text(l.jpSearchResultsEmpty), findsOneWidget);
  });

  testWidgets('jp_search_results_section_loading_shows_progress', (t) async {
    // Arrange + Act
    await t.pumpWidget(MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: JpSearchResultsSection(items: [], loading: true)),
    ));
    await t.pump();
    // Assert
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('jp_search_results_section_items_show_yen_price_and_station', (t) async {
    // Arrange
    int? opened;
    const item = JpListingSummary(
      listingId: 11,
      title: '渋谷 1LDK',
      monthlyRent: 145000,
      layout: '1LDK',
      floorAreaM2: 35,
      nearestStationName: '渋谷',
      nearestStationWalkMin: 8,
    );
    final l = await _pump(t, JpSearchResultsSection(items: const [item], loading: false, onOpen: (id) => opened = id));
    // Act
    await t.tap(find.text('¥145,000'));
    // Assert
    expect(find.text('¥145,000'), findsOneWidget);
    expect(find.text('渋谷 徒歩8分'), findsOneWidget);
    expect(find.text(l.jpSearchResultsTitle(1)), findsOneWidget);
    expect(opened, 11);
  });

  testWidgets('jp_search_results_section_failed_shows_error_and_retry_not_empty', (t) async {
    // Arrange
    var retried = 0;
    final l = await _pump(t, JpSearchResultsSection(items: const [], loading: false, failed: true, onRetry: () => retried++));
    // Act
    await t.tap(find.text(l.aiChatRetry));
    // Assert
    expect(find.text(l.aiChatErrorNetwork), findsOneWidget);
    expect(find.text(l.jpSearchResultsEmpty), findsNothing);
    expect(retried, 1);
  });
}
