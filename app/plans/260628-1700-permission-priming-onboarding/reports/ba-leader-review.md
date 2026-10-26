# BA Leader Review — Permission Priming & Notification Opt-in

**Reviewer:** BA Leader (Senior)
**Date:** 2026-06-28
**Document reviewed:** `phase-00-ba-requirements.md`
**Final rating:** **NEEDS_REVISION** (3 CRITICAL + 6 HIGH must address before Tech Lead plans)

---

## Summary

Solid foundation: psychology section + Vietnam insights are excellent. BUT document has 3 CRITICAL gaps around **lifecycle state** (logout/relogin/role-upgrade/multi-device), **Huawei/Android-without-GMS**, and **token lifecycle vs analytics auth**. Several ACs are not testable as written (no precise threshold definitions). D2 (login-trigger) silently contradicts Section 2.2 principle #2 (JIT) — must reconcile.

---

## CRITICAL (must fix before Tech Lead plan)

### C1 — Missing personas: logout/relogin & role-upgrade lifecycle
Document never addresses:
- User logs out → logs in as **different account** on same device. Should priming re-show?
- User registered as guest, **upgrades to host** later. Guest copy was already shown. Does host see priming again with host-specific copy?
- Same user logs in on **device #2** (phone + tablet). Cooldown is per-install (local) but BE has only 1 user record.

**Required addition (new ACs):**
- **AC-N7:** Priming cooldown keyed by `(userId + installId)` in local storage, NOT by `installId` alone. On logout, do NOT clear cooldown of previous user. On new-user login, evaluate cooldown for that userId fresh (treat as new install for priming purposes).
- **AC-N8:** On **role change** (guest→host, host→admin), re-trigger priming **once** with new role copy if user previously accepted (so they see host-specific benefits). If previously denied at OS level, do NOT re-trigger OS dialog — soft re-ask banner only.
- **AC-T1 (token):** FCM token registered per-device. BE endpoint `POST /api/users/me/push-token` MUST accept `{ token, deviceId, platform }` and store as a **list per user**, not single field. On logout: call `DELETE /api/users/me/push-token` to unregister current device (else logged-out user keeps receiving push). On token refresh (FCM rotates): re-register.

**US to add:**
- **US-1.7:** Là user dùng app trên nhiều thiết bị, tôi muốn nhận notification ở thiết bị đang active, không bị "ghost" notification sau khi logout.
- **US-1.8:** Là user upgrade từ guest sang host, tôi muốn được nhắc bật notification cho event của host (booking mới) dù trước đó tôi đã bật cho guest events.

### C2 — Huawei / Android-without-Google-Play-Services not handled
**Critical Vietnam-market gap.** Huawei P40/Mate series and many low-cost Android devices in VN have **no GMS** → FCM SDK initialization will **crash or silently fail**. Document risk section misses this entirely.

