# Phase 06 — Vietnamese Microcopy Glossary

**Priority:** P2 | **Status:** pending | **Estimate:** 1 ngày | **Depends on:** none (parallel)

## Context

Terminology hỗn tạp: 8 variants cho "booking" (đặt phòng / đặt lịch / booking / đặt), 4 variants cho "room" (phòng / căn hộ / tòa nhà / phòng trống), mix "khách" với "guest" English. Không có glossary enforced.

## Requirements

**Functional:**
- Có glossary chính thức document trong repo
- Terminology sử dụng nhất quán trên tất cả feature file
- Copy Vietnamese không mix tiếng Anh trừ term riêng ("QR", "OTP", "SDK" ok; "guest", "host" phải dịch)

**Non-functional:**
- Không đổi logic — chỉ đổi string display
- Có test/CI check tương lai

## Glossary chuẩn (từ researcher-05)

| Concept | Preferred VN | Never use | Notes |
|---|---|---|---|
| Guest (khách thuê) | Khách thuê | visitor | "khách" 1 mình có thể ambiguous — dùng "khách thuê" |
| Host (chủ nhà) | Chủ nhà | chủ trọ, host, owner, landlord | "Chủ nhà" universal |
| Admin | Quản trị | admin | |
| Operator | Đại lý quản lý | operator | Compound noun, không tự dịch từng chữ |
| Tenant (người thuê hợp đồng) | Người thuê | tenant | Phân biệt với "khách thuê" (short-term) |
| Booking (đặt phòng) | Đặt phòng | booking, đặt, reservation | "Đặt lịch" chỉ dùng cho appointment (surgery-context) |
| Viewing appointment | Đặt lịch xem nhà | viewing | Long form OK |
| Room | Phòng | room | "Căn hộ" cho apartment cụ thể |
| Apartment | Căn hộ | | |
| Building | Tòa nhà | building | |
| Vacant | Phòng trống | vacant, empty | |
| Check-in | Nhận phòng | check-in, vào phòng | |
| Check-out | Trả phòng | check-out, rời phòng | |
| Cancel | Hủy | huỷ (old orthography), cancel | 1999 orthography reform |
| Pending | Chờ xác nhận | pending, chưa | Context-dependent |
| Invoice | Hóa đơn | bill, đơn | Formal |
| Wishlist | Yêu thích | wishlist, favorite | |
| Delegation | Ủy thác quản lý | delegation | |
| Approval | Duyệt tin | approval, xét duyệt | |

## Related files

**Tạo mới:**
- `docs/vietnamese-glossary.md` — official doc
- `lib/core/localization/vn_terms.dart` — enum + display name mapping (nếu muốn code-enforce)

**Modify (grep-based):**
- Tất cả `lib/features/**/*.dart` với các term sai
- Ưu tiên: `lib/features/host/homestay/` (audit note weakest module)

## Implementation steps

1. **Doc** (0.5 giờ):
   - `docs/vietnamese-glossary.md` với bảng chuẩn + ví dụ đúng/sai
   - Reference từ `docs/code-standards.md`
2. **Enum central** (1 giờ):
   - `lib/core/localization/vn_terms.dart`:
     ```dart
     class VnTerms {
       static const guest = 'Khách thuê';
       static const host = 'Chủ nhà';
       static const booking = 'Đặt phòng';
       // ...
     }
     ```
   - Không bắt buộc dùng ở mọi nơi — soft enforcement, ưu tiên dùng cho tab labels, badge, button label
3. **Grep + fix** (5–6 giờ):
   - `grep -rn "đặt lịch"` — check context, đổi sang "đặt phòng" nếu là booking (giữ "đặt lịch xem nhà" cho viewing)
   - `grep -rn "huỷ"` → "hủy"
   - `grep -rn "chủ trọ"` → "chủ nhà"
   - `grep -rn '"guest"\|"host"'` string literal — dịch nếu là user-facing
   - `grep -rn "tòa nhà"` — check ambiguity với "phòng"
4. **CI hint** (30 phút):
   - Add note trong `docs/code-standards.md` + `CLAUDE.md`:
     > "Kiểm tra Vietnamese glossary trước khi commit user-facing text — xem `docs/vietnamese-glossary.md`"
5. **Spot-check:** run app, xem 5 màn cao traffic (guest home, host home, booking history, invoice list, wishlist) — copy nhất quán?

## TODO checklist

- [ ] `docs/vietnamese-glossary.md` published
- [ ] `lib/core/localization/vn_terms.dart` enum
- [ ] Fix "đặt lịch" → "đặt phòng" (booking context)
- [ ] Fix "huỷ" → "hủy"
- [ ] Fix "chủ trọ" → "chủ nhà"
- [ ] Dịch string literal English còn sót
- [ ] Update CLAUDE.md + code-standards.md reference glossary
- [ ] Spot check 5 màn

## Success criteria

- Doc glossary published, reachable từ CLAUDE.md
- 0 instances "huỷ" trong `lib/features/`
- 0 instances "chủ trọ"
- "đặt lịch" chỉ xuất hiện trong context "xem nhà" (viewing appointment)
- Manual review 5 màn key: consistent tone

## Risk

- **Grep false positive:** "đặt lịch" có thể đúng nếu là viewing. Mitigation: manual review từng match.
- **Copy đang hiển thị đúng UX nhưng sai glossary** → break user memory. Mitigation: prioritize spelling ("huỷ"→"hủy") trước, terminology change (chủ trọ→chủ nhà) làm sau kèm announcement.

## Out of scope

- Không dịch toàn bộ backend response messages
- Không setup i18n framework (Flutter intl) — dự án hiện chỉ Vietnamese
- Không đổi tone of voice / brand voice guide
