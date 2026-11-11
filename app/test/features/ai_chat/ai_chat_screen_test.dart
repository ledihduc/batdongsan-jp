/// Màn chat AI: gợi ý theo thị trường, trạng thái chờ/lỗi theo ngôn ngữ, thẻ tin theo tiền tệ (Phase 10, AC13).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/format/currency.dart';
import 'package:house_booking/data/models/ai/ai_chat_models.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/features/ai_chat/ai_chat_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';

import 'fake_ai_chat_repository.dart';

Future<AppLocalizations> _pump(WidgetTester t, FakeAiChatRepository repo,
    {String locale = 'ja', bool japan = true, void Function(int)? onOpen}) async {
  await t.pumpWidget(MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: AiChatScreen(repository: repo, japan: japan, onOpenListing: onOpen),
  ));
  await t.pumpAndSettle();
  return AppLocalizations.delegate.load(Locale(locale));
}

Future<void> _ask(WidgetTester t, String text) async {
  await t.enterText(find.byType(TextField), text);
  await t.tap(find.byKey(const Key('ai-chat-send')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('ai_chat_screen_no_messages_shows_suggestions', (t) async {
    // Arrange + Act
    final l = await _pump(t, FakeAiChatRepository());
    // Assert
    expect(find.text(l.aiChatSuggestionJp1), findsOneWidget);
    expect(find.text(l.aiChatEmptyTitle), findsOneWidget);
  });

  testWidgets('ai_chat_screen_vn_market_shows_vn_suggestions', (t) async {
    // Arrange + Act
    final l = await _pump(t, FakeAiChatRepository(), locale: 'vi', japan: false);
    // Assert
    expect(find.text(l.aiChatSuggestionVn1), findsOneWidget);
    expect(find.text(l.aiChatSuggestionJp1), findsNothing);
  });

  testWidgets('ai_chat_screen_english_locale_shows_english_timeout_error', (t) async {
    // Arrange
    final repo = FakeAiChatRepository([TimeoutException('slow')]);
    await _pump(t, repo, locale: 'en');
    // Act
    await _ask(t, 'Shibuya');
    // Assert
    expect(find.text('The reply is taking too long. Please try again.'), findsOneWidget);
    expect(repo.langs.single, 'en');
  });

  testWidgets('ai_chat_screen_vnd_card_shows_dong_price_and_bedrooms', (t) async {
    // Arrange
    const card = AiListingCard(listingId: 3, title: 'Căn hộ Q1', price: 15000000, currency: 'VND', bedrooms: 2, city: 'Hồ Chí Minh');
    await _pump(t, FakeAiChatRepository([const AiChatReply(reply: 'Có 1 tin', listings: [card], toolRounds: 1)]),
        locale: 'vi', japan: false);
    // Act
    await _ask(t, 'Quận 1');
    // Assert
    expect(find.text(formatPrice(15000000, locale: 'vi_VN')), findsOneWidget);
    expect(find.textContaining('2 phòng ngủ'), findsOneWidget);
    expect(find.textContaining('Hồ Chí Minh'), findsOneWidget);
  });

  testWidgets('ai_chat_screen_waiting_reply_shows_loading_indicator', (t) async {
    // Arrange
    final pending = Completer<AiChatReply>();
    await _pump(t, FakeAiChatRepository([pending]));
    // Act
    await t.enterText(find.byType(TextField), '渋谷');
    await t.tap(find.byKey(const Key('ai-chat-send')));
    await t.pump();
    // Assert
    expect(find.byKey(const Key('ai-chat-loading')), findsOneWidget);
    pending.complete(const AiChatReply(reply: 'ok', listings: [], toolRounds: 0));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('ai-chat-loading')), findsNothing);
  });

  testWidgets('ai_chat_screen_timeout_shows_japanese_error_and_retry', (t) async {
    // Arrange
    final l = await _pump(t, FakeAiChatRepository([TimeoutException('slow')]));
    // Act
    await _ask(t, '渋谷');
    // Assert
    expect(find.text(l.aiChatErrorTimeout), findsOneWidget);
    expect(find.text(l.aiChatRetry), findsOneWidget);
  });

  testWidgets('ai_chat_screen_rate_limited_shows_japanese_message', (t) async {
    // Arrange
    final l = await _pump(t, FakeAiChatRepository([ApiException(429, 'slow down')]));
    // Act
    await _ask(t, '渋谷');
    // Assert
    expect(find.text(l.aiChatErrorRateLimited), findsOneWidget);
  });

  testWidgets('ai_chat_screen_server_error_shows_japanese_message', (t) async {
    // Arrange
    final l = await _pump(t, FakeAiChatRepository([ApiException(502, 'bad gateway')]));
    // Act
    await _ask(t, '渋谷');
    // Assert
    expect(find.text(l.aiChatErrorServer), findsOneWidget);
  });

  testWidgets('ai_chat_screen_reply_shows_listing_cards_with_yen_price', (t) async {
    // Arrange
    int? opened;
    await _pump(t, FakeAiChatRepository([const AiChatReply(reply: '1件です', listings: [yenCard], toolRounds: 1)]),
        onOpen: (id) => opened = id);
    // Act
    await _ask(t, '渋谷');
    await t.tap(find.text('¥120,000'));
    // Assert
    expect(find.text('¥120,000'), findsOneWidget);
    expect(find.text('渋谷 徒歩8分'), findsOneWidget);
    expect(opened, 7);
  });

  testWidgets('ai_chat_screen_tap_retry_resends_question', (t) async {
    // Arrange
    final repo = FakeAiChatRepository([TimeoutException('slow'), const AiChatReply(reply: '見つかりました', listings: [], toolRounds: 1)]);
    final l = await _pump(t, repo);
    await _ask(t, '渋谷');
    // Act
    await t.tap(find.text(l.aiChatRetry));
    await t.pumpAndSettle();
    // Assert
    expect(repo.calls, hasLength(2));
    expect(repo.calls.last.last.content, '渋谷');
    expect(find.text('見つかりました'), findsOneWidget);
    expect(find.text(l.aiChatErrorTimeout), findsNothing);
  });
}
