# 01 — Đặc tả sản phẩm cho thị trường Nhật

## Ngôn ngữ và định dạng

- Locale mặc định: `ja-JP`; fallback: `en-US`, `vi-VN`.
- Tiền tệ: `JPY`, hiển thị bằng `¥` và số nguyên; không dùng VND trong nội dung Nhật.
- Diện tích: `m²`, có thể hiển thị thêm `畳` như thông tin tham khảo.
- Khoảng cách: `徒歩 X 分` theo cách hiển thị của thị trường Nhật; cần lưu cả số mét và số phút tính toán.
- Ngày giờ: `Asia/Tokyo`, định dạng `YYYY年M月D日`, thời gian 24 giờ.
- Địa chỉ: 都道府県 → 市区町村 → 町名 → 番地; hỗ trợ mã bưu chính và kana đọc địa chỉ.
- Tên người: giữ nguyên thứ tự và cách viết do người dùng cung cấp; không tự động phiên âm pháp lý.

## Bộ thuật ngữ cốt lõi

| Tiếng Nhật | Nghĩa dùng trong sản phẩm | Ghi chú dữ liệu |
|---|---|---|
| 入居者 / 借主 | Người thuê | customer/tenant |
| オーナー / 貸主 | Chủ nhà | owner/landlord |
| 仲介担当者 | Nhân viên môi giới phụ trách | sale/broker |
| 管理会社 | Công ty quản lý | property manager |
| 物件 | Bất động sản/listing | listing/property |
| 部屋 | Phòng/căn cụ thể | room/unit |
| 最寄り駅 | Ga gần nhất | station |
| 徒歩 X 分 | Đi bộ X phút | walking_minutes |
| 賃料 | Tiền thuê cơ bản | rent |
| 管理費 / 共益費 | Phí quản lý/phí dùng chung | management/common fee |
| 敷金 | Tiền đặt cọc theo hợp đồng | security deposit |
| 礼金 | Tiền lễ/key money | key money |
| 仲介手数料 | Phí môi giới | brokerage fee |
| 保証会社 | Công ty bảo lãnh | guarantor company |
| 連帯保証人 | Người bảo lãnh liên đới | co-signer/guarantor |
| 更新料 | Phí gia hạn | renewal fee |
| 重要事項説明 | Giải thích các điều quan trọng | legal workflow |
| IT重説 | Giải thích qua phương tiện IT | readiness/recording workflow |
| 申込 | Hồ sơ đăng ký thuê | application |
| 内見 | Xem nhà | viewing |

## Loại listing và tiêu chí tìm kiếm

Các filter bắt buộc nên có dạng có cấu trúc, không chỉ nhét vào mô tả tự do:

- khu vực: 都道府県, 市区町村, khu vực, mã bưu chính;
- ga và tuyến: ga gần nhất, tuyến, số phút đi bộ, số lần chuyển tuyến tùy chọn;
- tài chính: 賃料, 管理費/共益費, tổng chi phí hàng tháng, tổng chi phí ban đầu;
- căn hộ: 1R, 1K, 1DK, 1LDK, 2LDK, diện tích, tầng, hướng, năm xây dựng;
- điều kiện: 敷金ゼロ, 礼金ゼロ, 保証人不要, 外国人相談可/可, ペット可, 楽器可, 事務所利用可, 即入居可;
- nội thất và thiết bị: フローリング, バス・トイレ別, 独立洗面台, 宅配ボックス, オートロック, エレベーター, エアコン, 家具・家電付き;
- nhu cầu thuê: dài hạn, ngắn hạn/monthly, share house, corporate lease, người ở cùng, ngày dự kiến chuyển vào.

Các nhãn như `外国人可` phải có nguồn và policy phía chủ nhà; hệ thống không tự suy ra từ tên hoặc quốc tịch người dùng.

## Mô hình chi phí

Trang listing phải cho phép tính và giải thích:

```text
Tổng tháng đầu = 賃料 + 管理費/共益費 + 日割り家賃 + 敷金 + 礼金
              + 仲介手数料 + 保証会社初回料 + bảo hiểm + phí chìa khóa
              + các khoản bắt buộc khác theo listing
```

Mỗi khoản cần có `amount`, `tax_included`, `required`, `one_time_or_recurring`, `source`, `valid_from`, `valid_until`. AI chỉ được gọi là “ước tính” nếu còn thiếu khoản hoặc nguồn đã quá hạn.

## Hồ sơ thuê cho người nước ngoài

UX cần có checklist theo từng trường hợp, ví dụ:

- hộ chiếu và giấy tờ cư trú;
- địa chỉ hiện tại tại Nhật nếu có;
- thông tin việc làm, trường học hoặc nguồn thu;
- số điện thoại/email có thể xác minh;
- công ty bảo lãnh hoặc người bảo lãnh nếu listing yêu cầu;
- người liên hệ khẩn cấp;
- tài liệu bổ sung theo policy của chủ nhà/管理会社.

Checklist hiển thị song ngữ Nhật–Anh hoặc Nhật–Việt, có lý do cần từng tài liệu, trạng thái đã nhận/chưa đủ/hết hạn và kênh upload riêng tư. Đây là hướng dẫn thao tác; tiêu chí duyệt cuối cùng thuộc về chủ nhà, công ty quản lý hoặc đơn vị có thẩm quyền.

## Nội dung marketing và SEO

Web công khai cần có các landing page có ích, không tạo hàng loạt trang rỗng:

- `東京駅 徒歩10分以内`;
- `外国人相談可 東京 賃貸`;
- `敷金礼金ゼロ 大阪`;
- `家具家電付き マンスリー`;
- `初期費用を抑えたい人向け`;
- hướng dẫn `部屋探し`, `内見`, `申込`, `契約`, `引越し`.

Mỗi trang phải liên kết đến listing thật, ngày cập nhật, bộ lọc đang áp dụng và cảnh báo khi kết quả không còn mới. Không dùng nội dung AI chưa được biên tập làm tuyên bố pháp lý hoặc cam kết availability.

## Quy tắc nội dung Nhật

- Dùng giọng lịch sự `です・ます` cho khách hàng.
- Nút chính ngắn và rõ: `物件を探す`, `内見を予約`, `初期費用を計算`, `担当者に相談`.
- Trạng thái: `募集中`, `内見受付中`, `申込あり`, `契約済み`, `掲載終了`.
- Hiển thị giờ liên hệ, ngày nghỉ, tên đơn vị phụ trách và SLA phản hồi.
- Khi dịch từ tiếng Việt/Anh sang tiếng Nhật, hiển thị lại bản gốc trong hồ sơ nội bộ để sale kiểm tra.

## Ghi chú pháp lý sản phẩm

国土交通省 công bố mẫu hợp đồng thuê nhà chuẩn để tham khảo; việc dùng mẫu không tự động thay thế kiểm tra hợp đồng cụ thể. Luồng `重要事項説明` và `IT重説` phải được cấu hình theo quy trình của đơn vị môi giới, kiểm tra danh tính, tài liệu và lưu vết. Tài liệu dành cho người nước ngoài nên dựa trên hướng dẫn chính thức của 出入国在留管理庁 và được rà soát bản dịch trước khi phát hành.

Tham chiếu: [賃貸住宅標準契約書](https://www.mlit.go.jp/jutakukentiku/house/jutakukentiku_house_tk3_000023.html), [IT重説 Q&A](https://www.mlit.go.jp/common/001224217.pdf), [外国人の民間賃貸住宅入居円滑化ガイドライン](https://www.moj.go.jp/isa/content/001347827.pdf).
