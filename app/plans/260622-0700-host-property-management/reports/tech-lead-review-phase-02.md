# Tech Lead Review — Phase 02: Foundation: Host Profile + Security Hardening

**Reviewer:** code-reviewer (Staff Engineer, security-focused)
**Date:** 2026-06-22
**Spec:** `plans/260622-0700-host-property-management/phase-02-foundation-host-profile.md`
**Scope reviewed:** Staged Phase 02 backend + Flutter changes (uncommitted)

---

## Verdict

**CONDITIONAL — Must fix 1 CRITICAL acceptance-criteria failure (AC8) and 2 HIGH security gaps before merge.**

The security foundation is solid — JWT, `require_host`, ownership checks, CCCD storage isolation, audit logging, and IDOR fixes on the in-scope routers are all implemented correctly. Tests cover the four explicit ACs (AC2–AC5). However:

- **AC8 is not satisfied:** `house_to_dict` does NOT include `host_avg_response_hours` / `host_rating` from HostProfile (the Marketplace listing requirement). This is an explicit, testable acceptance criterion.
- **AC6 audit-log integrity is broken in one path:** `_log_access(action="read")` runs inside the same transaction as the caller and is flushed only — if the caller's outer transaction is rolled back (e.g., subsequent commit fails), the audit row is lost. This violates PDPL "every read is logged".
- **CCCD `read_cccd` lacks path-traversal hardening** (defence-in-depth): no check that the resolved path lives inside `_CCCD_DIR`.

These three items must be fixed before merge. All other items are HIGH / MEDIUM and may be deferred only with explicit acceptance.

---

## CRITICAL — Block merge

### [CRITICAL-1] AC8 failure: `host_avg_response_hours` and `host_rating` not exposed in `GET /api/houses/{id}`

**File:** `ancu365-backend/app/helpers.py:10-40` (`house_to_dict`)

**Problem:** The acceptance criterion (AC8) is "GET `/api/houses/{id}` includes `host_avg_response_hours` + `host_rating`". The current `house_to_dict` exposes `host_name`, `host_avatar`, `host_phone` but does NOT join `HostProfile` to surface `avg_response_hours` or `rating`. The Marketplace listing requirement (BA A2) is therefore unmet. There is also no test covering AC8.

**Suggested fix:**
```python
# app/helpers.py
from app.models import HostProfile  # add import

def house_to_dict(db: Session, h: House) -> dict:
    cat = db.get(Category, h.category_id)
    host = db.get(User, h.host_id)
    host_profile = (
        db.query(HostProfile).filter(HostProfile.user_id == h.host_id).first()
    )
    return {
        # ... existing fields ...
        "host_name": host.name if host else None,
        "host_avatar": host.avatar_path if host else None,
        "host_phone": host.phone if host else None,
        "host_avg_response_hours": host_profile.avg_response_hours if host_profile else None,
        "host_rating": host_profile.rating if host_profile else None,
        "host_verified": host_profile.verified if host_profile else False,
    }
```

> **Follow-up concern (N+1):** `house_to_dict` is called in a loop in `list_houses` (`q.all()` → list comprehension). Each call now performs 3 lookups (Category, User, HostProfile). For 100 houses listing this is 300 round-trips. Add a batched join or in-memory lookup map. Suggested replacement for list paths:
> ```python
> # Fetch host_profiles in bulk for this page
> host_ids = {h.host_id for h in houses}
> profiles_by_user = {p.user_id: p for p in db.query(HostProfile).filter(HostProfile.user_id.in_(host_ids)).all()}
> users_by_id = {u.id: u for u in db.query(User).filter(User.id.in_(host_ids)).all()}
> ```
> Acceptable to defer the N+1 cleanup to Phase 03, but the field exposure itself MUST land in Phase 02 to satisfy AC8.

**Add test:** `tests/test_houses_host_profile_fields.py` — seed House + HostProfile with rating=4.5, avg_response_hours=2.3 → GET /api/houses/{id} → assert both fields in response body.

