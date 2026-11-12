# AI Chat and JP API Wiring — Feature Documentation

> Source: plan `20261027-1102-jp-localization-mcp-ai-chatbot-registry`, Phase 10 and Phase 11.
> Scope: Flutter app only (`app/`, package `house_booking`). Backend contract: `backend/app/schemas/ai_chat.py`.

---

## 1. Overview

Phase 10 adds an AI chat screen that finds listings through `POST /api/ai/chat`, and replaces the mock JP listing
data on two guest screens with the real `/api/jp/listings` API. Phase 11 adds the confirmation step for write actions
proposed by the AI: a link screen (`/ai-confirm/:token`) and a confirm card and login prompt inside the chat.

| Area | Entry | Code |
|------|-------|------|
| AI chat (both markets, jp and vn) | Floating button in `GuestShell`, route `/ai-chat` | `lib/features/ai_chat/` |
| Confirm an AI write action (link) | Route `/ai-confirm/:token` (link from the MCP tool) | `lib/features/ai_chat/ai_action_confirm_screen.dart` |
| Confirm an AI write action (chat) | `pending_actions` in a chat reply | `lib/features/ai_chat/widgets/ai_chat_pending_card.dart` |
| JP search results | Apply a filter in the JP facets drawer on the guest home screen | `lib/features/guest/home/guest_home_screen.dart`, `.../home/widgets/jp_search_results_section.dart` |
| JP listing detail | `HouseDetailScreen` (`FeatureFlags.isJapan` only) | `lib/features/guest/house_detail/house_detail_screen.dart` |

---

## 2. AI chat

### 2.1 Route and entry point

- Route `/ai-chat` is declared in `lib/core/router/app_router.dart` outside the `if (FeatureFlags.isJapan)` block, so it
  exists in both the jp and vn builds.
- `GuestShell` (`lib/features/guest/guest_shell.dart`) renders a small `FloatingActionButton` (`heroTag: 'ai-chat-fab'`,
  `Icons.smart_toy_outlined`) at `right: 16, bottom: 96`. It calls `context.push('/ai-chat')`.
- Tapping a listing card inside the chat calls `context.push('/house/<listing_id>')` (default behaviour of `AiChatScreen`).

### 2.2 Request

`ApiAiChatRepository.send` (`lib/data/repositories/ai/api_ai_chat_repository.dart`) calls `ApiClient.post`:

```
POST /api/ai/chat
{ "messages": [{"role": "user" | "assistant", "content": "..."}], "lang": "<UI language code>" }
```

- `lang` is `Localizations.localeOf(context).languageCode` (`vi`, `en`, `zh`, `ja`), set when the screen creates its controller.
  The repository default is `ja`.
- Client timeout is 75 s (`ApiAiChatRepository.timeout`), set in the repository, not in `ApiClient`. The backend turn limit is
  60 s according to the code comment, so the client can receive the backend's JSON error instead of cutting the call first.
- `ApiClient` adds `Authorization: Bearer` when the user is logged in (comment in `api_ai_chat_repository.dart`).

### 2.3 History limits

History is kept in memory in `AiChatController` only. It is not persisted and is lost when the screen closes.

Limits applied to the history sent on every turn (`AiChatController._history`), mirroring `backend/app/schemas/ai_chat.py`:

| Limit | Value | Backend counterpart |
|-------|-------|---------------------|
| Turns sent | last 20 (`maxTurns`) | `messages` `max_length=20` |
| Total characters | 8000 (`maxTotalChars`) | `MAX_TOTAL_CHARS` |
| Characters per turn | 2000 (`maxTurnChars`), longer text is truncated when re-sent | `AiChatMessage.content` `max_length=2000` |

When trimming, the oldest turns are dropped until the total fits and the first turn has role `user`. The last turn is always kept.
The input field is also capped at 2000 characters (`maxLength: 2000` in `ai_chat_screen.dart`).

### 2.4 Response and rendering

`AiChatReply` (`lib/data/models/ai/ai_chat_models.dart`) reads `reply`, `listings`, `tool_rounds`, `pending_actions`
(default empty) and `login_required` (default `false`).
Each `listings` entry becomes an `AiListingCard` from snake_case keys: `listing_id`, `title`, `price`, `currency`, `area_m2`,
`layout`, `bedrooms`, `station_name`, `walk_min`, `city`, `thumbnail_url`. Entries without a numeric `listing_id` are dropped.

`AiChatListingCard` (`widgets/ai_chat_listing_card.dart`):

- Price uses `formatPrice` with `ja_JP` (shows ¥) unless `currency == 'VND'`, which uses `vi_VN` (shows ₫).
- Subtitle is `jpStationWalk(station, minutes)` when a station name exists; otherwise bedrooms and city joined by ` · `.

