# Codebase Audit: Host Property Management Feature

**Date**: June 22, 2026  
**Scope**: Full investigation of existing host infrastructure & property/booking models  
**Status**: READY FOR FEATURE PLANNING

---

## 1. User Roles & Host Model

### Current State

**User Model** (Backend: `/app/models.py:48-64`)
- Fields: `id`, `name`, `email`, `password_hash`, `phone`, `avatar_path`, `role`, `is_active`, `created_at`, `birthday`, `bio`, `id_number`
- **Role support**: Already defined as enum-like string field (`role: str = "guest"` default)
- Roles in system: `"guest"`, `"host"`, `"admin"` (verified in `auth.py:30` JWT payload)
- **Authentication**: JWT-based (HS256, 168hr TTL by default), bcrypt for passwords

**Flutter UserModel** (`lib/data/models/user_model.dart:1-108`)
- Mirrors backend exactly with `role: String` (comment confirms 'admin', 'host', 'guest')
- Supports age calculation from `birthday` field
- `copyWith()` and serialization helpers present

**Auth Flow** (`app/routers/auth_router.py:13-98`)
- Registration: `POST /api/auth/register` accepts `role` parameter (line 30)
- Login: `POST /api/auth/login` returns token + user object
- `GET /api/auth/me` for session validation

### Existing Gaps

1. **No host-specific profile table**: User data is monolithic
   - Missing: verified status, bank account, tax ID, avg rating, response time
   - Workaround: Could extend User with nullable fields or create separate `HostProfile` table

2. **No role-based access control middleware**: Only `require_admin()` exists (`auth.py:77-84`)
   - Missing: `require_host()`, `require_guest()` dependencies
   - Current: All routes trust `host_id` from client body (unsafe)

3. **No role validation on registration**: Client sends any role, backend accepts it
   - Line 30 in `auth_router.py`: `role = body.get("role") or "guest"`
   - Risk: Users self-promoting to host/admin

---

## 2. Property / House Model

### Current State

**House Model** (`app/models.py:80-107`)
```
Fields:
  - id, host_id (indexed), title, description
  - category_id (indexed), price, area
  - address, city, district, latitude, longitude
  - bedrooms, bathrooms
  - status: 'pending' | 'approved' | 'rejected' | 'hidden' (default: 'pending', indexed)
  - images, amenities (JSONList type — stored as TEXT JSON)
  - listing_type: 'single' | 'multi_unit' (default: 'single')
  - total_units, available_units (for multi-unit rentals)
  - gender_pref: 'any' | 'male' | 'female'
  - created_at (indexed)
```

**Multi-unit Support**: ✅ Already implemented (lines 103-106)
- `listing_type`, `total_units`, `available_units`, `gender_pref` fully wired
- `close-unit` endpoint (`houses.py:194-222`) decrements available_units + notifies pending bookings

**Booking Model** (`app/models.py:109-119`)
```
Fields:
  - id, house_id (indexed), guest_id (indexed)
  - booking_date (YYYY-MM-DD), booking_time (HH:MM)
  - message, status: 'pending'|'approved'|'rejected'|'completed'|'cancelled' (indexed)
  - created_at (indexed)
```
- **No long-term lease support**: Only viewing appointment, not rental contract
- **Status flow**: pending → approved/rejected → completed/lost → locked (special final state)

**Booking Workflow** (`routers/bookings.py:60-123`)
- Status transitions with auto-notification (`push_notification` calls at lines 72-88, 93-119)
- `locked` status: Special case that decrements `available_units` and marks other pending bookings as `lost`

**API Contracts** (`routers/houses.py:11-223`)
- `GET /api/houses` — filters: query, categoryId, minPrice, maxPrice, minArea, maxArea, status, hostId, showFull
- `POST /api/houses` — create (no auth check: line 85)
- `PUT /api/houses/{id}` — edit (no auth check)
- `DELETE /api/houses/{id}` — delete (cascades to bookings, wishlists)
- `POST /api/houses/{id}/close-unit` — decrement units

### Existing Gaps

1. **No ForeignKey constraints**: `host_id` and `guest_id` are bare integers
   - No cascade delete/update rules at DB level
   - Risk: Orphaned houses if user deleted

2. **Single property type only**: Supports viewing appointments, not rentals
   - Missing: move-in date, lease duration, monthly/yearly price split
   - Missing: Room-level sub-units (e.g., house with 4 rooms, list individually or as bundle?)

3. **No room/unit model**: Multi-unit stored in House.total_units (numeric)
   - Can't track individual room status, features, or pricing
   - Example: Can't say "Room 1 is 3x4m, Room 2 is 4x5m"