---

## HIGH — Should fix before merge

### [HIGH-1] CCCD access-log atomicity: audit row can be lost when reader transaction rolls back

**File:** `ancu365-backend/app/services/cccd_storage.py:139-157` and `app/routers/host_profile.py:197-208`

**Problem:** `_log_access` calls `db.add(log); db.flush()` but does NOT commit. The caller (`serve_cccd`) commits AFTER reading bytes (line 199). If any error occurs between `_log_access` and `db.commit()` — including the disk read raising, the session being invalidated, or another exception in the request lifecycle — SQLAlchemy will roll back the transaction at request teardown and the audit row is lost. The docstring (lines 155-157) explicitly claims this is for PDPL compliance, but flush-without-commit does not provide that guarantee.

This contradicts AC6 ("GET /api/host/cccd/{id} writes 1 row to cccd_access_logs per request") because a CCCD read that crashes mid-handler will not produce a log row.

**Suggested fix:** Write the audit row in a separate, autonomous transaction that commits independently of the caller's session. The cleanest approach is to use a fresh session bound to the same engine:

```python
# app/services/cccd_storage.py
from app.database import SessionLocal

def _log_access(
    db: Session,  # unused now, kept for API stability
    actor_id: int,
    file_path: str,
    action: str,
    ip_address: Optional[str],
) -> None:
    """Write CCCDAccessLog in an autonomous transaction.

    PDPL compliance: this row MUST persist even if the caller's transaction
    rolls back later in the request lifecycle.
    """
    with SessionLocal() as audit_db:
        try:
            audit_db.add(models.CCCDAccessLog(
                user_id=actor_id,
                file_path=file_path,
                action=action,
                accessed_at=datetime.utcnow(),
                ip_address=ip_address,
            ))
            audit_db.commit()
        except Exception:
            audit_db.rollback()
            # Re-raise: if we can't audit, we MUST not serve the file (fail-closed)
            raise
```

Then in `read_cccd`, the log is written BEFORE the file read (already done — line 121), but now durably committed. If audit write fails, the read aborts — fail-closed per PDPL.

Update caller: remove the trailing `db.commit()` from `serve_cccd` (line 199) since the audit row is no longer in that session.

**Add test:** `tests/security/test_cccd_audit_durability.py` — patch `read_cccd` to raise after `_log_access`; verify `cccd_access_logs` still contains a row.

---

### [HIGH-2] `read_cccd` lacks path-traversal hardening (defence-in-depth)

**File:** `ancu365-backend/app/services/cccd_storage.py:100-124`

**Problem:** `read_cccd(file_path, ...)` accepts an arbitrary `file_path` and opens it. The path comes from `HostProfile.cccd_front_path` / `cccd_back_path`, which today is only written by `save_cccd` (always under `_CCCD_DIR` with a UUID filename). However:

1. There is NO runtime check that the resolved path stays within `_CCCD_DIR`. If a future migration, admin tool, or compromised DB row contains `../../../etc/passwd`, this endpoint will happily serve it to the authenticated owner.
2. The `os.path.realpath` boundary check is the canonical mitigation and costs ~0 perf.

This is defence-in-depth — current attack surface is limited because `save_cccd` controls all writes — but missing the check violates the security review checklist ("Path traversal: user-controlled file paths sanitized").

**Suggested fix:**
```python
def read_cccd(file_path: str, actor_id: int, db: Session, ip_address: Optional[str] = None) -> bytes:
    # Defence-in-depth: ensure resolved path is inside CCCD dir
    cccd_root = os.path.realpath(_ensure_cccd_dir())
    resolved = os.path.realpath(file_path)
    if not resolved.startswith(cccd_root + os.sep) and resolved != cccd_root:
        raise PermissionError(f"CCCD path escapes storage root: {file_path}")

    if not os.path.isfile(resolved):
        raise FileNotFoundError(f"CCCD file not found: {resolved}")

    _log_access(db, actor_id, resolved, "read", ip_address)
    with open(resolved, "rb") as f:
        return f.read()
```

