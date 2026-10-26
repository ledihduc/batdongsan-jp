# 06 — Dữ liệu, bảo mật và quản trị AI

## Phân loại dữ liệu

| Nhóm | Ví dụ | Quy tắc |
|---|---|---|
| Public | listing đã publish, ga, tiện ích | index/search được nếu còn hiệu lực |
| Internal | ghi chú sale, SLA, owner report | chỉ workspace/organization được cấp |
| Personal | tên, email, phone, địa chỉ | mask, purpose, retention, audit |
| Sensitive document | hộ chiếu, thẻ cư trú, hồ sơ thu nhập, hợp đồng | private storage, signed URL, least privilege |
| Secret | JWT secret, provider key, MCP credential | secret manager, không vào log/prompt |

## APPI và quy trình dữ liệu

Thiết kế phải có mục đích sử dụng, consent khi cần, thông báo thay đổi mục đích, cơ chế xem/sửa/xóa theo policy, kiểm soát bên thứ ba và xử lý sự cố. Chi tiết phải được đánh giá theo loại dữ liệu, entity vận hành, nơi lưu trữ và nhà cung cấp AI thực tế. Tham chiếu khung hướng dẫn của [個人情報保護委員会](https://www.ppc.go.jp/personalinfo/legal/guidelines_tsusoku/).

Đối với từng trường dữ liệu, lưu `purpose`, `lawful_basis_or_consent_ref`, `retention_policy`, `visibility_scope`, `exportable`, `deletable` và `last_accessed_at` khi phù hợp.

## Bảo vệ AI/MCP

- MCP tool nhận identity từ gateway, không tin `user_id` do model tự tạo.
- Mọi resource và tool đều kiểm tra organization, workspace và object ownership.
- Tool write có allowlist, schema validation, idempotency và approval.
- Chặn prompt injection trong title listing, mô tả, file OCR, chat và knowledge base.
- Không cho model đọc secret, raw database, audit private hoặc tài liệu ngoài scope.
- Mask phone, email, số ID và địa chỉ đầy đủ trước khi gửi model nếu không cần.
- Log tool call bằng metadata tối thiểu; không ghi nguyên văn PII vào log.
- Có timeout, rate limit, budget, circuit breaker và kill switch cho từng workflow.
- Rà soát model/provider về nơi xử lý dữ liệu, lưu log, dùng dữ liệu cho training và chuyển dữ liệu xuyên biên giới.

## Phân quyền

Capability tối thiểu:

| Capability | Customer | Sale | Owner | Admin |
|---|---:|---:|---:|---:|
| Tìm listing public | ✓ | ✓ | ✓ | ✓ |
| Xem lead được gán | — | ✓ | theo tài sản | ✓ theo scope |
| Xem hồ sơ thuê | của mình | được gán | tài sản của mình | theo policy |
| Sửa listing | — | được cấp | tài sản của mình | ✓ |
| Duyệt hồ sơ | — | đề xuất | theo policy | ✓/delegated |
| Gửi payment request | — | — | đề xuất | theo policy |
| Quản lý role/policy | — | — | — | ✓ |

Tài khoản nhiều role có thể đổi workspace, nhưng mỗi request chỉ có một actor context rõ ràng để audit.

## Audit và lưu vết

Audit event tối thiểu: `actor`, `actor_role`, `organization`, `action`, `object`, `before_hash`, `after_hash`, `source` (human/automation/AI/MCP), `tool_name`, `approval_id`, `policy_version`, `ip/device` theo policy và timestamp JST/UTC.

Các sự kiện bắt buộc lưu:

- đọc tài liệu nhạy cảm;
- giải mã hoặc reveal contact;
- AI gọi tool;
- người dùng approve/reject/edit đề xuất;
- thay đổi role/capability;
- publish/unpublish listing;
- thay đổi tiền, hợp đồng hoặc trạng thái hồ sơ;
- export/delete dữ liệu.

## Khả năng giải trình

AI response cần hiển thị nguồn, thời điểm dữ liệu, confidence hoặc lý do chuyển người. Admin có thể xem chain:

```text
user_request → prompt_version → model → retrieved_sources → tool_calls
→ proposed_action → approval → domain_event → final_state
```

## Incident response

Khi phát hiện AI/MCP gọi sai hoặc lộ scope:

1. disable tool/workflow bằng kill switch;
2. giữ audit và snapshot liên quan;
3. kiểm tra token, signed URL và quyền đã bị dùng;
4. rollback side effect nếu nghiệp vụ cho phép;
5. thông báo owner/admin phụ trách;
6. đánh giá phạm vi dữ liệu và nghĩa vụ thông báo;
7. cập nhật policy, test và eval trước khi bật lại.
