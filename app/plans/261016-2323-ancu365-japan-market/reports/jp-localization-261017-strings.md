# JP Localization — Hardcoded String Replacement
Date: 2026-10-17

## Files Modified

| File | VN strings replaced |
|------|-------------------|
| `lib/features/guest/home/guest_home_screen.dart` | 2 (`Chủ nhà` → `オーナー`, `Người tìm nhà` → `入居希望者`) |
| `lib/features/guest/search/search_screen.dart` | 1 (short-stay nav bar label) |
| `lib/features/guest/house_detail/house_detail_screen.dart` | 6 (short-stay CTA, `/đêm` → `/泊`, room-type specs ×4, booking auth prompt, book button) |
| `lib/features/guest/profile/profile_screen.dart` | 5 (sale tools tile, projects tile, QR code tile, link-sale tile, host dashboard tile) |
| `lib/features/guest/profile/settings_screen.dart` | 2 (added `('ja', '日本語')` at top of language picker, added `'ja'` case in `_langName`) |
| `lib/features/chat/chat_screen.dart` | 5 (send-fail snackbar, listing card label, online/connecting status, empty state, input hint) |
| `lib/features/guest/wishlist/wishlist_screen.dart` | 1 (`_formatPrice` VND suffixes → `¥` / 万 format) |
| `lib/features/guest/booking/booking_detail_screen.dart` | 4 (view-ticket button, reschedule title, reschedule body, pick-time button) |

**Total: ~26 string replacements across 8 files.**

## Analyze Result

```
flutter analyze lib/features/guest lib/features/chat
```
Output: 6 pre-existing warnings in unrelated files (`coc_xac_nhan_thue_screen.dart`, `quan_ly_theo_vai_tro_screen.dart`, `short_stay_booking_detail_screen.dart`).  
**No errors. No new warnings introduced.**

## Notes / Concerns

- `house_detail_screen.dart` still has VN comments (`// Tin ngắn hạn`, etc.) — per spec, comments are left as-is.
- `_formatPrice` in wishlist now uses `¥`/万 (JP convention: ≥10,000 → 万). Prices from the backend are assumed to already be in JPY for the jp-version branch; if backend still returns VND, a currency conversion layer will be needed.
- `AppLocalizations`-keyed strings (e.g., `l.hdPerMonth`, `l.homeHost`) are not changed here — those require ARB file updates in a separate l10n task.
- Profile screen has additional VN strings inside `l.*` keys (e.g., `l.profMessages`, `l.profViewingAppointments`) that flow through ARB — out of scope for this hardcoded-string pass.
