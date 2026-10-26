# P0 Security Sweep — Plan

**Created:** 2026-06-28
**Status:** ✅ Done
**Trigger:** Audit phát hiện 6 backend router không có bất kỳ auth dep nào → PII leak + account takeover + impersonation rủi ro CRITICAL.
**Scope:** Bịt CRITICAL holes; KHÔNG ôm full Phase 02 của host plan (HostProfile rework / change_logs / HostScopedRepository — defer riêng).

## Mục tiêu

| KPI | Trước | Sau |
|---|---|---|
| Router không auth | 6 (users, wishlists, chat, notifications, upload, reviews) | 0 |
| Endpoint cho phép IDOR | nhiều (userId từ query/body) | 0 — actor lấy từ JWT sub |
| Endpoint admin-only nhưng public | 1 (GET /users) | 0 |
| `require_host` accept admin | Không | Có |
| Test smoke gate | Không | 17 test pytest pass |

## Threats đã chặn

| # | Threat | Trước | Sau |
|---|---|---|---|
| T1 | Account takeover (`PATCH /users/{id}` anonymous đổi email/role bất kỳ user) | Open | 401/403 — chỉ self hoặc admin sửa, chặn cả role escalation |
| T2 | PII leak (`GET /users` anonymous liệt kê toàn bộ user) | Open | 403 — admin-only |
| T3 | Wishlist IDOR (`?userId=X` đọc wishlist user khác) | Open | userId lấy từ JWT, query param bị ignore |
| T4 | Notification IDOR (đánh dấu read noti user khác → silence noti) | Open | ownership check trên notif.user_id |
| T5 | Chat impersonation (`sender_id` bất kỳ trong body → gửi message giả danh) | Open | sender_id LUÔN từ JWT sub |
| T6 | Chat eavesdrop (đọc history giữa B↔C bằng userId=B) | Open | actor LUÔN từ JWT |
| T7 | Anonymous file upload spam (fill ổ cứng) | Open | require_user + cap 8MB base64 |
| T8 | Fake review impersonation (`user_id` trong body → review giả danh) | Open | user_id từ JWT |

## Files đổi

**Backend (6 file):**
- `app/auth.py` — `require_host` accept admin; thêm `_ensure_owner_or_admin` helper
- `app/routers/users.py` — list = `require_admin`, patch = `require_user` + IDOR check, chặn `role` field escalation
- `app/routers/wishlists.py` — userId từ JWT, drop query/body param
- `app/routers/notifications.py` — userId từ JWT, ownership check trên mark_read
- `app/routers/chat.py` — sender + actor từ JWT cho TẤT CẢ endpoint
- `app/routers/upload.py` — `require_user` + size cap 8MB
- `app/routers/reviews.py` — POST require_user + user_id từ JWT (GET vẫn public)

**Frontend (4 file) — clean dead userId params:**
- `lib/providers/wishlist_provider.dart`
- `lib/providers/notification_provider.dart`
- `lib/providers/chat_provider.dart`
- `lib/data/services/review_service.dart`

**Tests (1 file mới):**
- `tests/security/test_security_sweep.py` — 17 test, không cần real DB (auth dep trip trước route function)

## Verify

```
cd ancu365-backend
python3 -m pytest tests/security/test_security_sweep.py -q
# 17 passed in 0.08s
```

```
cd ancu365-app
flutter analyze lib/providers/{wishlist,notification,chat}_provider.dart lib/data/services/review_service.dart
# 1 pre-existing info (use_null_aware_elements) — không liên quan refactor
```

## Out of scope (defer)

| Item | Lý do defer | Plan tiếp theo |
|---|---|---|
| `change_logs` audit table | Bigger lift, không block bleeding | host plan Phase 02 |
| `HostScopedRepository` base + cross-host integration test | Architectural pattern, cần cho Phase 03 đỡ rối | host plan Phase 02 |
| HostProfile rework + onboarding 3-step | Có sẵn, không bị thủng | host plan Phase 02 |
| Rate limit endpoint nhạy cảm (login, upload) | Mitigation P1, không cấp bách bằng auth gap | follow-up ticket |
| `planning`, `planning_tiles`, `catalog` để public | Read-only public data, ETL endpoint đã yêu cầu admin riêng | OK as-is |
| Postgres migration | Không có production data, không cấp bách | host plan Phase 01 |

## Risks còn lại (acceptable for now)

1. **No rate limit trên upload** — auth user vẫn có thể spam (chỉ ngăn anonymous abuse). Mitigation: monitor disk usage.
2. **No replay protection trên review POST** — auth user có thể spam review trên 1 nhà (dù logic dedupe trên `(user_id, house_id)` ngăn duplicate). Acceptable.
3. **`upgrade_to_host` vẫn dùng `require_user`** — intentional, đây là endpoint guest → host.
4. **`planning_tiles` + `catalog` để public** — read-only public data, không leak PII.

## Open questions cho user

1. **Rate limit cho `/api/upload`** — đặt giới hạn bao nhiêu/phút/user? (mặc định slowapi 60/min OK?)
2. **Bumping JWT TTL** — hiện `token_ttl_hours` setting, có cần rotate / refresh token flow? (không trong scope sweep nhưng nên có roadmap).
3. **Audit log cho `_ensure_owner_or_admin` 403** — log để phát hiện brute force enumeration?

## Next phase

Sau sweep này:
- (a) Tiếp tục host plan Phase 02 (Foundation full) — 4-5d, code on SQLite OK
- (b) Phase 01 Postgres migration — 2-3d, mechanical infra setup
- (c) Verify Phase 01b (Booking rename) thực sự done — 1h spot check