Apply same hardening in `delete_cccd`.

---

### [HIGH-3] `serve_cccd` query parameter `side` not validated (Pydantic / Enum)

**File:** `ancu365-backend/app/routers/host_profile.py:165-171`

**Problem:** `side: str = "front"` accepts ANY string. Code only treats `"back"` specially; everything else falls into the "front" branch. While not a security hole, this is sloppy validation that the spec calls out (Security checklist: "Input validation: all external inputs validated at system boundaries").

**Suggested fix:** Use a Literal type:
```python
from typing import Literal

@router.get("/cccd/{profile_id}")
def serve_cccd(
    profile_id: int,
    side: Literal["front", "back"] = "front",
    ...
):
```
FastAPI/Pydantic will then 422 on bad input rather than silently falling through.

---

### [HIGH-4] CCCD upload missing magic-byte validation (MIME spoofing)

**File:** `ancu365-backend/app/services/cccd_storage.py:73-92`

**Problem:** MIME validation uses `upload.content_type`, which is client-controlled (HTTP `Content-Type` header). An attacker can send a `.exe` or polyglot file with `Content-Type: image/jpeg`. We save it to disk with the extension derived from the same client-supplied MIME. While the file isn't executed server-side, when the file is later served via `serve_cccd`, the browser/client interprets it. A polyglot HTML+JPEG could in theory enable XSS if served on the same origin (less critical because content-type is sniffed from extension on response — but extension was also derived from client MIME).

**Suggested fix:** Validate the magic bytes:
```python
def _detect_image_mime(content: bytes) -> Optional[str]:
    """Return real MIME from magic bytes, or None if not a supported image."""
    if content[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if content[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    if content[:4] == b"RIFF" and content[8:12] == b"WEBP":
        return "image/webp"
    return None

# in save_cccd:
content = await upload.read()
if len(content) > _MAX_SIZE_BYTES:
    raise ValueError("File quá lớn. Tối đa 10 MB.")

real_mime = _detect_image_mime(content)
if real_mime is None or real_mime not in _ALLOWED_MIME:
    raise ValueError("File không phải ảnh JPEG/PNG/WebP hợp lệ.")

# Derive extension from REAL mime, not client claim
ext = _ext_from_mime(real_mime)
```

Also: enforce `X-Content-Type-Options: nosniff` on the `serve_cccd` response.

```python
return Response(
    content=content,
    media_type=media_type,
    headers={"X-Content-Type-Options": "nosniff", "Content-Disposition": "inline"},
)
```

---

### [HIGH-5] Pre-existing IDOR holes in `notifications`, `wishlists`, `chat`, `users.PATCH` left unfixed

**Files:**
- `ancu365-backend/app/routers/notifications.py:11,20,40-42` — `userId` query param trusted, no auth
- `ancu365-backend/app/routers/wishlists.py:11,28,44` — `userId` / `user_id` body trusted, no auth
- `ancu365-backend/app/routers/chat.py:21,68,120` — `userId` query param trusted, no auth
- `ancu365-backend/app/routers/users.py:16-49` — `PATCH /api/users/{user_id}` has NO `require_user` and NO ownership check; any unauthenticated caller can modify ANY user's `email`, `phone`, `name`, `bio`, `id_number`, `birthday`, `avatar_path`

**Problem:** The research doc (`researcher-backend-audit.md` §2) flagged these as "8+ unauth endpoints". The Phase 02 spec listed them under "Key insights" (line 33) but the "Auth fixes" table on lines 75-86 narrowed scope to only houses/viewing_appointments/auth_router. Per the strict letter of the spec, they are out of scope for Phase 02 — but the Phase 02 description claims to fix the security debt of "8+ unauth endpoints".

