# Short-stay MVP — application handoff

The research and pre-implementation plan live in
[the backend plan](../../ancu365-backend/plans/20260909-short-stay-mvp.md).
This change stays within short-term search, reservation and operational surfaces.

## Paths through the application

1. Guest: Search → **Ở ngắn hạn** → location/mode/time → room detail →
   **Kiểm tra phòng & xem giá** → guest details → **Đặt phòng** → confirmation
   → booking code/status. Linked house detail and existing project room booking
   also enter the same form. Prices always come from the server quote.
2. Profile → settings → **Đặt phòng ngắn hạn của tôi**: code, status, stay times,
   price/policy snapshot and eligible cancellation with confirmation.
3. Profile → settings → **Quản lý ở ngắn hạn**: today's/all short-stay bookings,
   approve/reject/check-in/check-out/cancel; **Giá & khoá phòng** opens room setup.
4. Owner sets room type, individual mode rates and cancellation windows. Assigned
   sale can manage bookings and blocks; rate editing is hidden and server-denied.

## Validation and limits

- Full Flutter suite: 1,244 passed; new feature tests: 10 passed, including a run
  under America/New_York to verify explicit Vietnam time handling.
- New feature analyze: no issues. Full analyze: 0 errors, 16 pre-existing warnings,
  310 infos; pristine HEAD baseline has the same warnings and 311 infos.
- Tests run after pub get in a clean temporary copy; only that copy uses the
  system SQLite hook to avoid a stalled binary download. No dependency changes
  are included in this commit.
- Uses the existing HD/Ds components and Vietnamese language. No online charge,
  refund execution, promotion/dynamic pricing or redesign of unrelated screens.
- Overnight is 21:00–09:00 next day; hourly 1–24 whole hours; daily 1–30 periods
  of 24 hours. These rules and property cancellation terms are shown before booking.
- Deploy backend migration 0105 before using this client in a future release.
  Nothing was deployed or pushed during implementation.
