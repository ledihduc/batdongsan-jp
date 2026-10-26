# Dự án = Toà nhà: hợp nhất `listing_albums` vào `buildings`

> Chốt 05/09/2026. Thay cho `docs/PLAN-ALBUM-SALE.md` (album là bước đệm, nay gỡ).

## Vì sao đổi hướng

Yêu cầu: *"mỗi dự án có một cái mã liên quan tới một tài khoản chủ nhà; chủ nhà
là người khác, quản lý điện nước"*.

Đó **không phải** album. Đó là quan hệ sở hữu + vận hành, và backend đã có đủ:

```
buildings (host_id = CHỦ NHÀ)
  └── rooms (code "P01", "A-101")          ← "cái mã"
        ├── marketplace_house_id → houses  ← cầu nối sang tin đăng
        ├── contracts → tenants
        ├── meter_readings                 ← điện nước
        └── invoices
delegations / delegation_invitations / delegation_approvals
  └── ActorContext.effective_owner_id      ← sale thao tác HỘ chủ nhà
```

FE cũng có sẵn: `DelegationInviteScreen`, `OperatorPortfolioScreen`,
`ApprovalInboxScreen`, `InvitationInboxScreen`, `OperatorWorkspaceShell`.

**Đo trên staging 05/09/2026:** 2 toà · 9 phòng · **0** hợp đồng · **0** chỉ số
điện nước · **0** hoá đơn · **0** phòng nối tin đăng · **0** delegation.
Cả cụm bị dark-launch tắt bằng `FeatureFlags.roleShellsV2Enabled = false`.

Nên việc cần làm **không phải là xây**, mà là **nối và bật**. `listing_albums`
là bản sao yếu hơn của `buildings` — giữ cả hai sẽ có hai cách gom tin song song
và cái mã bàn giao sẽ nằm ở nhánh không có công tơ lẫn hoá đơn.

## Điểm phải chốt trước: AI SỞ HỮU bản ghi toà nhà

`Building.host_id` là một người duy nhất. Có hai cách và chúng không tương đương:

- **Chủ nhà sở hữu, sale là operator** ← chọn cái này.
  Đúng với thực tế pháp lý (nhà là của chủ), và `effective_owner_id` đã bảo đảm
  hoá đơn/thanh toán luôn về chủ nhà kể cả khi sale thao tác (`AC-51`).
  Đổi lại: sale phải tạo được toà **trước khi** chủ nhà có tài khoản → cần
  trạng thái "toà chưa có chủ" (`host_id` tạm là sale, kèm `claim_code`).
- ~~Sale sở hữu, chuyển giao sau~~ — sẽ phải viết luồng đổi `host_id`, mà
  `houses.host_id`, `invoices`, `contracts` đều trỏ theo; rủi ro tiền đi sai chỗ.

## Các đợt

### P1 — Tin cho thuê phải thuộc một toà nhà
- Migration: `houses.building_id` (FK, nullable, indexed) + `houses.room_code`.
  Nullable ở tầng DB; **bắt buộc ở tầng nghiệp vụ** chỉ với tin `thuê/nhà trọ`
  (tin **bán đứt** vẫn đăng lẻ — bán xong là hết, không có điện nước để quản lý).
- Form đăng tin: ô "Toà nhà" + "Mã căn/phòng", có nút tạo toà ngay tại chỗ.
- Backend chặn: `product_type` thuộc nhóm cho thuê mà thiếu `building_id` → 422.
- Backfill: 5 tin đang thuộc album → toà tương ứng (album 2 và 4).

### P2 — Trang cá nhân đọc từ toà nhà
- `AlbumStrip` → `BuildingStrip`: nguồn dữ liệu đổi sang
  `GET /api/host/buildings` (bản công khai, lọc toà có ≥1 tin published).
- `/album/:id` **giữ nguyên, chuyển hướng** sang `/toa-nha/:id` — link đã chia
  sẻ không được chết.

### P3 — Mã bàn giao + mời chủ nhà
- `buildings.claim_code` (6 ký tự, sinh khi tạo). Sale đưa mã cho chủ nhà.
- Chủ nhà nhập mã → tạo `delegation_invitation` chiều ngược: chủ nhà nhận
  `host_id`, sale được giữ lại làm operator preset `operator_full`.
- Bật `roleShellsV2Enabled` và nối `SharedLoginDisclosureDialog` (đang là dead
  code UI theo `docs/BUSINESS-FLOWS.md` mục 203).

### P4 — Gỡ `listing_albums`
Chỉ sau khi P1–P3 chạy thật. Migration drop + xoá `app/routers/albums.py`,
`lib/data/services/album_api.dart`, `lib/features/guest/album/`.

## Bẫy đã biết
- **Đừng đổi `Building.host_id` sau khi đã có hoá đơn.** `AC-51` chốt payout
  theo `effective_owner_id`; đổi chủ giữa chừng là tiền đi sai tài khoản.
- `roleShellsV2Enabled` bật là **auto-land `/operator`** cho user có delegation
  active — kiểm kỹ chủ nhà thường không bị đá vào đó.
- 9.004 tin published hiện có **không** có `building_id`. Ràng buộc chỉ áp cho
  tin **tạo mới**, không hồi tố, nếu không toàn bộ tin cũ thành không sửa được.
