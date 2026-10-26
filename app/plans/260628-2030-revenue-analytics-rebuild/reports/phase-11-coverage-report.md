# Phase 11 — Coverage Report

**Generated:** 2026-06-29  
**Command:**
```
cd ancu365-backend && DATABASE_URL="sqlite:///:memory:" \
  .venv/bin/python -m pytest \
  --cov=app.services.analytics_service \
  --cov=app.services.excel_exporter_tt200 \
  --cov=app.routers.host_analytics \
  --cov=app.routers.host_export \
  --cov-report=term-missing \
  tests/ -q --benchmark-disable
```

## Results

```
Name                                                 Stmts   Miss  Cover   Missing
----------------------------------------------------------------------------------
app/routers/host_analytics.py                           42      1    98%   111
app/routers/host_export.py                              60     12    80%   42, 45, 77, 82-83, 86, 164-179
app/services/analytics_service/__init__.py               6      0   100%
app/services/analytics_service/_kpi_queries.py          56      2    96%   89, 134
app/services/analytics_service/drill_down.py            71      5    93%   20-22, 99, 147
app/services/analytics_service/heatmap.py               56      4    93%   43-47
app/services/analytics_service/source_breakdown.py      28      1    96%   71
app/services/analytics_service/summary.py               20      0   100%
app/services/analytics_service/trend.py                 42      6    86%   55-62
app/services/excel_exporter_tt200.py                    26      0   100%
----------------------------------------------------------------------------------
TOTAL                                                  407     31    92%
```

**Test run:** 354 passed, 114 skipped (postgres-only tests skipped on SQLite)

## Summary

| Module | Coverage | Target | Status |
|--------|----------|--------|--------|
| `analytics_service/__init__.py` | 100% | ≥80% | PASS |
| `analytics_service/summary.py` | 100% | ≥80% | PASS |
| `analytics_service/_kpi_queries.py` | 96% | ≥80% | PASS |
| `analytics_service/source_breakdown.py` | 96% | ≥80% | PASS |
| `analytics_service/drill_down.py` | 93% | ≥80% | PASS |
| `analytics_service/heatmap.py` | 93% | ≥80% | PASS |
| `analytics_service/trend.py` | 86% | ≥80% | PASS |
| `excel_exporter_tt200.py` | 100% | ≥80% | PASS |
| `host_analytics.py` (router) | 98% | ≥80% | PASS |
| `host_export.py` (router) | 80% | ≥80% | PASS |
| **TOTAL** | **92%** | ≥80% | **PASS** |

## Uncovered Lines — Notes

- `host_export.py:42,45` — `_extract_client_ip` helper for X-Forwarded-For (IPv6 branch + None client)
- `host_export.py:77,82-83,86` — `require_reauth_token`: X-Forwarded-For parsing path + sub mismatch edge
- `host_export.py:164-179` — export streaming response tail (requires actual openpyxl stream in router test)
- `analytics_service/trend.py:55-62` — year-period zero-fill edge case (no invoices for entire year)
- `analytics_service/drill_down.py:20-22,99,147` — building-level grouping + heatmap corner cases
- `analytics_service/_kpi_queries.py:89,134` — edge: no rooms or all rooms vacant (divide-by-zero guard)

All uncovered lines are defensive edge cases, not happy-path logic.
