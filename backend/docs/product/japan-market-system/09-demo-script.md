# 09 — Kịch bản demo Ancu365 Japan

Thời lượng đề xuất: 15–20 phút. Dữ liệu demo phải là dữ liệu giả lập, không dùng hồ sơ cá nhân hoặc thông tin hợp đồng thật.

## 1. Mở đầu — 2 phút

Giới thiệu bằng tiếng Nhật:

> **Ancu365 Japan は、物件探しから入居後の管理までをつなぐ、AI対応の不動産プラットフォームです。**

Nói rõ ba nhóm người dùng: 入居者, 仲介担当者, オーナー/管理会社. Nhấn mạnh hệ thống dùng cùng một dữ liệu và phân quyền riêng theo workspace.

## 2. Người thuê tìm nhà — 4 phút

Nhập query:

> `新宿まで30分以内、家賃8万円以下、1K、駅徒歩10分以内、外国人相談可、敷金礼金ゼロ`

Cho xem:

- chips mà AI đã hiểu;
- kết quả và lý do khớp;
- giá thuê, phí quản lý, tổng chi phí ban đầu;
- nguồn và thời điểm cập nhật;
- sửa một điều kiện để thấy kết quả đổi;
- `内見を予約`.

Nêu rõ AI không khẳng định chắc chắn điều kiện `外国人相談可` nếu owner chưa xác nhận.

## 3. Chọn role và app — 3 phút

Đăng nhập bằng tài khoản demo có cả role. Chọn:

- `入居者`: favorite, viewing, checklist;
- đổi sang `仲介担当者`: lead và lịch xem;
- đổi sang `オーナー`: phòng trống, listing, task.

Giải thích rằng UI thay đổi theo capability server và mọi workspace dùng chung timeline có kiểm soát.

## 4. AI copilot và MCP — 3 phút

Hỏi AI:

> “Tóm tắt các khách đã xem căn này trong tuần, căn nào cần follow-up hôm nay và nguồn dữ liệu là gì?”

Cho thấy:

- AI đọc resource trong scope;
- gọi tool read-only;
- trả timeline có source và freshness;
- tạo draft task nhưng chưa tự gửi.

Sau đó tạo một đề xuất `draft_bilingual_message`; người dùng xem diff và approve.

## 5. Tự động hóa hồ sơ — 3 phút

Mở application giả lập, upload tài liệu giả lập. OCR trích trường, đánh dấu confidence và thiếu file. AI tạo checklist tiếng Nhật–Việt. Chuyển vào approval queue, không trình diễn việc tự duyệt hợp đồng hoặc tự chuyển tiền.

## 6. Backoffice — 2 phút

Cho xem:

- policy version;
- automation run;
- tool call/audit chain;
- kill switch;
- KPI freshness, response SLA, AI correction.

## Thông điệp chốt

> **探す、比較する、内見する、申込を進める。その後の管理まで、データとAIでつなぎます。**

Ancu365 Japan giúp đội ngũ xử lý nhanh hơn và minh bạch hơn, trong khi quyết định về hồ sơ, hợp đồng, tiền và quyền truy cập vẫn thuộc về người có trách nhiệm.
