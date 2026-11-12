/// Đổi ngôn ngữ ngay trong màn chat AI: giao diện + `lang` gửi lên backend đổi theo (Phase 14, S7, T16).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/ai/ai_chat_models.dart';
import 'package:house_booking/domain/repositories/ai/i_ai_chat_repository.dart';
import 'package:house_booking/features/ai_chat/ai_chat_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/locale_provider.dart';
import 'package:provider/provider.dart';

class _RecordingRepo implements IAiChatRepository {
  String? lastLang;

  @override
  Future<AiChatReply> send(List<AiChatTurn> history, {String lang = 'ja'}) async {
    lastLang = lang;
    return const AiChatReply(reply: 'ok', listings: [], toolRounds: 0);
  }
}

Widget _host(LocaleProvider p, Widget home) => ChangeNotifierProvider.value(
      value: p,
      child: Consumer<LocaleProvider>(
        builder: (_, lp, _) => MaterialApp(
          locale: lp.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );

Future<void> _switchToEnglish(WidgetTester t) async {
  await t.tap(find.byKey(const Key('language-picker-button')));
  await t.pumpAndSettle();
  await t.tap(find.text('English'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('ai_chat_screen_language_button_switches_ui_to_english', (t) async {
    // Arrange
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    await t.pumpWidget(_host(LocaleProvider(japan: true), AiChatScreen(japan: true, repository: _RecordingRepo())));
    await t.pumpAndSettle();
    // Act
    await _switchToEnglish(t);
    // Assert
    expect(find.text(en.aiChatTitle), findsOneWidget);
    expect(find.text(en.aiChatSuggestionJp1), findsOneWidget);
  });

  testWidgets('ai_chat_screen_after_switch_sends_lang_en', (t) async {
    // Arrange
    final repo = _RecordingRepo();
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    await t.pumpWidget(_host(LocaleProvider(japan: true), AiChatScreen(japan: true, repository: repo)));
    await t.pumpAndSettle();
    await _switchToEnglish(t);
    // Act
    await t.tap(find.text(en.aiChatSuggestionJp1));
    await t.pumpAndSettle();
    // Assert
    expect(repo.lastLang, 'en');
  });

  testWidgets('ai_chat_screen_vn_default_vi_sends_lang_vi', (t) async {
    // Arrange
    final repo = _RecordingRepo();
    final vi = await AppLocalizations.delegate.load(const Locale('vi'));
    await t.pumpWidget(_host(LocaleProvider(japan: false), AiChatScreen(japan: false, repository: repo)));
    await t.pumpAndSettle();
    // Act
    await t.tap(find.text(vi.aiChatSuggestionVn1));
    await t.pumpAndSettle();
    // Assert
    expect(repo.lastLang, 'vi');
  });

  testWidgets('ai_chat_screen_switch_after_first_turn_sends_new_lang', (t) async {
    // Arrange — đã có 1 lượt bằng tiếng Nhật rồi mới đổi (QA P14 F5)
    final repo = _RecordingRepo();
    final ja = await AppLocalizations.delegate.load(const Locale('ja'));
    await t.pumpWidget(_host(LocaleProvider(japan: true), AiChatScreen(japan: true, repository: repo)));
    await t.pumpAndSettle();
    await t.tap(find.text(ja.aiChatSuggestionJp1));
    await t.pumpAndSettle();
    expect(repo.lastLang, 'ja');
    await _switchToEnglish(t);
    // Act
    await t.enterText(find.byType(TextField), 'Shibuya 1LDK');
    await t.tap(find.byKey(const Key('ai-chat-send')));
    await t.pumpAndSettle();
    // Assert
    expect(repo.lastLang, 'en');
  });
}
