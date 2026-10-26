# Vietnamese Microcopy Glossary

Official terminology for user-facing text. Enforced during code review and
via manual glossary check before every commit that touches Vietnamese copy.

> Code source of truth: `lib/core/localization/vn_terms.dart`.
> When adding a new user-facing concept, add it here **and** to `VnTerms`.

## Roles

| Concept | Preferred VN | Never use | Notes |
|---|---|---|---|
| Guest (khách thuê) | Khách thuê | visitor, khách (alone) | "Khách" alone is ambiguous — use "khách thuê" |
| Host (chủ nhà) | Chủ nhà | chủ trọ, host, owner, landlord | Universal — do not swap to "chủ trọ" |
| Admin | Quản trị | admin | |
| Operator | Đại lý quản lý | operator | Compound noun — do not translate word-by-word |
| Tenant | Người thuê | tenant | Long-term contract holder, distinct from "khách thuê" |

## Booking & appointments

| Concept | Preferred VN | Never use | Notes |
|---|---|---|---|
| Booking | Đặt phòng | booking, đặt, reservation | "Đặt lịch" is reserved for appointment |
| Viewing appointment | Đặt lịch xem nhà | viewing | Long form OK |
| Cancel | Hủy | huỷ (old orthography), cancel | Post-1999 orthography reform |
| Pending | Chờ xác nhận | pending, chưa | Context-dependent |

## Property

| Concept | Preferred VN | Never use | Notes |
|---|---|---|---|
| Room | Phòng | room | "Căn hộ" only for apartments |
| Apartment | Căn hộ | | |
| Building | Tòa nhà | building | |
| Vacant | Phòng trống | vacant, empty | |

## Lifecycle

| Concept | Preferred VN | Never use | Notes |
|---|---|---|---|
| Check-in | Nhận phòng | check-in, vào phòng | |
| Check-out | Trả phòng | check-out, rời phòng | |

## Financial

| Concept | Preferred VN | Never use | Notes |
|---|---|---|---|
| Invoice | Hóa đơn | bill, đơn | Formal |

## Engagement

| Concept | Preferred VN | Never use | Notes |
|---|---|---|---|
| Wishlist | Yêu thích | wishlist, favorite | |

## Ops

| Concept | Preferred VN | Never use | Notes |
|---|---|---|---|
| Delegation | Ủy thác quản lý | delegation | |
| Approval | Duyệt tin | approval, xét duyệt | |

## Untranslated technical terms

These stay English — abbreviations widely understood and canonical in Vietnamese
tech copy: **QR, OTP, SDK, API, PIN, PDF, JSON, URL, SMS**.

## Examples

### Good

- "Bạn có 3 phòng đang chờ xác nhận" ✔
- "Hủy đặt phòng?" ✔
- "Chủ nhà đã xác nhận nhận phòng." ✔

### Bad

- "Bạn có 3 booking đang pending" ✘ — mixed English
- "Huỷ đặt lịch?" ✘ — old orthography, wrong term
- "Chủ trọ đã xác nhận check-in." ✘ — deprecated term + English

## Enforcement

1. **Grep before commit** — search `chủ trọ`, `huỷ`, `booking`, `check-in` in
   any newly changed file under `lib/features/**`.
2. **Use `VnTerms.*`** for tab labels, badges, filter chips, column headers.
3. Long-form dialog / help text — natural sentences may use synonyms if
   clarity improves.
