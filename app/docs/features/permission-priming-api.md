# Permission Priming — Backend API Contract

**Status: DRAFT — implement on BE side**

This document is the deliverable for the backend team. It defines the 3 HTTP endpoints
required to support the Permission Priming feature on the client (Phase 6 of the
permission-priming-onboarding plan).

Client implementation is complete. BE implementation is pending. The client gracefully
degrades if any endpoint returns 4xx/5xx — it backs off and retries on next app foreground.

---

## Authentication

All 3 endpoints **MUST require JWT** via `Authorization: Bearer <token>`. Return 401 if
the token is missing, expired, or invalid. No anonymous access is permitted.

---

## 1. `POST /api/users/me/push-token`

Registers an FCM push token for the current user's device. Called after the OS grants
notification permission, and on every FCM token refresh.

### Auth

JWT required (existing scheme — reads `sub` claim for user identity).

### Request Body

```json
{
  "token": "fGxK8s...long_fcm_token...",
  "deviceId": "uuid-v4-from-permission-install-id",
  "platform": "ios"
}
```

**Field rules:**
- `token` — string, required. The FCM registration token for this device.
- `deviceId` — string, required. Opaque 32-char hex UUID generated on first install (`priming_install_id_v1` key in client secure storage). Stable per install, resets on uninstall.
- `platform` — enum, required. Must be one of: `"ios" | "android" | "web"`. Reject any other value with 400.

### Response 200

```json
{ "registered": true, "deviceCount": 2 }
```

- `deviceCount` — total number of registered devices for this user after upsert.

### Response 400

Schema violation: invalid `platform` enum value, missing required fields.

### Backend Storage

Table: `user_push_tokens`

```sql
CREATE TABLE user_push_tokens (
  user_id     BIGINT       NOT NULL REFERENCES users(id),
  device_id   VARCHAR(64)  NOT NULL,
  token       TEXT         NOT NULL,
  platform    VARCHAR(16)  NOT NULL CHECK (platform IN ('ios','android','web')),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (device_id)
);

CREATE INDEX idx_user_push_tokens_user_id ON user_push_tokens(user_id);
CREATE UNIQUE INDEX idx_user_push_tokens_token ON user_push_tokens(token);
```

**Upsert logic:** `ON CONFLICT (device_id) DO UPDATE SET token = EXCLUDED.token, last_seen_at = NOW()`.

**Token rotation (multi-user devices):** If `token` already exists for a different `user_id`, delete the old row before upsert. This handles the case where a user logs out and another user logs in on the same device.

**Stale token cleanup:** Schedule a background job to delete rows where `last_seen_at < NOW() - INTERVAL '90 days'`. These correspond to uninstalled apps that never called DELETE.

**Multi-device support:** Multiple rows per `user_id` are allowed and expected (D8 — multi-device push).

---

## 2. `DELETE /api/users/me/push-token`

Unregisters the current device's push token on logout. Idempotent — device may call
this even if the token was never registered (e.g. after a failed register attempt).

### Auth

JWT required.

### Request Body

```json
{ "deviceId": "uuid-v4-from-permission-install-id" }
```

The `deviceId` matches the same install UUID used in the register call.
Accept as request body (not query param) to avoid logging token-like identifiers in server access logs.

### Response 200

```json
{ "unregistered": true, "deviceCount": 1 }
```

- `deviceCount` — remaining devices after deletion (0 if no more devices registered).

### Response 404

Device not found. **Return 200 anyway** (idempotent — treat as success). Log a warning
internally for observability, but do not surface the error to the client.

**Behavior:** Delete the row matching `(user_id, device_id)` from `user_push_tokens`.
Other devices for the same user are unaffected. If no matching row found, return 200.

---

## 3. `POST /api/analytics/permission-events`

Batch-ingest permission analytics events from the client. Events are captured locally
on-device and flushed in batches of ≤50 on each app foreground after login.

### Auth

JWT required. Reject with 401 if missing or expired.

### Rate Limit

60 requests per minute per user (AC-M3 revised). Return 429 with standard `Retry-After`
header. Client backs off exponentially: 1m → 5m → 15m (capped).

### Request Body

