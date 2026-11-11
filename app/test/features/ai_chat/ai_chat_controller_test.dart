/// `AiChatController`: trạng thái lỗi theo loại, thử lại, ghép câu trả lời (Phase 10, AC13).
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/data/models/ai/ai_chat_models.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/features/ai_chat/ai_chat_controller.dart';

import 'fake_ai_chat_repository.dart';

void main() {
  test('ai_chat_controller_timeout_sets_error_kind_timeout', () async {
    // Arrange
    final c = AiChatController(FakeAiChatRepository([TimeoutException('slow')]));
    // Act
    await c.send('渋谷');
    // Assert
    expect(c.status, AiChatStatus.error);
    expect(c.errorKind, AiChatErrorKind.timeout);
  });

  test('ai_chat_controller_429_sets_error_kind_rate_limited', () async {
    // Arrange
    final c = AiChatController(FakeAiChatRepository([ApiException(429, 'slow down')]));
    // Act
    await c.send('渋谷');
    // Assert
    expect(c.errorKind, AiChatErrorKind.rateLimited);
  });

  test('ai_chat_controller_503_sets_error_kind_server', () async {
    // Arrange
    final c = AiChatController(FakeAiChatRepository([ApiException(503, 'down')]));
    // Act
    await c.send('渋谷');
    // Assert
    expect(c.errorKind, AiChatErrorKind.server);
  });

  test('ai_chat_controller_retry_resends_last_user_question', () async {
    // Arrange
    final repo = FakeAiChatRepository([TimeoutException('slow')]);
    final c = AiChatController(repo, lang: 'vi');
    await c.send('Quận 1');
    // Act
    await c.retry();
    // Assert
    expect(repo.calls, hasLength(2));
    expect(repo.calls.last.last.content, 'Quận 1');
    expect(repo.calls.last.where((t) => t.role == 'user'), hasLength(1));
    expect(c.bubbles.where((b) => b.role == 'user'), hasLength(1));
    expect(c.status, AiChatStatus.idle);
    expect(repo.langs, ['vi', 'vi']);
  });

  test('ai_chat_controller_success_appends_assistant_bubble_with_listings', () async {
    // Arrange
    final repo = FakeAiChatRepository([const AiChatReply(reply: '1件です', listings: [yenCard], toolRounds: 1)]);
    final c = AiChatController(repo);
    // Act
    await c.send('渋谷');
    // Assert
    expect(c.status, AiChatStatus.idle);
    expect(c.bubbles.map((b) => b.role), ['user', 'assistant']);
    expect(c.bubbles.last.text, '1件です');
    expect(c.bubbles.last.listings.single.listingId, 7);
  });

  test('ai_chat_controller_long_history_sends_at_most_20_turns', () async {
    // Arrange
    final repo = FakeAiChatRepository();
    final c = AiChatController(repo);
    for (var i = 0; i < 12; i++) {
      await c.send('q$i');
    }
    // Act
    await c.send('last');
    // Assert
    final sent = repo.calls.last;
    expect(sent.length, lessThanOrEqualTo(20));
    expect(sent.first.role, 'user');
    expect(sent.last.content, 'last');
  });

  test('ai_chat_controller_long_replies_history_stays_within_backend_char_caps', () async {
    // Arrange — mỗi câu trả lời 3000 ký tự: không cắt thì lượt thứ 4 vượt 8000 ⇒ backend 422 mãi (QA H1).
    final long = 'あ' * 3000;
    final repo = FakeAiChatRepository([
      for (var i = 0; i < 5; i++) AiChatReply(reply: long, listings: const [], toolRounds: 0),
    ]);
    final c = AiChatController(repo);
    for (var i = 0; i < 5; i++) {
      await c.send('q$i');
    }
    // Act
    await c.send('last');
    // Assert
    final sent = repo.calls.last;
    final total = sent.fold<int>(0, (n, t) => n + t.content.length);
    expect(total, lessThanOrEqualTo(AiChatController.maxTotalChars));
    expect(sent.every((t) => t.content.length <= AiChatController.maxTurnChars), isTrue);
    expect(sent.first.role, 'user');
    expect(sent.last.content, 'last');
    expect(c.bubbles[1].text.length, 3000); // bong bóng hiển thị vẫn đủ, chỉ bản gửi đi bị cắt
  });

  test('ai_chat_controller_disposed_while_waiting_does_not_throw', () async {
    // Arrange
    final pending = Completer<AiChatReply>();
    final c = AiChatController(FakeAiChatRepository([pending]));
    final future = c.send('渋谷');
    // Act
    c.dispose();
    pending.complete(const AiChatReply(reply: 'ok', listings: [], toolRounds: 0));
    // Assert
    await expectLater(future, completes);
  });
}
