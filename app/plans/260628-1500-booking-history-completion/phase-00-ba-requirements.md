# Phase 00 — BA Requirements: Hoàn thiện màn "Lịch sử đặt lịch"

## 1. Problem Statement

Màn `BookingHistoryScreen` (tab `Đặt lịch` ở footer Guest) đang ở trạng thái **half-baked**: layout đã render đầy đủ
nhưng phần lớn tương tác chưa nối — search field không filter, nút "Chi tiết" / "Liên hệ host" rỗng,
card không click được, không có màn appointment detail, ngày tháng hiển thị format ISO khô,
không có badge count theo tab, không refetch khi vào lại screen. Guest hiện không thể:

- Xem chi tiết lịch hẹn đã đặt (message gốc, host info, address đầy đủ).
- Chat trực tiếp với host từ card.
- Tìm theo tên nhà / địa chỉ.
- Quay lại đặt lịch khác sau khi bị từ chối / huỷ.

→ Feature mới chỉ làm tròn phần "list view", **chưa phải workflow hoàn chỉnh**.

## 2. User Stories

| ID | Story |
|----|-------|
| US-1 | Là **guest**, tôi muốn **mở chi tiết một lịch hẹn** để xem message tôi đã gửi, thông tin host, địa chỉ, thời gian, status timeline → để khỏi nhớ lại nội dung tin nhắn. |
| US-2 | Là **guest**, tôi muốn **chat ngay với host** từ card lịch hẹn đã duyệt → để xác nhận giờ, hỏi đường, gửi yêu cầu phát sinh. |
| US-3 | Là **guest**, tôi muốn **gọi điện cho host** (tap số → mở dialer) khi lịch đã duyệt → để liên hệ nhanh. |
| US-4 | Là **guest**, tôi muốn **search theo tên nhà / địa chỉ** trong list → để tìm lại lịch hẹn cũ khi list dài. |
| US-5 | Là **guest**, tôi muốn **thấy badge count [N]** trên từng tab (Chờ / Duyệt / Hoàn thành) → để biết số lượng mỗi nhóm mà không phải tap qua từng tab. |
| US-6 | Là **guest**, tôi muốn **thấy ngày tháng kiểu Việt** ("Thứ 7, 28/06/2026 · 14:00") → để đọc tự nhiên thay vì ISO. |
| US-7 | Là **guest**, tôi muốn **list tự refetch khi tôi quay lại tab** (sau khi tạo lịch mới ở chỗ khác) → để thấy luôn lịch mới mà không phải bấm refresh. |
| US-8 | Là **guest**, sau khi lịch hẹn bị **rejected / cancelled / lost**, tôi muốn **CTA "Đặt lịch khác"** dẫn về Khám phá hoặc về House Detail → để không bị dead-end. |
| US-9 | Là **guest**, ở tab "Hoàn thành" tôi muốn **filter phụ** (Đã chốt phòng / Bị từ chối / Đã huỷ / Đã có người chốt) → để phân biệt rõ vì các status này khác nhau hoàn toàn về ý nghĩa. |
| US-10 | Là **guest** ở tab "Hoàn thành" có status `completed`, tôi muốn nút **"Đánh giá"** chỉ hiện một lần (sau khi đã review thì ẩn) → tránh tạo review trùng. |

## 3. Acceptance Criteria

### AC-1 — Appointment Detail Screen
- Mở từ tap card hoặc nút "Chi tiết".
- Hiển thị: house thumbnail + title + address, status chip lớn, ngày giờ format Vietnamese, message gốc của guest, host name + phone (chỉ khi status >= approved), createdAt.
- Status timeline (Created → Pending → Approved → Locked) với check icon cho các bước đã qua.
- Action buttons theo status (giống card nhưng to hơn, có label rõ).

### AC-2 — Chat với host
- Nút "Liên hệ host" mở `ChatScreen(peerId=hostId, peerName=hostName, houseId=houseId)`.
- Backend `helpers.viewing_appointment_to_dict` phải trả `host_id` (hiện chưa rõ — cần verify).
- Chỉ hiện nút này khi `status ∈ {approved, completed, locked}`.

### AC-3 — Gọi điện
- Tap vào số phone (hoặc icon phone) gọi `url_launcher` với `tel:<phone>`.
- Chỉ hiện khi `hostPhone != null` và `status ∈ {approved, completed, locked}`.

### AC-4 — Search
- Field có controller, debounce 300ms, filter `appointments` theo `houseTitle` hoặc `houseAddress` (case-insensitive, lowercase, không dấu nếu khả thi).
- Có nút clear (×) khi có text.
- Empty state khác khi search không match: "Không có lịch hẹn khớp với '<query>'".

### AC-5 — Badge count
- Tab text format: `Chờ duyệt (3)` — chỉ hiện số khi > 0.