**Required addition:**
- **AC-N9:** App MUST detect GMS availability at startup (`GoogleApiAvailability.isGooglePlayServicesAvailable()`). If unavailable:
  - Skip FCM init (don't crash).
  - Hide notification priming entirely (don't promise feature we can't deliver).
  - Fallback: in-app polling continues as today.
  - Log analytics event `fcm_unavailable_gms_missing` for sizing the affected user base.
- **R6 (new risk):** Estimate 3–8% of VN Android users on Huawei / non-GMS devices. Without fallback handling, FCM init crash → app won't launch. Mitigation: GMS check + graceful skip.

### C3 — D2 ("after login") contradicts Section 2.2 principle #2 (JIT)
Section 2.2 explicitly states JIT principle: "chỉ xin notification khi user cần". D2 then decides to ask **all roles right after login** — a batch/cold ask, the exact anti-pattern Section 2.2 warns against. **Pick one position and justify it.**

**Recommended resolution:** Keep D2 for guest+host (login is acceptable because login itself proves intent) BUT add explicit rationale to the doc:
- **Add to D2 consequences:** "Section 2.2 JIT principle is **relaxed for notification** because (a) notification value depends on future async events the user can't trigger himself, (b) industry data shows post-login asks outperform deep-funnel asks when copy is role-specific. JIT is **fully preserved for camera** (AC-C1) where user action creates direct context."
- This makes the trade-off explicit instead of contradictory.

---

## HIGH (should add before plan)

### H1 — "First-time login" is undefined
AC-N2 says "after login first time" but doesn't define:
- First time per install? Per user? Per (user+install)?
- Does fresh install with existing-account login count?
- What if user uninstalls and reinstalls — same user, treated as new?

**Add to AC-N2:** "First-time login = first successful auth for a `(userId, installId)` pair, persisted in secure storage key `priming_shown_v1:{userId}`. App uninstall clears all local state — treat reinstall as first-time."

### H2 — Cooldown "7/30 days" not measurably testable
QA cannot test 7-day cooldown without time-travel. **Add AC-V4:** "Debug menu (dev build only) exposes a 'time-skip' toggle that advances stored cooldown timestamps by N days. Production build excludes this menu via `kReleaseMode` guard."

### H3 — Analytics endpoint security underspecified
AC-M3 says JWT-authenticated, but:
- What if user is logged out and we have buffered events? Discard or attach anon session?
- Rate-limit on endpoint to prevent abuse?
- PII risk: `role` + `ts` + `platform` is fine, but ensure no `userAgent`/IP/deviceModel sneaks in.

**Add to AC-M3:** "Buffered events while logged out are discarded on next login (do not send retroactively). Endpoint rate-limited to 60 req/min/user. Payload whitelist enforced server-side; reject unknown fields with 400."

### H4 — iOS provisional + Vietnamese carrier APN edge case
US-1.5 + AC-N5 use `.provisional`. Known issue: provisional notifications require working APNs delivery on first attempt — on Viettel/Mobifone/Vinaphone with strict NAT, APNs can be delayed 30–60s. If priming says "you'll get a sample notification soon" and nothing arrives → trust damaged.

**Add to AC-N5:** "Priming copy on iOS does NOT promise sample notification timing. Server sends 'welcome' provisional notification within 5min of permission grant. If no APNs delivery within 24h (server can detect via APNs feedback), fall back to soft re-ask banner."

### H5 — Web user who already granted notification at browser level
AC-N6 doesn't handle `Notification.permission === 'granted'` on first visit. Showing priming is pointless and looks broken.

**Add to AC-N6:** "On web, check `Notification.permission` BEFORE rendering priming. If already `granted`, skip priming, just register FCM web token. If `denied`, show recover-path UI instead of priming."

### H6 — Admin role on web vs mobile
D4 says admin gets own priming, but Open Q #4 asked if admin uses web. **Decision missing.** If admin is web-only, mobile admin priming is dead code.

**Add D8:** "Admin uses BOTH web (primary dashboard) and mobile (on-call alerts). Mobile admin priming IS in scope."

---

## MEDIUM (nice to have)

- **M1** — AC-C1 lists 4 contexts but doc earlier says "6+ chỗ" calling image_picker. Resolve count discrepancy or explicitly list which 2 are skipped and why.
- **M2** — No spec for what happens if user kills app during priming flow (mid-state). Default: treat as defer.
- **M3** — Section 7 D7 says "secure storage hoặc SharedPreferences". Pick one; mixing creates state-sync bugs. Recommend `flutter_secure_storage` (consistent with existing onboarding flag).
- **M4** — Success metric AC-M2 (≥65% opt-in) has no measurement window. Add: "Measured over 14 days post-rollout, min 500 unique users per role."
- **M5** — No mention of `flutter_local_notifications` channel setup for Android 8+ (required for foreground display). Add to AC-N1 or impact table.

## LOW (nits)

- **L1** — Doc mixes VN and EN inline; pick a primary language for ACs (recommend EN for testability, VN for copy examples).
- **L2** — Section 8 impact table missing `lib/router/` (priming route registration).
- **L3** — D3 says iOS-only feature but consequence note repeats it — consolidate.

---

## Final Rating: **NEEDS_REVISION**

**Gate to pass:** Address all 3 CRITICAL + 6 HIGH items. Re-submit for sign-off. Estimated revision effort: 1–2 hours (mostly AC additions, no rework of structure).

## Unresolved Questions for User

1. **Multi-device push:** allow same user logged in on >1 active device simultaneously, or single-device-active model?
2. **Huawei users:** acceptable to silently hide notification feature, or show explanatory message?
3. **Provisional fallback:** if VN APNs delivery fails, willing to escalate to soft re-ask, or accept silent fail?
