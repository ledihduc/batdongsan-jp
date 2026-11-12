/// Màn `/ai-confirm/:token`: xem trước, mời đăng nhập, xác nhận 1 lần, lỗi theo mã, slot JST, bản vi + ₫ (Phase 11, AC14).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/format/currency.dart';
import 'package:house_booking/data/models/ai/ai_pending_action_models.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/features/ai_chat/ai_action_confirm_screen.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:provider/provider.dart';

import 'fake_ai_action_repository.dart';

Future<AppLocalizations> _pump(WidgetTester t, FakeAiActionRepository repo,
    {bool isLoggedIn = true, String locale = 'ja'}) async {
  await t.pumpWidget(MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: AiActionConfirmScreen(token: tok, repository: repo, isLoggedIn: isLoggedIn),
  ));
  await t.pumpAndSettle();
  return AppLocalizations.delegate.load(Locale(locale));
}

void main() {
  testWidgets('ai_action_confirm_screen_ready_shows_action_listing_warning_and_buttons', (t) async {
    // Arrange + Act
    final l = await _pump(t, FakeAiActionRepository(previewResult: favoritePreview()));
    // Assert
    expect(find.text('お気に入りに保存'), findsOneWidget);
    expect(find.text('[SBY-OK1] 渋谷1LDK'), findsOneWidget);
    expect(find.text('¥120,000'), findsOneWidget);
    expect(find.text(l.aiConfirmWarning), findsOneWidget);
    expect(find.text(l.aiConfirmButton), findsOneWidget);
  });

  testWidgets('ai_action_confirm_screen_not_logged_in_shows_login_prompt_without_confirm_button', (t) async {
    // Arrange + Act
    final l = await _pump(t, FakeAiActionRepository(previewResult: favoritePreview()), isLoggedIn: false);
    // Assert
    expect(find.text(l.aiConfirmLoginRequired), findsOneWidget);
    expect(find.text(l.aiConfirmReopenAfterLogin), findsOneWidget);
    expect(find.text(l.aiConfirmLoginButton), findsOneWidget);
    expect(find.text(l.aiConfirmButton), findsNothing);
    expect(find.text('お気に入りに保存'), findsOneWidget); // vẫn thấy tóm tắt
  });

  testWidgets('ai_action_confirm_screen_tap_confirm_twice_calls_repository_once_and_shows_done', (t) async {
    // Arrange
    final gate = Completer<void>();
    final repo = FakeAiActionRepository(previewResult: favoritePreview(), confirmResult: favoriteDone, confirmGate: gate);
    final l = await _pump(t, repo);
    // Act
    await t.tap(find.text(l.aiConfirmButton));
    await t.pump();
    await t.tap(find.text(l.aiConfirmButton), warnIfMissed: false);
    await t.pump();
    gate.complete();
    await t.pumpAndSettle();
    // Assert
    expect(repo.confirmCalls, 1);
    expect(find.text(l.aiConfirmDoneFavorite), findsOneWidget);
    expect(find.text(l.aiConfirmButton), findsNothing);
  });

  testWidgets('ai_action_confirm_screen_expired_shows_japanese_expired_message', (t) async {
    // Arrange + Act
    final l = await _pump(t, FakeAiActionRepository(previewError: ApiException(410, 'expired')));
    // Assert
    expect(find.text(l.aiConfirmErrorExpired), findsOneWidget);
    expect(find.text(l.aiConfirmButton), findsNothing);
  });

  testWidgets('ai_action_confirm_screen_used_shows_already_processed', (t) async {
    // Arrange
    final repo = FakeAiActionRepository(previewResult: favoritePreview(), confirmError: ApiException(409, 'used'));
    final l = await _pump(t, repo);
    // Act
    await t.tap(find.text(l.aiConfirmButton));
    await t.pumpAndSettle();
    // Assert
    expect(find.text(l.aiConfirmErrorUsed), findsOneWidget);
  });

  testWidgets('ai_action_confirm_screen_forbidden_shows_other_account_message', (t) async {
    // Arrange
    final repo = FakeAiActionRepository(previewResult: favoritePreview(), confirmError: ApiException(403, 'forbidden'));
    final l = await _pump(t, repo);
    // Act
    await t.tap(find.text(l.aiConfirmButton));
    await t.pumpAndSettle();
    // Assert
    expect(find.text(l.aiConfirmErrorForbidden), findsOneWidget);
  });

  testWidgets('ai_action_confirm_screen_request_viewing_shows_slots_in_jst', (t) async {
    // Arrange
    final preview = AiPendingPreview(
      action: 'request_viewing',
      title: '内見を申し込む',
      description: '',
      params: const {'listing_id': 1, 'slots': ['2026-10-29T11:00:00+09:00', '2026-10-30T05:30:00Z']},
      listing: const AiPendingListing(listingId: 1, title: '渋谷 1LDK', price: 120000, currency: 'JPY'),
      status: 'pending',
      expiresAt: DateTime.utc(2026, 10, 28, 3, 15),
      ownerBound: true,
    );
    // Act
    final l = await _pump(t, FakeAiActionRepository(previewResult: preview));
    // Assert
    expect(find.text(l.aiConfirmSlots), findsOneWidget);
    expect(find.text('2026/10/29 11:00'), findsOneWidget);
    expect(find.text('2026/10/30 14:30'), findsOneWidget); // UTC 05:30 ⇒ JST 14:30
  });

  testWidgets('ai_action_confirm_screen_vi_locale_vnd_listing_shows_vietnamese_text', (t) async {
    // Arrange
    final repo = FakeAiActionRepository(
      previewResult: favoritePreview(
        listing: const AiPendingListing(listingId: 9, title: 'Căn hộ Quận 1', price: 15000000, currency: 'VND'),
      ),
    );
    // Act
    final l = await _pump(t, repo, locale: 'vi');
    // Assert
    expect(find.text(l.aiConfirmWarning), findsOneWidget);
    expect(l.aiConfirmWarning, 'Nếu bạn không yêu cầu việc này, đừng xác nhận.');
    expect(find.text(formatPrice(15000000, locale: 'vi_VN')), findsOneWidget);
    expect(repo.previewLangs.single, 'vi');
  });

  testWidgets('ai_action_confirm_screen_session_restored_after_open_shows_confirm_not_login', (t) async {
    // Arrange — mở link = tải lại trang: phiên khôi phục SAU frame đầu (QA C1)
    final auth = _RestoringAuth();
    await t.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiActionConfirmScreen(token: tok, repository: FakeAiActionRepository(previewResult: favoritePreview())),
      ),
    ));
    await t.pump();
    await t.pump(); // xem trước đã về; phiên còn khôi phục ⇒ vòng chờ quay mãi, không pumpAndSettle được
    final l = await AppLocalizations.delegate.load(const Locale('ja'));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(l.aiConfirmLoginRequired), findsNothing); // đang khôi phục ⇒ chưa mời đăng nhập
    // Act
    auth.finish(authenticated: true);
    await t.pumpAndSettle();
    // Assert
    expect(find.text(l.aiConfirmButton), findsOneWidget);
    expect(find.text(l.aiConfirmLoginRequired), findsNothing);
  });

  testWidgets('ai_action_confirm_screen_request_viewing_note_is_shown_before_confirm', (t) async {
    // Arrange — note được gửi nguyên văn cho người phụ trách ⇒ phải hiện (QA H1)
    final preview = AiPendingPreview(
      action: 'request_viewing', title: '内見を申し込む', description: '',
      params: const {'listing_id': 1, 'slots': ['2026-10-29T11:00:00+09:00'], 'note': '鍵は郵便受けに入れてください'},
      status: 'pending', expiresAt: DateTime.utc(2026, 10, 28, 3, 15), ownerBound: false,
    );
    // Act
    final l = await _pump(t, FakeAiActionRepository(previewResult: preview));
    // Assert
    expect(find.text(l.aiConfirmNote), findsOneWidget);
    expect(find.text('鍵は郵便受けに入れてください'), findsOneWidget);
  });

  testWidgets('ai_action_confirm_screen_timeout_then_retry_loads_preview', (t) async {
    // Arrange (QA M2)
    final repo = FakeAiActionRepository(previewResult: favoritePreview(), previewError: TimeoutException('slow'));
    final l = await _pump(t, repo);
    expect(find.text(l.aiChatErrorNetwork), findsOneWidget);
    repo.previewError = null;
    // Act
    await t.tap(find.text(l.aiChatRetry));
    await t.pumpAndSettle();
    // Assert
    expect(find.text(l.aiConfirmButton), findsOneWidget);
  });
}

class _RestoringAuth extends AuthProvider {
  bool _boot = true;
  bool _auth = false;

  @override
  bool get isBootstrapping => _boot;

  @override
  bool get isAuthenticated => _auth;

  void finish({required bool authenticated}) {
    _boot = false;
    _auth = authenticated;
    notifyListeners();
  }
}
