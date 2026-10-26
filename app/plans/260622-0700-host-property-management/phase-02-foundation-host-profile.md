---
title: "Phase 02 — Foundation: require_host + HostProfile + Audit Trail + Repo Pattern"
description: "Security foundation: require_host dep, fix 8+ unauth endpoints, HostProfile + CCCD upload, change_logs, HostScopedRepository base"
status: pending
priority: P1
effort: 4-5d
branch: TBD
tags: [backend, flutter, security, foundation, host-profile]
created: 2026-06-22
---

# Phase 02 — Foundation: Host Profile + Security Hardening

**Sized:** 4–5d
**Status:** ⏸ Pending (Ready)
**Blocks:** 03, 04, 05, 06, 07, 08 (all ops phases need security base)
**Blocked by:** 01 (DB ready), 01b (no naming clash)

## Context links
- BA doc §4 A1-A2 (onboarding), §5 AC kỹ thuật, §9 D6 (Repository pattern), D7 (CCCD local + audit), Q5 (audit trail)
- Research: `research/researcher-backend-audit.md` §2 (8+ unauth endpoints), §3 (require_host scaffolding), §6 (existing patterns)
- `research/researcher-flutter-audit.md` §5 (host_home_screen exists)
- Code files affected (backend): `app/auth.py`, `app/dependencies.py` (new), `app/repositories/` (new), `app/models.py`, `app/routers/*.py` (auth fixes), `app/schemas/` (new)

## Overview
Khoá an ninh + xác thực host trước khi build ops. 4 deliverables song song:
1. `require_host()` dependency + sửa 8+ endpoints thiếu auth (security debt)
2. `HostProfile` model + onboarding 3-step (info → CCCD → bank)
3. `change_logs` audit table (cho Phase 03+04 dispute prevention)
4. `HostScopedRepository` base class (D6 multi-tenant isolation foundation)

## Key insights from research
- Backend audit phát hiện 8+ endpoints thiếu auth check: POST/PUT/DELETE houses, all bookings (đã rename → viewing_appointments), close-unit, change-password (IDOR risk), chat/notifications/wishlists (query userId param không auth)
- `/api/auth/register` line 30 accept role từ client body → users tự promote thành host/admin → CRITICAL fix
- `app/schemas/` directory rỗng → cần introduce Pydantic schemas từ Phase 02
- Flutter `host_home_screen.dart` đã có scaffolding nhưng thiếu onboarding flow
- No FCM/APNs hiện tại → notification poll DB (defer push to Phase 06)
- Folder `storage/cccd/` chmod 0700 + filename UUIDv4 (D7 sealed)

## Requirements

### Functional (from BA user stories)
- **A1:** Host đăng ký role + xác thực CCCD + bank account → AC: 3-step onboarding form complete <5 phút, CCCD photo upload success, bank account validated format
- **A2:** Marketplace listing hiển thị avg_response_time + rating từ HostProfile → AC: GET `/api/houses/{id}` includes `host_response_hours`, `host_rating`