### AC-6 — Date/time format Vietnamese
- `28/06/2026` thay vì `2026-06-28`.
- Có thể thêm thứ trong tuần: `Thứ 7, 28/06`.
- Time vẫn `HH:mm`.

### AC-7 — Auto refetch
- `initState` gọi `fetchAppointments` post-frame (giống `HostAppointmentsScreen`).
- Khi user kéo refresh (pull-to-refresh) gọi lại — đã có sẵn.

### AC-8 — Dead-end recovery
- Card status `rejected | cancelled | lost`: thêm nút outline "Xem nhà khác" → push `HouseDetailScreen(houseId)`.
- Nếu nhà đã không còn (deleted): fallback về `GuestShell(initialTab=0)`.

### AC-9 — Sub-filter trong tab "Hoàn thành"
- Phía dưới tab strip, khi `_activeTab == 'completed'`, hiện 4 chip nhỏ: All / Đã chốt / Bị từ chối / Đã huỷ.
- Default `All`.

### AC-10 — Hide "Đánh giá" nếu đã review
- Provider có hàm `hasReviewed(houseId, userId)` (hoặc API endpoint mới).
- Nếu đã review → ẩn nút, hiện text "Đã đánh giá" + sao đã chấm.

## 4. Out of Scope (Phase này không làm)

- Reschedule flow (đổi ngày giờ lịch hẹn) — cần backend mới, để phase sau.
- Push notification khi status đổi — đã có ở backend, không thuộc UI này.
- Tab "Hoàn thành" sort by date — chỉ giữ default newest-first.
- iCal export, share lịch hẹn ra app khác.
- Multi-select bulk cancel.
- Map view của địa chỉ nhà.

## 5. Open Questions

1. **`host_id` có nằm trong response `viewing_appointment_to_dict` không?** Cần grep backend `helpers.py` để verify trước khi thiết kế nút "Liên hệ host". → Sẽ verify ở Phase Tech Lead Planning.
2. **API check "đã review chưa"?** Có endpoint `/api/reviews?guestId=X&houseId=Y` chưa, hay cần thêm? → Verify ở Tech Lead Planning.
3. **Số tab "Hoàn thành" có gom luôn `lost` (người khác chốt) không?** → Theo logic hiện tại có. Nhưng `lost` mang ý nghĩa khác (bị thua khách khác chốt), nên sub-filter ở AC-9 sẽ tách rõ.
4. **Date format có cần localized "Hôm nay" / "Ngày mai" cho các ngày gần?** → Không phase này; chỉ format DD/MM/YYYY.

## 6. Assumptions

- `ViewingAppointmentModel` đã có `hostName`, `hostPhone` từ backend (đã verify trong code model — có).
- `url_launcher` package đã install (cần verify `pubspec.yaml`).
- `ChatScreen` constructor stable: `peerId`, `peerName`, `peerAvatar`, `houseId` — đã verify.
- Backend không cần đổi schema viewing_appointments; chỉ có thể cần thêm `host_id` vào response dict (nếu thiếu).

## 7. Impact / Risk

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Backend `viewing_appointment_to_dict` thiếu `host_id` | Cannot wire chat button | Verify ngay phase planning; thêm field nếu thiếu (1-line change). |
| Auto-refetch trên tab switch (`AuthWrapper` đã hydrate 1 lần) gây double-fetch | Tốn bandwidth + dễ race | Dùng `initState` post-frame + check `_appointments.isEmpty || stale` để skip. |
| Search dấu tiếng Việt không match | UX kém | Phase 1 dùng so sánh lowercase đơn giản; nâng cấp remove-diacritics ở phase 2 nếu cần. |
| Sub-filter "Hoàn thành" gây UI cluttered trên màn nhỏ | Visual noise | Dùng horizontal scrollable chip strip, ẩn khi không ở tab `completed`. |
| Review-existed check tăng N+1 query | Slow render với list lớn | Backend batch endpoint trả `Map<houseId, reviewed>`; hoặc inline `has_reviewed` vào response appointment. |

---

## BA Leader Review Notes (self-review)

- ✅ User stories tách rõ theo persona, có outcome cụ thể.
- ✅ Acceptance criteria testable từng dòng.
- ⚠ AC-10 cần backend support — nếu phase 1 không muốn đụng backend, có thể dời sang phase sau và keep nút "Đánh giá" như cũ. Đề xuất giữ trong scope vì impact nhỏ (chỉ thêm 1 field response).
- ⚠ AC-9 sub-filter có thể dồn vào Phase 2 nếu phase 1 đang dài. Đề xuất giữ vì code mức UI 1 file, không phức tạp.

**Readiness: READY** — đủ chi tiết để Tech Lead lên architecture/plan.
