/// Thẻ xác nhận trong chat + mời đăng nhập (Phase 11, AC14).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/ai/ai_chat_models.dart';
import 'package:house_booking/data/models/ai/ai_pending_action_models.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/features/ai_chat/ai_chat_screen.dart';
import 'package:house_booking/features/ai_chat/widgets/ai_chat_login_prompt.dart';
import 'package:house_booking/features/ai_chat/widgets/ai_chat_pending_card.dart';
import 'package:house_booking/l10n/app_localizations.dart';

import 'fake_ai_action_repository.dart';
import 'fake_ai_chat_repository.dart';

final _pending = AiPendingAction(
  token: tok,
  action: 'save_favorite',
  title: 'お気に入りに保存',
  params: const {'listing_id': 1},
  expiresAt: DateTime.utc(2026, 10, 28, 3, 15),
);

Future<AppLocalizations> _pump(WidgetTester t, Widget home) async {
  await t.pumpWidget(MaterialApp(
    locale: const Locale('ja'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ));
  await t.pumpAndSettle();
  return AppLocalizations.delegate.load(const Locale('ja'));
}

void main() {
  testWidgets('ai_chat_pending_card_tap_confirm_shows_done_message', (t) async {
    // Arrange
    final repo = FakeAiActionRepository(confirmResult: favoriteDone);
    final l = await _pump(t, Scaffold(body: AiChatPendingCard(pending: _pending, repository: repo)));
    // Act
    await t.tap(find.text(l.aiConfirmButton));
    await t.pumpAndSettle();
    // Assert
    expect(repo.confirmCalls, 1);
    expect(find.text(l.aiConfirmDoneFavorite), findsOneWidget);
    expect(find.text(l.aiConfirmButton), findsNothing);
  });

  testWidgets('ai_chat_pending_card_cancel_hides_card_without_request', (t) async {
    // Arrange
    final repo = FakeAiActionRepository(confirmResult: favoriteDone);
    final l = await _pump(t, Scaffold(body: AiChatPendingCard(pending: _pending, repository: repo)));
    // Act
    await t.tap(find.text(l.aiConfirmCancel));
    await t.pumpAndSettle();
    // Assert
    expect(find.text('お気に入りに保存'), findsNothing);
    expect(find.text(l.aiConfirmButton), findsNothing);
    expect(repo.confirmCalls, 0);
  });

  testWidgets('ai_chat_screen_login_required_reply_shows_login_prompt', (t) async {
    // Arrange
    final chat = FakeAiChatRepository([
      const AiChatReply(reply: 'ログインが必要です', listings: [], toolRounds: 1, loginRequired: true),
    ]);
    await _pump(t, AiChatScreen(repository: chat, japan: true));
    // Act
    await t.enterText(find.byType(TextField), 'お気に入りに保存して');
    await t.tap(find.byKey(const Key('ai-chat-send')));
    await t.pumpAndSettle();
    // Assert
    expect(find.byType(AiChatLoginPrompt), findsOneWidget);
  });

  testWidgets('ai_chat_screen_reply_with_pending_action_shows_pending_card', (t) async {
    // Arrange
    final chat = FakeAiChatRepository([
      AiChatReply(reply: '確認してください', listings: const [], toolRounds: 1, pendingActions: [_pending]),
    ]);
    final l = await _pump(t, AiChatScreen(repository: chat, japan: true, actionRepository: FakeAiActionRepository()));
    // Act
    await t.enterText(find.byType(TextField), 'お気に入りに保存して');
    await t.tap(find.byKey(const Key('ai-chat-send')));
    await t.pumpAndSettle();
    // Assert
    expect(find.byType(AiChatPendingCard), findsOneWidget);
    expect(find.text(l.aiConfirmButton), findsOneWidget);
  });

  testWidgets('ai_chat_pending_card_network_error_keeps_button_and_retry_confirms', (t) async {
    // Arrange (QA M2)
    final repo = FakeAiActionRepository(confirmResult: favoriteDone, confirmError: TimeoutException('slow'));
    final l = await _pump(t, Scaffold(body: AiChatPendingCard(pending: _pending, repository: repo)));
    await t.tap(find.text(l.aiConfirmButton));
    await t.pumpAndSettle();
    expect(find.text(l.aiChatErrorNetwork), findsOneWidget);
    repo.confirmError = null;
    // Act
    await t.tap(find.text(l.aiConfirmButton));
    await t.pumpAndSettle();
    // Assert
    expect(repo.confirmCalls, 2);
    expect(find.text(l.aiConfirmDoneFavorite), findsOneWidget);
  });

  testWidgets('ai_chat_pending_card_used_error_hides_confirm_button', (t) async {
    // Arrange — 409 không thử lại được
    final repo = FakeAiActionRepository(confirmError: ApiException(409, 'used'));
    final l = await _pump(t, Scaffold(body: AiChatPendingCard(pending: _pending, repository: repo)));
    // Act
    await t.tap(find.text(l.aiConfirmButton));
    await t.pumpAndSettle();
    // Assert
    expect(find.text(l.aiConfirmErrorUsed), findsOneWidget);
    expect(find.text(l.aiConfirmButton), findsNothing);
  });

  testWidgets('ai_chat_pending_card_cancelled_stays_hidden_after_scrolling_away_and_back', (t) async {
    // Arrange — ListView(children:) gỡ con ngoài màn ⇒ không keep-alive thì thẻ hiện lại (QA M3)
    final repo = FakeAiActionRepository(confirmResult: favoriteDone);
    final ctrl = ScrollController();
    final l = await _pump(t, Scaffold(body: ListView(controller: ctrl, children: [
      AiChatPendingCard(pending: _pending, repository: repo),
      const SizedBox(height: 5000),
    ])));
    await t.tap(find.text(l.aiConfirmCancel));
    await t.pumpAndSettle();
    // Act
    ctrl.jumpTo(4500);
    await t.pumpAndSettle();
    ctrl.jumpTo(0);
    await t.pumpAndSettle();
    // Assert
    expect(find.text(l.aiConfirmButton), findsNothing);
    expect(repo.confirmCalls, 0);
  });
}
