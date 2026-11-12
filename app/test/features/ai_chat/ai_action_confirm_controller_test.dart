/// `AiActionConfirmController`: phiên/ngôn ngữ khôi phục muộn, map lỗi, thử lại (Phase 11, QA C1/M1/M2).
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/features/ai_chat/ai_action_confirm_controller.dart';

import 'fake_ai_action_repository.dart';

void main() {
  test('ai_action_confirm_controller_unknown_login_stays_loading_then_ready_after_restore', () async {
    // Arrange
    final c = AiActionConfirmController(FakeAiActionRepository(previewResult: favoritePreview()), token: tok);
    await c.load();
    expect(c.status, AiConfirmStatus.loading);
    // Act
    c.setLoggedIn(true);
    // Assert
    expect(c.status, AiConfirmStatus.ready);
  });

  test('ai_action_confirm_controller_login_after_need_login_becomes_ready', () async {
    // Arrange
    final c = AiActionConfirmController(FakeAiActionRepository(previewResult: favoritePreview()), token: tok, isLoggedIn: false);
    await c.load();
    expect(c.status, AiConfirmStatus.needLogin);
    // Act
    c.setLoggedIn(true);
    // Assert
    expect(c.status, AiConfirmStatus.ready);
  });

  test('ai_action_confirm_controller_lang_restored_reloads_preview_in_new_lang', () async {
    // Arrange
    final repo = FakeAiActionRepository(previewResult: favoritePreview());
    final c = AiActionConfirmController(repo, token: tok, isLoggedIn: true);
    await c.load();
    // Act
    c.setLang('vi');
    await Future<void>.delayed(Duration.zero);
    // Assert
    expect(repo.previewLangs, ['ja', 'vi']);
    expect(c.status, AiConfirmStatus.ready);
  });

  test('ai_action_confirm_controller_done_ignores_lang_change', () async {
    // Arrange
    final repo = FakeAiActionRepository(previewResult: favoritePreview(), confirmResult: favoriteDone);
    final c = AiActionConfirmController(repo, token: tok, isLoggedIn: true);
    await c.load();
    await c.confirm();
    // Act
    c.setLang('en');
    // Assert
    expect(repo.previewLangs, ['ja']);
    expect(c.status, AiConfirmStatus.done);
  });

  test('ai_action_confirm_controller_401_on_confirm_asks_login_again', () async {
    // Arrange
    final repo = FakeAiActionRepository(previewResult: favoritePreview(), confirmError: ApiException(401, 'expired'));
    final c = AiActionConfirmController(repo, token: tok, isLoggedIn: true);
    await c.load();
    // Act
    await c.confirm();
    // Assert
    expect(c.status, AiConfirmStatus.needLogin);
  });

  test('ai_action_confirm_controller_kind_of_maps_every_status', () {
    // Arrange + Act + Assert
    expect(AiActionConfirmController.kindOf(ApiException(404, '')), AiConfirmErrorKind.notFound);
    expect(AiActionConfirmController.kindOf(ApiException(409, '')), AiConfirmErrorKind.used);
    expect(AiActionConfirmController.kindOf(ApiException(410, '')), AiConfirmErrorKind.expired);
    expect(AiActionConfirmController.kindOf(ApiException(403, '')), AiConfirmErrorKind.forbidden);
    expect(AiActionConfirmController.kindOf(ApiException(422, '')), AiConfirmErrorKind.invalid);
    expect(AiActionConfirmController.kindOf(ApiException(502, '')), AiConfirmErrorKind.network);
    expect(AiActionConfirmController.kindOf(TimeoutException('slow')), AiConfirmErrorKind.network);
  });
}
