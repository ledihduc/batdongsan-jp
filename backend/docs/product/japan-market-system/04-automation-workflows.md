# 04 — Tự động hóa quy trình quản lý và quản trị

## Nguyên tắc chung

Mỗi automation có trigger, điều kiện, hành động, người chịu trách nhiệm, SLA, retry, dead-letter và đường rollback. Automation chỉ tự thực hiện phần có rủi ro thấp. Hành động ảnh hưởng đến hợp đồng, tiền, quyền truy cập, trạng thái duyệt hoặc giao tiếp bên ngoài phải dừng ở bước `待機中 / chờ duyệt`.

## Workflow 1 — Tiếp nhận và phân loại lead

**Trigger:** lead từ web, app, landing page hoặc đối tác.

1. Chuẩn hóa email/số điện thoại và phát hiện lead trùng.
2. Dịch yêu cầu vào schema: khu vực, ga, ngân sách, ngày vào, layout, điều kiện.
3. AI gắn nhãn nhu cầu và confidence; không suy đoán thông tin không được khai báo.
4. Matching với listing còn phù hợp.
5. Gán sale theo khu vực, ngôn ngữ, tải công việc và policy.
6. Tạo task phản hồi trong SLA; gửi draft song ngữ để sale duyệt.

**Tự động được:** chuẩn hóa, gắn nhãn, tạo task, đề xuất listing.  
**Cần duyệt:** gửi tin lần đầu, cam kết giá/availability, từ chối lead.

## Workflow 2 — Đặt và nhắc lịch xem

**Trigger:** tenant chọn `内見を予約`.

- đọc availability của sale/owner và căn;
- đề xuất ba slot phù hợp múi giờ Nhật;
- giữ slot tạm thời với TTL;
- gửi confirmation sau khi người dùng xác nhận;
- nhắc trước 24 giờ và 2 giờ;
- sau lịch, tạo task nhập kết quả `興味あり / 保留 / 見送り / 申込へ`;
- nếu no-show, đề xuất reschedule và ghi lý do.

Automation không tự gửi lịch nếu có xung đột hoặc listing đã quá thời gian freshness.

## Workflow 3 — Hồ sơ thuê và tài liệu

**Trigger:** người thuê bắt đầu `申込`.

1. Chọn checklist theo listing, tenant type và policy.
2. OCR file private, trích trường có schema và trả confidence.
3. So khớp tên/ngày sinh/số tài liệu theo policy; không dùng AI để quyết định duyệt.
4. Báo tài liệu thiếu, sai định dạng hoặc sắp hết hạn.
5. Tạo task cho sale/admin review.
6. Khi đủ hồ sơ, chuyển trạng thái `確認待ち` cho người có thẩm quyền.

File gốc luôn ở private storage. Model chỉ nhận bản đã mask hoặc phần cần đọc. Kết quả OCR giữ cả giá trị trích xuất, confidence, source page và người sửa.

## Workflow 4 — IT重説 và hợp đồng

Automation chuẩn bị checklist và phòng họp, không thay thế宅建士 hoặc quy trình nội bộ của đơn vị môi giới:

- kiểm tra bản tài liệu đúng version;
- xác nhận các bên và người phụ trách;
- tạo lịch giải thích;
- gửi reminder và link phiên;
- ghi nhận tài liệu đã mở, câu hỏi và kết quả;
- tạo bản preview hợp đồng để người có thẩm quyền kiểm tra;
- chỉ khi approval đủ mới chuyển sang bước ký/lưu trữ.

Thông tin “sẵn sàng IT重説” phải là một trạng thái vận hành có điều kiện, không phải cam kết pháp lý tự động.

## Workflow 5 — Thu tiền, hóa đơn và gia hạn

- tạo invoice theo kỳ và policy;
- nhắc trước hạn bằng kênh đã consent;
- phát hiện invoice quá hạn và tạo task theo SLA;
- trước gia hạn 90/60/30 ngày, AI tóm tắt hợp đồng, phí và việc cần làm;
- đề xuất checklist gia hạn/trả phòng;
- không tự thay đổi số tiền, gia hạn hay gửi yêu cầu thanh toán nếu chưa có approval.

## Workflow 6 — Bảo trì và support

**Trigger:** `修理を依頼` hoặc chat báo sự cố.

AI phân loại mức độ, địa điểm, thiết bị và ngôn ngữ; tra knowledge base cách xử lý an toàn; tạo ticket, gán vendor và SLA. Sự cố có khả năng nguy hiểm phải được đẩy lên người trực và hiển thị hướng dẫn khẩn cấp đã được duyệt. Chi phí phát sinh cần owner/admin duyệt.

## Workflow 7 — Báo cáo chủ nhà

Hàng tuần, AI tạo bản nháp tiếng Nhật gồm:

- số phòng trống và thời gian trống;
- listing/lead/viewing/application theo funnel;
- doanh thu dự kiến và invoice cần chú ý;
- ticket bảo trì quá SLA;
- đề xuất việc tuần sau.

Owner xem nguồn dữ liệu và bấm `承認して共有` trước khi gửi cho đối tác.

## Workflow 8 — Quản trị nội dung và chất lượng

- phát hiện listing thiếu giá, ảnh, ga, phí hoặc điều kiện;
- kiểm tra nội dung trùng, mâu thuẫn giữa title và field;
- flag nội dung có vẻ phân biệt đối xử hoặc cam kết không có nguồn;
- gán moderation queue;
- tạo bản sửa đề xuất và diff;
- publish sau khi moderator duyệt.

AI chỉ flag để người kiểm tra; không tự xóa hoặc từ chối listing dựa trên suy luận mơ hồ.

## State machine chung

```text
detected → classified → proposed → awaiting_approval → approved → executed
                                      ↘ rejected
executed → verified → completed
executed → failed → retrying → dead_letter → manual_review
```

Mỗi bước có `run_id`, `idempotency_key`, `actor`, `policy_version`, `input_snapshot`, `output`, `source_refs`, timestamp và error code.

## SLO vận hành ban đầu

| Workflow | SLO đề xuất |
|---|---|
| Lead được gán sale | dưới 1 phút |
| Draft phản hồi đầu tiên | dưới 2 phút |
| Nhắc lịch | gửi trong cửa sổ ±5 phút |
| OCR hồ sơ | dưới 60 giây/tài liệu, tùy kích thước |
| Ticket khẩn | tạo và báo người trực dưới 1 phút |
| Báo cáo tuần | hoàn thành trước giờ làm việc đã cấu hình |

SLO là mục tiêu vận hành; cần đo production trước khi cam kết với khách hàng.
