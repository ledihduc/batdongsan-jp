# Phase 08 — Tests + QA Checklist (22 AC) + Documentation

## Context Links
- BA: `phase-00-ba-requirements.md` § ALL AC-01..22
- Reports: All prior phases (01-07)
- Reference code: All `services/`, `routers/`, `features/planning/` từ P01-P07

## Overview
- Priority: **P0** (gate trước P09 deploy)
- Status: Pending
- Estimate: 1.5 ngày
- Description: Unit/widget/integration tests cho backend + frontend; manual QA checklist 22 AC; docs `planning-lookup.md` ở cả 2 repo.

## Key Insights
- Backend: pytest + httpx (FastAPI test client) — focus rate limit, bbox guard, admin auth, parcel lookup ST_Contains.
- Frontend: `flutter_test` widget tests cho `PlanningBadge`, `ParcelDetailSheet`, `PlanningMapProvider`; integration test smoke trên emulator.
- Manual QA: 22 AC checklist — KHÔNG test trên emulator các AC perf (AC-02 nói rõ).
- Docs: 2 file song song — backend docs API contract + ETL ops; frontend docs UI flows + state diagrams.

## Requirements
### Functional — Test Matrix

#### Backend (`ancu365-backend/tests/`)

| Test file | What |
|-----------|------|
| `test_planning_parcels.py` | GET /parcels by point — happy path + 404 (no parcel) + 422 bbox |
| `test_planning_search.py` | GET /search — Nominatim proxy mock + bbox filter |
| `test_planning_districts.py` | GET /districts — count parcels grouped |
| `test_planning_report_error.py` | POST /report-error — auth required, validation, DB insert |
| `test_planning_admin.py` | GET /admin/risky-listings — admin only, non-admin 403, anonymous 401 |
| `test_planning_rate_limit.py` | 31st req in 1h → 429 (anonymous IP key); 201st req → 429 (user_id key) |
| `test_planning_etl_smoke.py` | `seed-all --districts "Quận 1"` → planning.parcels has > 100 rows |

Coverage target: services + router ≥ 80%.

#### Frontend (`ancu365-app/test/`)

| Test file | What |
|-----------|------|
| `planning_service_test.dart` | All 7 methods with mocked dio (cancel token, error mapping) |
| `bbox_guard_test.dart` | True/False matrix 4 corners HCMC + 4 outside points |
| `zone_color_resolver_test.dart` | Hex valid/invalid/null; dark mode opacity |
| `planning_badge_widget_test.dart` | Loading → ready → fail-silent (empty render) |
| `parcel_detail_sheet_widget_test.dart` | Render parcel fields; show warning if fetched_at > 30 days; disclaimer present |
| `planning_warning_modal_widget_test.dart` | Risky → banner amber; non-risky → no banner; log event called |
| `planning_map_provider_test.dart` | State transitions: idle → loading → ready/error; retry counter ≤ 3; cancel token |
| `risky_listings_screen_widget_test.dart` | Empty state; populated list; pull to refresh |

Coverage target: features/planning ≥ 70%.

#### Integration (smoke E2E)
- `integration_test/planning_e2e_test.dart`: Boot app → tap "Tra quy hoạch" → pick from search → tap parcel → sheet show → close. Run on Android emu.

### Non-functional — Manual QA Checklist 22 AC

Run trên Android Galaxy A series (real device) + iPhone 13 simu (per AC-02 instruction).

Checklist file: `plans/.../reports/qa-checklist-22ac.md` — sẽ tạo ở phase này.

## Architecture
```
Backend tests
 ├─ conftest.py: pytest fixture for FastAPI TestClient + Postgres test DB
 ├─ test_planning_*.py × 7
 └─ pytest-cov → coverage report

Frontend tests
 ├─ test/: unit + widget × 8
 ├─ integration_test/: 1 E2E smoke
 └─ flutter test --coverage → lcov

Docs
 ├─ ancu365-backend/docs/planning-lookup.md (NEW)
 └─ ancu365-app/docs/features/planning-lookup.md (NEW)
```

## Related Code Files

### To create
- `ancu365-backend/tests/conftest.py`
- `ancu365-backend/tests/test_planning_parcels.py`
- `ancu365-backend/tests/test_planning_search.py`
- `ancu365-backend/tests/test_planning_districts.py`
- `ancu365-backend/tests/test_planning_report_error.py`
- `ancu365-backend/tests/test_planning_admin.py`
- `ancu365-backend/tests/test_planning_rate_limit.py`
- `ancu365-backend/tests/test_planning_etl_smoke.py`
- `ancu365-backend/docs/planning-lookup.md`
- `ancu365-app/test/planning_service_test.dart`
- `ancu365-app/test/bbox_guard_test.dart`
- `ancu365-app/test/zone_color_resolver_test.dart`
- `ancu365-app/test/widgets/planning_badge_widget_test.dart`
- `ancu365-app/test/widgets/parcel_detail_sheet_widget_test.dart`
- `ancu365-app/test/widgets/planning_warning_modal_widget_test.dart`
- `ancu365-app/test/widgets/risky_listings_screen_widget_test.dart`
- `ancu365-app/test/providers/planning_map_provider_test.dart`
- `ancu365-app/integration_test/planning_e2e_test.dart`
- `ancu365-app/docs/features/planning-lookup.md`
- `plans/.../reports/qa-checklist-22ac.md`

