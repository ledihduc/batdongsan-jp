/// Bộ chọn ngôn ngữ dùng chung (Settings, drawer, AppBar chat): 4 ngôn ngữ, đổi locale (Phase 14, S13).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/widgets/language_picker_sheet.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/locale_provider.dart';
import 'package:provider/provider.dart';

Widget _host(LocaleProvider p) => ChangeNotifierProvider.value(
      value: p,
      child: Consumer<LocaleProvider>(
        builder: (_, lp, _) => MaterialApp(
          locale: lp.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(appBar: AppBar(actions: const [LanguagePickerButton()])),
        ),
      ),
    );

Future<void> _open(WidgetTester t) async {
  await t.tap(find.byKey(const Key('language-picker-button')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('language_picker_sheet_lists_four_languages_and_marks_current', (t) async {
    // Arrange
    await t.pumpWidget(_host(LocaleProvider(japan: true)));
    // Act
    await _open(t);
    // Assert
    for (final name in ['日本語', 'Tiếng Việt', 'English', '中文']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('language_picker_sheet_tap_english_sets_locale_en', (t) async {
    // Arrange
    final p = LocaleProvider(japan: true);
    await t.pumpWidget(_host(p));
    await _open(t);
    // Act
    await t.tap(find.text('English'));
    await t.pumpAndSettle();
    // Assert
    expect(p.locale.languageCode, 'en');
    expect(find.text('中文'), findsNothing); // sheet đã đóng
  });

  testWidgets('language_picker_button_tooltip_follows_ui_language', (t) async {
    // Arrange
    final lVi = await AppLocalizations.delegate.load(const Locale('vi'));
    // Act
    await t.pumpWidget(_host(LocaleProvider(japan: false)));
    // Assert
    final button = t.widget<IconButton>(find.byKey(const Key('language-picker-button')));
    expect(button.tooltip, lVi.language);
  });

  testWidgets('language_picker_sheet_short_viewport_all_languages_reachable', (t) async {
    // Arrange — viewport ngang thấp (QA P14 F4)
    t.view.physicalSize = const Size(800, 300);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final p = LocaleProvider(japan: true);
    await t.pumpWidget(_host(p));
    await _open(t);
    // Act
    await t.scrollUntilVisible(find.text('中文'), 50, scrollable: find.byType(Scrollable).last);
    await t.tap(find.text('中文'));
    await t.pumpAndSettle();
    // Assert
    expect(t.takeException(), isNull);
    expect(p.locale.languageCode, 'zh');
  });
}
