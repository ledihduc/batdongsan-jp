# Revenue Analytics Rebuild — Plan Index

**Plan Date:** 28 Jun 2026  
**Target:** Full rebuild of host revenue reporting & analytics features  
**Status:** Research Phase Complete → Ready for BA Requirements → Tech Lead Planning

---

## Document Hierarchy

```
plans/260628-2030-revenue-analytics-rebuild/
├── README.md                                    ← You are here
├── AUDIT_SUMMARY.md                            ← Quick reference (228 lines)
├── research/
│   ├── researcher-codebase-audit.md           ← Full audit (604 lines) ★★★
│   └── architecture-data-flow.txt              ← Visual flow diagram (225 lines)
└── reports/                                    ← (Empty, for phase outputs)
```

---

## How to Use This Plan

### For Business Analysts (5 min read)
1. Start with **AUDIT_SUMMARY.md** — Quick findings table
2. Jump to section "Keep / Refactor / Delete Ratio" — Understand reusable code
3. Review "Key Gaps for Rebuild" — Critical, High, Medium priorities
4. Skip technical sections; focus on "Next Steps for BA / Tech Lead"

### For Tech Leads (20 min read)
1. Read **AUDIT_SUMMARY.md** in full
2. Skim **researcher-codebase-audit.md** sections 1–6 (models → dependencies)
3. Review section 10: "Keep/Refactor/Delete Assessment" + "Optimal Rebuild Roadmap"
4. Reference **architecture-data-flow.txt** for entity relationships
5. Create detailed phase plans based on "Rebuild Phases (5–6 weeks)" estimate

### For Developers (Implementation)
1. **Before coding:** Read sections 1–3 of **researcher-codebase-audit.md** (data models, endpoints, screens)
2. **During Phase 1:** Keep `invoice_model.dart`, `contract_model.dart` as-is; create `CurrencyFormatter` service
3. **During Phase 2:** Refactor `report_provider.dart` with caching logic
4. **During Phase 3:** Reference `architecture-data-flow.txt` for component coupling
5. **For widget work:** Check section 3 for existing widget line counts (estimate refactor effort)

---

## Key Files Discovered

### Keep (Reusable — 65%)
| File | Lines | Use As-Is? | Notes |
|------|-------|-----------|-------|
| `invoice_model.dart` | 121 | ✓ Yes | Schema correct; add CreditNoteModel if missing |
| `payment_model.dart` | 35 | ✓ Yes | Minimal, clean |
| `contract_model.dart` | 113 | ✓ Yes | Multi-tenant pivot handled well |
| `revenue_report_model.dart` | 54 | ✓ Yes | Flexible breakdown structure |
| `api_report_repository.dart` | 42 | ✓ Yes | 3 endpoints mapped correctly |
| `api_invoice_repository.dart` | 118 | ✓ Yes | 7 endpoints, comprehensive |
| `host_dashboard_tokens.dart` | 168 | ✓ Yes (light) | Add dark mode tokens later |
| `api_client.dart` | 200 | ✓ Yes | Solid HTTP abstraction |

### Refactor (Replace/Enhance — 30%)
| File | Lines | Action | Effort |
|------|-------|--------|--------|
| `report_provider.dart` | 72 | Add caching + `isFresh()` | 2 hours |
| `revenue_report_screen.dart` | 137 | Redesign with chart | 3 days |
| `revenue_breakdown_table.dart` | 95 | Add pie chart + drill-down | 2 days |
| `period_selector.dart` | 90 | Integrate date picker | 1 day |
| Category labels (hardcoded) | 8 | Move to i18n | 2 hours |

### Delete (5%)
| Item | Reason |
|------|--------|
| Placeholder mock data | If any in test fixtures |
| Unused utility functions | Code cleanup |

---

## Critical Gaps to Address

### Chart Library (Highest Priority)
- **Current state:** Only static table rendering
- **Required:** Pie chart (categories), line chart (12-month trend), bar chart (room occupancy)
- **Recommendation:** `fl_chart: ^0.68.0` (lightweight, MIT, no vendor lock-in)
- **Estimated effort:** 3–4 days per chart type