4. **No contract/lease table**: Bookings are just viewing appointments
   - Missing: formal rental agreement tracking
   - Missing: deposit, payment schedule, end date

---

## 3. Existing Host-Facing Screens in Flutter

### Current Implementation

**HostHomeScreen** (`lib/features/host/host_home_screen.dart:1-642`)
- ✅ **My Listings (Tin đăng của tôi)**
  - Displays all properties by host (status: pending/approved/rejected)
  - Stats: Total listings, Pending approval count, Active count
  - Actions: Add listing, Edit, Delete per property
  - Multi-unit badge: shows "Còn X/Y phòng" or "Đã đủ phòng"
  - Close-unit button (line 280-296): Decrements available_units
  
- ✅ **Booking Requests (Yêu cầu hẹn xem nhà)**
  - Lists all bookings for host's properties (role='host', line 57)
  - Per-booking actions:
    - Approve (→ approved status)
    - Reject (→ rejected)
    - Lock (→ locked, decrements units, notifies other pending)
  - Status badges with Vietnamese labels

- ✅ **Add/Edit Listing**
  - Reuses `PostHouseScreen` from guest module (line 7)
  - Navigation: Line 109-115 (add new), Line 310-318 (edit)

### Navigation Structure

**GuestShell** (`lib/features/guest/guest_shell.dart:1-78`)
- Tab index 4 = Host home (`const int _tabHost = 4`)
- Tab switching triggers `bookings.fetchBookings(user.id!, 'host')` (line 58)
- Only shows when `user.role == 'host'` (implied by navigation logic)

### Existing Gaps

1. **No separate host registration flow**: Uses guest registration
   - No verification flow (e.g., ID check, address proof)
   - No onboarding to explain host features

2. **No host dashboard analytics**: Missing
   - Monthly earnings
   - Booking conversion rate
   - Response time stats
   - View count per listing
   - Guest reviews/ratings

3. **Limited listing creation UI**: Uses generic `PostHouseScreen`
   - No image upload preview
   - No drag-reorder amenities
   - No room/unit breakdown for multi-unit

4. **No host settings page**: Missing
   - Bank account details
   - Payout schedule
   - Notification preferences
   - Booking rules (min lease, price, etc.)

---

## 4. Image Upload, Chat, Notification Infrastructure

### Image Upload

**Implemented**: ✅ Yes (`routers/upload.py:23-40`)
- Endpoint: `POST /api/upload`
- Input: base64-encoded image in JSON body (`data` field)
- Storage: Local filesystem at `settings.upload_dir` (default: `./uploads`)
- Returns: `{"filename": "...", "url": "/uploads/..."}`
- Allowed types: `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp` (line 13)
- **Gap**: No S3/cloud storage; local-only

**Flutter Integration**: ✅ Present
- `ApiHouseRepository` → `createHouse()` likely encodes images before POST
- `HouseModel.images` stored as `List<String>` (image URLs)

### Chat System

**Backend**: ✅ Implemented (`routers/chat.py:1-159`)
- REST API:
  - `GET /api/chats` — all conversations for user
  - `GET /api/chats/{peer_id}/messages` — message history (limit 200)
  - `POST /api/chats/{peer_id}/messages` — send message (triggers WebSocket notify)
  - `PATCH /api/chats/{peer_id}/read` — mark as read
- **WebSocket**: `/ws?token=JWT` — real-time messaging hub
- Model: `ChatMessage` (sender_id, receiver_id, house_id, body, read, created_at)
- **Hub implementation**: Uses `app.chat_hub.hub` (not shown, likely in-memory or Redis-backed)

**Flutter**: ✅ `ChatProvider` exists (`lib/providers/chat_provider.dart`)
- Provider pattern setup for chat state management

### Notifications

**Backend**: ✅ Implemented (`routers/notifications.py:1-46`)
- Model: `Notification` (user_id, type, title, body, related_id, read, created_at)
- API:
  - `GET /api/notifications` — list all for user
  - `PATCH /api/notifications/{id}/read` — mark one read
  - `PATCH /api/notifications/read-all` — mark all read
- Push types seen: `booking_new`, `booking_approved`, `booking_rejected`, `booking_locked`, `booking_lost`
- **Triggered via**: `helpers.push_notification()` (called from bookings, houses routers)
- **Gap**: Database-only (no push service integration like FCM, APNs)

**Flutter**: ✅ `NotificationProvider` exists
- Notification UI likely in feature folder

### Existing Gaps

1. **Chat linked to House**: `house_id` field in ChatMessage (line 157 in models.py)
   - ✅ Supports context (host-guest talk about specific property)

2. **No FCM/APNs for push notifications**: Only database events
   - Real-time notify requires WebSocket (works via chat hub)
   - Missing: Mobile push service (Firebase Cloud Messaging)

