# 07 — API và hợp đồng tích hợp

## Nguyên tắc API

- Giữ route hiện tại để tương thích; API Nhật hóa bổ sung field/endpoint additive.
- Mọi write command có idempotency key, actor context, policy version và audit event.
- Không nhận `owner_id`, `sale_id` hoặc `workspace` từ client rồi tin trực tiếp; server resolve từ token và assignment.
- Response public không trả contact đầy đủ hoặc tài liệu private.
- Ngày giờ truyền ISO 8601 UTC; UI chuyển sang Asia/Tokyo.
- Số tiền dùng integer JPY và currency rõ ràng.
- Các field có thể chưa có dữ liệu phải nullable và kèm freshness/status.

## Domain API đích

| Domain | API gợi ý | Mục đích |
|---|---|---|
| Auth/workspace | `/api/auth/login`, `/api/auth/me`, `/api/workspaces` | đăng nhập, capability, đổi role context |
| Locale/catalog | `/api/catalog/jp`, `/api/i18n`, `/api/policies` | ga, tuyến, layout, label, policy |
| Search | `/api/jp/listings`, `/api/jp/search/interpret`, `/api/jp/search/explain` | filter có cấu trúc và AI search |
| Cost | `/api/jp/listings/{id}/initial-cost` | breakdown chi phí đầu vào |
| Viewing | `/api/viewing-appointments`, `/api/viewing-appointments/{id}/slots` | đặt, đổi, hủy và nhắc lịch |
| Application | `/api/applications`, `/api/applications/{id}/checklist` | hồ sơ thuê và tài liệu |
| Contract | `/api/contracts`, `/api/contracts/{id}/explanation-readiness` | hợp đồng, version, IT重説 readiness |
| Operations | `/api/work-items`, `/api/maintenance-tickets`, `/api/automation-runs` | task, support và job |
| AI | `/api/ai/sessions`, `/api/ai/proposals`, `/api/ai/evals` | session, đề xuất và đánh giá |
| Admin | `/api/admin/policies`, `/api/admin/approvals`, `/api/admin/audit` | policy, approval, audit |

Tên endpoint chỉ là hợp đồng mục tiêu; cần map với route đang có trước khi code và không được đổi route legacy chỉ để đẹp tên.

## Listing schema Nhật hóa

```json
{
  "id": 123,
  "locale": "ja-JP",
  "status": "募集中",
  "transaction_type": "rent",
  "property_type": "apartment",
  "layout": "1K",
  "rent": {"amount": 78000, "currency": "JPY", "period": "month"},
  "management_fee": {"amount": 5000, "currency": "JPY"},
  "area_m2": 25.4,
  "stations": [{"name": "池袋", "line": "JR山手線", "walk_minutes": 8}],
  "conditions": {"foreign_resident": "consultation", "pet": false},
  "initial_cost": {"status": "estimated", "total": 247000, "currency": "JPY"},
  "freshness": {"checked_at": "2026-10-14T08:30:00Z", "expires_at": "2026-10-14T09:00:00Z"},
  "source": {"organization_id": "org_1", "verified": false}
}
```

## AI proposal schema

```json
{
  "proposal_id": "prop_123",
  "kind": "send_message",
  "status": "awaiting_approval",
  "actor_context": {"user_id": 8, "workspace": "sale", "organization_id": "org_1"},
  "input_sources": [{"type": "listing", "id": 123}, {"type": "lead", "id": 77}],
  "draft": {"locale": "ja-JP", "body": "..."},
  "risk": {"level": "medium", "reasons": ["external_communication"]},
  "expires_at": "2026-10-14T10:00:00Z"
}
```

Approval endpoint phải kiểm tra proposal chưa hết hạn, đúng actor scope, policy hiện hành và version object chưa thay đổi. Nếu object đã thay đổi, yêu cầu AI tạo proposal mới.

## Tích hợp bên ngoài

Tích hợp có thể gồm:

- bản đồ/geocoding và ga/tuyến;
- lịch Google/Outlook hoặc lịch nội bộ;
- email, SMS, push và kênh chat;
- OCR/document intelligence;
- storage private và antivirus;
- payment provider tại Nhật;
- chữ ký số nếu quy trình pháp lý/đối tác cho phép;
- model provider hoặc self-hosted model.

Mỗi connector phải có interface, health check, timeout, retry, circuit breaker, secret reference, data classification và fallback thủ công. Không để MCP gọi thẳng connector; MCP gọi domain service/connector gateway.

## Event và job

Event gợi ý: `lead.created`, `viewing.confirmed`, `viewing.completed`, `application.document_uploaded`, `application.ready_for_review`, `contract.explanation_scheduled`, `invoice.overdue`, `maintenance.created`, `ai.proposal.created`, `approval.completed`.

Consumer phải idempotent, có outbox hoặc cơ chế tương đương, dead-letter và replay có kiểm soát. Payload event không chứa file/PII dư thừa; dùng reference rồi service kiểm tra quyền khi đọc.

## Error contract

```json
{
  "error": {
    "code": "LISTING_DATA_STALE",
    "message_key": "listing.data_stale",
    "message": "物件情報を確認中です。担当者にお問い合わせください。",
    "retryable": false,
    "trace_id": "tr_123",
    "next_action": "contact_assignee"
  }
}
```

Client hiển thị message theo locale nhưng log/audit giữ code ổn định. Không trả traceback hoặc thông tin secret.