In particular `users.PATCH` is **CRITICAL severity** as a vulnerability (account takeover by email change → forgot-password reset), but **out of strict Phase 02 scope**. The review treats it as HIGH because the phase explicitly claims to be a security-hardening phase.

**Recommended action:** Either (a) extend Phase 02 to fix `users.PATCH` (15-line change), or (b) explicitly document the deferral and create a Phase 02.5 ticket. Do NOT ship Phase 02 with `users.PATCH` unauth in production. Minimal patch:

```python
# app/routers/users.py
@router.patch("/{user_id}")
def update_user(
    user_id: int,
    body: dict = Body(...),
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
):
    if user_id != claims["sub"] and claims.get("role") != "admin":
        raise HTTPException(403, "Không có quyền chỉnh sửa người dùng khác")
    # ... existing logic ...
```

And remove `id_number` (CCCD) from the writable field list — it now lives on HostProfile with a hash.

---

### [HIGH-6] `list_users` returns full user list (PII) without auth

**File:** `ancu365-backend/app/routers/users.py:10-13`

**Problem:** `GET /api/users` returns all users including email, phone, id_number, birthday — full PII dump — with NO auth. Same scope-defer call as HIGH-5.

**Suggested fix:** Add `require_admin`, or remove the endpoint entirely:
```python
@router.get("")
def list_users(claims: dict = Depends(auth.require_admin), db: Session = Depends(get_db)):
    ...
```

---

### [HIGH-7] `forgot_password` returns temp password in response body (pre-existing)

**File:** `ancu365-backend/app/routers/auth_router.py:92-108`

**Problem:** The endpoint returns `{"temp_password": temp, ...}` directly to the client. This means an attacker who knows a victim's email can call `/api/auth/forgot-password` and immediately receive a working password — total account takeover with no email or SMS verification. Also: no rate limiting on auth endpoints.

**Status:** Pre-existing. Not introduced by Phase 02. But this is a security-hardening phase and the issue is reachable.

**Suggested fix (deferred ok, but file a CRITICAL ticket):**
- Send temp password via email (or just send a magic link)
- Return only `{"success": true, "message": "Email reset đã được gửi"}` regardless of whether email exists (prevent enumeration)
- Add `@limiter.limit("3/hour")` to forgot-password, login, register, change-password

---

### [HIGH-8] `update_status` "locked" path: race condition decrementing `available_units`

**File:** `ancu365-backend/app/routers/viewing_appointments.py:121-150`

**Problem:** Two hosts (or one host with concurrent requests) can both PATCH `status=locked` on different appointments of the same house simultaneously. Both reads see `available_units > 0`, both decrement, both commit — over-allocation. SQLAlchemy default isolation does not protect this.

**Suggested fix:** `SELECT ... FOR UPDATE` on the house row:
```python
house = (
    db.query(models.House)
    .filter(models.House.id == b.house_id)
    .with_for_update()
    .first()
)
```
And wrap the cascade-to-other-appointments in the same transaction. Also enforce a DB-level check constraint `available_units >= 0`.

This is technically inherited from Phase 01b but is a clear concurrency bug that should be flagged.

---

### [HIGH-9] `upgrade_to_host` transactional risk: User.role updated but HostProfile create failure could leave half-state

**File:** `ancu365-backend/app/routers/host_profile.py:123-159`

