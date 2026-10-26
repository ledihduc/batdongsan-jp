# Role Layout Audit & UI/UX Improvement

**Date:** 2026-07-02
**Status:** ALL PHASES COMPLETE (00–08). Ready for commit + push.
**Revision history:** v1 (initial draft) → v2 (post Tech Lead review) → v3 (decisions locked) → **v4 (all phases shipped)**

## Decisions locked (user approved 2026-07-02)

| # | Question | **Decision** | Impact |
|---|---|---|---|
| 1 | Operator model | **A — delegation scope** (không đổi backend) | Phase 03 spec dùng Option A path |
| 2 | Tenant model | **Email deep-link + JWT** — backend làm U2 song song | Phase 04 TenantShell defer đến khi U2 ready |
| 3 | Admin persona toggle | **Disable hoàn toàn** — impersonation mode phase sau nếu cần | Phase 04 admin không thấy toggle |
| 4 | Scope | **P0 only (Phase 00+01+02+03, ~5 ngày) → review** | P1+P2+P3 defer đến sau P0 review |
| 5 | Cache invalidation | **Compromise: hard clear on actual role change, skip persona toggle** | Phase 02 step 5b: 14 provider reset() gọi khi logout/auto-upgrade/actor change, KHÔNG gọi khi persona toggle |
| 6 | Notification wrong role | **B — Defer + inline banner** "Bạn có N thông báo cho role X" | Phase 04 notification_router.dart implement pending queue |
| 7 | Feature flag | **`--dart-define=ROLE_SHELLS_V2_ENABLED`** build-time | Phase 04 dùng FeatureFlags class simple, không add Remote Config |
| 8 | Analytics | **Stub interface noop** — `AnalyticsService.instance.logEvent()` | Phase 04 code sẵn interface, future swap implementation |
| 9 | Testing budget | **Selective critical (+1 ngày)** — unit test cho RoleGuard, DisplayedRoleProvider, route_guards | Phase 01/02/03 add Testing subsection, Phase 04 skip widget test |
| 10 | Multi-role user | **Assume YES, role switcher conditional** — chỉ show khi > 1 displayed role | Phase 04 role_switcher.dart implement với conditional render |
| 11 | Phase 04 rollout | **Progressive: Admin → Operator → defer Tenant** | Phase 04 chia thành 3 shell shipping riêng, không all-or-nothing |

## Context

App có 5 role: `guest`, `host`, `admin`, `operator`, `tenant`. Nhưng auth model chỉ recognize 3 (`guest|host|admin`); operator và tenant là **permission scope** (delegation) và **contract role** (email deep-link) — không phải user role thực.

Cùng lúc có 3 chiều song song:
1. **Auth role** — persistent, gate route
2. **UI persona** — toggle `guest|host` trong GuestShell, không gate route
3. **Actor delegation context** — request-scoped header

Layout leak = hệ quả trực tiếp của việc: (a) 3 chiều chưa được document/tách rõ, (b) mọi role hiện đều fallback vào GuestShell, (c) role guard bị thiếu ở nhiều nơi.

## Reports (nguồn insight)

**Research reports (v1 audit):**
- `reports/researcher-01-guest-audit.md` — CRITICAL: `post_house_screen`, `my_listings_screen` nằm trong `guest/` nhưng là host feature
- `reports/researcher-02-host-audit.md` — CRITICAL: destructive actions không có role guard; 5 file > 500 dòng
- `reports/researcher-03-admin-operator-tenant-audit.md` — Operator không có shell/logout; tenant không có auth model
- `reports/researcher-04-router-shell-audit.md` — Router matrix: 9/24 route thiếu guard; ActorContext không clear khi logout
- `reports/researcher-05-design-system-ux-audit.md` — 23 hardcoded colors, 11 bare AppBar, terminology inconsistent

**Tech Lead review reports (v2 gap analysis):**
- `reports/tech-lead-review-01-holistic.md` — 4 CRITICAL + 6 HIGH gaps in v1 plan
- `reports/tech-lead-review-02-state-lifecycle.md` — 14/17 provider không clear on logout; FCM topic leak; offline cache leak
- `reports/tech-lead-review-03-backend-contract.md` — 5 verified, 4 unverified assumption; U2 tenant JWT là BLOCKER cho Phase 02 tenant guard
- `reports/tech-lead-review-04-references-verified.md` — 34/38 line ref pass; 1 INACCURATE (building_detail_screen không có delete UI); 1 NOT_FOUND (`ds_empty_state.dart` — thực tế `empty_state.dart`)

## Phases (revised — 10 phases; **P0 only trong đợt này ~5 ngày**, còn lại defer đến review)

