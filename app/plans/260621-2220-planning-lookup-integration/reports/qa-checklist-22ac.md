# QA Checklist — 22 Acceptance Criteria

> Planning Lookup Module — Manual QA Sign-Off Sheet
> Created: Phase 08 (P08)
> Prerequisite: Backend passes all unit tests (P08) + deployed to staging (P09)

---

## Test Environment

| Field | Value |
|-------|-------|
| Tested device (Android) | ___________ (e.g. Samsung Galaxy A54) |
| Tested device (iOS) | ___________ (e.g. iPhone 13 simulator) |
| Network | ___________ (MUST use 4G LTE for AC-02/03/22) |
| Backend URL | ___________ (staging URL from P09) |
| App build | ___________ (Flutter build number) |
| Tester | ___________ |
| Date | ___________ |
| Flutter version | ___________ |

---

## Acceptance Criteria Checklist

| AC | Description | Pass/Fail | Device | Notes |
|----|-------------|-----------|--------|-------|
| AC-01 | Cold start < 3s (from tap icon to map visible) | [ ] | Android / iOS | _____ ms measured |
| AC-02 | Parcel tap p95 < 1.5s on 4G LTE real device (median of 20 taps, different parcels) | [ ] | Android only | _____ ms p95 |
| AC-03 | Address search p95 < 2.5s on 4G LTE | [ ] | Android / iOS | _____ ms p95 |
| AC-04 | 100% house badges show correct zone_code for 10 tested houses | [ ] | Android / iOS | ___/10 correct |
| AC-05 | Layer toggle + opacity slider works smoothly (≥ 30fps during interaction) | [ ] | Android / iOS | _____ fps |
| AC-06 | Tap outside HCMC bbox shows toast "Tạm thời chỉ hỗ trợ TP.HCM" + back button | [ ] | Android / iOS | |
| AC-07 | After 3 consecutive parcel lookup failures, shows final message instead of infinite retry | [ ] | Android / iOS | |
| AC-08 | Skeleton/loading indicator appears within 200ms of parcel tap | [ ] | Android / iOS | |
| AC-09 | Legal disclaimer visible in ALL 4 locations: bottom sheet, footer, warning modal, badge link | [ ] | Android / iOS | Locations: _____ |
| AC-10 | UI fully functional in Vietnamese (primary) and English (secondary language) | [ ] | Android / iOS | |
| AC-11 | Zone colors in dark mode have 10% reduced opacity vs light mode | [ ] | Android / iOS | |
| AC-12 | TalkBack/VoiceOver accessible; all tap targets ≥ 48×48dp | [ ] | Android / iOS | |
| AC-13 | Location permission denied → address search still works; map defaults to HCMC center | [ ] | Android / iOS | |
| AC-14 | Tile cache ≤ 100MB; "Clear cache" button in Settings works | [ ] | Android / iOS | _____ MB used |
| AC-15 | Parcels with `fetched_at` > 30 days show freshness warning in detail sheet | [ ] | Android / iOS | |
| AC-16 | Disclaimer "Thông tin quy hoạch chỉ mang tính tham khảo" present on all planning UI | [ ] | Android / iOS | (duplicate check of AC-09) |
| AC-17 | Rapid tap 2 different parcels in < 500ms does NOT cause race condition (second result always shown) | [ ] | Android / iOS | |
| AC-18 | Anonymous user: 31st search request in 1 hour returns 429 error (tested via backend logs) | [ ] | Backend API | Verify in Nginx/API logs |
| AC-19 | Non-admin user: GET /api/planning/admin/risky-listings returns 403 | [ ] | Backend API | `curl` test |
| AC-20 | App size delta for Planning module ≤ +15MB (compare AAB before/after planning feature) | [ ] | Build | Before: ___ MB / After: ___ MB / Delta: ___ MB |
| AC-21 | Peak memory during map browsing (5 min session) < 350MB | [ ] | Android | Android Profiler: ___ MB peak |
| AC-22 | 5-minute active map browsing < 5% battery drain | [ ] | Android (Galaxy A54, fresh charge) | Battery: ___% used in 5min |

---

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| QA Tester | | | |
| Tech Lead | | | |
| Product Owner | | | |

---

## Notes & Deviations

List any AC that failed and the agreed remediation:

| AC | Issue | Remediation | Owner | Due |
|----|-------|-------------|-------|-----|
| | | | | |

---

## Reference

- Backend tests: `ancu365-backend/tests/` (65 passed, 4 skipped — Phase 08)
- Backend coverage: 90% (planning module)
- Staging deploy: Phase 09 (`ancu365-app/plans/260621-2220-planning-lookup-integration/phase-09-vps-deploy.md`)
- Backend docs: `ancu365-backend/docs/planning-lookup.md`
