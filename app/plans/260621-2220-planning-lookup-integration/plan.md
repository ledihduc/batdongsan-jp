# Plan — Tích hợp Tra cứu Quy hoạch vào ancu365 (rev2)

> Source feature: `faceconst` (Python FastAPI + PostGIS + Martin + Nominatim)
> Target app: `ancu365-app` (Flutter) + `ancu365-backend` (FastAPI — **share backend**)
> Status: **Phase 3 — Tech Lead Planning in progress**

---

## Strategy tổng quan (rev2 — UPDATED after user decisions)

**Approach:** **SHARE BACKEND.** Vì `ancu365-backend` đã là **FastAPI + SQLAlchemy + JWT** (cùng stack faceconst), port toàn bộ planning module trực tiếp vào, KHÔNG tách microservice.

```
┌─────────────────────────┐    HTTPS    ┌──────────────────────────────────┐
│  ancu365 Flutter (lib)  │ ──────────→ │  ancu365-backend (FastAPI :3000) │
│  features/planning/*    │             │                                  │
│  vector_map_tiles       │             │  ├ existing: auth, houses, ...   │
│  flutter_map ^7.0.2     │             │  └ NEW: /api/planning/*          │
└─────────────────────────┘             │     ├ services/planning_etl/     │
                                        │     ├ routers/planning.py        │
                                        │     └ models/planning_*.py       │
                                        └────────┬─────────────────────────┘
                                                 │
                              ┌──────────────────┼───────────────────┐
                              ▼                  ▼                   ▼
                       PostgreSQL+PostGIS    Martin (vector       Nominatim VN
                       (replaces SQLite     tiles) :3001          (geocoding)
                        for prod)                                  :8080
                       schema: planning,
                              public
```

**Why share backend:** cùng FastAPI stack, dùng chung `auth.py`, `database.py`, CORS, JWT secret. Tránh 2 deployment, 2 secret rotation, 2 monitoring stack.

---

## Locked decisions (xem `phase-00-ba-requirements.md` § Locked Decisions)

| # | Quyết định |
|---|------------|
| D1 | Share backend (merge vào ancu365-backend) |
| D2 | Flutter dùng `vector_map_tiles` trước, fallback Martin raster |
| D3 | Hosting production: VPS self-host Docker |
| D4 | Host đăng tin sai zone: cảnh báo, không block |
| D5 | Nominatim self-host cho production |

---

## Phases

| Phase | Tên | Estimate | Phụ thuộc |
|-------|-----|----------|-----------|
| 01 | Port planning module vào ancu365-backend + switch sang PostgreSQL+PostGIS | 2 ngày | — |
| 02 | Setup Docker stack (PostGIS + Martin + Nominatim) + seed HCMC | 1 ngày | 01 |
| 03 | FastAPI routes `/api/planning/*` (search, parcel, districts, layers, admin) | 1.5 ngày | 02 |
| 04 | Flutter data layer (service, models, repository) + POC `vector_map_tiles` | 1.5 ngày | 03 |
| 05 | Flutter `PlanningMapScreen` (map + search + parcel sheet + layer panel) | 2 ngày | 04 |
| 06 | Tích hợp vào house detail (badge) + post house (button cảnh báo) | 1 ngày | 05 |
| 07 | Admin "risky listings" report + US-08 báo cáo dữ liệu sai | 1 ngày | 03, 05 |
| 08 | Tests + QA (manual checklist 22 AC) + docs | 1.5 ngày | 06, 07 |
| 09 | Deploy VPS production (Docker compose + nginx + cron) | 1 ngày | 08 |

**Total estimate:** ~12.5 ngày dev (1 fullstack).

---

## Dependencies / Tech Stack

### ancu365-backend (additions)
| Package | Lý do |
|---------|-------|
| `sqlalchemy[asyncio]` (đã có) | Reuse cho planning queries |
| `geoalchemy2 ^0.15` | PostGIS ORM (giống faceconst) |
| `psycopg2-binary` | PostgreSQL driver |
| `requests` (đã có?) hoặc `httpx` | WFS client cho ETL |
| `shapely ^2.0` | Geometry validate / reproject |
| `pyproj ^3.6` | VN-2000 → WGS84 |
| `APScheduler ^3.10` | Daily cron 2AM ICT |
| `slowapi ^0.1.9` | Rate limit (AC-18: 30/h anonymous, 200/h logged-in) |

### ancu365-app (additions trong `pubspec.yaml`)
| Package | Lý do | Note |
|---------|-------|------|
| `vector_map_tiles ^7.x` | Render MVT từ Martin | Test compat với `flutter_map ^7.0.2` |
| `vector_map_tiles_pmtiles ^1.x` | Optional cache PMTiles | Optional |
| `cached_network_image ^3.x` | Cache raster tile + ảnh search | Có thể đã có |
| `geolocator ^12.x` | "Vị trí của tôi" | Optional |
| `flutter_localizations` (đã có) | i18n (AC-10) | Đã có sẵn |