| # | Phase | Priority | Effort | Depends on |
|---|---|---|---|---|
| **00** ✅ DONE | **Pre-flight scout + assumption verification** | **P0 gate** | **0.5 ngày** | **— (blocks 01)** |
| 01 ✅ DONE | Critical role-leak fixes + widget state lifecycle | P0 | 1.5 ngày | 00 |
| 02 ✅ DONE | Router guard sweep + provider cache + FCM lifecycle + delegation revocation + bootstrap ordering | P0 | 2 ngày | 01, 03 spec |
| 03 ✅ DONE | Role model architecture (Option A locked) — spec + impl | P0 design | 0.5 ngày spec + 1 ngày impl | — (spec blocks 02) |
| 04 ✅ MVP | Role-specific shells + role-aware Profile + notification routing (progressive: Admin ✅, Operator behind flag, Tenant defer U2) | P1 | 3–4 ngày | 03 |
| 05a ✅ PARTIAL | Design tokens expanded + DsSnackBar/DsErrorState/DsLoadingOverlay scaffolded + 23/30 AppBar → DsAppBar (7 skipped with TODO for TabBar/widget-title cases). ~13 additional bare AppBar files discovered outside original 30 remain untouched. Hardcoded color audit deferred. | P1 | 1.5 ngày | — |
| 05b ✅ | Loading/error/empty state pattern sweep — 10 host feature list screens migrated to 3-state pattern (DsRowSkeleton / DsErrorState / DsEmptyState); reviewer APPROVED with only LOW/INFO findings | P1 | 1.5 ngày | 05a |
| 06 ✅ | Vietnamese microcopy glossary — glossary doc + `VnTerms` published; 35 huỷ→hủy substitutions across 22 files; 0 chủ trọ; đặt lịch confirmed viewing-only | P2 | 1 ngày | — |
| 07 ✅ | Modularize 5 files > 500 dòng — split into 13 sibling files; contract_form kept at 377 (justified); reviewer APPROVED after fixing 3 unnecessary imports | P2 | 1.5 ngày | 05a |
| 08 ✅ | Accessibility + polish — 20 IconButton tooltips (VN) across 14 screen/widget files; 7 CachedNetworkImage Semantics wrappers; DsAppBar back-button tooltip + DsBottomNav strut/indicator from 05a preserved | P3 | 1 ngày | 05a |

**Legend:** ✅ = P0 in scope this cycle | ⏸ = Deferred until P0 review complete

**Total estimate P0 (current scope):** ~5 ngày dev (1 người) — Phase 00 (0.5d) + Phase 01 (1.5d) + Phase 02 (2d) + Phase 03 (1.5d spec+impl).

**Total estimate full plan:** ~14 ngày dev (Phase 04–08 defer đến sau P0 review).

## Rollout gates

Between phases, các gate sau MUST pass trước khi tiến:

1. **Gate 00→01:** Scout report attached, tất cả line ref verified, backend contract cho auto-upgrade JWT confirm
2. **Gate 02→04:** Phase 03 impl xong (`DisplayedRoleProvider` unit test 5×N permutation pass), `role-model.md` product review approved
3. **Gate 04→ship:** Feature flag `role_shells_v2_enabled` implement; shell code có cả code path A (giữ GuestShell fallback) + B (new shell) để rollback nhanh nếu prod issue
4. **Gate 05a→07:** DsAppBar retrofit xong trước khi Phase 07 split screen files (tránh double edit)

## Key decisions — LOCKED ✅

Xem bảng "Decisions locked" ở đầu file. Tất cả 11 câu đã có phương án user approve 2026-07-02.

**Blocked dependencies:**
- **U2 (backend tenant JWT):** Phase 04 TenantShell defer đến khi backend team ready. Frontend gate qua feature flag riêng `tenant_shell_enabled = false`.
- **U3 (backend role enum):** Option A chọn → U3 không apply.
- **U4 (backend approval self-check):** Frontend disable admin toggle mitigate. Backend team should also add server-side check separately (not blocking Phase 04).

## Success criteria

- Không role/persona nào thấy được screen của role khác trên nav/profile mặc định
- Deep-link đến route sai role → redirect graceful (không màn trắng, không lỗi)
- Mỗi role có: shell phù hợp, profile section riêng, logout rõ ràng
- Destructive actions luôn có role check (`build` + `provider` layer)
- **Logout clears TẤT CẢ user-scoped provider state (17/17), không leak sang login user tiếp** (mới v2)
- **FCM topic subscription cleared trên logout, resubscribed đúng role trên login** (mới v2)
- **Deep-link cold-start hoạt động chính xác (không redirect loop, không flash sai shell)** (mới v2)
- Design system: 0 hardcoded color trong feature code, 100% DsAppBar, 1 loading pattern, 1 error pattern
- Vietnamese microcopy tuân glossary
- **Automated tests: RoleGuard, guard functions, DisplayedRoleProvider unit test pass với coverage > 80%** (mới v2 — nếu chọn testing budget câu 9)

## Non-goals (revised — chính xác hơn)

- Không thay đổi business logic booking/contract/payment
- Không refactor backend **trừ khi:** (a) Phase 03 Option B được chọn (backend role enum), hoặc (b) tenant JWT model cần bổ sung (câu hỏi 2)
- Không đổi navigation library (giữ GoRouter)
- Không rework theme/design tokens core — chỉ mở rộng semantic tokens
- Không refactor `ActorContextProvider` internals — Phase 02 CHỈ add `clear()` call từ AuthProvider
- Không rewrite provider architecture — Phase 02 CHỈ add `reset()` method vào provider hiện có
- Không tạo dark mode variants (chỉ note token phải dark-ready cho future)
- Không tạo i18n framework (giữ Vietnamese-only)

## Estimated effort recap

- v1 (initial): 11–12 ngày, 8 phase
- v2 (this): 14 ngày, 9 phase (thêm Phase 00 + tăng Phase 02 + Phase 04 + tách Phase 05)
- Trade-off: +2 ngày để mitigate 4 CRITICAL blocker + tăng test coverage + rollout safety
