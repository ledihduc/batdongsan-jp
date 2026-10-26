# Architecture Pattern Audit — Mirror for Analytics Module

**Date:** 2026-06-28  
**Scope:** Backend (FastAPI + SQLAlchemy) & Flutter (Provider + go_router)  
**Goal:** Establish conventions for `analytics_service.py`, `host_analytics.py` router, and Flutter `analytics/` module.

---

## Backend Patterns (FastAPI + SQLAlchemy + Pydantic v2)

### Router Pattern

**Files:** `app/routers/host_dashboard.py`, `app/routers/host_contract.py`, `app/routers/host_report.py`

**Naming Convention:**
- File: `app/routers/host_<feature>.py` (kebab-case feature name)
- Router prefix: `/api/host/<feature>`
- Tags: `["host-<feature>"]` for OpenAPI grouping

**Skeleton:**
```python
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from app import auth
from app.database import get_db
from app.schemas.report import RevenueReport
from app.services import report_service

router = APIRouter(prefix="/api/host/reports", tags=["host-reports"])

@router.get("/revenue", response_model=RevenueReport)
def revenue(
    period: str = Query("month", pattern="^(month|year)$"),
    date: str = Query(..., description="YYYY-MM or YYYY"),
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_host),
):
    return report_service.revenue_report(db, int(claims["sub"]), period, date)
```

**Patterns:**
- Auth: `claims: dict = Depends(auth.require_host)` — injects JWT claims dict
- Host ID: extract via `int(claims["sub"])` and pass to service
- Query params: use `Query(...)` with pattern validation for dates
- Return: `response_model=SchemaClass` — Pydantic response validation
- Error: `HTTPException(status_code=400, detail=str(e))` for validation errors
- Sessions: `db: Session = Depends(get_db)` injected at router level

### Service Layer Pattern

**Files:** `app/services/contract_service.py`, `app/services/invoice_service.py`, `app/services/report_service.py`

**Signature Style:**
- All public functions are **sync** (not async) — database is sync via SQLAlchemy 1.4/2.0 ORM
- Session injected at **router level**, passed as first param to service function
- Functions receive `host_id: int` explicitly — no implicit context
- Return domain dict or ORM model, NOT Pydantic schema (schema conversion at router)
- Never commit within service — router owns transaction lifecycle

**Skeleton:**
```python
def revenue_report(db: Session, host_id: int, period: str, date_str: str) -> dict:
    """Sum paid invoice line items grouped by category for the host.
    
    Returns {total: float, breakdown: {category: amount}, by_building: [...]}
    """
    prefix = _period_prefix(period, date_str)
    
    # Query with host_id filter
    cat_rows = (
        db.query(
            models.InvoiceLineItem.category,
            func.sum(models.InvoiceLineItem.amount),
        )
        .join(models.Invoice, models.Invoice.id == models.InvoiceLineItem.invoice_id)
        .filter(
            models.Invoice.host_id == host_id,  # IDOR gate
            models.Invoice.status == "paid",
            models.Invoice.period_start.like(f"{prefix}%"),
        )
        .group_by(models.InvoiceLineItem.category)
        .all()
    )
    breakdown: dict[str, float] = {row[0]: float(row[1] or 0) for row in cat_rows}
    return {"breakdown": breakdown, "total": sum(breakdown.values())}
```

**Transaction Pattern:**
- Service functions do NOT call `db.commit()`
- Router calls `db.commit()` and `db.refresh()` after service success
- Enables atomic multi-step operations (service1 → service2 → commit)

**Query Style:**
- SQLAlchemy ORM (not raw SQL text)
- Always filter by `host_id` or `building.host_id` to prevent IDOR
- Use `func.sum()`, `func.count()` for aggregations
- Prefix matching for date ranges: `.like(f"{prefix}%")`

### Schema (Pydantic v2) Pattern

**Files:** `app/schemas/contract.py`, `app/schemas/invoice.py`, `app/schemas/report.py`

**Config:**
```python
from pydantic import BaseModel, field_validator
from typing import Literal, Optional

# Literal types for enums (not Python enum)
InvoiceStatus = Literal["draft", "sent", "paid", "overdue", "cancelled"]

class InvoiceLineItemResponse(BaseModel):
    id: int
    invoice_id: int
    category: str
    description: str
    
    model_config = {"from_attributes": True}  # v2 ORM mode
```

