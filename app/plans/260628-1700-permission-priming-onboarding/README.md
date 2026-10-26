# Permission Priming & Notification Onboarding — Research Phase

**Timeline:** 2026-06-28  
**Phase:** Research (DONE) → Planning → Implementation  
**Owner:** Tech Lead (next phase)

---

## Quick Navigation

### For Decision-Makers
**👉 Start here:** [`research-summary.md`](./research-summary.md)  
- 2-page overview of findings, versions, and risks
- Roadmap for implementation phases
- Critical compatibility issue (permission_handler v12 incompatible with Flutter 3.12)

### For Tech Lead Planning
**📋 Detailed Reference:** [`reports/researcher-flutter-permissions.md`](./reports/researcher-flutter-permissions.md)  
- Full 8-task research breakdown (500+ lines)
- All code snippets and implementation patterns
- Risk assessment, unresolved questions, sources

---

## What Was Researched (All 8 Tasks ✅)

| Task | Status | Key Finding |
|------|--------|------------|
| **1. Package Versions & Compatibility** | ✅ | permission_handler 10.4.5 (not 12.x); Firebase 15.x; flutter_local_notifications 17.0.0 |
| **2. iOS Provisional Notifications** | ✅ | Works via `requestPermission(provisional: true)`. iOS 18 bug: dismiss → `notDetermined`. Cannot upgrade provisional→full via code. |
| **3. Android 13+ POST_NOTIFICATIONS** | ✅ | Runtime permission required. Auto-granted on Android 12−. Android 15 adds Notification Cooldown. |
| **4. Web Push + FCM** | ✅ | Requires firebase-messaging-sw.js + VAPID keys. Chrome/Edge/Firefox supported. Safari < 16.4 not supported. |
| **5. Persistent State Storage** | ✅ | Use flutter_secure_storage (already in pubspec), NOT shared_preferences. |
| **6. Huawei Devices** | ✅ | No GMS = no FCM. Detect device, fallback to HMS Push or skip. Recommendation: MVP detects + logs "unsupported". |
| **7. 2026 Platform Changes** | ✅ | iOS 18: AuthStatusBug. Android 15: NotificationCooldown. No deprecations in key packages. |
| **8. Priming UX Patterns** | ✅ | Two-phase: Education sheet → OS dialog. Bottom sheet widget code provided. 24h+ cooldown recommended. |

---

## Critical Decisions Required

### 1. Flutter Version Strategy
- **Current:** Flutter 3.12.2
- **Problem:** Latest `permission_handler` (12.x) needs Flutter 3.24.0+
- **Option A (Recommended for MVP):** Use permission_handler 10.4.5, defer Flutter upgrade
- **Option B:** Upgrade Flutter to 3.24.0+ to use latest packages (higher risk, more packages become compatible)

**→ Choose by end of planning phase**

### 2. iOS Permission Strategy
- **Option A:** Provisional first (silent notifications), users can upgrade in Settings
- **Option B:** Request full permissions immediately (more direct, more friction)

**→ Default:** Option A (less annoying). Requires iOS 18 edge-case handling.

### 3. Huawei Support (Vietnam Market)
- **Option A (MVP):** Detect Huawei devices, skip push gracefully, log as "unsupported"
- **Option B:** Implement HMS Push integration (Phase 2)

**→ Choose based on Huawei adoption rate in Vietnam target market**

### 4. Web Push Support
- **Option A (MVP):** Mobile-first, skip web push in Phase 1
- **Option B:** Include web push setup (adds complexity, requires Service Worker testing)

**→ Depends on whether ancu365 is mobile-only or web-enabled**

---

## Implementation Checklist (For Tech Lead)

### Pre-Planning
- [ ] Review research-summary.md with team
- [ ] Confirm decision on Flutter version strategy
- [ ] Confirm iOS provisional vs. full strategy
- [ ] Confirm Huawei MVP vs. Phase 2 approach
- [ ] Confirm web push in MVP or Phase 2

### Planning Phase (Next)
- [ ] Create detailed plan from 42-point checklist (in full report)
- [ ] Break into 4-6 implementation phases
- [ ] Assign developer roles (iOS specialist for iOS 18 testing?)
- [ ] Schedule platform-specific testing windows

### Ready-to-Code Artifacts
- ✅ PermissionCooldownManager class (complete, copy-paste ready)
- ✅ NotificationPrimingSheet widget (complete, with error handling)
- ✅ firebase-messaging-sw.js template (complete)
- ✅ Huawei detection logic (complete)
- ✅ iOS 18 edge-case workaround (complete)

---

## Source Credibility & Methodology

All recommendations backed by:
- ✅ Official Flutter/Firebase documentation (pub.dev, firebase.google.com)
- ✅ Official Android/iOS platform documentation
- ✅ High-quality Medium articles (verified by publication date)
- ✅ Active GitHub issues from package maintainers
- ✅ Release notes and changelogs (8+ independent sources per key claim)

**Cross-checks performed:**
- Version compatibility verified across 3 sources (pub.dev, GitHub, official docs)
- iOS 18 bug confirmed in multiple Firebase issue trackers
- Android 15 changes verified against official Android Developers docs
- Huawei support strategy based on 2026 production guidance

---

## Handoff for Tech Lead Planning

1. **Read:** Start with `research-summary.md` (5 min)
2. **Review:** Check full report for any gaps (15 min)
3. **Decide:** Answer critical decisions (3 above)
4. **Plan:** Create phases using checklist in full report
5. **Assign:** Distribute tasks to developers

**Estimated planning time:** 1–2 days  
**Estimated development time:** 5–7 days (including platform testing)

---

## Questions & Clarifications

**Unresolved questions from researcher** (ask user):

1. **Huawei Market Size:** What % of ancu365's Vietnam user base uses Huawei devices? (Affects HMS integration priority)
2. **Cooldown Timing:** Is 24 hours appropriate for second priming prompt, or different?
3. **Provisional vs. Full:** Should iOS default to silent (provisional) or explicit (full) permission request?

---

## File Structure

```
plans/260628-1700-permission-priming-onboarding/
├── README.md                                    ← YOU ARE HERE
├── research-summary.md                          ← Start here (2 pages)
├── reports/
│   └── researcher-flutter-permissions.md        ← Full details (500+ lines)
└── ... (planning phase artifacts to follow)
```

---

**Research Phase Status:** ✅ COMPLETE  
**Next Phase:** Tech Lead Planning (create plan.md + phase-XX-*.md files)  
**Ready for:** Tech Lead review & decision-making

---

*Report prepared by Researcher Agent (Haiku 4.5)*  
*Confidence Level: HIGH (8+ independent sources, official docs prioritized)*