3. **No email notifications**: Only in-app
   - `Notification` model has no email_sent flag

---

## 5. Database & Migration Setup

### Database Config

**Type**: Dual-mode architecture
- **Primary**: SQLite (default: `./urbannest.db`)
- **Planning module**: PostgreSQL with PostGIS (optional, Postgres-only)

**Location**: `app/database.py:1-39`
- Engine: SQLAlchemy with SQLite connection args (`check_same_thread=False`)
- ORM: SQLAlchemy 2.0+ (Mapped, mapped_column syntax)
- Base: `Base = DeclarativeBase()`

**Schema Creation**: `main.py:50`
```python
Base.metadata.create_all(bind=engine)  # Auto-create from models
```

### Migrations

**Tool**: Alembic (configured at `alembic.ini`)
- **Versions directory**: `alembic/versions/`
- **Current state**: Only 1 migration file
  - `0001_planning_reports.py` — for planning module only
  - Main schema uses auto-create (no formal migration history for core tables)

**Seed Data**: `app/seed.py`
- Called on startup (line 52 in `main.py`)
- Likely creates categories, amenities, admin user (not inspected in detail)

### Existing Gaps

1. **No formal migration strategy for core tables**
   - All core tables (users, houses, bookings, etc.) use metadata.create_all()
   - Risk: No migration history if deploying to production with data

2. **No database indexes beyond primary keys and noted (indexed=True)**
   - Has: host_id, category_id, status, created_at on House
   - Has: house_id, guest_id, status, created_at on Booking
   - Missing: composite indexes (e.g., house_id + status on Booking)

3. **Planning schema only on Postgres**
   - Will fail if trying to use planning features on SQLite
   - Conditional import at line 57 in `main.py`

---

## Summary: Ready-to-Build Scaffolding vs. Gaps

### What You Can Build On (✅ Already Works)

| Feature | Backend | Flutter | Status |
|---------|---------|---------|--------|
| **User roles (guest/host/admin)** | ✅ | ✅ | JWT + string field |
| **Multi-unit property** | ✅ | ✅ | Full CRUD + unit closure |
| **Viewing appointment booking** | ✅ | ✅ | Full lifecycle (pending→locked) |
| **Host listing dashboard** | ✅ | ✅ | My listings + incoming requests |
| **Image upload** | ✅ | ✅ | Local filesystem |
| **Chat (host ↔ guest)** | ✅ | ✅ | REST + WebSocket |
| **Notifications** | ✅ | Partial | DB-stored, no push service |
| **Database** | ✅ | N/A | SQLite or Postgres |

### What's Missing (❌ Gaps to Fill)

| Feature | Impact | Effort |
|---------|--------|--------|
| **Host profile/verification** | Essential for homestay feature | Medium |
| **Room-level (sub-units)** | Important for nhà trọ (shared houses) | Medium-High |
| **Long-term rental contract model** | Required for monthly/yearly leases | Medium |
| **Role-based access control middleware** | Security issue (currently trusts client host_id) | Low |
| **Host analytics dashboard** | Nice-to-have for host engagement | High |
| **Push notifications (FCM/APNs)** | Mobile UX improvement | Medium |
| **Cloud image storage (S3)** | Production-ready uploads | Low |
| **Formal migrations (Alembic for core)** | Deployment safety | Low |
| **House.seller_id or dual roles** | If same user is both buyer & seller | Low |

---

## Recommended Implementation Order

### Phase 1: Security & Data Model (Week 1)
1. Add `require_host()` middleware in auth.py
2. Create `HostProfile` model (verified, bank_account, etc.)
3. Validate `host_id == current_user.id` on POST /houses
4. Create Room model for nhà trọ (separate from listing_type=multi_unit)

### Phase 2: Host Features (Week 2-3)
1. Host settings screen (Flutter)
2. Host onboarding/verification flow
3. Analytics dashboard (earnings, booking stats)
4. Host-specific listing editor with room breakdown

### Phase 3: Polish (Week 4+)
1. FCM integration for push notifications
2. S3 image storage
3. Alembic migrations for production
4. Performance: Add composite indexes, optimize queries

---

## Files to Review Next

**Backend** (FastAPI):
- `/app/models.py` — add HostProfile, Room models
- `/app/routers/houses.py` — add auth checks
- `/app/auth.py` — add require_host()
- `/app/routers/auth_router.py` — registration flow

**Flutter**:
- `/lib/features/host/` — extend with settings, analytics
- `/lib/features/auth/` — add host onboarding
- `/lib/providers/auth_provider.dart` — track host status

---

**END OF AUDIT**
