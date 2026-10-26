# Plan Reference Verification Report

## Summary
Verified 38/38 claims across all phases. **1 critical inaccuracy**, **1 not found**, **2 minor discrepancies**.

## Per-Phase Verification Results

### Phase 01: Critical Role-Leak Fixes
| # | Claim | Status | Actual |
|---|-------|--------|--------|
| 1 | `lib/features/guest/post/post_house_screen.dart` exists | VERIFIED | ✓ File exists |
| 2 | `lib/features/guest/profile/my_listings_screen.dart` exists | VERIFIED | ✓ File exists |
| 3 | `host_home_screen.dart:590-625` contains `_confirmDelete()` | VERIFIED | Lines 590–625 confirmed |
| 4 | `building_detail_screen.dart` has delete button | NOT_FOUND | No delete UI found in file; only add/edit room actions |
| 5 | `contract_terminate_screen.dart` exists | VERIFIED | ✓ File exists |
| 6 | `contract_transfer_room_screen.dart` exists | VERIFIED | ✓ File exists |
| 7 | `building_provider.dart` has `deleteBuilding()` | VERIFIED | Line 90: `Future<bool> deleteBuilding(int buildingId)` |
| 8 | `house_provider.dart` has `deleteHouse()` | VERIFIED | Line 188: `Future<bool> deleteHouse(int id)` |
| 9 | `contract_provider.dart` has terminate/transfer | VERIFIED | Lines 98 (`terminateContract`) & 122 (`transferRoom`) |
| 10 | `guest_shell.dart:203-217` has FAB "Đăng tin" | VERIFIED | Line 214: `'Đăng tin'` label confirmed |
| 11 | `post_house_screen.dart` line 286 auto-upgrades guest→host | VERIFIED | Lines 283–291: auto-host upgrade flow confirmed |

### Phase 02: Router & Guard Sweep
| # | Claim | Status | Actual |
|---|-------|--------|--------|
| 12 | `app_router.dart` is ~700 lines | INACCURATE | Actual: 662 lines (not ~700) |
| 13 | `app_router.dart:83-111` is redirect logic | VERIFIED | Lines 83–111 confirmed as redirect handler |
| 14 | `auth_provider.dart:113-131` is logout flow | VERIFIED | Lines 113–131 confirmed as `logout()` method |
| 15 | `actor_context_provider.dart` exists | VERIFIED | ✓ File exists |
| 16 | `delegation_provider.dart` has `myDelegationsAsOperator` | VERIFIED | Line 34: getter returns `List.unmodifiable(_myDelegationsAsOperator)` |
| 17 | `deferred_route_widget.dart` exists | VERIFIED | ✓ File exists |

### Phase 03: Role Enum Decision
| # | Claim | Status | Actual |
|---|-------|--------|--------|
| 18 | `auth_provider.dart:159-171` is role enum parsing | VERIFIED | Lines 159–171: `_parseUserRole()` switch statement |
| 19 | Enum has 3 roles (guest\|host\|admin) | VERIFIED | Cases at lines 162 (guest), 164 (host), 166 (admin) |

### Phase 04: Role-Specific Shells
| # | Claim | Status | Actual |
|---|-------|--------|--------|
| 20 | `guest_shell.dart` exists | VERIFIED | ✓ File exists |
| 21 | `profile_screen.dart` (guest) exists | VERIFIED | ✓ File exists |
| 22 | `profile_screen.dart:332-352` has role badge | VERIFIED | Lines 332–352: `_roleBadge()` widget confirmed |
| 23 | `operator_workspace_shell.dart` exists | VERIFIED | ✓ File exists |
| 24a | `admin_home_screen.dart` exists | VERIFIED | ✓ File exists at `lib/features/admin/` |
| 24b | `risky_listings_screen.dart` exists | VERIFIED | ✓ File exists at `lib/features/admin/planning/` |
| 24c | `activity_feed_screen.dart` exists | VERIFIED | ✓ File exists at `lib/features/audit/` |
| 24d | `operator_portfolio_screen.dart` exists | VERIFIED | ✓ File exists at `lib/features/operator/portfolio/` |
| 24e | `ActingAsBanner` exists | VERIFIED | ✓ Class defined in `lib/core/widgets/acting_as_app_bar.dart` |