**Problem:** The function does:
1. `user.role = "host"` (line 145) — staged
2. `db.flush()` (line 146) — sends UPDATE
3. `repo.create(...)` — may raise (e.g., FK violation if user_id doesn't exist somehow, or schema error)
4. `db.commit()` (line 154)

SQLAlchemy `commit()` is atomic across (1) and (3) so the half-state is unlikely in practice — IF the same session is used. The current code does use one `db` session, so this is safe.

**However**, the JWT is issued AFTER `db.commit()`. If the commit succeeds but the response is lost (network error), the user has `role=host` in DB but still holds the old guest token. They'll have to re-login. Not a security issue, but worth a UX note. The current Flutter code calls `bootstrap()` after the response which mitigates this.

**No fix required** — flagging as defensive-coding awareness.

---

## MEDIUM — Should consider

### [MEDIUM-1] `HostProfileResponse.bank_account_number` exposed in full in response

**File:** `ancu365-backend/app/schemas/host_profile.py:36`

**Problem:** When host views their own profile, full bank account number is returned. Reasonable for the owner. But if the response is ever logged, cached, or leaked via the browser dev tools / sentry, it's plaintext. Consider masking all but last 4 digits except in a dedicated "view full" endpoint.

```python
# Add helper
def _mask_account(n: Optional[str]) -> Optional[str]:
    if not n or len(n) < 8:
        return n
    return n[:2] + "*" * (len(n) - 6) + n[-4:]
```

This is a hardening recommendation, not a blocker.

---

### [MEDIUM-2] `host_profile_repository.update` silently ignores unknown fields

**File:** `ancu365-backend/app/repositories/host_profile_repository.py:74-76`

**Problem:** `update_fields = data.model_dump(exclude_none=True)` then `setattr(profile, key, value)` for every key. If the Pydantic model is ever extended with sensitive fields, this becomes a write-through-to-DB without explicit allowlist. The Pydantic schema currently controls what's allowed, which is fine, but the repository should keep an internal allowlist as defence-in-depth.

**Suggested fix:**
```python
_ALLOWED_UPDATE_FIELDS = {
    "bank_account_number", "bank_name", "bank_account_holder",
    "tax_id", "payout_schedule",
}
update_fields = {
    k: v for k, v in data.model_dump(exclude_none=True).items()
    if k in _ALLOWED_UPDATE_FIELDS
}
```
This protects against schema regressions that might add `verified` or `rating` as patchable.

---

### [MEDIUM-3] `HostProfileResponse.from_orm_safe` reimplements what Pydantic v2 `model_validate` could do

**File:** `ancu365-backend/app/schemas/host_profile.py:48-66`

**Problem:** With `model_config = {"from_attributes": True}`, Pydantic v2 can build the response from an ORM model directly (`HostProfileResponse.model_validate(profile)`). The current `from_orm_safe` is 20 lines of `# type: ignore` boilerplate. It also lacks fields like `cccd_front_uploaded` being computed automatically.

**Suggested fix:** Use a computed field:
```python
from pydantic import computed_field, BaseModel

class HostProfileResponse(BaseModel):
    id: int
    user_id: int
    verified: bool
    # ... other fields, but NOT cccd_*_path ...

    # Define cccd_front_uploaded as a derived property on the source model,
    # or use a model_validator(mode="before") to inject them:
    @classmethod
    def from_profile(cls, p) -> "HostProfileResponse":
        return cls.model_validate({
            **{c.name: getattr(p, c.name) for c in p.__table__.columns
               if c.name not in ("cccd_front_path", "cccd_back_path", "cccd_number_hash")},
            "cccd_front_uploaded": bool(p.cccd_front_path),
            "cccd_back_uploaded": bool(p.cccd_back_path),
        })
```
Functionally equivalent, less boilerplate. Not blocking.

---

### [MEDIUM-4] All tests gated on `SMOKE_DATABASE_URL` — no coverage in default CI run

**Files:** `tests/security/test_cross_host_isolation.py`, `test_require_host.py`, `test_auth_register_role_whitelist.py`, `test_host_profile.py`

**Problem:** Every test in these files has `@pytest.mark.skipif(not os.getenv("SMOKE_DATABASE_URL"))`. A default `pytest` run skips ALL Phase 02 security tests. CI must explicitly set this env var, or the tests must use the in-process Postgres provided by `conftest.py`. Verify CI config.

**Suggested fix:** Confirm `SMOKE_DATABASE_URL` is set in CI. Also add at least one test that runs without Postgres (e.g., SQLite-backed unit test) to keep `pytest` green for local dev:
```python
# Replace skipif with a fixture that auto-provisions an ephemeral SQLite session
@pytest.fixture
def in_memory_session():
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker
    from app.database import Base
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    yield Session()
```

---

### [MEDIUM-5] `HostProfile.created_at` / `updated_at` use `datetime.utcnow()` (deprecated in Python 3.12)

**Files:** `app/models.py:46`, `app/services/cccd_storage.py:151`, `app/repositories/audit.py:55`, `app/repositories/host_profile_repository.py:36,77,104`

**Problem:** `datetime.utcnow()` is deprecated in Python 3.12+. Replace with `datetime.now(timezone.utc)`. Existing `now_utc()` helper is also affected.

**Suggested fix:**
```python
from datetime import datetime, timezone

def now_utc() -> datetime:
    return datetime.now(timezone.utc)
```

DB columns should be timezone-aware too (`DateTime(timezone=True)`). Defer to a chore ticket if not done now, but note it.

---

### [MEDIUM-6] `_get_client_ip` trusts `X-Forwarded-For` without verifying request came from a known proxy

**File:** `ancu365-backend/app/routers/host_profile.py:38-40`

**Problem:** Any client can send `X-Forwarded-For: 1.2.3.4` and have it logged as the source IP in `cccd_access_logs`. This degrades the audit trail integrity. Either restrict X-F-F handling to traffic from known proxy IPs (configured) or use `request.client.host` directly when no proxy is configured.

**Suggested fix:** If you deploy behind a single trusted reverse proxy, use Starlette `ProxyHeadersMiddleware` and only read the leftmost X-F-F entry. Otherwise:
```python
def _get_client_ip(request: Request) -> str:
    if settings.trust_proxy_headers:
        forwarded = request.headers.get("x-forwarded-for", "")
        if forwarded:
            return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"
```

---

### [MEDIUM-7] `cccd_storage._ensure_cccd_dir` chmod fails silently on Windows

**File:** `ancu365-backend/app/services/cccd_storage.py:35-40`

**Problem:** `os.chmod(_CCCD_DIR, stat.S_IRWXU)` is a no-op on Windows (sets a read-only flag at best). On Windows dev machines, files are world-readable. Spec acknowledges this (risk table, line 299) but the production deployment doc should clearly state Linux/macOS only for storage, and CI should run on Linux.

**Suggested fix:** Log a warning if `os.name == "nt"`:
```python
if os.name == "nt":
    import logging
    logging.getLogger(__name__).warning(
        "CCCD storage chmod 0700 is a no-op on Windows. Production must run on Linux."
    )
```

---

### [MEDIUM-8] No CCCD `_ensure_cccd_dir` call on application startup; first upload sets perms

**Problem:** The chmod 0700 only runs the first time `save_cccd` is called. If the storage dir already exists with permissive perms from a previous deploy, those perms persist until the first upload. Negligible window, but worth a startup hook in `main.py`:

```python
@app.on_event("startup")
async def init_cccd_storage():
    from app.services.cccd_storage import _ensure_cccd_dir
    _ensure_cccd_dir()  # idempotent; sets 0700 on first deploy
```

---

### [MEDIUM-9] Flutter `HostProfileProvider` uses concrete repo, not DI

**File:** `ancu365-app/lib/providers/host_profile_provider.dart:14`

**Problem:** `final IHostProfileRepository _repo = ApiHostProfileRepository();` — interface is declared but the concrete class is hard-wired. This makes the provider untestable without HTTP. Inject via constructor:

```dart
class HostProfileProvider extends ChangeNotifier {
  HostProfileProvider({IHostProfileRepository? repo})
      : _repo = repo ?? ApiHostProfileRepository();
  final IHostProfileRepository _repo;
}
```

---

### [MEDIUM-10] CCCD upload flow: orphan files when DB write fails after disk write

**File:** `ancu365-backend/app/routers/host_profile.py:79-118`

**Problem:** Sequence is: (1) `save_cccd` writes file to disk + audit log row, (2) `repo.set_cccd_paths` mutates DB, (3) `db.commit()`. If (2) or (3) fails, the file is on disk forever (orphan). Not security-critical, but creates disk-leak over time.

**Suggested fix:** Either (a) write file to a temp path and move into place after DB commit, or (b) add a periodic GC job that deletes files not referenced by any `HostProfile.cccd_*_path`. Defer the GC to a follow-up phase.

---

## LOW — Optional polish

### [LOW-1] `HostProfileResponse` does not expose `cccd_number_hash` — good

`bank_account_number` is exposed in plaintext; consider adding a separate "view sensitive" endpoint requiring re-auth in the future.

### [LOW-2] `host_profile.py` line 168 — `request: Request = None  # type: ignore[assignment]`

Use `request: Optional[Request] = None` properly typed:
```python
from typing import Optional
request: Optional[Request] = None
```
But more cleanly: make `request` a non-default `Request` parameter — FastAPI injects it automatically.

### [LOW-3] `cccd_uploader.dart:109` — `.withOpacity()` deprecated in Flutter 3.27+

Use `.withValues(alpha: 0.05)`:
```dart
color: const Color(0xFF00A65A).withValues(alpha: 0.05),
```

### [LOW-4] `OnboardingStepper(currentStep: 2)` — magic number

Define a `const int kCccdStep = 2;` or pass via a generated enum.

### [LOW-5] `auth_router.py:30-33` comment is helpful — keep it

Good security commenting pattern, applied throughout the diff. ✔

---

## Positive Observations (Security Done Right)

1. **JWT signing/verification:** `python-jose` with HS256, signature is verified (`jwt.decode` with `algorithms=["HS256"]`). No `verify=False` anywhere. `exp` claim is checked by `jose` by default. ✔
2. **`sub` claim coercion:** Correctly stored as string in JWT (per spec) and converted to int on decode with try/except for safety. ✔
3. **`require_host` properly chains `require_user`:** Two-layer dependency means unauth → 401 first, auth-but-wrong-role → 403. Correct semantics. ✔
4. **Role whitelist at registration:** Hard-coded `role = "guest"` line 33; client body is completely ignored. Test coverage present. ✔
5. **`change-password` uses `claims["sub"]`:** Explicit comment line 73-74, test covers IDOR attempt. ✔
6. **House mutations (`POST/PUT/DELETE/close-unit`):** Each has `require_host` + explicit `h.host_id != claims["sub"]` ownership check. Houses tests cover the cross-host case. ✔
7. **`create_viewing_appointment`:** `guest_id=claims["sub"]` always — body ignored. Status forced to "pending" regardless of body. ✔
8. **`upgrade_to_host`:** Admin explicitly blocked from this path (line 136-137). Already-host returns 409 (line 134-135). Good state-machine design. ✔
9. **CCCD storage:**
   - UUIDv4 filenames (no PII in path) ✔
   - 0700 on dir, 0600 on file ✔
   - One-way bcrypt hash for `cccd_number` available (`hash_cccd_number`) ✔
   - Filename extension derived from MIME (but see HIGH-4 for hardening) ✔
   - File size cap 10 MB ✔
   - MIME allowlist (JPEG/PNG/WebP) ✔
10. **`HostProfileResponse` strips CCCD paths:** Replaces with `cccd_front_uploaded` / `cccd_back_uploaded` booleans. Tested by `test_host_get_profile_returns_safe_fields`. ✔
11. **Audit-log writer (`write_change_log`):** Uses `json.dumps(..., default=str)` — no string concatenation, no SQL injection vector. ✔
12. **Repository pattern (`HostScopedRepository`):** `host_field_name` is a class attribute set by subclass authors, NOT user-controlled — safe `getattr`. ✔
13. **HostProfile is 1-1 with User:** Correct decision to NOT use `HostScopedRepository` here (documented in `host_profile_repository.py:2-5`). ✔
14. **GET `/api/host/cccd/{profile_id}`:** Performs ownership check (`profile.user_id != claims["sub"]` → 403) BEFORE serving bytes. ✔
15. **Alembic migration 0004:** Proper FKs with `ondelete` semantics (CASCADE for host_profiles.user_id, SET NULL for change_logs.actor_id — both correct). Unique constraint on `host_profiles.user_id`. Indexes on filter columns. No raw SQL. ✔
16. **Pydantic v2 usage:** `model_dump`, `model_config = {"from_attributes": True}` — correct v2 idioms. ✔
17. **Flutter side correctness:** Session token updated AFTER backend confirms upgrade (`SessionService.instance.setToken(newToken)`), then profile is refetched. Auth provider is re-bootstrapped in step3. ✔
18. **Flutter `IHostProfileRepository` interface declared:** Good separation, even if DI is incomplete (MEDIUM-9). ✔
19. **Flutter `_uploadCccd` handles error states + loading states:** `provider.isLoading`, `provider.error`, mounted checks. ✔

---

## Must-Fix Items Before Merge

1. **[CRITICAL-1]** Add `host_avg_response_hours` + `host_rating` to `house_to_dict` (and add a test).
2. **[HIGH-1]** Make `_log_access` write to an autonomous transaction so CCCD audit row is durable.
3. **[HIGH-2]** Add path-traversal boundary check in `read_cccd` and `delete_cccd`.
4. **[HIGH-3]** Validate `side` query param with `Literal["front", "back"]`.
5. **[HIGH-4]** Validate uploaded image by magic bytes (not just MIME header) + add `X-Content-Type-Options: nosniff` to CCCD response.
6. **[HIGH-5]** Decision on `users.PATCH` IDOR + `list_users` PII dump: either fix in Phase 02 (15-line change) or formally defer with a tracked ticket.

---

## Unresolved Questions

1. Does CI set `SMOKE_DATABASE_URL`? If not, the four Phase 02 test files all skip → green pipeline with zero security coverage. (MEDIUM-4)
2. Is the project deployed behind a known reverse proxy? Determines whether `X-Forwarded-For` parsing is correct or attacker-spoofable. (MEDIUM-6)
3. Will `forgot-password` be fixed in a separate auth-hardening phase, or is the current "return temp_password in body" behavior acceptable for the BETA? (HIGH-7)
4. Is there a rate-limit policy for auth endpoints (login/register/change-password)? None currently. Brute-force is wide open.
5. Is there a CCCD GC story for orphan files? (MEDIUM-10) — defer ok, but track.
6. Spec lines 33-34 describe "8+ unauth endpoints" but implementation only fixed 6 (houses ×4, viewing_appointments ×3, auth ×2). Confirm scope decision on the remaining 5+ (notifications, wishlists, chat, users PATCH, list_users).

---

## Metrics

- Backend files reviewed: 14 (4 new schemas/repos/services, 6 routers/auth, 1 migration, 3 model/main updates) + 4 test files
- Flutter files reviewed: 4 (provider, repo, model, 2 onboarding screens, 1 widget)
- CRITICAL issues: 1
- HIGH issues: 9 (3 must-fix in scope + 6 pre-existing/scope-edge)
- MEDIUM issues: 10
- LOW issues: 5
- Test coverage for explicit ACs (AC2–AC5): present, but gated behind `SMOKE_DATABASE_URL`
- Test coverage for AC6 (audit log on CCCD read): MISSING — no test verifies the cccd_access_logs row is written per request
- Test coverage for AC8 (host_avg_response_hours / host_rating in /api/houses/{id}): MISSING
- Repository pattern usage: defined but only `HostProfileRepository` uses it; `houses.py` still uses direct `db.query(...)` — acceptable for Phase 02 (the pattern is foundational for Phase 03+)