### To modify
- `ancu365-backend/requirements.txt` → add `pytest==8.3.2`, `pytest-cov==5.0.0`, `pytest-asyncio==0.23.8`, `httpx==0.27.0` (đã có)
- `ancu365-app/pubspec.yaml` → add `mocktail ^1.0.4`, `integration_test` (sdk)
- `ancu365-backend/.github/workflows/test.yml` (optional CI — defer nếu chưa có)

### To delete
- (none)

## Implementation Steps

1. **Backend test setup** `conftest.py`:
   ```python
   import pytest
   from fastapi.testclient import TestClient
   from app.main import app
   from app.database import engine, Base
   @pytest.fixture(scope="session")
   def client():
       # Use isolated test DB
       return TestClient(app)
   @pytest.fixture
   def admin_token():
       return create_test_jwt(role="admin")
   @pytest.fixture
   def user_token():
       return create_test_jwt(role="guest")
   ```

2. **Sample backend test** `test_planning_parcels.py`:
   ```python
   def test_parcel_by_point_inside_bbox(client, seed_q1):
       r = client.get("/api/planning/parcels?lat=10.77&lng=106.69")
       assert r.status_code == 200
       data = r.json()
       assert data["zone_code"] is not None
       assert "geometry" in data
   def test_parcel_by_point_outside_bbox(client):
       r = client.get("/api/planning/parcels?lat=21.0&lng=105.85")
       assert r.status_code == 422
       assert r.json()["error"]["code"] == "OUT_OF_BBOX"
   def test_parcel_not_found(client):
       r = client.get("/api/planning/parcels?lat=10.40&lng=106.32")  # ngoài seed
       assert r.status_code == 200
       assert r.json() is None
   ```

3. **Sample backend test** `test_planning_rate_limit.py`:
   ```python
   def test_anonymous_rate_limit_30_per_hour(client):
       for i in range(30):
           r = client.get("/api/planning/search?q=test")
           assert r.status_code in (200, 503)  # 503 if Nominatim down
       r31 = client.get("/api/planning/search?q=test")
       assert r31.status_code == 429
   ```

4. **Sample frontend widget test** `planning_badge_widget_test.dart`:
   ```dart
   testWidgets('PlanningBadge shows loading then ready', (tester) async {
     final mockSvc = MockPlanningService();
     when(() => mockSvc.getParcelByPoint(any(), any())).thenAnswer(
         (_) async => _fakeParcel());
     await tester.pumpWidget(MaterialApp(home: Provider<PlanningService>.value(
         value: mockSvc, child: const PlanningBadge(lat: 10.77, lng: 106.69))));
     expect(find.byType(LinearProgressIndicator), findsOneWidget);
     await tester.pumpAndSettle();
     expect(find.textContaining('Quy hoạch:'), findsOneWidget);
   });
   testWidgets('PlanningBadge fails silently on error', (tester) async {
     final mockSvc = MockPlanningService();
     when(() => mockSvc.getParcelByPoint(any(), any())).thenThrow(Exception('fail'));
     // ... pump ... expect SizedBox.shrink (no badge)
   });
   ```

5. **Sample frontend test** `planning_map_provider_test.dart`:
   ```dart
   test('tapParcel transitions idle → loading → ready', () async {
     final svc = MockPlanningService();
     when(() => svc.getParcelByPoint(any(), any(), cancelToken: any(named: 'cancelToken')))
         .thenAnswer((_) async => _fakeParcel());
     final p = PlanningMapProvider(svc);
     expect(p.state, MapState.idle);
     final future = p.tapParcel(10.77, 106.69);
     expect(p.state, MapState.loading);
     await future;
     expect(p.state, MapState.ready);
     expect(p.selectedParcel, isNotNull);
   });
   test('retry counter capped at 3', () async {
     // simulate 3 errors → message cuối
   });
   ```

6. **Run tests:**
   ```bash
   # Backend
   cd ancu365-backend && pytest --cov=app --cov-report=html
   # Frontend
   cd ancu365-app && flutter test --coverage
   # Integration
   flutter test integration_test/planning_e2e_test.dart
   ```