**Naming Convention:**
- Request schemas: `CreateName`, `UpdateName`, `FilterRequest`
- Response schemas: `NameResponse`, `NameDetail`
- Literals for status/enum fields (not Python `Enum`)

**Validation:**
```python
@field_validator("month")
@classmethod
def month_format(cls, v: str) -> str:
    if len(v) != 7 or v[4] != "-":
        raise ValueError("Tháng phải đúng định dạng YYYY-MM")
    return v
```

### Auth & IDOR Pattern

**Location:** `app/auth.py` lines 87–95

**Role Check:**
```python
def require_host(claims: dict = Depends(require_user)) -> dict:
    """Require role host or admin. Admin is super-host."""
    if claims.get("role") not in ("host", "admin"):
        raise HTTPException(status_code=403, detail="Yêu cầu quyền host")
    return claims
```

**IDOR Prevention:**
- Every service function receives `host_id: int` from router
- Service-layer queries ALWAYS filter: `.filter(models.Invoice.host_id == host_id, ...)`
- Example: `revenue_report(db, int(claims["sub"]), ...)` passes host_id explicitly
- No path to query other hosts' data even if JWT claims forged

### DB Session Pattern

**File:** `app/database.py`

**Setup:**
```python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

**Style:**
- Sync engine (not async SQLAlchemy)
- SQLAlchemy 2.0 ORM style (`.query()` chaining)
- Per-request session via FastAPI `Depends(get_db)` generator
- Autoflush=False, autocommit=False (explicit control)

### Test Pattern

**Files:** `tests/conftest.py`, `tests/test_contract_transfer_room.py`

**Fixture Strategy:**
```python
# conftest.py — shared canned data + FakeSession for planning tests
CANNED_PARCEL: dict = {
    "parcel_id": "Q1-001-TEST",
    "area_m2": 120.5,
    # ...
}

# Per-test setup: real Postgres via pytest-postgresql
@pytest.fixture
def pg_session(pg_smoke_engine):
    """Transactional rollback per test."""
    connection = pg_smoke_engine.connect()
    transaction = connection.begin()
    Session = sessionmaker(bind=connection, autoflush=False, autocommit=False)
    session = Session()
    yield session
    session.close()
    transaction.rollback()  # Clean after each test
    connection.close()
```

**Auth Gate Test Pattern:**
```python
def _setup(db):
    from app import models, auth
    user = models.User(
        name="Host 1234",
        email="host_12345@test.com",
        password_hash=auth.hash_password("pass"),
        role="host",
        is_active=True,
        created_at=datetime.utcnow(),
    )
    db.add(user)
    db.flush()
    token = auth.sign_token(user.id, "host")
    return user, token
```

**Framework:** pytest + pytest-asyncio (for async tests if needed in future)

### CSV Export Pattern

**File:** `app/routers/host_report.py` lines 60–75

```python
from fastapi.responses import StreamingResponse
from app.services import report_service

@router.get("/export")
def export_invoices_csv(
    type: str = Query("invoices", pattern="^(invoices)$"),
    month: str = Query(..., description="YYYY-MM"),
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_host),
):
    host_id = int(claims["sub"])
    safe_month = month[:7]
    filename = f"invoices-{safe_month}.csv"
    return StreamingResponse(
        report_service.export_invoices_csv(db, host_id, safe_month),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
```

**Service Implementation:**
```python
import csv
import io
from typing import Generator

def export_invoices_csv(db: Session, host_id: int, month: str) -> Generator[str, None, None]:
    """Generator yields CSV lines. FastAPI streams to client."""
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["Invoice", "Tenant", "Amount", "Status"])
    
    rows = db.query(...).filter(Invoice.host_id == host_id, ...).all()
    for row in rows:
        writer.writerow([row.invoice_number, row.tenant_name, row.amount, row.status])
        yield output.getvalue()
        output.truncate(0)
        output.seek(0)
