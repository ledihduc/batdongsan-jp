# AI Chat and JP API Wiring — Feature Documentation

> Source: plan `20261027-1102-jp-localization-mcp-ai-chatbot-registry`, Phase 10.
> Scope: Flutter app only (`app/`, package `house_booking`). Backend contract: `backend/app/schemas/ai_chat.py`.

---

## 1. Overview

Phase 10 adds an AI chat screen that finds listings through `POST /api/ai/chat`, and replaces the mock JP listing
data on two guest screens with the real `/api/jp/listings` API.

| Area | Entry | Code |
|------|-------|------|
| AI chat (both markets, jp and vn) | Floating button in `GuestShell`, route `/ai-chat` | `lib/features/ai_chat/` |
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

`AiChatReply` (`lib/data/models/ai/ai_chat_models.dart`) reads `reply`, `listings` and `tool_rounds`.
Each `listings` entry becomes an `AiListingCard` from snake_case keys: `listing_id`, `title`, `price`, `currency`, `area_m2`,
`layout`, `bedrooms`, `station_name`, `walk_min`, `city`, `thumbnail_url`. Entries without a numeric `listing_id` are dropped.

`AiChatListingCard` (`widgets/ai_chat_listing_card.dart`):

- Price uses `formatPrice` with `ja_JP` (shows ¥) unless `currency == 'VND'`, which uses `vi_VN` (shows ₫).
- Subtitle is `jpStationWalk(station, minutes)` when a station name exists; otherwise bedrooms and city joined by ` · `.

Not rendered yet: `pending_actions` and `login_required` (backend Phase 09). `AiChatReply` does not read them
(comment in `ai_chat_models.dart` says they are for Phase 11).

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

---

## 5. Tests

| Path | Covers |
|------|--------|
| `test/data/repositories/ai/api_ai_chat_repository_test.dart` | `ApiAiChatRepository` |
| `test/features/ai_chat/ai_chat_controller_test.dart` | history limits, error kinds, retry |
| `test/features/ai_chat/ai_chat_screen_test.dart` | screen (uses `fake_ai_chat_repository.dart`) |
| `test/data/repositories/jp/api_jp_listing_repository_test.dart` | `ApiJpListingRepository` |
| `test/features/guest/jp_search_results_section_test.dart` | `JpSearchResultsSection` |

Test file contents were not re-run for this document. Run commands for the app: see `app/CLAUDE.md` (Docker-based `flutter test`).
