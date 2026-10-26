# 02 — Trải nghiệm web và app

## Web công khai

### Trang chủ

Hero dùng tiếng Nhật, tập trung vào nhu cầu thay vì giới thiệu tính năng:

> **日本で、あなたに合う住まいを探す**  
> Ga, ngân sách, điều kiện sống và tổng chi phí được giải thích rõ ràng.

CTA:

- `物件を探す` — mở search;
- `条件を入力してAIで探す` — mở AI search;
- `初期費用を計算` — mở calculator;
- `外国人向けの部屋探しガイド` — mở knowledge hub.

### Search và listing detail

Search có hai chế độ:

1. Bộ lọc truyền thống theo ga, tuyến, giá, diện tích, layout, điều kiện.
2. Ô hỏi tự nhiên: `新宿まで30分以内、家賃8万円以下、外国人相談可、敷金礼金ゼロ`.

Card listing phải hiển thị giá/tháng, quản lý phí, diện tích, layout, ga gần nhất, `徒歩 X 分`, chi phí ban đầu ước tính, thời điểm cập nhật, nguồn tin và badge policy. Detail có so sánh nhiều căn, tính chi phí, đặt lịch xem và hỏi chuyên viên.

### Knowledge hub

Các trang giải thích quy trình bằng tiếng Nhật đơn giản và bản dịch hỗ trợ:

`部屋探し` → `内見` → `申込` → `審査` → `重要事項説明` → `契約` → `入居`.

Mỗi bài có phiên bản, người duyệt, ngày cập nhật và liên kết đến nguồn chính thức nếu đề cập quy định.

## App Flutter

### Luồng khởi động và đăng nhập

1. Chọn ngôn ngữ.
2. Chọn `入居者`, `仲介担当者`, `オーナー` hoặc `管理者` nếu tài khoản có quyền.
3. Đăng nhập bằng email/số điện thoại và mật khẩu; có thể mở rộng OTP.
4. Server trả capability và workspace được cấp.
5. App mở dashboard đúng role, cho phép đổi role ở profile nếu tài khoản có nhiều role.

Không để client tự bật menu dựa trên role do người dùng gửi lên. Role picker chỉ là lựa chọn context; API phải kiểm tra capability ở mỗi command.

### Workspace 入居者・借主

- `探す`: tìm nhà, AI search, map/ga, bộ lọc Nhật;
- `お気に入り`: lưu và so sánh;
- `内見`: đề xuất slot, xác nhận, đổi lịch, nhắc lịch;
- `申込`: checklist hồ sơ, OCR, trạng thái và thiếu tài liệu;
- `契約・支払い`: xem tài liệu, khoản phải trả, lịch hạn;
- `入居中`: yêu cầu sửa chữa, meter, thông báo;
- `サポート`: chat và AI FAQ có chuyển cho người thật.

### Workspace 仲介担当者

- lead từ web/app và phân loại tự động;
- nguồn hàng, availability và điều kiện chủ nhà;
- matching khách–listing bằng AI có giải thích;
- lịch xem, nhắc lịch, kết quả sau xem;
- pipeline `新規 → 相談中 → 内見 → 申込 → 審査 → 契約 → 成約`;
- soạn tin nhắn Nhật/Anh/Việt, nhưng gửi ra ngoài cần xác nhận;
- AI copilot tóm tắt timeline và đề xuất việc tiếp theo.

### Workspace オーナー・貸主

- dashboard tòa/phòng, tỷ lệ trống, listing và lead;
- điều kiện thuê, phí, policy `外国人相談可`, `ペット可`;
- duyệt lịch xem, hồ sơ, yêu cầu và tài liệu;
- hợp đồng, tiền thuê, hóa đơn, công việc bảo trì;
- báo cáo tuần/tháng bằng tiếng Nhật;
- phê duyệt các hành động AI đề xuất.

### Workspace 管理者・運営スタッフ

- hàng đợi hồ sơ và nội dung cần duyệt;
- quản lý user, role, organization và policy;
- AI/MCP run history, approval queue, error và cost;
- audit log, data export, retention và incident;
- catalog thuật ngữ, bản dịch, template và knowledge base.

## Hệ thống giao diện

Giữ cấu trúc component và design token hiện tại, thay nội dung và dữ liệu theo Nhật:

- nền trung tính, card rõ ràng, accent tin cậy và màu trạng thái nhất quán;
- font hỗ trợ kana/kanji tốt, ưu tiên Noto Sans JP hoặc font tương đương có license phù hợp;
- mobile first cho app và responsive cho web;
- luôn có loading, empty, error, stale-data state;
- nút tác động lớn (`契約を承認`, `支払いを実行`, `申込を送信`) phải hiển thị người/role phê duyệt và trạng thái trước khi bấm;
- thông báo lỗi nói rõ phải làm gì tiếp theo, tránh chỉ hiện mã lỗi.

## Trạng thái UI quan trọng

| Trạng thái | Tiếng Nhật gợi ý | Nội dung cần có |
|---|---|---|
| Listing cũ | `情報を更新中` | thời điểm cập nhật, nút hỏi 담당者 |
| Thiếu dữ liệu giá | `初期費用は要確認` | khoản còn thiếu và người xác nhận |
| AI chưa chắc chắn | `担当者の確認が必要です` | lý do, nguồn và CTA chuyển người |
| Hồ sơ thiếu file | `不足書類があります` | danh sách tài liệu, hạn nộp |
| Chờ duyệt | `確認待ち` | ai duyệt, SLA, lịch sử |
| Không có kết quả | `条件に合う物件が見つかりません` | nới điều kiện từng bước |
