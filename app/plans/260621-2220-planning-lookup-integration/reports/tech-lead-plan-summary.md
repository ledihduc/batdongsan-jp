# Tech Lead Plan Summary — Planning Lookup Integration

**Plan dir:** `plans/260621-2220-planning-lookup-integration/`
**Status:** Phase 3 complete — 9 phase files generated, ready for user approval.
**Total estimate:** ~12.5 ngày dev (1 fullstack) + 48h staging soak.

---

## Critical Path

```
P01 (Backend port + Postgres) ──▶ P02 (Docker stack + seed) ──▶ P03 (FastAPI routes)
                                                                       │
P04 (Flutter data + POC) ──────────────────────────────────────────────┘
        │
        ▼ (POC Go/No-Go gate)
P05 (Planning map screen) ──▶ P06 (House detail + post house) ──┐
        │                                                       │
        └───▶ P07 (Admin + report form) ────────────────────────┤
                                                                ▼
                                                  P08 (Tests + QA 22 AC + docs)
                                                                │
                                                                ▼
                                                  P09 (VPS deploy + 48h soak)
```

**Hard blockers:**
- P01 → P02 → P03 (sequential, backend foundation)
- P04 POC → P05 (Go/No-Go gate; nếu fail, fallback raster +2-3 ngày)
- P05 → P06, P07 (UI components reuse)
- P08 → P09 (no deploy without test pass)

---

## Parallel Execution Opportunities

| Cặp song song | Lý do |
|--------------|-------|
| **P03 + P04 (after P02)** | Backend routes vs Flutter data layer độc lập (P04 mock API trước, integrate sau khi P03 done) |
| **P06 + P07** | House detail badge + admin screen độc lập file ownership |
| **Backend tests + Frontend tests trong P08** | 2 codebase riêng biệt |

**KHÔNG song song được:**
- P01 + bất kỳ phase nào (block foundation)
- P05 + P04 (P05 cần POC verify trước)
- P08 + P09 (deploy phải sau test)

---

## Top 5 Risks Cần User Attention

| # | Risk | Phase | Mức | Cần user làm gì |
|---|------|-------|-----|----------------|
| 1 | **Legal/IP — TNMT cấm redistribute** | trước P01 | **CRITICAL** | Đọc ToU WFS TP.HCM TRƯỚC commit. Nếu cấm → đàm phán license hoặc dừng dự án. |
| 2 | **Sáp nhập đơn vị HC HCMC 2025** | P02 | Trung | Confirm dataset planning đã update chưa; mapping quận cũ→mới? Block full 24-quận seed. |
| 3 | **VPS RAM 8GB không đủ Nominatim** | P02, P09 | Cao | Confirm budget: VPSServer VN 16GB ($40/mo) vs Hetzner Singapore 16GB ($22/mo) — latency tradeoff. |
| 4 | **vector_map_tiles POC fail** | P04 | Cao | Nếu POC fail, accept fallback raster +2-3 ngày timeline. |
| 5 | **Privacy Nghị định 13/2023** | P03 + P09 | Cao | Confirm GPS log retention policy (≤30 ngày); privacy policy ancu365 cần update? |

---

## 5 Câu Hỏi Cần User Trả Lời Trước Khi Start P01

1. **Legal:** ToU của TNMT TP.HCM có cấm redistribute dữ liệu WFS trong app thương mại không? (Block toàn bộ dự án nếu cấm.)
2. **Sáp nhập HC 2025:** Dataset planning có cập nhật cho sáp nhập đơn vị hành chính HCMC 2025 chưa? Có file mapping quận cũ → mới không?
3. **VPS budget:** Quyết định $30/mo (Hetzner Singapore, +40ms latency) hay $40/mo (VPSServer VN, <10ms)?
4. **Dark mode ancu365:** App hiện đã có dark mode chưa? Nếu chưa → AC-11 đẩy Phase 2.
5. **Analytics platform:** Team đang dùng Firebase / Mixpanel / nothing? (Block clean up `PlanningAnalytics` stub trong P06.)

---

## File Ownership Map (Tránh Conflict)

| Phase | Owns (exclusive write) |
|-------|------------------------|
| P01 | `ancu365-backend/app/models/`, `services/planning_etl/`, `database.py`, `auth.py`, `main.py`, alembic |
| P02 | `ancu365-backend/docker-compose.yml`, `infra/`, `.env.example`, `Makefile` |
| P03 | `ancu365-backend/app/routers/planning.py`, `schemas/`, `middleware/` |
| P04 | `ancu365-app/lib/data/models/planning_*`, `data/services/planning_service.dart`, `core/config/env.dart` |
| P05 | `ancu365-app/lib/features/planning/` (all) |
| P06 | Modifies `house_detail_screen.dart`, `post_house_screen.dart` (need P05 stable) |
| P07 | `ancu365-app/lib/features/admin/planning/`, `features/planning/report/` |
| P08 | `ancu365-backend/tests/`, `ancu365-app/test/`, `integration_test/`, both `docs/` |
| P09 | VPS files (`/opt/ancu365/`), Caddyfile, `docker-compose.prod.yml`, `docs/deploy-runbook.md` |

**Overlap warning:** P05 + P06 đều chạm `planning_map_screen.dart` (P05 owns, P06 modify). → P06 phải start AFTER P05 done.

---

## Estimate Breakdown

| Phase | Estimate | Cumulative |
|-------|----------|------------|
| P01 | 2.0 ngày | 2.0 |
| P02 | 1.0 ngày | 3.0 |
| P03 | 1.5 ngày | 4.5 |
| P04 | 1.5 ngày | 6.0 |
| P05 | 2.0 ngày | 8.0 |
| P06 | 1.0 ngày | 9.0 |
| P07 | 1.0 ngày | 10.0 |
| P08 | 1.5 ngày | 11.5 |
| P09 | 1.0 ngày | 12.5 + 48h soak |

**Caveat:** estimate giả định 1 fullstack solo. Nếu parallel P03+P04 → tiết kiệm ~1 ngày (xuống ~11.5).

---

## Unresolved Questions

1. **Firebase Analytics có sẵn không?** — Block P06 analytics stub cleanup.
2. **Risky zone codes** chính xác là set nào? (Hiện hardcode `{DGT, CXP, DCC, DXH}` — cần TNMT confirm.)
3. **CI/CD pipeline** ancu365 hiện có không? (Defer Github Actions trong P08 nếu chưa có.)
4. **Staging VPS** dùng VPS riêng hay subdomain trên prod VPS? (Khuyến nghị riêng để soak test thật.)