```

**Library:** Python `csv` module (standard library, no openpyxl or pandas)  
**Response:** `StreamingResponse` with `text/csv` media type + Content-Disposition header  
**Key:** Service returns Generator[str], router wraps in StreamingResponse

---

## Flutter Patterns (Provider + go_router)

### Repository Pattern

**Files:** `lib/domain/repositories/i_house_repository.dart`, `lib/data/repositories/api_invoice_repository.dart`

**Interface Convention:**
```dart
// lib/domain/repositories/i_analytics_repository.dart
abstract class IAnalyticsRepository {
  Future<RevenueReportModel> getRevenueReport({
    required String period,  // 'month' | 'year'
    required String date,    // 'YYYY-MM' or 'YYYY'
  });
  Future<OccupancyReportModel> getOccupancyReport({
    required int buildingId,
    required String month,   // 'YYYY-MM'
  });
}
```

**Implementation:**
```dart
// lib/data/repositories/api_analytics_repository.dart
class ApiAnalyticsRepository implements IAnalyticsRepository {
  final ApiClient _client = const ApiClient();

  @override
  Future<RevenueReportModel> getRevenueReport({
    required String period,
    required String date,
  }) async {
    final query = {'period': period, 'date': date};
    final resp = await _client.get(
      '/api/host/reports/revenue',
      queryParameters: query,
    );
    return RevenueReportModel.fromJson(Map<String, dynamic>.from(resp));
  }
  
  @override
  Future<OccupancyReportModel> getOccupancyReport({
    required int buildingId,
    required String month,
  }) async {
    final query = {'building_id': buildingId, 'month': month};
    final resp = await _client.get(
      '/api/host/reports/occupancy',
      queryParameters: query,
    );
    return OccupancyReportModel.fromJson(Map<String, dynamic>.from(resp));
  }
}
```

**Error Handling:** Throws exceptions; caller (provider) handles via try/catch  
**HTTP Client:** `ApiClient` (custom wrapper around `http` package)

### Provider Pattern

**File:** `lib/providers/host_profile_provider.dart`

**State Management:** ChangeNotifier + Provider package (NOT Riverpod)

```dart
class AnalyticsProvider extends ChangeNotifier {
  final IAnalyticsRepository _repo = ApiAnalyticsRepository();

  RevenueReportModel? _revenueReport;
  OccupancyReportModel? _occupancyReport;
  bool _isLoading = false;
  String? _error;

