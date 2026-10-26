# 08 — Roadmap, rollout và KPI

## Phase 0 — Chuẩn hóa nền tảng

**Mục tiêu:** có thể demo và đo được phiên bản Nhật.

- locale `ja-JP`, font, timezone, JPY;
- catalog thuật ngữ và bản dịch;
- trường ga/tuyến/walking minutes/layout/initial cost;
- content policy, privacy notice, retention và audit baseline;
- feature flags cho Japan search và AI.

**Gate:** không lỗi API cũ, listing public không có giá trị mâu thuẫn, phone/document không lộ, test locale pass.

## Phase 1 — Web/app tìm kiếm Nhật

- SEO landing theo ga/tuyến/khu vực;
- search filter mới và calculator chi phí;
- app role picker + workspace Nhật hóa;
- favorite, compare, viewing và guide người nước ngoài;
- dashboard freshness và content quality.

**Gate:** 100% kết quả search có nguồn/freshness, calculator nêu khoản thiếu, flow viewing end-to-end pass trên web/app.

## Phase 2 — AI search và copilot read-only

- natural-language parser;
- hybrid search + reranking;
- RAG knowledge hub;
- MCP resources và read-only tools;
- AI summary cho sale/owner/admin.

**Gate:** eval tiếng Nhật đạt ngưỡng đã chốt; không có tool write; citation correctness và scope isolation pass.

## Phase 3 — Automation có approval

- lead triage, lịch xem, checklist hồ sơ, OCR;
- draft message đa ngôn ngữ;
- maintenance triage;
- owner report;
- MCP proposal/approval queue.

**Gate:** idempotency, retry/dead-letter, audit chain, human approval và kill switch được diễn tập.

## Phase 4 — Tích hợp sâu và mở rộng

- calendar/messaging/payment/OCR connector production;
- IT重説 readiness theo policy đối tác;
- vendor maintenance;
- organization/management company;
- AI eval continuous, cost routing và analytics.

**Gate:** security review, DPIA/đánh giá privacy phù hợp, load test, incident drill, partner sign-off.

## KPI sản phẩm

| Nhóm | KPI |
|---|---|
| Acquisition | organic landing to search, signup completion, qualified lead rate |
| Search | search-to-detail, detail-to-viewing, top-3 relevance, constraint satisfaction |
| Conversion | viewing attendance, application completion, document completion, contract conversion |
| Operations | median lead response, tasks completed in SLA, no-show rate, time to resolve maintenance |
| AI | grounded answer, citation correctness, human correction, unsafe tool call, cost/session |
| Trust | stale listing rate, missing-cost rate, complaint rate, audit completeness |
| Business | active listings, occupancy, owner retention, revenue per organization |

Đặt baseline trước rollout; không đưa mục tiêu phần trăm nếu chưa có dữ liệu production đủ tin cậy.

## Feature flag và rollback

Mỗi capability có flag theo environment, organization và cohort:

```text
jp_locale_enabled
jp_listing_fields_enabled
jp_ai_search_enabled
mcp_read_enabled
mcp_write_proposals_enabled
automation_lead_triage_enabled
automation_document_ocr_enabled
```

Flag mặc định tắt cho write/side effect. Rollout theo `internal → pilot partner → 10% → 50% → 100%`, có dashboard và owner on-call. Rollback flag không xóa dữ liệu và không làm mất API legacy.

## Tiêu chí launch

- product/legal/partner owner đã duyệt terminology và nội dung Nhật;
- test auth, role, IDOR, privacy, AI scope và tool approval pass;
- có incident runbook và người trực;
- có data deletion/export process;
- có source cho giá, availability, policy;
- web SEO có canonical, sitemap, structured data và trang lỗi rõ;
- app có loading/error/offline state;
- không dùng demo credential, secret hoặc PII thật trong tài liệu/demo.
