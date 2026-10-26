---
title: "Permission Priming & Notification Opt-in"
description: "JIT priming sheets + FCM push (iOS/Android/Web) with role-aware copy, cooldown, Huawei fallback"
status: pending
priority: P1
effort: 38h
branch: main
tags: [permissions, notifications, fcm, ux, vietnamese]
created: 2026-06-28
---

# Plan: Permission Priming & Notification Opt-in

**BA doc:** `phase-00-ba-requirements.md` (Section 10 = final ACs after BA Leader review)
**Research:** `reports/researcher-flutter-permissions.md`, `reports/researcher-priming-ux-copy.md`
**Tech Lead:** Main Claude | **Date:** 2026-06-28

## Goal

Add **priming sheets** before all permission asks (camera × 6 sites, push notification × all roles) + **FCM push** for iOS/Android/Web with Huawei graceful fallback. Target opt-in ≥65% notif / ≥85% camera (14-day window).

## Architecture

```
                       ┌──────────────────────────────────────┐
                       │  lib/core/permissions/  (NEW MODULE) │
                       │                                       │
                       │  permission_types.dart  (enums)      │
                       │  permission_storage.dart (cooldown)  │
                       │  permission_service.dart (FCM+OS)    │
                       │  permission_events.dart  (analytics) │
                       └──────────────────────────────────────┘
                                  ▲          ▲
                                  │          │
              ┌───────────────────┘          └───────────────────┐
              │                                                   │
   ┌──────────┴──────────────┐                  ┌─────────────────┴────┐
   │ lib/features/permissions │                  │ Integration sites    │
   │  widgets/                │                  │ • main.dart (Firebase│
   │  ├ notification_priming  │                  │   + GMS detect)      │
   │  ├ camera_priming        │                  │ • app_router (login) │
   │  ├ soft_reask_banner     │                  │ • 6× image_picker    │
   │  └ permission_settings   │                  │ • notification_prov  │
   └──────────────────────────┘                  └──────────────────────┘
                                                          │
                                                  ┌───────┴────────┐
                                                  │  Backend (BE)  │
                                                  │  POST  push-tok│
                                                  │  DELETE push-tk│
                                                  │  POST  events  │
                                                  └────────────────┘
```

## Phases

| # | Phase | File | Status | Effort | Depends |
|---|-------|------|--------|--------|---------|
| 1 | Setup & Config | `phase-01-setup-and-config.md` | pending | 4h | — |
| 2 | Core Permission Module | `phase-02-core-permission-module.md` | pending | 6h | 1 |
| 3 | Priming UI Widgets | `phase-03-priming-ui-widgets.md` | pending | 6h | 1 |
| 4 | Integration | `phase-04-integration.md` | pending | 8h | 2, 3 |
| 5 | Platform Specifics | `phase-05-platform-specifics.md` | pending | 4h | 4 |
| 6 | Analytics & BE Contract | `phase-06-analytics-and-be-contract.md` | pending | 4h | 2 |
| 7 | Testing | `phase-07-testing.md` | pending | 6h | 4, 5, 6 |

**Parallelism:** Phase 1 sequential first. Then (2 ∥ 3) → 4 → (5 ∥ 6) → 7.

## Key Dependencies (external)

- Firebase project (Console) with iOS/Android/Web apps registered.
- `google-services.json`, `GoogleService-Info.plist`, Web VAPID key — provided by ops.
- BE endpoints (separate ticket): `POST/DELETE /api/users/me/push-token`, `POST /api/analytics/permission-events`.

## AC Coverage Map (Section 10 totals)

- **Notification (11):** AC-N1–N9 + AC-T1 → phases 2, 3, 4, 5
- **Camera (3):** AC-C1–C3 → phases 3, 4
- **UX/Visual (4):** AC-V1–V4 → phases 3, 4, 7
- **Quantitative (3):** AC-M1–M3 → phase 6
- **Token (1):** AC-T1 → phases 2, 4

## Critical Risks (carry from BA Leader review)

| ID | Risk | Phase mitigated |
|----|------|------------------|
| R1 | iOS one-shot perm decisions | 7 (TestFlight + reset script AC-V4) |
| R6 | Huawei/non-GMS crash | 5 (AC-N9 GMS detect) |
| C1 | Lifecycle (logout/relogin/role) | 2 (per-user key AC-N7/N8) |
| C3 | JIT preserved for camera | 3, 4 (sheet only at image_picker site) |

## Success Criteria

1. All 22 ACs in Section 10 pass on iOS 16/17/18 + Android 12/13/14/15 + Chrome/Firefox/Safari 16.4+.
2. Huawei device launches without crash, no notif promised, polling intact.
3. Debug "time-skip" menu works (`kDebugMode` guard).
4. `docs/features/permission-priming.md` ships with copy + flow.

## Open Questions (Gate 3)

User to confirm D8 (multi-device), D9 (Huawei silent), D10 (24h APNs fallback), D11 (mobile admin in scope).
