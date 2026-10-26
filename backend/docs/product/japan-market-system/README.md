# Ancu365 Japan — bộ tài liệu giới thiệu hệ thống

## Mục đích

Bộ tài liệu này mô tả hướng phát triển Ancu365 thành nền tảng tìm, thuê và vận hành bất động sản cho thị trường Nhật Bản. Phạm vi bao gồm:

- web công khai và web quản trị;
- app đa vai trò cho 入居者/借主, 仲介担当者 và オーナー/貸主;
- backend, dữ liệu và các quy trình nghiệp vụ;
- lớp MCP để AI truy cập dữ liệu, công cụ và quy trình có kiểm soát;
- AI tìm kiếm sản phẩm, đọc hồ sơ, hỗ trợ giao tiếp đa ngôn ngữ;
- tự động hóa vận hành, quản trị, lịch xem, hồ sơ thuê, hợp đồng, hóa đơn và bảo trì.

Đây là **tài liệu sản phẩm và kiến trúc mục tiêu**. Nội dung tiếng Nhật, quy tắc tiền tệ, hợp đồng, 重要事項説明/IT重説 và các quy trình pháp lý phải được xác nhận lại với đơn vị môi giới hoặc tư vấn pháp lý tại Nhật trước khi đưa vào vận hành thật.

Nếu chỉ cần đọc một file, mở bản Word [ANCU365-JAPAN-SYSTEM.docx](./ANCU365-JAPAN-SYSTEM.docx) hoặc bản Markdown [ANCU365-JAPAN-SYSTEM.md](./ANCU365-JAPAN-SYSTEM.md). Các file đánh số bên dưới là bản tách theo chủ đề để dùng khi triển khai.

Mockup Sale Nhật hóa: [sale-japan-ui-board-v1.png](./assets/sale-japan-ui-board-v1.png).

## Tài liệu trong bộ

| Tài liệu | Nội dung | Đối tượng đọc |
|---|---|---|
| [00 — Tổng quan hệ thống](./00-system-overview.md) | Định vị sản phẩm, hiện trạng repo, kiến trúc đích và vai trò | Chủ sản phẩm, đối tác, kỹ thuật |
| [01 — Đặc tả thị trường Nhật](./01-japan-market-product-spec.md) | Nhật hóa nội dung, dữ liệu, thuật ngữ, giá và nghiệp vụ | Product, BA, vận hành |
| [02 — Web và app](./02-web-and-app-experience.md) | Luồng màn hình, giao diện, role và nội dung tiếng Nhật | UX/UI, frontend, marketing |
| [03 — MCP và AI](./03-mcp-ai-architecture.md) | MCP server, resource, tool, prompt, AI gateway và quyền hạn | Backend, AI engineer, security |
| [04 — Tự động hóa](./04-automation-workflows.md) | Các workflow tự động có điều kiện, SLA và human approval | Vận hành, admin, kỹ thuật |
| [05 — AI tìm kiếm sản phẩm](./05-ai-product-search.md) | Tìm kiếm ngôn ngữ tự nhiên, RAG, xếp hạng và giải thích kết quả | Product, search, AI |
| [06 — Dữ liệu và quản trị](./06-data-security-and-governance.md) | APPI, dữ liệu cá nhân, audit, retention, phân quyền và an toàn AI | Security, pháp chế, admin |
| [07 — API và tích hợp](./07-api-and-integration-contracts.md) | Các domain API, hợp đồng dữ liệu và tích hợp bên ngoài | Backend, mobile, web |
| [08 — Roadmap và KPI](./08-roadmap-and-kpis.md) | Thứ tự triển khai, feature flag, chỉ số đo và tiêu chí ra mắt | Chủ sản phẩm, delivery |
| [09 — Kịch bản demo](./09-demo-script.md) | Kịch bản giới thiệu 15–20 phút cho đối tác Nhật | Sales, demo, onboarding |

## Cách dùng

1. Đọc tài liệu 00 để thống nhất phạm vi.
2. Dùng tài liệu 01 và 02 khi làm nội dung, UX và bản dịch tiếng Nhật.
3. Dùng tài liệu 03–07 để tách backlog kỹ thuật và kiểm tra các điểm cần phê duyệt.
4. Dùng tài liệu 08 để chia phase; không bật workflow ghi dữ liệu hoặc gọi dịch vụ bên ngoài khi chưa có audit và approval.
5. Dùng tài liệu 09 cho demo; các số liệu trong kịch bản là dữ liệu minh họa, không phải số liệu production.

## Nguồn tham chiếu chính thức

- [国土交通省 — 賃貸住宅標準契約書](https://www.mlit.go.jp/jutakukentiku/house/jutakukentiku_house_tk3_000023.html)
- [国土交通省 — IT重説 Q&A](https://www.mlit.go.jp/common/001224217.pdf)
- [出入国在留管理庁 — 外国人の民間賃貸住宅入居円滑化ガイドライン](https://www.moj.go.jp/isa/content/001347827.pdf)
- [個人情報保護委員会 — APPI guidelines, general provisions](https://www.ppc.go.jp/personalinfo/legal/guidelines_tsusoku/)
- [Model Context Protocol — official specification](https://modelcontextprotocol.io/specification/draft/server/index)

Các nguồn trên chỉ là đầu vào thiết kế. Tài liệu không thay thế quy trình kiểm tra pháp lý, giấy phép hoặc xác nhận nghiệp vụ tại Nhật.