### Infrastructure (VPS, Docker Compose)
| Service | Image | Port | RAM tối thiểu |
|---------|-------|------|---------------|
| PostgreSQL + PostGIS | `postgis/postgis:16-3.4` | 5432 | 2GB |
| Martin (tile server) | `ghcr.io/maplibre/martin:v0.14` | 3001 | 256MB |
| Nominatim VN | `mediagis/nominatim:4.4` | 8080 | 4GB |
| ancu365-backend | Build local | 3000 | 512MB |
| nginx (reverse proxy + TLS) | `nginx:1.27-alpine` | 80/443 | 64MB |

**Tổng RAM estimate:** ~7GB → khuyến nghị **VPS ≥ 8GB RAM, 4 vCPU, 80GB SSD** (Hetzner CCX23 hoặc tương đương ~$30/mo).

---

## Phase Files (sẽ generate bởi planner sau Phase 3)

- `phase-01-backend-port-planning-module.md`
- `phase-02-docker-stack-and-seed.md`
- `phase-03-fastapi-planning-routes.md`
- `phase-04-flutter-data-layer-and-vector-tiles-poc.md`
- `phase-05-flutter-planning-map-screen.md`
- `phase-06-flutter-integration-house-and-post.md`
- `phase-07-admin-and-user-feedback.md`
- `phase-08-tests-qa-docs.md`
- `phase-09-vps-deploy.md`

---

## Risk Assessment (sync với phase-00 § Impact / Risk)

| Risk | Mức | Owner | Phase mitigation |
|------|-----|-------|------------------|
| Legal/IP TNMT redistribute | **CRITICAL** | PO (Duc) | Trước Phase 01: chốt ToU |
| `vector_map_tiles` không tương thích `flutter_map 7` | Cao | Mobile | Phase 04 POC đầu tiên; fallback raster |
| VPS thiếu RAM (PostGIS+Nominatim ngốn) | Cao | DevOps | Phase 09 staging test trước prod |
| Sáp nhập đơn vị HC HCMC 2025 chưa update dataset | Trung | Backend | Phase 02 verify district list |
| Switch SQLite → Postgres breaking existing data | Trung | Backend | Phase 01 dump/restore + alembic migration |
| ETL fail âm thầm | Trung | Backend | Phase 03 expose `/api/planning/health` + alert |
| App size delta > 15MB | Trung | Mobile | Phase 08 đo & report |
| Privacy Nghị định 13 (GPS log) | Cao | Backend | Phase 03 log policy + Phase 08 docs |

---

## Security Considerations

- ✅ Reuse `auth.py` của ancu365-backend (JWT HS256 + bcrypt) — đã có sẵn.
- [ ] Rate limit: `slowapi` middleware (AC-18: 30/IP/h anonymous, 200/user/h logged-in).
- [ ] CORS: hiện `allow_origins=["*"]` → production phải lock domain ancu365.
- [ ] Nominatim KHÔNG expose port 8080 ra public, chỉ FastAPI proxy.
- [ ] Admin endpoint `/api/planning/admin/*` check role `admin` qua existing `auth.py` deps.
- [ ] Disclaimer pháp lý (AC-09/16) ở 4 vị trí UI.
- [ ] GPS log retention ≤ 30 ngày, hash userId (Nghị định 13).
- [ ] Privacy policy update: add "Sử dụng vị trí cho tra cứu quy hoạch".

---

## Success Criteria (DoD)

- [ ] Tất cả 22 AC (AC-01 → AC-22) pass manual QA checklist.
- [ ] FastAPI có Swagger doc đầy đủ cho 5 endpoint mới + admin.
- [ ] Flutter unit test cho service + repository ≥ 80% coverage.
- [ ] Widget test cho `PlanningMapScreen` render được trong test env.
- [ ] KHÔNG regress: house_detail, post_house, map_screen vẫn hoạt động.
- [ ] Disclaimer pháp lý hiển thị đầy đủ 4 nơi.
- [ ] Docs:
  - `ancu365-backend/docs/planning-lookup.md` (mới) — API contract + ETL ops.
  - `ancu365-app/docs/features/planning-lookup.md` (mới) — UI flows + state diagram.
- [ ] Deploy VPS staging chạy ≥ 48h không crash, ETL daily cron pass 2 ngày liên tiếp.

---

## Next Steps

1. ⏳ **Phase 3 — Tech Lead Planning:** spawn 3 researcher song song:
   - R1: ancu365-backend deep-dive (auth deps, DB session, router pattern, alembic status)
   - R2: vector_map_tiles + flutter_map 7.0.2 compatibility test
   - R3: PostGIS + Martin + Nominatim Docker Compose best practice trên VPS Linux
   → `planner` agent tổng hợp + sinh 9 phase files chi tiết.

2. **Phase 4+:** chờ user approve plan rồi mới execute.

3. **User cần trả lời 5 câu hỏi còn lại** (legal ToU, sáp nhập HC, VPS budget cụ thể, dark mode hiện trạng, analytics) — không chặn Phase 3 plan nhưng chặn merge code.