```json
{
  "events": [
    {
      "outcome": "prime_shown",
      "kind": "notification",
      "role": "guest",
      "context": null,
      "platform": "ios",
      "ts": "2026-06-28T10:15:30.000Z"
    },
    {
      "outcome": "os_grant",
      "kind": "notification",
      "role": "host",
      "context": null,
      "platform": "android",
      "ts": "2026-06-28T10:15:35.123Z"
    }
  ]
}
```

### Field Rules

- `events` — array, required. Length ≤ 50. Reject >50 with 400.
- `outcome` — enum, required. Allowed values:
  ```
  "prime_shown" | "prime_accept" | "prime_defer"
  | "os_grant" | "os_deny" | "os_perm_deny"
  | "os_provisional" | "os_provisional_upgrade"
  | "settings_opened" | "fcm_unavailable_gms_missing"
  ```
- `kind` — enum, required. `"notification" | "camera"`.
- `role` — string or null. Required if `kind == "notification"` (one of `"guest" | "host" | "admin"`). Null is allowed for camera events.
- `context` — string or null. Required if `kind == "camera"` (one of `"cccdUpload" | "postHousePhoto" | "contractPhoto" | "contractTerminatePhoto" | "profileAvatar" | "reportErrorPhoto"`). Null is allowed for notification events.
- `platform` — enum, required. `"ios" | "android" | "web"`.
- `ts` — string, required. ISO 8601 UTC timestamp. Reject if unparseable.

### Server-Side Whitelist (Security — AC-M3 revised)

**Reject any unknown field with HTTP 400.** The whitelist is the security boundary.
The following fields are explicitly forbidden and MUST NOT be stored even if sent:
- `userAgent`
- `ip` (do not read from request IP either — no IP logging)
- `deviceModel`
- Any user-identifying field (email, phone, name, userId in body — use JWT sub instead)

### Response 200

```json
{ "accepted": 12 }
```

- `accepted` — count of events persisted. May be < `events.length` if some were
  duplicates or invalid (BE may silently drop per-event validation failures while
  accepting the rest, returning the accepted count).

### Response 400

Schema violation: unknown field, unknown enum value, `events.length > 50`, unparseable `ts`.

### Response 401

JWT invalid or expired. Client discards the local event queue on receipt (events are
stale and retrying with a fresh token would be a new session).

### Response 429

Rate limit exceeded. Client backs off exponentially and retries on next app foreground.

### Backend Storage

Table: `permission_events`

```sql
CREATE TABLE permission_events (
  id          BIGSERIAL    PRIMARY KEY,
  user_id     BIGINT       NOT NULL REFERENCES users(id),
  outcome     VARCHAR(40)  NOT NULL,
  kind        VARCHAR(20)  NOT NULL,
  role        VARCHAR(20),
  context     VARCHAR(40),
  platform    VARCHAR(16)  NOT NULL,
  ts          TIMESTAMPTZ  NOT NULL,
  received_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_permission_events_user_ts ON permission_events(user_id, ts);
CREATE INDEX idx_permission_events_outcome ON permission_events(outcome);
```

**Notes:**
- `user_id` is extracted from the JWT `sub` claim — never from the request body.
- `received_at` is server wall-clock time; `ts` is the client-reported event time.
- Index on `(user_id, ts)` supports dashboard queries for opt-in rate monitoring (AC-M2).

---

## Summary Table

| Endpoint | Method | Auth | Rate Limit | Client calls when |
|----------|--------|------|------------|-------------------|
| `/api/users/me/push-token` | POST | JWT | — | OS grants notification permission; FCM token refreshes |
| `/api/users/me/push-token` | DELETE | JWT | — | User logs out |
| `/api/analytics/permission-events` | POST | JWT | 60/min/user | App foreground after login (batch flush) |

---

## Error Handling Contract (Client Behaviour Reference)

| BE Response | Client action |
|-------------|--------------|
| 200 | Clear uploaded events from local queue; reset backoff |
| 400 | Log warning; clear chunk (schema mismatch — no retry value) |
| 401 | Discard entire local queue; stop retrying |
| 404 (analytics) | Treat as 5xx — back off; retry next foreground |
| 404 (push-token DELETE) | Treat as success — idempotent |
| 429 | Back off (1m → 5m → 15m); retry next foreground |
| 5xx | Back off; retry next foreground |
| Network error | Back off; retry next foreground |