### Phase 05: Design System Unification
| # | Claim | Status | Actual |
|---|-------|--------|--------|
| 25 | `design_tokens.dart` exists with `HD.*` tokens | VERIFIED | ✓ File exists; tokens confirmed (e.g., `HD.paper`, `HD.accent`) |
| 26 | `ds_dialog.dart` exists | VERIFIED | ✓ File exists |
| 27 | `ds_empty_state.dart` exists | NOT_FOUND | No such file found in `lib/core/widgets/` |
| 28 | `skeleton.dart` exists | VERIFIED | ✓ File exists |
| 29 | AppBar files (sample check) | VERIFIED | ✓ `_EditorialAppBar` (line 136, building_detail_screen.dart); `_roomFormAppBar` (line 6, room_form_screen.dart) |
| 30 | `_EditorialAppBar` & `_roomFormAppBar` exist | VERIFIED | Both helper classes/functions confirmed |

### Phase 07: Large File Modularization
| # | Claim | Status | Actual |
|---|-------|--------|--------|
| 31 | `host_home_screen.dart` is ~767 lines | VERIFIED | Actual: 767 lines (exact match) |
| 32 | `room_detail_screen.dart` is ~654 lines | VERIFIED | Actual: 654 lines (exact match) |
| 33 | `analytics_home_screen.dart` is ~545 lines | VERIFIED | Actual: 545 lines (exact match) |
| 34 | `occupancy_heatmap_screen.dart` is ~599 lines | VERIFIED | Actual: 599 lines (exact match) |
| 35 | `contract_form_screen.dart` is ~502 lines | VERIFIED | Actual: 502 lines (exact match) |

### Phase 08: Accessibility Polish
| # | Claim | Status | Actual |
|---|-------|--------|--------|
| 36 | `ds_app_bar.dart` exists | VERIFIED | ✓ File exists |
| 37 | `ds_bottom_nav.dart` exists | VERIFIED | ✓ File exists |

## Critical Inaccuracies (Block Execution)
**Claim #4: Delete button in `building_detail_screen.dart`**
- **Plan says:** "has delete button"
- **Actual:** No delete UI button exists; file only contains room add/edit/view actions
- **Impact:** If plan assumes building deletion UI, implementation must add it
- **Fix:** Either plan new delete-building UI or remove this claim

**Claim #27: `ds_empty_state.dart`**
- **Plan says:** File exists in `lib/core/widgets/`
- **Actual:** File not found anywhere in codebase
- **Impact:** Design system may lack empty-state component; plan unclear on reuse strategy
- **Fix:** Verify if this component should be created or if empty states are handled elsewhere

## Minor Discrepancies (Safe to Fix During Implementation)
**Claim #12: `app_router.dart` line count**
- **Plan says:** ~700 lines
- **Actual:** 662 lines
- **Impact:** Negligible; 38-line difference within margin of change
- **Fix:** No action needed; update line count in final docs if needed

## Missing or Vague References
None identified. All claims reference concrete files or line ranges. Line numbers for large methods (30+ lines) show drift potential during refactor but are specific enough for grep verification.

## Confidence Level
**High.** 38 of 38 claims directly verifiable via file-existence checks, grep for methods, and wc for line counts. No ambiguous references like "check somewhere in utils/" or "look for pattern X."

## Recommendations
1. **Before Phase 04 implementation:** Confirm if empty-state component should be created or standardized
2. **Before Phase 01 implementation:** Add delete-building UI mockup to building_detail_screen.dart plan or remove claim
3. **Phase 05 onward:** Line count checks are solid; use them as regression tests during refactoring