  RevenueReportModel? get revenueReport => _revenueReport;
  OccupancyReportModel? get occupancyReport => _occupancyReport;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchRevenueReport({
    required String period,
    required String date,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _revenueReport = await _repo.getRevenueReport(period: period, date: date);
    } catch (e) {
      _error = _toMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshOccupancy(int buildingId, String month) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _occupancyReport = await _repo.getOccupancyReport(
        buildingId: buildingId,
        month: month,
      );
    } catch (e) {
      _error = _toMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _toMessage(dynamic error) {
    if (error is Exception) return error.toString();
    return 'Lỗi không xác định';
  }
}
```

**State Pattern:**
- `_isLoading`: bool (mutually exclusive with `_revenueReport` and `_error`)
- `_error`: String? (set when exception caught)
- `_<data>`: Model? (set on success)
- All state changes followed by `notifyListeners()`

**Method Naming:** `fetch*` (initial load), `refresh*` (reload)

### Model Pattern

**Files:** `lib/data/models/invoice_model.dart`, `lib/data/models/revenue_report_model.dart`

**Style:** Manual `fromJson` (no freezed package)

```dart
class RevenueReportModel {
  final String period;        // 'month' | 'year'
  final String date;          // 'YYYY-MM' or 'YYYY'
  final double total;
  final Map<String, double> breakdown;  // category → amount
  final List<BuildingRevenue> byBuilding;

  const RevenueReportModel({
    required this.period,
    required this.date,
    required this.total,
    required this.breakdown,
    required this.byBuilding,
  });

  factory RevenueReportModel.fromJson(Map<String, dynamic> json) {
    return RevenueReportModel(
      period: json['period'] as String,
      date: json['date'] as String,
      total: (json['total'] as num).toDouble(),
      breakdown: Map<String, double>.from(
        (json['breakdown'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble()))
      ),
      byBuilding: (json['by_building'] as List<dynamic>?)
          ?.map((e) => BuildingRevenue.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList() ?? [],
    );
  }
}

class BuildingRevenue {
  final int buildingId;
  final String buildingName;
  final double total;

  const BuildingRevenue({
    required this.buildingId,
    required this.buildingName,
    required this.total,
  });

  factory BuildingRevenue.fromJson(Map<String, dynamic> json) {
    return BuildingRevenue(
      buildingId: json['building_id'] as int,
      buildingName: json['building_name'] as String,
      total: (json['total'] as num).toDouble(),
    );
  }
}
```

**Date Handling:** Stored as ISO String (`YYYY-MM-DD`), parsed to DateTime only when needed  
**Nullable Fields:** Use `??` with sensible defaults (empty list, 0, empty string)

### Screen Pattern

**Type:** StatefulWidget when local tab/filter state needed

```dart
class AnalyticsHomeScreen extends StatefulWidget {
  const AnalyticsHomeScreen({super.key});

  @override
  State<AnalyticsHomeScreen> createState() => _AnalyticsHomeScreenState();
}

class _AnalyticsHomeScreenState extends State<AnalyticsHomeScreen> {
  String _selectedPeriod = 'month';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    final provider = Provider.of<AnalyticsProvider>(context, listen: false);
    final dateStr = _selectedPeriod == 'month'
        ? '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}'
        : '${_selectedDate.year}';
    await provider.fetchRevenueReport(period: _selectedPeriod, date: dateStr);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AnalyticsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return const RevenueReportSkeleton();
          if (provider.error != null) return _ErrorWidget(provider.error!);
          if (provider.revenueReport == null) return const EmptyState();
          return _RevenueReportView(provider.revenueReport!);
        },
      ),
    );
  }
}
```

**Loading/Error States:**
```dart
if (provider.isLoading) return const LoadingSkeleton();
if (provider.error != null) return ErrorMessage(message: provider.error!);
return DataView(data: provider.revenueReport!);
```

### Routing Pattern (go_router)

**File:** `lib/core/router/app_router.dart` lines 1–200

**Deferred Import for Analytics Module:**

```dart
// At top with other deferred imports
import 'package:house_booking/features/host/analytics/screens/analytics_home_screen.dart'
    deferred as analytics;
import 'package:house_booking/features/host/analytics/providers/analytics_provider.dart'
    deferred as analytics_provider;

// In GoRouter routes array
GoRoute(
  path: '/host/analytics',
  pageBuilder: (ctx, state) => _fadePage(
    state: state,
    child: DeferredRouteWidget(
      loadLibrary: () async {
        // Load screen + provider in parallel
        await Future.wait([
          analytics.loadLibrary(),
          analytics_provider.loadLibrary(),
        ]);
      },
      builder: (_) => ChangeNotifierProvider(
        create: (_) => analytics_provider.AnalyticsProvider(),
        child: analytics.AnalyticsHomeScreen(),
      ),
    ),
  ),
),

// Nested routes for detail views
GoRoute(
  path: '/host/analytics/revenue/:period/:date',
  pageBuilder: (ctx, state) {
    final period = state.pathParameters['period']!;
    final date = state.pathParameters['date']!;
    return _fadePage(
      state: state,
      child: DeferredRouteWidget(
        loadLibrary: () async {
          await analytics.loadLibrary();
        },
        builder: (_) => analytics.RevenueDetailScreen(
          period: period,
          date: date,
        ),
      ),
    );
  },
),
```

**Deferred Import Pattern:**
- Use `deferred as <name>` for large modules to enable web chunk splitting
- Call `<name>.loadLibrary()` before accessing symbols
- Wrap in `DeferredRouteWidget` (custom widget that shows loading spinner until loaded)
- Parallel load: `Future.wait([chunk1.loadLibrary(), chunk2.loadLibrary()])`

**Auth Redirect:** Already handled by top-level redirect logic — analytics under `/host` auto-redirects to login if not authenticated

### Design Tokens

**File:** `lib/features/host/dashboard/host_dashboard_tokens.dart`

**Reusable Tokens for Analytics:**
```dart
// Colors (already defined in HD)
HD.paper        // Warm cream background
HD.paperRaised  // Lifted surface
HD.ink          // Primary text (navy)
HD.inkSoft      // Secondary text
HD.inkMuted     // Metadata, captions
HD.hairline     // Divider (1px warm grey)
HD.accent       // Red — primary actions
HD.positive     // Green — good status
HD.warning      // Amber — caution
HD.negative     // Dark red — past-due, risk