`AiChatController` copies `pendingActions` and `loginRequired` from the reply onto the assistant bubble, and
`AiChatBubbleView` renders one `AiChatPendingCard` per pending action (keyed by token) and an `AiChatLoginPrompt` when
`loginRequired` is true. See sections 2.8 and 2.9.

### 2.5 Errors and retry

`AiChatController._kindOf` maps the failure to `AiChatErrorKind`:

| Cause | Kind |
|-------|------|
| `TimeoutException` | `timeout` |
| `ApiException` with status 429 | `rateLimited` |
| `ApiException` with status >= 500 | `server` |
| anything else (including other 4xx) | `network` |

The screen shows an error bar with a retry button. `retry()` resends the current history without duplicating the last
user message; it does nothing unless the status is `error` and the last bubble is from the user.
A new `send` is ignored while a request is loading.

### 2.6 Empty state

`AiChatEmptyState` shows three tappable suggestions chosen by market: `aiChatSuggestionJp1..3` when `FeatureFlags.isJapan`,
otherwise `aiChatSuggestionVn1..3`. Tapping one sends it as the first message.

### 2.7 Confirm screen `/ai-confirm/:token`

Route `/ai-confirm/:token` is declared in `lib/core/router/app_router.dart` outside the `if (FeatureFlags.isJapan)` block
(both markets). A comment there states the prefix is not behind a guard, so a guest can open it and see the login prompt.
The screen is `AiActionConfirmScreen`; state is in `AiActionConfirmController`.

**Requests.** `ApiAiActionRepository` (`lib/data/repositories/ai/api_ai_action_repository.dart`, interface
`IAiActionRepository` in `lib/domain/repositories/ai/i_ai_action_repository.dart`), both through `ApiClient`, 20 s timeout
(`timeout`, set in the repository), token URL-encoded:

```
GET  /api/ai/actions/{token}?lang=<UI language code>     preview, writes nothing
POST /api/ai/actions/{token}/confirm                      executes; ApiClient adds Authorization: Bearer when logged in
```

**Flow.**

1. Opening the screen only calls the preview (`load()`). Writing happens only when the user taps the confirm button.
2. The preview shows an `AiActionSummaryCard` (section 2.9), the `aiConfirmWarning` text, a confirm button and a cancel button.
   Cancel pops the route, or goes to `/` when it cannot pop.
3. Tapping confirm sets status `submitting` immediately; `confirm()` is ignored unless the status is `ready`, so repeated taps send one request.
4. On success the status is `done` and the screen shows `aiConfirmDoneFavorite` for action `save_favorite`,
   `aiConfirmDoneViewing` for `request_viewing`, otherwise `aiConfirmDoneGeneric` (`aiConfirmDoneText`).

**Login state.** The screen reads `AuthProvider` on every dependency change: `isBootstrapping` gives `null` and the
controller stays in `loading`; otherwise `isAuthenticated` decides `ready` or `needLogin`. `AiActionConfirmController.setLoggedIn` and
`setLang` apply later changes: a login-state change re-settles the screen while it is waiting for the user, and a locale change reloads the preview
(ignored while `submitting` or after the result is in). A preview response for a language that is no longer current is discarded.

When not logged in, the summary is still shown, with `aiConfirmLoginRequired`, `aiConfirmReopenAfterLogin` and a login button
(`push('/login')`). Login does not return to this screen (code comment cites F26), which is why the text asks the user to reopen the link.

**Errors** (`AiActionConfirmController.kindOf`, shared with the chat card):

| Cause | Result |
|-------|--------|
| `ApiException` 401 (preview or confirm) | status `needLogin` |
| 404 | `notFound` |
| 409 | `used` |
| 410 | `expired` |
| 403 | `forbidden` |
| 422 | `invalid` |
| other status, timeout, no connection, parse error | `network`: error text `aiChatErrorNetwork` plus a retry button |

`retry()` works only for `network` errors; it reloads the preview and the user has to tap confirm again.

**Token handling.** The token lives in memory (route parameter, controller field, card field). A search of `lib/features/ai_chat/`
and `api_ai_action_repository.dart` found no `print`, `debugPrint` or `log(` call, and nothing persists it.

**Owner binding.** `AiPendingPreview` parses `owner_bound` but no app code reads it. The backend sets it from `owner_user_id is not None`
(`backend/app/services/ai_actions/confirm_service.py`), and writes `owner_user_id` as NULL for MCP-created pending actions
(`backend/app/services/ai_actions/pending_store.py`), so MCP links currently come back with `owner_bound: false`; a logged-in user confirms
under their own identity. The forbidden error appears only when the backend rejects a different owner.

### 2.8 Chat card and login prompt

- `AiChatPendingCard` (`widgets/ai_chat_pending_card.dart`) renders for each `pending_actions` entry (`token`, `action`, `title`, `params`,
  `expires_at`). It shows the same `AiActionSummaryCard` (without a listing block, since the entry carries none), the warning, a confirm
  and a cancel button, and calls the same `IAiActionRepository.confirm` (default `ApiAiActionRepository`).
