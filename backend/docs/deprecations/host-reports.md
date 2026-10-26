# Deprecation — `/api/host/reports/*`

**Status:** DEPRECATED
**Sunset date:** 2026-09-30 (UTC)
**Removal commit (planned):** after Flutter releases the analytics-aware build (tracking issue TBD).
**Owner:** backend team
**Client impact:** Flutter pre-update (host app < v2.x). Web admin already migrated.

## Why

Phase 04 đã port toàn bộ logic doanh thu / occupancy / ADR sang
`app/services/analytics_service.py` và expose qua `/api/host/analytics/*`.
Router `app/routers/host_report.py` chỉ còn là shim giữ JSON shape cũ
cho Flutter pre-update — không có business logic riêng.

`report_service.py` đã bị xoá ở Phase 03 nên shim hiện inline CSV streaming.

## Endpoint mapping

| Deprecated                                | Successor                                  | Notes |
|-------------------------------------------|--------------------------------------------|-------|
| `GET /api/host/reports/revenue`           | `GET /api/host/analytics/summary`          | Gap: field `breakdown` (by InvoiceLineItem.category) bị drop — empty dict. |
| `GET /api/host/reports/occupancy`         | `GET /api/host/analytics/occupancy-heatmap`| Gap: `building_id=0` (heatmap không trả). |
| `GET /api/host/reports/adr`               | `GET /api/host/analytics/summary`          | Gap: `revpar=0.0` (sẽ port ở Phase 09). |
| `GET /api/host/reports/export?type=invoices` | `GET /api/host/analytics/export`        | Phase 09 sẽ thay; CSV shape giữ nguyên. |

## Response headers (mỗi response từ shim)

```
Deprecation: true
Sunset: Wed, 30 Sep 2026 00:00:00 GMT
Link: </api/host/analytics/summary>; rel="successor-version",
      </docs/deprecations/host-reports.md>; rel="deprecation"
X-Deprecated: true
```

Per RFC 8594 (Sunset) + RFC 9745 (Deprecation). `X-Deprecated` được giữ
để backward-compat với client cũ đang sniff header này.

## Timeline

| Date        | Milestone                                                   |
|-------------|-------------------------------------------------------------|
| 2026-06-28  | Sunset header thêm vào shim (this commit).                  |
| 2026-07-15  | Flutter team confirm release date cho analytics-aware build.|
| 2026-08-15  | Flutter store rollout reaches >95% — gửi cảnh báo cuối.     |
| 2026-09-30  | **Sunset.** Router gỡ khỏi `main.py`; tất cả URL → 410 Gone.|
| 2026-10-15  | File `app/routers/host_report.py` + shim tests bị xoá.      |

## What to do as a client (Flutter / integration)

1. Subscribe response header `Sunset` — log warning nếu sắp tới hạn.
2. Migrate calls per "Endpoint mapping" table above.
3. Verify khi `Deprecation: true` xuất hiện trên môi trường staging trước.
4. Ship app update trước 2026-09-30 để tránh outage.

## Removal checklist (backend, sau sunset)

- [ ] Remove `app.include_router(host_report.router)` trong `main.py:163`.
- [ ] Xoá `app/routers/host_report.py`.
- [ ] Xoá `tests/reports/test_legacy_shim.py`.
- [ ] Xoá schemas còn dùng riêng cho shim (kiểm tra `app/schemas/report.py`).
- [ ] Optional: add 410 stub router để URL cũ trả "Gone" thay vì 404 silent.

## Tracking

- Migration plan: Phase 04 wrap-up (completed 2026-06-28).
- Slack notice: #flutter-team, #backend — TBD.
- Linear/Jira: TBD ticket cho removal sprint.