### Export Capabilities
- **Current state:** CSV only (via ApiReportRepository)
- **Required:** PDF + Excel
- **Recommendation:** 
  - PDF: `syncfusion_flutter_pdf: ^25.x` (paid, polished) OR `pdf: ^3.x` (open-source)
  - Excel: `syncfusion_flutter_xlsx: ^25.x` (paid) OR `csv: ^6.x` → Excel library
- **Estimated effort:** 2–3 days per format

### Provider Caching
- **Current state:** Every tab switch refetches data
- **Required:** Cache with freshness check (5–10 min TTL)
- **Implementation:**
  ```dart
  ReportProvider {
    DateTime? _lastFetched;
    bool isFresh([Duration ttl = const Duration(minutes: 5)]) =>
      _lastFetched != null && 
      DateTime.now().difference(_lastFetched!) < ttl;
  }
  ```
- **Estimated effort:** 2 hours

### Timezone Handling
- **Current state:** Server-side occupancy calculation; no timezone context
- **Risk:** Off-by-one day if server ≠ client timezone
- **Solution:** Add `timezone: String` field to OccupancyRow; parse with timezone awareness
- **Estimated effort:** 4 hours

---

## Rebuild Timeline (Realistic)

| Phase | Focus | Duration | Blocker? |
|-------|-------|----------|----------|
| **Phase 1** | Data layer refactoring | 0.5 week | No |
| **Phase 2** | Provider caching + tests | 1 week | No |
| **Phase 3** | UI redesign + charts | 1.5 weeks | Need fl_chart decision |
| **Phase 4** | PDF/Excel exports | 1 week | Need export lib decision |
| **Phase 5** | Testing + polish | 1 week | No |
| **TOTAL** | — | **5–6 weeks** | — |

**Assumption:** 1 mid-level Flutter developer, 1 code reviewer, design already approved (using HD tokens).

---

## Unresolved Questions for Backend Team

1. **ADR Calculation:** What's the formula for Average Daily Rate?
   - Is it `sum(invoice totals) / days_in_period`?
   - Separate endpoint or computed client-side from invoices?

2. **Debt Aging:** Is `/api/host/invoices/{id}/debt-aging` correct?
   - Looks like it should be `/api/host/debt-aging` (host-level, not per-invoice)
   - Confirm endpoint location

3. **Timezone:**
   - Server timezone for occupancy calculations?
   - Should OccupancyRow include `timezone` field?

4. **Multi-currency:**
   - Will hosts operate in non-VND currencies (KHR, THB, etc.)?
   - If yes, need `currency: String` field on Invoice + ??? models

5. **Forecast:**
   - Any 30/60/90-day revenue projection endpoint?
   - Machine learning model on backend, or client-side simple average?

---

## Code Standards Reference

For implementation teams, refer to:
- **TypeScript/React rules:** (not applicable; this is Flutter/Dart)
- **Development rules:** `$HOME/.claude/rules/development-rules.md`
  - File naming: kebab-case, descriptive
  - Keep files < 200 lines; modularize early
  - Use proper logging (no console.log equivalent in Dart)
  - Validate inputs at boundaries
- **Security rules:** `$HOME/.claude/rules/security-review-rules.md`
  - Payment flows: code review required
  - CSV export: ensure no data leakage (build query from user context)
  - File operations: sanitize paths

---

## Resource Links

### Flutter Documentation
- **fl_chart:** https://github.com/imaNNeoFighT/fl_chart
- **intl (Internationalization):** https://pub.dev/packages/intl
- **provider (State Management):** https://pub.dev/packages/provider

### Design Reference
- HD design tokens: `lib/features/host/dashboard/host_dashboard_tokens.dart`
- Existing screens: `lib/features/host/reports/screens/`

### Backend Integration
- API client: `lib/data/services/api_client.dart`
- Report endpoints: Defined in `lib/data/repositories/api_report_repository.dart`

---

## Sign-Off Checklist

- [ ] **BA:** Reviewed audit findings; confirmed scope
- [ ] **Tech Lead:** Approved phased approach; assigned developer
- [ ] **Backend:** Clarified ADR, debt-aging, timezone, multi-currency requirements
- [ ] **Designer:** Approved chart styles, export layouts (if new designs needed)
- [ ] **Developer:** Read sections 1–3 of audit; ready to begin Phase 1

---

**Last Updated:** 28 Jun 2026  
**Next Review:** After BA requirements finalized  
**Plan Stability:** 🟢 Stable (data models locked; endpoints confirmed)
