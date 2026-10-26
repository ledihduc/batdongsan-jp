# Phase 01 — Basic Design (Information Architecture & UX Flow)

## 1. Screen Inventory

| Screen | Route | Owner |
|--------|-------|-------|
| **BookingHistoryScreen** (cải tổ) | embedded trong `GuestShell` tab 2 | đã có — cải tạo |
| **BookingDetailScreen** (mới) | `MaterialPageRoute` từ card tap / "Chi tiết" | mới |
| ChatScreen (reuse) | existing | reuse |
| HouseDetailScreen (reuse) | existing | reuse |
| WriteReviewScreen (reuse) | existing | reuse |

## 2. Information Architecture

```
BookingHistoryScreen (List)
├── AppBar: "Lịch sử đặt lịch" + refresh icon
├── TabBar [Chờ duyệt (3) | Đã duyệt (1) | Hoàn thành (5)]
├── [Conditional: chỉ tab Hoàn thành]
│     Sub-filter chip strip: [All] [Chốt] [Từ chối] [Huỷ] [Người khác chốt]
├── SearchField (debounce 300ms)
├── ListView
│     └── AppointmentCard (tap → BookingDetailScreen)
│           ├── Thumbnail + StatusChip
│           ├── House title + Address (1 line ellipsis)
│           ├── Date · Time (Vietnamese format)
│           ├── Price /tháng
│           └── Action bar (status-dependent)
│                 ├── pending: [Huỷ] [Chi tiết]
│                 ├── approved: [Chat] [Gọi] [Chi tiết]
│                 ├── completed: [Đánh giá|Đã đánh giá] [Chi tiết]
│                 ├── locked: [Chat] [Chi tiết]
│                 ├── rejected/cancelled/lost: [Xem nhà khác] [Chi tiết]
│
BookingDetailScreen
├── AppBar: "Chi tiết lịch hẹn"
├── Header card
│     ├── House thumbnail (160px high)
│     ├── House title + address
│     └── StatusChip (lớn)
├── Section "Lịch hẹn"
│     ├── Ngày: Thứ 7, 28/06/2026
│     ├── Giờ: 14:00 - 15:00
│     └── Thời điểm gửi: 25/06/2026 09:12
├── Section "Lời nhắn của bạn"
│     └── message text (italic, bordered)
├── Section "Thông tin chủ nhà" (chỉ khi status ∈ {approved, locked, completed})
│     ├── Avatar + tên
│     ├── Phone (tap → tel:)
│     └── Nút "Nhắn tin với host"
├── Section "Tiến trình"
│     └── Vertical timeline: Created → Pending → Approved → Locked
└── Sticky bottom action bar (status-dependent, full-width buttons)
```

## 3. UX Flow Diagrams

### Flow A — Guest cancels pending request
```
Card[pending] → tap "Huỷ"
    → Confirm dialog
        → Yes → updateStatus('cancelled') → optimistic UI move card sang tab "Hoàn thành"
        → No  → dismiss
```

### Flow B — Guest contacts host after approval
```
Card[approved] → tap "Chat"
    → ChatScreen(peerId=hostId, houseId=...)
        ↓ User can send messages via existing WS chat
```

### Flow C — Guest reviews after stay
```
Card[completed, !reviewed] → tap "Đánh giá"
    → WriteReviewScreen(houseId, houseTitle)
        → On submit success → backend marks reviewed → refetch list
            → Card shows "Đã đánh giá ★4.5"
```

### Flow D — Guest opens detail
```
Card → tap anywhere (besides action buttons)
    → BookingDetailScreen(appointmentId)
        → Bottom CTA tuỳ status
            pending: [Huỷ lịch hẹn]
            approved: [Nhắn tin] [Gọi điện]
            rejected: [Xem nhà tương tự]
            ...
```

### Flow E — Dead-end recovery
```
Card[rejected | cancelled | lost] → tap "Xem nhà khác"
    → Try push HouseDetailScreen(houseId)
        Nhà còn → mở detail
        Nhà đã xoá (404) → SnackBar "Nhà này không còn" + back to list
```

## 4. Visual Design Decisions

### 4.1 Tab strip — current vs new
**Current:** 3 chip pill rounded corners (BorderRadius 10), primary color when selected.
**New:** Same shape, thêm badge count format `Chờ duyệt (3)` inline. Chỉ hiện số khi > 0.

### 4.2 Sub-filter strip (Hoàn thành tab only)
- Horizontal scrollable, 5 small filter chips.
- Default: All. Tap để filter thêm theo `completed | rejected | cancelled | lost`.
- Visual khác tab strip chính: thấp hơn, viền 1px thay vì fill, font nhỏ hơn 1 size.

### 4.3 Card layout — same structure, tăng cường
- **Thêm:** `houseAddress` 1 line dưới title.
- **Thêm:** Tap area cho toàn card → BookingDetailScreen. Action buttons stop propagation.
- **Đổi:** Date `28/06/2026 · 14:00` thay vì `2026-06-28` + `14:00`.
- **Đổi:** Status chip giữ nguyên, action row có thêm icon Phone khi `hostPhone != null`.

### 4.4 BookingDetailScreen — tổng thể
- Material 3 surface, vertical scroll.
- Section cách nhau bằng `Divider(thickness:6)` light background (separator pattern Apple iOS).
- Sticky bottom action bar `SafeArea` wrap.

### 4.5 Empty state
- Empty state hiện tại: generic. Đổi 2 nhánh:
  - Không có gì: "Chưa có lịch hẹn nào" + CTA "Khám phá nhà cho thuê" → tab 0.
  - Search no match: "Không có lịch hẹn khớp với '<query>'" + nút Clear.

## 5. Loading / Error States

| State | UI |
|-------|----|
| First load | Full-screen `CircularProgressIndicator` (đã có). |
| Refetch (pull-to-refresh) | `RefreshIndicator` spinner. |
| Action loading (cancel, chat, lock) | Disable button + small spinner thay icon. |
| Network error | SnackBar đỏ với message + nút "Thử lại". |
| Empty list (no filter) | Friendly empty state có CTA. |
| Empty list (search no match) | Different empty state có Clear button. |

## 6. Navigation Coupling

- BookingHistoryScreen vào `GuestShell` tab 2 → giữ nguyên.
- BookingDetailScreen push lên cùng Navigator stack (không nested).
- Tap card → Navigator.push, đảm bảo back lại preserve scroll position (đã handle bởi `IndexedStack` ở GuestShell).

## 7. Out-of-band considerations

- **Realtime push** khi host approve: notification provider đã polling. Khi user còn ở BookingHistoryScreen, nhận notif → có thể trigger silent refetch.
  - Phase này: KHÔNG implement; refetch khi tab gain focus là đủ.
- **Offline cache:** không thuộc scope phase này; appointment list hiện không có local cache.