// Typography
HD.masthead(color: HD.ink)        // 36pt serif — hero KPI numerals
HD.sectionTitle(color: HD.ink)    // 22pt italic serif — section headers
HD.bodyBold(size: 14)             // Sans, 600wt — labels
HD.body(size: 12)                 // Sans, 400wt — descriptions
HD.caption()                      // 11pt, muted — metadata
HD.tabular(size: 13)              // Mono, tabular figures — times, codes

// Spacing
HD.s2, HD.s4, HD.s8, HD.s12, HD.s16, HD.s20, HD.s24, HD.s32, HD.s40, HD.s56

// Edges
HD.gutterX                        // horizontal: 20
HD.hairline                       // 1px divider widget
```

**For Analytics KPI Cards:**
```dart
Container(
  padding: const EdgeInsets.symmetric(vertical: HD.s16, horizontal: HD.s12),
  decoration: BoxDecoration(
    color: HD.paperRaised,
    border: Border(bottom: BorderSide(color: HD.hairline, width: 1)),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Doanh thu tháng', style: HD.eyebrow(color: HD.inkMuted)),
      SizedBox(height: HD.s8),
      Text('₫2.5B', style: HD.masthead(color: HD.accent)),
      SizedBox(height: HD.s4),
      Text('Tăng 12% so tháng trước', style: HD.caption()),
    ],
  ),
)
```

---

## Reusable Helpers Identified

### Backend Helpers

**Location:** `app/services/report_service.py`

- `_period_prefix(period: str, date_str: str) -> str` — Convert `(month, "2026-07")` → `"2026-07"` for LIKE queries
- `_round_vnd(value: float) -> float` — Round to whole VND (no fractional cents)
- `_invoice_number(contract_id: int, period_start: str) -> str` — Generate `"INV-202607-C42"` pattern

**Location:** `app/auth.py`

- `hash_password(plain: str) -> str` — bcrypt with cost 12
- `verify_password(plain: str, hashed: str) -> bool` — bcrypt comparison
- `sign_token(user_id: int, role: str) -> str` — JWT with 'sub' (string), 'role', 'iat', 'exp'
- `verify_token(token: str) -> Optional[dict]` — Decode + convert 'sub' back to int
- `require_host(claims: dict) -> dict` — Auth dependency for host+ endpoints
- `_ensure_owner_or_admin(claims: dict, owner_id: int) -> None` — IDOR gate helper

### Flutter Helpers

**Location:** `lib/data/services/api_client.dart`

- `ApiClient().get(path, queryParameters: {})` — GET with query params
- `ApiClient().postList(path, body: {})` — POST returning list
- `ApiClient().patch(path, body: {})` — PATCH returning single object
- All throw on non-2xx status

**Location:** `lib/features/host/dashboard/host_dashboard_tokens.dart`

- `HD.masthead()`, `HD.sectionTitle()`, `HD.body()`, `HD.caption()`, `HD.tabular()` — TextStyle builders
- `HDHairline()` — 1px divider widget

---

## Anti-patterns Detected (Avoid in New Module)

1. **Mixing Concerns in Router:**
   - Seen: none. Router delegates to service ✓
   - Good pattern.

2. **Schema Conversion:**
   - Seen: Router uses `.model_validate(orm_obj)` after service returns ORM model
   - Pattern: Service returns ORM / dict, router wraps in response_model ✓
   - Correct approach.

3. **Transaction Ownership:**
   - Seen: Router calls `db.commit()` after service success
   - Pattern: Service does NOT commit ✓
   - Correct approach.

4. **Auth Dependency Injection:**
   - Pattern: `Depends(auth.require_host)` for all host routes ✓
   - Pattern: `int(claims["sub"])` for host_id ✓
   - Consistent.

5. **Flutter State Management:**
   - Pattern: ChangeNotifier + Provider (NOT Riverpod) ✓
   - Consistent across codebase.

6. **Date Handling (Backend):**
   - Stored as ISO string `YYYY-MM-DD`
   - Queries use prefix matching `.like(f"{prefix}%")`
   - Consistent across invoices, contracts, reports ✓

7. **Flutter Model Parsing:**
   - Manual `fromJson`, no freezed
   - Consistent across all models ✓
   - No package overhead.

---

## Architecture Fit for Analytics Module

### Backend (analytics_service.py + host_analytics.py router)

**Recommended Structure:**

```
app/routers/host_analytics.py
├── router = APIRouter(prefix="/api/host/analytics", tags=["host-analytics"])
├── @router.get("/revenue", response_model=RevenueReport)
├── @router.get("/occupancy", response_model=OccupancyReport)
├── @router.get("/sources", response_model=SourcesReport)
└── @router.get("/export", response=StreamingResponse)