7. **Manual QA checklist** `reports/qa-checklist-22ac.md`:
   ```markdown
   # QA Checklist 22 AC
   Tested device: __________ (Android Galaxy A54 / iPhone 13 simu)
   Network: __________ (4G LTE / WiFi)
   Tester: __________
   Date: __________

   | AC | Description | Pass/Fail | Notes |
   |----|-------------|-----------|-------|
   | AC-01 | Cold start < 3s | [ ] | _____ ms |
   | AC-02 | Parcel tap p95 < 1.5s (4G real device) | [ ] | _____ ms (median of 20) |
   | AC-03 | Search p95 < 2.5s | [ ] | _____ ms |
   | AC-04 | 100% house badge correct | [ ] | _____/10 |
   | AC-05 | Layer toggle + opacity smooth | [ ] | _____ fps |
   | AC-06 | Out-of-bbox toast + button | [ ] | |
   | AC-07 | 3 retry then final message | [ ] | |
   | AC-08 | Skeleton < 200ms | [ ] | |
   | AC-09 | Disclaimer 4 vị trí | [ ] | sheet/footer/warning/badge link |
   | AC-10 | i18n VI primary + EN | [ ] | |
   | AC-11 | Dark mode opacity -10% | [ ] | |
   | AC-12 | TalkBack + tap ≥ 48dp | [ ] | |
   | AC-13 | Permission denied → search vẫn dùng được | [ ] | |
   | AC-14 | Cache ≤ 100MB + clear button | [ ] | |
   | AC-15 | Freshness warning > 30 ngày | [ ] | |
   | AC-16 | Disclaimer ubiquitous (dup AC-09) | [ ] | |
   | AC-17 | Tap 2 thửa nhanh KHÔNG race | [ ] | |
   | AC-18 | Anonymous 30 req/IP/h → 429 | [ ] | |
   | AC-19 | Admin endpoint 403 cho non-admin | [ ] | |
   | AC-20 | App size delta ≤ +15MB | [ ] | actual: ___ MB |
   | AC-21 | Memory peak < 350MB | [ ] | actual: ___ MB |
   | AC-22 | 5 phút < 5% pin | [ ] | actual: ___ % |
   ```

8. **Backend doc** `ancu365-backend/docs/planning-lookup.md`:
   - Endpoint contract (9 routes) + Pydantic schema
   - Rate limit table
   - ETL ops: seed-all command, cron schedule, troubleshooting
   - Risky zone codes list + how to update
   - Privacy log policy (Nghị định 13)
   - Migration: SQLite → Postgres steps

9. **Frontend doc** `ancu365-app/docs/features/planning-lookup.md`:
   - UI flows: 4 entry points (tab, badge, warning modal, admin)
   - State diagram `PlanningMapProvider`
   - Widget tree map screen
   - i18n keys table
   - Cache strategy + clear cache
   - Testing guide

10. **Fix any failed tests** — KHÔNG ignore. Re-run cho tới pass.

11. **Manual QA full pass** trên real Android device (Galaxy A series) — 22 AC.

## Todo List
- [ ] Backend tests setup `conftest.py`
- [ ] 7 backend test files
- [ ] Backend coverage ≥ 80% planning module
- [ ] Frontend test setup `mocktail`, fakes
- [ ] 8 frontend unit/widget test files
- [ ] Integration test smoke E2E
- [ ] Frontend coverage ≥ 70% features/planning
- [ ] QA checklist file `qa-checklist-22ac.md`
- [ ] Manual QA 22 AC trên real Android device
- [ ] Manual QA 22 AC trên iOS simulator
- [ ] Backend doc `planning-lookup.md`
- [ ] Frontend doc `planning-lookup.md`
- [ ] All tests pass (NO ignore)

## Success Criteria
- Backend pytest 100% pass, coverage planning module ≥ 80%.
- Frontend flutter test 100% pass, coverage features/planning ≥ 70%.
- Integration E2E smoke pass trên Android emu.
- Manual QA 22 AC: ≥ 20/22 pass; nếu fail AC nào → fix hoặc document acceptable trong report.
- 2 docs (`planning-lookup.md`) review-ready, link từ root README.

## Risk Assessment
| Risk | Mức | Mitigation |
|------|-----|-----------|
| AC-02/03 fail trên real device do mạng | Trung | Test với 4G LTE chỉ, không WiFi; log p95 thật, nếu fail → tune backend index hoặc cache layer |
| AC-21 memory > 350MB | Trung | Profile DevTools, tìm leak; nếu vector tile cache lớn → reduce cache size |
| AC-22 pin > 5% | Trung | Disable polling, reduce animation; defer nếu giảm < 6% acceptable |
| Test DB conflict với dev DB | Cao | Separate `DATABASE_URL_TEST=postgresql://...test`; teardown sau session |
| Nominatim down during test | Trung | Mock `httpx.AsyncClient` trong `test_planning_search.py` |
| Integration test flaky | Trung | Retry 2 lần trong CI; debug timing với `pumpAndSettle(Duration(seconds: 5))` |
| Coverage thấp hơn target | Thấp | Identify uncovered lines; add edge case tests; report % thực tế |

## Security Considerations
- Test KHÔNG dùng production credentials.
- Fake JWT generation via shared util, KHÔNG hardcode secret thật.
- E2E test KHÔNG submit data thật lên prod backend — point to staging/local.

## Next Steps
- ✅ Phase 09 (VPS deploy) start sau khi P08 all tests pass + QA report ≥ 20/22 AC.
- ⚠️ Tech Lead Review (Phase 5 important workflow) cần tests + QA report làm input.