- Cancel only sets the card to hidden. It makes no network call; the pending action expires on the backend.
- Confirm is locked while submitting. Success shows the same done text as section 2.7. A 401 shows `aiConfirmLoginRequired`.
  A `network` error shows the error text and keeps the buttons so the user can tap again; other error kinds show the text without buttons.
- The card uses `AutomaticKeepAliveClientMixin`, so a card that was cancelled or completed does not show the confirm button again after scrolling.
- `AiChatLoginPrompt` (`widgets/ai_chat_login_prompt.dart`) is shown when the reply has `login_required: true`: a lock icon,
  `aiConfirmLoginRequired` and a login button that calls `push('/login')`.
- `AiChatScreen` and `AiChatBubbleView` take an optional `actionRepository` so tests can inject a fake.

### 2.9 Summary card

`AiActionSummaryCard` (`widgets/ai_action_summary_card.dart`) is used by both the screen and the chat card. It shows:

- the action title;
- the listing (preview only): title, price and `layout`. Price uses `formatPrice` with `vi_VN` (₫) when `currency == 'VND'`, otherwise `ja_JP` (¥);
- `params.slots` (list), each formatted by `AiActionSummaryCard.jst` as `yyyy/MM/dd HH:mm` in JST (UTC+9) regardless of the device time zone;
  an unparsable string is shown as received;
- `params.note` when it is a non-empty string, under `aiConfirmNote`. The code comment explains why: the note is sent as written to the
  person in charge under the confirming user's name, so it must be visible before confirming;
- the expiry (`expires_at`) as `aiConfirmExpiresAt`, converted to the device's local time with the same pattern.

---

## 3. JP API wiring

- **Listing detail.** `HouseDetailScreen` now uses `ApiJpListingRepository` (was `MockJpListingRepository`). When
  `FeatureFlags.isJapan`, it calls `getById`, which requests `GET /api/jp/listings/{id}`. A failed call is swallowed
  and the detail page shows the non-JP content only.
- **Search results.** Applying a filter in `JpSearchFacetsDrawer` triggers `_taiKetQuaJp` in `GuestHomeScreen`, which calls
  `ApiJpListingRepository.search` (`GET /api/jp/listings`) with `filter.toSearchParams()`. A newer filter application
  discards the result of an older one still in flight.
- **Results section.** `JpSearchResultsSection` renders only after a filter is applied (and only when `FeatureFlags.isJapan`).
  It has four states: loading spinner, error with retry (`aiChatErrorNetwork` text, retry re-runs the last filter),
  empty (`jpSearchResultsEmpty`), and a list of `AiChatListingCard` (title `jpSearchResultsTitle(count)`).
  A card opens `/house/<listing_id>`. The JP listing is mapped to `AiListingCard` with `currency: 'JPY'`.

---

## 4. Localization

Strings live in `lib/l10n/app_{vi,en,zh,ja}.arb` with the generated `app_localizations*.dart`. Keys added for this phase
use the prefixes `aiChat*`, `aiCardBedrooms`, `jpSearch*` and `jpStationWalk`. The `aiChat*` keys cover title, tooltip,
input hint, send, empty title, six suggestions, thinking label, four error messages and retry.

Phase 11 adds 18 `aiConfirm*` keys (title, warning, confirm and cancel buttons, login required, login button, reopen-after-login,
three done messages, five error messages, slots label, `aiConfirmExpiresAt` with a `{time}` placeholder, note label) to the four ARB files.

---

## 5. Tests

| Path | Covers |
|------|--------|
| `test/data/repositories/ai/api_ai_chat_repository_test.dart` | `ApiAiChatRepository` |
| `test/features/ai_chat/ai_chat_controller_test.dart` | history limits, error kinds, retry |
| `test/features/ai_chat/ai_chat_screen_test.dart` | screen (uses `fake_ai_chat_repository.dart`) |
| `test/data/repositories/ai/api_ai_action_repository_test.dart` | `ApiAiActionRepository` |
| `test/features/ai_chat/ai_action_confirm_controller_test.dart` | `AiActionConfirmController` |
| `test/features/ai_chat/ai_action_confirm_screen_test.dart` | `AiActionConfirmScreen` (uses `fake_ai_action_repository.dart`) |
| `test/features/ai_chat/ai_chat_pending_card_test.dart` | `AiChatPendingCard` |
| `test/data/repositories/jp/api_jp_listing_repository_test.dart` | `ApiJpListingRepository` |
| `test/features/guest/jp_search_results_section_test.dart` | `JpSearchResultsSection` |

Test file contents were not re-run for this document. Run commands for the app: see `app/CLAUDE.md` (Docker-based `flutter test`).