### Non-functional
- All host-only endpoints reject 403 nếu role != host
- Cross-host data access blocked (Host A query Host B's resource → 403/404)
- CCCD files stored 0700 permissions, mọi read/write log vào `cccd_access_log`
- Audit trail: every Contract/Invoice mutation từ Phase 03+ ghi vào `change_logs`

## Architecture

### Backend

**New models:**

| Model | Fields | Notes |
|---|---|---|
| `HostProfile` | id, user_id (FK, unique), verified BOOL, cccd_front_path, cccd_back_path, cccd_number_hash, bank_account_number, bank_name, bank_account_holder, tax_id, avg_response_hours, rating, payout_schedule, created_at, updated_at | 1-1 với User; CCCD lưu hash (1-way) cho compare, không lưu plain |
| `ChangeLog` | id, entity_type ENUM('contract'\|'invoice'\|'host_profile'\|...), entity_id, actor_id (FK user), action ENUM('create'\|'update'\|'status_change'\|'delete'), before_json TEXT, after_json TEXT, created_at | Phase 02 tạo table; Phase 03+ trigger qua repository |
| `CCCDAccessLog` | id, user_id (FK actor), file_path, action ENUM('upload'\|'read'\|'delete'), accessed_at, ip_address | PDPL compliance audit |

**New endpoints:**

| Method | Path | Auth | Body | Returns |
|---|---|---|---|---|
| GET | `/api/host/profile` | require_host | - | `{profile: HostProfile}` |
| PATCH | `/api/host/profile` | require_host | `HostProfileUpdate` (info/bank fields) | `{profile}` |
| POST | `/api/host/profile/cccd` | require_host | multipart (front, back) | `{success, paths}` |
| POST | `/api/host/upgrade-to-host` | require_user (guest only) | - | `{token: new_jwt_with_host_role}` |
| GET | `/api/host/cccd/{id}` | require_host (owner only) | - | binary stream + log access |

**Auth fixes (in existing routers):**

| Endpoint | Current | Fix |
|---|---|---|
| `POST /api/houses` | ❌ no auth | `require_host` + body.host_id MUST == claims.sub |
| `PUT /api/houses/{id}` | ❌ no auth | `require_host` + verify house.host_id == claims.sub |
| `DELETE /api/houses/{id}` | ❌ no auth | `require_host` + ownership check |
| `POST /api/houses/{id}/close-unit` | ❌ no auth | `require_host` + ownership |
| `GET /api/viewing-appointments?userId=` | ❌ no auth | `require_user` + verify userId == claims.sub OR is host of related house |
| `POST /api/viewing-appointments` | ❌ no auth | `require_user` + body.guest_id MUST == claims.sub |
| `PATCH /api/viewing-appointments/{id}/status` | ❌ no auth | `require_host` + verify appointment.house.host_id == claims.sub |
| `POST /api/auth/register` | Accept role from body | Whitelist role: chỉ `'guest'` (default), require `/api/host/upgrade-to-host` để thành host |
| `POST /api/auth/change-password` | Trust body.user_id | Use `claims.sub`, ignore body.user_id |

**Repository pattern base:**

```python
# app/repositories/base.py
from sqlalchemy.orm import Session, Query
from typing import TypeVar, Generic, Type

T = TypeVar('T')

class HostScopedRepository(Generic[T]):
    """Auto-inject host_id filter. Subclass per model."""
    model_class: Type[T]
    host_field_name: str = "host_id"

    def __init__(self, db: Session, host_id: int):
        self.db = db
        self.host_id = host_id

    def query(self) -> Query:
        return self.db.query(self.model_class).filter(
            getattr(self.model_class, self.host_field_name) == self.host_id
        )

    def get(self, entity_id: int) -> T | None:
        return self.query().filter(self.model_class.id == entity_id).first()

    def list(self, **filters) -> list[T]:
        q = self.query()
        for k, v in filters.items():
            q = q.filter(getattr(self.model_class, k) == v)
        return q.all()
```

**Audit trail decorator:**

```python
# app/repositories/audit.py
def with_audit_log(action: str, entity_type: str):
    """Wrap repo mutation methods → write ChangeLog row."""
```

**Pydantic schemas (new):**

- `app/schemas/host_profile.py` — `HostProfileBase`, `HostProfileCreate`, `HostProfileUpdate`, `HostProfileResponse`
- `app/schemas/common.py` — shared response envelopes

**Migrations:**
- `alembic/versions/0004_add_host_profile_audit_log.py` — create `host_profiles`, `change_logs`, `cccd_access_logs`

### Flutter

**New screens (sub-module `lib/features/host/onboarding/`):**

| Screen | File | Purpose |
|---|---|---|
| `HostOnboardingStep1Screen` | `step1_info_screen.dart` | Tên, ngày sinh, địa chỉ, số ĐT |
| `HostOnboardingStep2Screen` | `step2_cccd_screen.dart` | Upload CCCD front + back, preview crop |
| `HostOnboardingStep3Screen` | `step3_bank_screen.dart` | Bank name picker, account number, account holder |
| `HostProfileScreen` | `host_profile_screen.dart` | View/edit profile (post-onboarding) |

**New providers:**
- `lib/providers/host_profile_provider.dart` — `HostProfileProvider extends ChangeNotifier`, methods: `fetchProfile()`, `updateProfile()`, `uploadCccd()`

**New widgets:**
- `lib/features/host/onboarding/widgets/onboarding_stepper.dart`
- `lib/features/host/onboarding/widgets/cccd_uploader.dart`
- `lib/core/widgets/labeled_text_field.dart` (reusable)

**Packages to add to pubspec.yaml:**
- `image_cropper: ^7.0.0` — CCCD crop tool
- `intl: ^0.20.0` — Date formatting

### Data flow

```
Guest đăng ký → Login → tap "Trở thành host" trong Profile
  ↓
HostOnboardingStep1Screen → submit info → store local draft
  ↓
HostOnboardingStep2Screen → camera/gallery → image_cropper → upload to /api/host/profile/cccd → save paths
  ↓
HostOnboardingStep3Screen → bank info → PATCH /api/host/profile → POST /api/host/upgrade-to-host
  ↓
Backend: validate, set User.role='host', create HostProfile row, return new JWT
  ↓
Flutter: save token → reload AuthProvider → redirect to HostHomeScreen
```

## Related code files

### Backend new files
- `backend/app/dependencies.py` — centralized DI (require_host, require_owner, etc.)
- `backend/app/repositories/__init__.py`
- `backend/app/repositories/base.py` — HostScopedRepository
- `backend/app/repositories/host_profile_repository.py`
- `backend/app/repositories/audit.py` — change_logs writer
- `backend/app/routers/host_profile.py` — host-only endpoints
- `backend/app/schemas/host_profile.py`
- `backend/app/schemas/common.py`
- `backend/app/services/cccd_storage.py` — file IO with 0700 perms + audit log
- `backend/alembic/versions/0004_add_host_profile_audit_log.py`
- `backend/tests/security/test_cross_host_isolation.py`
- `backend/tests/security/test_require_host.py`
- `backend/tests/test_host_profile.py`

### Backend modified files
- `backend/app/auth.py` — add `require_host()` (line ~85)
- `backend/app/models.py` — add HostProfile, ChangeLog, CCCDAccessLog classes
- `backend/app/routers/auth_router.py` — fix register role whitelist, change_password use claims.sub
- `backend/app/routers/houses.py` — add `require_host` to 4 endpoints + ownership check
- `backend/app/routers/viewing_appointments.py` — add auth to 3 endpoints (renamed Phase 01b)
- `backend/main.py` — include host_profile router
- `backend/requirements.txt` — add `python-multipart` (CCCD upload), `pillow` (image validation)

### Flutter new files
- `lib/features/host/onboarding/step1_info_screen.dart`
- `lib/features/host/onboarding/step2_cccd_screen.dart`
- `lib/features/host/onboarding/step3_bank_screen.dart`
- `lib/features/host/onboarding/widgets/onboarding_stepper.dart`
- `lib/features/host/onboarding/widgets/cccd_uploader.dart`
- `lib/features/host/profile/host_profile_screen.dart`
- `lib/data/models/host_profile_model.dart`
- `lib/providers/host_profile_provider.dart`
- `lib/data/repositories/api_host_profile_repository.dart`
- `lib/domain/repositories/i_host_profile_repository.dart`
- `lib/core/widgets/labeled_text_field.dart`

### Flutter modified files
- `lib/main.dart` — add HostProfileProvider to MultiProvider
- `lib/features/host/host_home_screen.dart` — entry point: nếu HostProfile chưa tồn tại → redirect onboarding step 1
- `lib/features/guest/profile_screen.dart` (nếu có) — add "Trở thành host" button
- `pubspec.yaml` — image_cropper, intl

### Test files
- `backend/tests/test_host_profile.py`
- `backend/tests/security/test_cross_host_isolation.py` — Host A login + try GET/PUT/DELETE Host B's resources → 403/404
- `backend/tests/security/test_require_host.py` — guest tries host endpoints → 403
- `backend/tests/test_auth_register_role_whitelist.py` — POST /register với role=admin → ignore, set role=guest

## Implementation steps

1. **Backend (deps):** Add `require_host()` to `app/auth.py:85`:
   ```python
   def require_host(claims: dict = Depends(require_user)) -> dict:
       if claims.get("role") != "host":
           raise HTTPException(403, "Yêu cầu quyền host")
       return claims
   ```
2. **Backend (schemas):** Create `app/schemas/host_profile.py` with Pydantic models.
3. **Backend (models):** Add HostProfile, ChangeLog, CCCDAccessLog classes to `app/models.py`.
4. **Backend (migration):** `alembic revision -m "add_host_profile_audit_log"` → write CREATE TABLE statements with proper FK + indexes.
5. **Backend (storage):** Create `app/services/cccd_storage.py`:
   - `save_cccd(file: UploadFile, host_id: int) → path` (UUIDv4 filename, chmod 0700 on `storage/cccd/`)
   - `read_cccd(path: str, actor_id: int) → bytes` (write CCCDAccessLog before reading)
6. **Backend (repo base):** Create `app/repositories/base.py` with HostScopedRepository.
7. **Backend (repo host_profile):** Create `app/repositories/host_profile_repository.py`.
8. **Backend (router):** Create `app/routers/host_profile.py` with 5 endpoints (GET profile, PATCH, POST cccd, POST upgrade, GET cccd binary).
9. **Backend (fix auth):** 
   - `app/routers/auth_router.py` line 30: whitelist `role = 'guest'` ignore body; line 66 change-password use `claims.sub`.
   - `app/routers/houses.py` lines 85, 128, 183: add `claims=Depends(auth.require_host)` + ownership check.
   - `app/routers/viewing_appointments.py`: add auth to 3 endpoints.
10. **Backend (main):** Include `host_profile.router` in `main.py`.
11. **Backend (tests security):** Write `tests/security/test_cross_host_isolation.py` + `test_require_host.py` + `test_auth_register_role_whitelist.py`.
12. **Backend (tests positive):** Write `tests/test_host_profile.py` with happy path.
13. **Backend (verify):** `pytest tests/security/` → all pass. `alembic upgrade head` clean.
14. **Flutter (packages):** Add `image_cropper`, `intl` to `pubspec.yaml`, `flutter pub get`.
15. **Flutter (model):** Create `host_profile_model.dart`.
16. **Flutter (repo):** Create `api_host_profile_repository.dart` + `i_host_profile_repository.dart`.
17. **Flutter (provider):** Create `host_profile_provider.dart`.
18. **Flutter (widgets):** Create `labeled_text_field.dart`, `onboarding_stepper.dart`, `cccd_uploader.dart`.
19. **Flutter (screens):** Create step1, step2, step3 + host_profile_screen.
20. **Flutter (main):** Add HostProfileProvider to MultiProvider in `main.dart`.
21. **Flutter (entry):** Edit `host_home_screen.dart` initState: nếu `hostProfileProvider.profile == null` → push HostOnboardingStep1Screen.
22. **Flutter (analyze):** `flutter analyze` → 0 errors.
23. **E2E test:** Register guest → tap "Trở thành host" → complete 3-step → CCCD upload success → role='host' in JWT → redirected to HostHomeScreen.

## Todo list
- [ ] Backend: add `require_host()` dependency
- [ ] Backend: Pydantic schemas for HostProfile
- [ ] Backend: HostProfile, ChangeLog, CCCDAccessLog models
- [ ] Backend: Alembic 0004 migration
- [ ] Backend: cccd_storage service with 0700 perms + audit log
- [ ] Backend: HostScopedRepository base + host_profile_repository
- [ ] Backend: host_profile router (5 endpoints)
- [ ] Backend: fix auth_router role whitelist + change-password IDOR
- [ ] Backend: add auth to 4 houses endpoints
- [ ] Backend: add auth to 3 viewing_appointments endpoints
- [ ] Backend: security tests (cross-host isolation, require_host, role whitelist)
- [ ] Backend: positive tests host_profile
- [ ] Flutter: add image_cropper, intl packages
- [ ] Flutter: host_profile_model + repository + provider
- [ ] Flutter: reusable widgets (labeled_text_field, stepper, cccd_uploader)
- [ ] Flutter: 3 onboarding screens + host_profile screen
- [ ] Flutter: MultiProvider entry + onboarding redirect logic
- [ ] E2E test: complete onboarding → host role granted

## Success criteria (testable)
- AC1: Guest tap "Trở thành host" → 3-step onboarding complete <5 phút (manual measure)
- AC2: `pytest tests/security/test_cross_host_isolation.py` — Host A queries Host B's house → 403/404
- AC3: `pytest tests/security/test_require_host.py` — guest hit `/api/host/profile` → 403
- AC4: `pytest tests/test_auth_register_role_whitelist.py` — POST register with role=admin → DB row.role='guest'
- AC5: CCCD upload: file lưu `storage/cccd/<uuid>.jpg` with `stat -c %a` returning 600/700 perms
- AC6: GET `/api/host/cccd/{id}` writes 1 row vào `cccd_access_logs` per request
- AC7: `flutter analyze` 0 errors; manual demo: onboarding 3 steps render correct
- AC8: Marketplace listing GET `/api/houses/{id}` response includes `host_avg_response_hours`, `host_rating`
- Demo: register guest → upgrade → seeded HostProfile → see "Profile verified" badge

## Risk assessment
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Existing data: houses have host_id pointing to users with role='guest' (legacy from before Phase 02) | 50% | MED | Seed script: bulk upgrade legacy hosts; document in README |
| File permissions 0700 fail on Windows dev | 30% | LOW | Document Linux/macOS only for storage; Windows dev OK without perms (insecure dev) |
| CCCD images leak via wrong endpoint | LOW | HIGH | Only expose via `/api/host/cccd/{id}` with require_host + ownership check; no direct file URL |
| Pydantic v1/v2 mismatch | 10% | LOW | Pin Pydantic version in requirements.txt; use v2 syntax `model_dump()` not `dict()` |
| Repository pattern misused by future devs (direct query bypass) | 60% | MED | Document pattern in `docs/code-standards.md`; code-reviewer enforce |

## Security considerations
- **Auth:** `require_host()` middleware enforced on all host-only endpoints
- **Input validation:** Pydantic schemas at every POST/PATCH route boundary
- **Data isolation:** HostScopedRepository auto-filters `host_id`; integration test cross-host verifies
- **PDPL (CCCD):**
  - Folder `storage/cccd/` chmod 0700 (host user only)
  - Filename UUIDv4 (no PII in path)
  - CCCD number stored as one-way hash (compare-only, no plaintext)
  - All file reads/writes logged to `cccd_access_logs` with actor_id, ip, timestamp
  - No direct file URL exposed; only via authenticated endpoint
- **Audit trail:** `change_logs` table receives mutations from Phase 03+
- **JWT:** After upgrade-to-host, issue new JWT with role='host'; old guest token still valid until expiry but `require_host` blocks

## Next steps
- Unblocks Phase 03 (Building/Room/Tenant CRUD secure foundation)
- Unblocks Phase 05 (KhaiBaoTamTru needs HostProfile context)
- Dependencies for next: repository pattern must be used by Phase 03 router code