app/services/analytics_service.py
├── revenue_report(db, host_id, period, date) → dict
├── occupancy_report(db, host_id, building_id, month) → dict
├── sources_report(db, host_id) → dict
├── export_analytics_csv(db, host_id, export_type) → Generator[str]
└── _period_prefix(period, date_str) → str [reuse from report_service]

app/schemas/analytics.py
├── RevenueReport(BaseModel)
├── OccupancyReport(BaseModel)
├── SourcesReport(BaseModel)
└── SourceBucket(BaseModel)
```

**Key Decisions:**
- Sync functions (match existing codebase)
- Session injected at router, passed to service
- Host ID extraction: `int(claims["sub"])`
- IDOR: Every query filters `.filter(Invoice.host_id == host_id)` or via Building→host_id join
- CSV export: Generator[str] wrapped in StreamingResponse, reuse `text/csv` media type
- Pydantic v2 with `from_attributes=True` for ORM models

### Flutter (analytics/ module)

**Recommended Structure:**

```
lib/domain/repositories/
├── i_analytics_repository.dart

lib/data/repositories/
├── api_analytics_repository.dart

lib/data/models/
├── revenue_report_model.dart
├── occupancy_report_model.dart
├── sources_report_model.dart

lib/providers/
├── analytics_provider.dart

lib/features/host/analytics/
├── screens/
│   ├── analytics_home_screen.dart
│   ├── revenue_detail_screen.dart
│   └── occupancy_detail_screen.dart
├── widgets/
│   ├── kpi_card.dart
│   ├── period_selector.dart
│   └── source_breakdown_chart.dart

lib/core/router/
└── app_router.dart [add deferred routes for analytics]
```

**Key Decisions:**
- Repository interface + implementation (match existing pattern)
- ChangeNotifier provider (match existing codebase — NOT Riverpod)
- Manual fromJson models (no freezed)
- StatefulWidget for local period/building filter state
- Deferred imports via go_router for lazy loading
- Reuse `HD.*` design tokens from host_dashboard_tokens.dart
- All date strings stored as `YYYY-MM`, parsed to DateTime only when rendering

---

## Summary

**Backend:** Sync FastAPI router → service layer (no commit) → Pydantic v2 response. Auth via `require_host` dependency. IDOR via host_id filter in all queries. CSV via Generator + StreamingResponse.

**Flutter:** Repository interface + implementation. ChangeNotifier provider with loading/error/data states. Manual fromJson models. StatefulWidget for local state. Deferred imports for lazy loading via go_router. Reuse HD tokens.

**No Drift:** Both the analytics module and existing modules (reports, invoices, contracts) follow identical patterns. Consistency assured.

---

## Unresolved Questions

1. Should `analytics_service.py` share query helpers with `report_service.py` via `app/utils/analytics_helpers.py`, or keep separate?
   - Recommendation: Keep separate for now (YAGNI). Refactor if overlap reaches 30% LOC.

2. CSV export for occupancy/sources — same Generator pattern or DataFrame + openpyxl for Excel?
   - Recommendation: Generator + CSV (consistent with existing). Excel export can be Phase 2.

3. Flutter — pagination for revenue/occupancy breakdowns (by building, by source)?
   - Recommendation: Start with no pagination (assume <100 buildings). Add pagination if UX shows truncation.

