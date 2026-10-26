"""Tạo file Excel roadmap 6 tháng cho ancu365 - phiên bản tiếng Việt dễ đọc."""
from datetime import date, timedelta
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

# ─── Bảng màu cho từng nhóm công việc ────────────────────────────────────────
SECTION_COLORS = {
    "A": "4F81BD",  # Sản phẩm & Kỹ thuật - xanh dương
    "B": "E26B0A",  # Marketing - cam
    "C": "9BBB59",  # Pháp lý - xanh lá
    "D": "8064A2",  # Kinh doanh & Đối tác - tím
    "E": "C0504D",  # Vận hành & Nhân sự - đỏ
    "M": "F2C700",  # Cột mốc quan trọng - vàng
}
HEADER_FILL = PatternFill("solid", fgColor="1F4E78")
HEADER_FONT = Font(bold=True, color="FFFFFF", size=11)
SECTION_HEADER_FILL = PatternFill("solid", fgColor="D9E1F2")
RISK_FILLS = {
    "Thấp": PatternFill("solid", fgColor="C6EFCE"),
    "Trung bình": PatternFill("solid", fgColor="FFEB9C"),
    "Cao": PatternFill("solid", fgColor="FFC7CE"),
}
THIN = Side(border_style="thin", color="BFBFBF")
BORDER = Border(left=THIN, right=THIN, top=THIN, bottom=THIN)

# ─── Khoảng thời gian dự án ──────────────────────────────────────────────────
START = date(2026, 7, 1)
END = date(2026, 12, 31)
TOTAL_DAYS = (END - START).days + 1  # 184 ngày

# ─── Danh sách công việc ──────────────────────────────────────────────────────
# (mã, nhóm, tên việc, người phụ trách, ngày bắt đầu, số ngày, phụ thuộc, tiêu chí hoàn thành, mức rủi ro)
TASKS = [
    # A — Sản phẩm & Kỹ thuật
    ("A1",  "A", "Khoá chống trùng lịch đặt phòng ở tầng cơ sở dữ liệu",
     "Lập trình viên 1", date(2026,7,1),  3,  "—",
     "Hai khách không thể đặt cùng phòng cùng ngày. Test tự động chạy thành công.", "Thấp"),

    ("A2",  "A", "Tích hợp cổng thanh toán VNPay và MoMo",
     "Lập trình viên 1", date(2026,7,6),  21, "A1, D3",
     "Khách có thể: đặt phòng → thanh toán → nhận thông báo → hoá đơn chuyển trạng thái đã thanh toán.", "Cao"),

    ("A3",  "A", "Hệ thống chuyển tiền cho chủ nhà sau khi khách thuê",
     "Lập trình viên 1", date(2026,7,28), 14, "A2, C5",
     "Hệ thống tự động trả tiền hàng ngày. Số liệu khớp 100% giữa thu và chi.", "Cao"),

    ("A4",  "A", "Trang web giới thiệu chuẩn SEO (Next.js)",
     "Lập trình viên 2", date(2026,7,15), 35, "—",
     "Trang tải dưới 2.5 giây. Có 100 trang con cho Google index. Có cấu trúc dữ liệu chuẩn cho thuê nhà.", "Trung bình"),

    ("A5",  "A", "Trang quản trị nội bộ phiên bản 1",
     "Lập trình viên 2", date(2026,7,6),  28, "A1",
     "Admin quản lý được chủ nhà, danh sách phòng, khiếu nại. Phân quyền theo vai trò.", "Trung bình"),

    ("A6",  "A", "Xác thực danh tính online nâng cao (đối chiếu CCCD + ảnh selfie)",
     "Lập trình viên 1", date(2026,7,28), 21, "A2, D2",
     "Hệ thống tự động so khớp CCCD với ảnh selfie. Tính điểm rủi ro gian lận.", "Cao"),

    ("A7",  "A", "Quy trình khiếu nại và hoàn tiền",
     "Lập trình viên 1", date(2026,8,11), 21, "A3",
     "Khách/chủ nhà có thể: mở khiếu nại → phản hồi → giải quyết → hoàn tiền.", "Cao"),

    ("A8",  "A", "Đo lường hành vi người dùng (Google Analytics + Mixpanel)",
     "Lập trình viên 2", date(2026,8,19), 21, "A4",
     "Theo dõi được phễu chuyển đổi: đăng ký → đặt phòng → thanh toán.", "Trung bình"),

    ("A11", "A", "Kiểm tra và tối ưu hiệu năng hệ thống",
     "Cả 2 lập trình viên", date(2026,11,15), 21, "A7, A8",
     "Chịu được 500 yêu cầu/giây. Phản hồi dưới 0.5 giây. 5000 người dùng đồng thời.", "Trung bình"),

    ("A11b","A", "Củng cố hạ tầng (lưu ảnh trên đám mây, sao lưu định kỳ)",
     "Lập trình viên 1", date(2026,11,1),  14, "A11",
     "Ảnh lưu trên đám mây Amazon S3. Có sao lưu cơ sở dữ liệu hàng ngày + diễn tập khôi phục.", "Cao"),

    ("A12", "A", "Dự phòng sửa lỗi sau khi ra mắt",
     "Tất cả lập trình viên", date(2026,12,1),  15, "A11",
     "Phân loại và sửa lỗi. Không còn lỗi nghiêm trọng nào tồn đọng.", "Trung bình"),

    # B — Marketing (Video AI + Tăng trưởng)
    ("B1",  "B", "Bộ nhận diện thương hiệu và nội dung trang chủ",
     "Designer + Marketing", date(2026,7,1),  14, "E5",
     "Có logo, bảng màu, font chữ, giọng nói thương hiệu, bản hero trang chủ phiên bản 1.", "Thấp"),

    ("B2",  "B", "Đợt 1 video AI - kể chuyện chủ nhà",
     "Đội Video AI", date(2026,7,15), 30, "B1, D1",
     "Sản xuất 10 video TikTok/Reels. Đạt 100,000 lượt tiếp cận tự nhiên.", "Trung bình"),

    ("B3",  "B", "Viết bài SEO 15 bài/tháng",
     "Đội Content", date(2026,7,15), 150,"B1",
     "Có 90 bài viết. 30 bài lọt top 10 Google.", "Trung bình"),

    ("B4",  "B", "SEO địa phương + hồ sơ Google Maps cho HCM",
     "Marketing", date(2026,7,15), 30, "B1",
     "Hồ sơ Google Maps được xác minh cho 24 quận HCM. Có đánh giá ban đầu.", "Thấp"),

    ("B5",  "B", "Chạy quảng cáo thử nghiệm 30 triệu đồng",
     "Marketing", date(2026,8,14), 30, "B2",
     "Chi phí mỗi lượt đăng ký dưới 150,000đ. Tỷ lệ nhấp quảng cáo trên 2%.", "Trung bình"),

    ("B6",  "B", "Hợp tác 5 người có ảnh hưởng nhỏ (50-200k follower)",
     "Marketing", date(2026,9,13), 30, "B5",
     "Ký 5 người có ảnh hưởng. Chi phí mỗi 1000 lượt hiển thị dưới 50,000đ.", "Trung bình"),

    ("B7",  "B", "Đợt 2 video AI - khách thuê chia sẻ trải nghiệm",
     "Đội Video AI", date(2026,8,14), 30, "B2",
     "12 video. Có hashtag chiến dịch #ancu365.", "Trung bình"),

    ("B8",  "B", "Chiến dịch ra mắt mềm (PR báo chí + quảng cáo)",
     "Marketing + PR", date(2026,9,15), 21, "A8, B6",
     "3 bài PR trên báo. Đạt 50,000 lượt khách truy cập duy nhất.", "Trung bình"),

    ("B9",  "B", "Tối ưu quảng cáo retargeting (đuổi theo khách đã ghé thăm)",
     "Marketing", date(2026,10,6), 60, "B8",
     "Tỷ lệ doanh thu trên chi phí quảng cáo trên 3.0 vào cuối tháng 11.", "Trung bình"),

    ("B10", "B", "Chiến dịch Q4 - đẩy 500 đơn đặt phòng",
     "Cả đội Marketing", date(2026,11,1), 45, "B9",
     "Đạt 500 đơn đặt phòng tính đến 15/12 (đã giảm mục tiêu từ 1000).", "Trung bình"),

    ("B11", "B", "Trang tải hợp đồng thuê nhà mẫu (chiến lược SEO)",
     "Content + SEO", date(2026,9,1), 30, "C1",
     "Lọt top 3 Google với từ khoá 'hợp đồng thuê nhà trọ mẫu'.", "Thấp"),

    # C — Pháp lý & Tuân thủ
    ("C1",  "C", "Hợp đồng mẫu giữa nền tảng và chủ nhà",
     "Luật sư + Chuyên gia ngành", date(2026,7,1),  21, "—",
     "Luật sư review xong. Sẵn sàng ký kết.", "Trung bình"),

    ("C2",  "C", "Điều khoản dịch vụ + Chính sách bảo mật cho khách thuê",
     "Luật sư + Chuyên gia ngành", date(2026,7,22), 14, "C1",
     "Tuân thủ Nghị định 13/2023 về dữ liệu cá nhân + nghị định TMĐT.", "Trung bình"),

    ("C3",  "C", "Đăng ký xử lý dữ liệu cá nhân với Cục An ninh mạng",
     "Chuyên gia ngành", date(2026,7,15), 60, "—",
     "Nộp hồ sơ đúng quy định Nghị định 13/2023.", "Cao"),

    ("C4",  "C", "Kiểm toán pháp lý mô hình môi giới bất động sản",
     "Luật sư + Chuyên gia ngành", date(2026,7,22), 21, "C1",
     "Xác nhận không vi phạm Luật Kinh doanh BĐS 2023.", "Trung bình"),

    ("C5",  "C", "Thuê đối tác xử lý thanh toán (để không cần giấy phép trung gian thanh toán)",
     "Chuyên gia ngành", date(2026,8,5),  30, "C2, D3",
     "Ký hợp đồng affiliate với MoMo/VNPay. Kết nối được môi trường thử nghiệm.", "Cao"),

    ("C6",  "C", "Thiết lập thuế và hoá đơn điện tử",
     "Kế toán", date(2026,9,4),  21, "C5",
     "Hoá đơn điện tử Viettel hoặc M-Invoice hoạt động.", "Trung bình"),

    ("C7",  "C", "Bảo hiểm trách nhiệm dân sự cho nền tảng",
     "Chuyên gia ngành", date(2026,8,12), 30, "C4",
     "Ký hợp đồng với Bảo Việt/PVI. Mức bồi thường 500 triệu - 1 tỷ/vụ.", "Trung bình"),

    ("C8",  "C", "Đăng ký sàn thương mại điện tử với Bộ Công Thương",
     "Chuyên gia ngành", date(2026,9,13), 45, "C3",
     "Nộp hồ sơ Cục Thương mại điện tử. Công bố trên online.gov.vn.", "Cao"),

    # D — Kinh doanh & Đối tác
    ("D1",  "D", "Khảo sát + phỏng vấn 20 chủ nhà tại HCM",
     "Founder + Chuyên gia ngành", date(2026,7,1),  21, "—",
     "Có báo cáo nghiên cứu: mức sẵn sàng trả tiền, vấn đề đau đầu, công cụ đang dùng.", "Trung bình"),

    ("D2",  "D", "Ký đối tác xác thực danh tính online (FPT.AI / VNPT)",
     "Chuyên gia ngành", date(2026,7,22), 21, "D1",
     "Kết nối được môi trường thử nghiệm. Đã chốt giá.", "Trung bình"),

    ("D3",  "D", "Ký đối tác cổng thanh toán (VNPay / MoMo)",
     "Chuyên gia ngành", date(2026,7,22), 30, "D1",
     "Đã ký hợp đồng affiliate.", "Cao"),

    ("D4",  "D", "Ký đối tác bảo hiểm tài sản",
     "Chuyên gia ngành", date(2026,8,12), 30, "D2",
     "Có báo giá từ Bảo Việt/PVI cho nhóm chủ nhà thử nghiệm.", "Trung bình"),

    ("D5",  "D", "Founder trực tiếp ký 10 chủ nhà đầu tiên (dùng thử miễn phí)",
     "Founder + Chuyên gia ngành", date(2026,8,21), 30, "D3, C1",
     "10 chủ nhà ký dùng thử. Đã hoàn tất quy trình tiếp nhận.", "Cao"),

    ("D6",  "D", "Ký biên bản hợp tác với Hiệp hội BĐS TP.HCM",
     "Chuyên gia ngành", date(2026,9,20), 21, "D5",
     "Ký 1 biên bản hợp tác. Có ưu đãi cho thành viên hiệp hội.", "Trung bình"),

    ("D7",  "D", "Bộ tài liệu đào tạo nhân viên kinh doanh + video",
     "Founder", date(2026,9,20), 14, "D5",
     "Có sổ tay bán hàng + 5 video đào tạo.", "Thấp"),

    ("D8",  "D", "Mở rộng lên 50 chủ nhà",
     "Đội Sales", date(2026,10,4), 45, "D7, E2",
     "50 chủ nhà trả phí hoặc đang dùng thử miễn phí.", "Trung bình"),

    ("D9",  "D", "Mở rộng lên 80 chủ nhà (mục tiêu cuối năm)",
     "Đội Sales", date(2026,11,18), 30, "D8",
     "80 chủ nhà tính đến cuối năm (đã giảm mục tiêu từ 100).", "Trung bình"),

    ("D11", "D", "Khảo sát phần mềm quản lý nhà trọ để bán module pháp lý (B2B)",
     "Chuyên gia ngành", date(2026,10,1), 45, "D5",
     "Có 1 thư đề nghị hợp tác từ 1 phần mềm quản lý (như Cohousing, Stayhub).", "Trung bình"),

    # E — Vận hành & Nhân sự
    ("E1",  "E", "Tuyển 1 Trưởng nhóm Chăm sóc khách hàng",
     "HR / Founder", date(2026,7,1),  30, "—",
     "Đã tiếp nhận và đào tạo xong.", "Trung bình"),

    ("E2",  "E", "Tuyển 1 Nhân viên Kinh doanh (lùi sang tháng 9)",
     "HR / Founder", date(2026,9,1),  30, "D5",
     "Tiếp nhận sau khi xong pilot. Đã có sổ tay bán hàng.", "Trung bình"),

    ("E3",  "E", "Cài công cụ chat hỗ trợ khách (Crisp hoặc Intercom)",
     "Trưởng nhóm CSKH", date(2026,7,31), 14, "E1",
     "Có 3 kênh: chat trên web, Zalo OA, email.", "Thấp"),

    ("E4",  "E", "Sổ tay xử lý sự cố + quy trình trực sự cố",
     "Lập trình viên 1", date(2026,8,14), 14, "E3",
     "Có lịch trực luân phiên. Cam kết phản hồi sự cố nghiêm trọng dưới 30 phút.", "Trung bình"),

    ("E5",  "E", "Tuyển 1 Designer giao diện (hợp đồng dự án)",
     "HR / Founder", date(2026,8,1),  21, "—",
     "Có Designer toàn thời gian hoặc theo giờ.", "Trung bình"),

    ("E6",  "E", "Tuyển 1 Nhân viên Kiểm thử (bán thời gian)",
     "HR / Founder", date(2026,9,1),  21, "—",
     "Có thể chạy kiểm thử hồi quy trước cột mốc M3.", "Trung bình"),

    ("E7",  "E", "Bộ tài liệu hướng dẫn chủ nhà + quy trình chuẩn",
     "Trưởng nhóm CSKH", date(2026,8,28), 21, "E4",
     "Có video hướng dẫn + FAQ + chuỗi email tự động.", "Thấp"),

    ("E8",  "E", "Bảng theo dõi chỉ số kinh doanh + họp tổng kết hàng tuần",
     "Founder + PM", date(2026,9,18), 14, "E7",
     "Dùng Notion + Metabase. Họp toàn công ty hàng tuần.", "Thấp"),

    ("E9",  "E", "Quan hệ công an khu vực (khai báo tạm trú + PCCC)",
     "Chuyên gia ngành", date(2026,9,18), 60, "E7",
     "Có người liên lạc tại công an quận. Hệ thống khai báo tạm trú tự động vượt qua kiểm tra.", "Trung bình"),
]

# ─── Cột mốc quan trọng ──────────────────────────────────────────────────────
MILESTONES = [
    ("M1", "Cổng thanh toán đi vào hoạt động chính thức",
     date(2026,8,10),  "A2, A3, C5, D3",
     "Chạy thử end-to-end: đặt phòng → thanh toán → hoá đơn đã thanh toán."),
    ("M2", "10 chủ nhà đầu tiên ký dùng thử miễn phí",
     date(2026,9,19),  "D5, C1",
     "10 chủ nhà hoàn tất tiếp nhận. Tính năng khai báo tạm trú tự động chạy được."),
    ("M3", "Ra mắt công khai tại TP.HCM",
     date(2026,10,5),  "A7, A8, B8, C2, C3",
     "Website công khai. 1 bài PR báo chí. Đạt 50,000 lượt khách truy cập."),
    ("M4", "100 phòng đang hiển thị trên sàn",
     date(2026,11,17), "D8, B5, B7",
     "100 phòng cho thuê được đăng công khai."),
    ("M5", "500 đơn đặt phòng + hoà vốn trên mỗi đơn",
     date(2026,12,15), "B10, A11",
     "Đạt 500 đơn đặt phòng. Chi phí thu hút khách < 1/3 giá trị vòng đời khách."),
    ("M6", "Hoàn tất gói pháp lý đầy đủ",
     date(2026,11,30), "C3, C7, C8, E9",
     "Đăng ký NĐ13. Có bảo hiểm. Đăng ký sàn TMĐT xong."),
    ("M7", "Đóng băng code và ổn định hệ thống dịp Tết",
     date(2026,12,15), "A12",
     "Đóng băng từ 15/12 đến 28/02/2027 vì Tết âm lịch."),
]

# ─── 5 Quyết định BẮT BUỘC chốt trong tuần đầu ───────────────────────────────
DECISIONS = [
    ("D-1", "Chốt phương án thanh toán cuối cùng",
     "Founder + Chuyên gia ngành",
     "01/07 → 04/07",
     "Chọn 1 trong 3: (a) Thu phí hoa hồng sau khi khách thuê / (b) Tài khoản trung gian ngân hàng / (c) Hợp đồng affiliate MoMo",
     "Trễ → chặn cả A2 và D3 → cột mốc M1 trượt 2-4 tuần"),

    ("D-2", "Có tuyển thêm lập trình viên hay không",
     "Founder",
     "01/07 → 07/07",
     "Chọn: (a) Tuyển 1 lập trình viên toàn thời gian thứ 2 / (b) Giữ 1 lập trình viên + dùng AI hỗ trợ",
     "Trễ → buộc phải hạ scope từ phương án B xuống C (giảm tính năng đáng kể)"),

    ("D-3", "Cách triển khai 10 chủ nhà đầu tiên",
     "Founder + Chuyên gia ngành",
     "01/07 → 05/07",
     "Chọn: (a) Founder trực tiếp đi tiếp cận từng người / (b) Tuyển nhân viên kinh doanh ngay từ tháng 7",
     "Trễ → mất 30-40 triệu tiền lương lãng phí + chất lượng pilot kém"),

    ("D-4", "Chiến lược thương hiệu",
     "Founder",
     "01/07 → 14/07",
     "Chọn: (a) Dùng 1 thương hiệu ancu365 (dài hạn) / (b) Tách thương hiệu 365Stay cho homestay / (c) Dual brand",
     "Trễ → các thông điệp marketing không nhất quán"),

    ("D-5", "Vai trò của chuyên gia ngành trong công ty",
     "Founder",
     "01/07 → 14/07",
     "Chọn: (a) Đồng sáng lập (có cổ phần ESOP) / (b) Cố vấn / (c) Trưởng nhóm kinh doanh",
     "Trễ → có thể tranh chấp tương lai khi exit"),
]

# ─── 3 Phương án scope ───────────────────────────────────────────────────────
SCENARIOS = [
    ("Phương án A — Tham vọng cao",
     "Làm hết 47 việc trong 6 tháng",
     "Có đủ thanh toán + quản lý kênh + định giá động + chiến dịch quý 4 đạt 1000 đơn",
     "Lập trình viên phải làm 70-80% công suất liên tục. Không có thời gian dự phòng. Cần ít nhất 3 lập trình viên.",
     "Trượt cột mốc M3 khoảng 50%",
     "KHÔNG khuyến nghị"),

    ("Phương án B — Thực tế (KHUYẾN NGHỊ)",
     "Bỏ bớt 30% việc không quan trọng. Tập trung vào con đường ngắn nhất tới ra mắt.",
     "Giữ được M1/M2/M3. Có thời gian dự phòng 30%. Đủ cho 2 lập trình viên. Quý 4 đạt 500 đơn.",
     "Mất khoảng 30% doanh thu tiềm năng quý 4 nhưng giữ chất lượng ra mắt.",
     "Khả thi với 2 lập trình viên toàn thời gian + công cụ AI hỗ trợ.",
     "KHUYẾN NGHỊ ✓"),

    ("Phương án C — Thận trọng",
     "Chỉ làm bản tối thiểu (MVP) để ra mắt. Bỏ phần bán phần mềm SaaS sang Q1/2027.",
     "Khả thi với 1 lập trình viên. Có dự phòng 40%. An toàn cho dịp Tết.",
     "Mất 50% doanh thu tiềm năng quý 4. Không có doanh thu từ SaaS đến quý 1/2027.",
     "Có thể thực hiện được",
     "Phương án dự phòng nếu không tuyển được lập trình viên thứ 2"),
]

# ─── Ngân sách ước lượng cho 6 tháng ─────────────────────────────────────────
BUDGET = [
    ("Lương 2 lập trình viên toàn thời gian", "Kỹ thuật",
     "60-90 triệu/tháng", "30-45 triệu/người (cấp trung-cao). Trong 6 tháng."),

    ("Lương Trưởng nhóm Chăm sóc khách hàng", "Vận hành",
     "18-25 triệu/tháng", "Cấp trung. Từ tháng 7."),

    ("Lương Nhân viên Kinh doanh (từ tháng 9)", "Kinh doanh",
     "15-22 triệu/tháng + hoa hồng",
     "4 tháng = 60-88 triệu tiền lương cơ bản."),

    ("Designer giao diện (hợp đồng dự án)", "Thiết kế",
     "30-50 triệu/tháng", "3 tháng theo giờ hoặc theo dự án."),

    ("Nhân viên Kiểm thử bán thời gian (từ tháng 9)", "Kiểm thử",
     "8-12 triệu/tháng", "4 tháng."),

    ("Cộng tác viên viết bài SEO", "Marketing",
     "10-15 triệu/tháng", "15 bài × 600,000 - 1 triệu/bài."),

    ("Đội Video AI", "Marketing",
     "30-50 triệu/tháng", "10 video × 3-5 triệu/video."),

    ("Quảng cáo trả phí (Facebook/TikTok/Google)", "Marketing",
     "30-100 triệu/tháng",
     "Thử nghiệm 30 triệu/tháng → 100 triệu/tháng cho chiến dịch quý 4."),

    ("Chi phí luật sư + review pháp lý", "Pháp lý",
     "100-200 triệu (1 lần)", "Cho các hạng mục C1+C2+C4 + audit."),

    ("Bảo hiểm trách nhiệm nền tảng", "Pháp lý",
     "30-50 triệu/năm", "Bảo Việt/PVI - mức 500 triệu đến 1 tỷ/vụ."),

    ("Công cụ chat khách hàng (Crisp/Intercom)", "Vận hành",
     "3-8 triệu/tháng", "Bắt đầu bằng gói miễn phí → nâng cấp khi scale."),

    ("Hạ tầng đám mây (GCP/AWS)", "Kỹ thuật",
     "10-30 triệu/tháng", "Cơ sở dữ liệu + lưu ảnh + CDN. Tăng theo lượng truy cập."),

    ("Công cụ khác (Figma, Google Analytics, v.v.)", "Chung",
     "3-5 triệu/tháng", "Phí thuê bao tổng hợp."),

    ("TỔNG ƯỚC TÍNH 6 THÁNG", "Tất cả",
     "Khoảng 1.2 - 1.8 tỷ VND",
     "Trung vị 1.5 tỷ - cần chuẩn bị đủ trước cột mốc M2."),
]

# ─── Bắt đầu tạo file Excel ──────────────────────────────────────────────────
wb = Workbook()

# ════════════ Sheet 1: Biểu đồ Gantt ════════════
ws = wb.active
ws.title = "1. Biểu đồ Gantt"
ws.freeze_panes = "G5"

# Hàng 1: tiêu đề
ws.merge_cells("A1:Z1")
ws["A1"] = "ancu365 — Lộ trình 6 tháng (Tháng 7/2026 → Tháng 12/2026)"
ws["A1"].font = Font(bold=True, size=14, color="FFFFFF")
ws["A1"].fill = HEADER_FILL
ws["A1"].alignment = Alignment(horizontal="center", vertical="center")
ws.row_dimensions[1].height = 28

# Hàng 3: tiêu đề cột cố định
fixed_cols = ["Mã", "Nhóm", "Tên công việc", "Người phụ trách", "Ngày bắt đầu", "Ngày kết thúc"]
for c, label in enumerate(fixed_cols, 1):
    cell = ws.cell(row=3, column=c, value=label)
    cell.font = HEADER_FONT
    cell.fill = HEADER_FILL
    cell.alignment = Alignment(horizontal="center", vertical="center")
    cell.border = BORDER

# Chia thành tuần (26 tuần)
WEEK_START_COL = len(fixed_cols) + 1  # cột 7 = G
weeks = []
w = START
while w <= END:
    weeks.append(w)
    w += timedelta(days=7)
TOTAL_WEEKS = len(weeks)

# Merge cột tháng
month_groups = {}
for idx, wk in enumerate(weeks):
    month_groups.setdefault(wk.month, []).append(idx)

MONTH_LABELS_VI = {
    7: "Tháng 7/2026", 8: "Tháng 8/2026", 9: "Tháng 9/2026",
    10: "Tháng 10/2026", 11: "Tháng 11/2026", 12: "Tháng 12/2026",
}

for m in sorted(month_groups.keys()):
    indices = month_groups[m]
    start_col = WEEK_START_COL + indices[0]
    end_col = WEEK_START_COL + indices[-1]
    ws.merge_cells(start_row=3, start_column=start_col, end_row=3, end_column=end_col)
    cell = ws.cell(row=3, column=start_col, value=MONTH_LABELS_VI[m])
    cell.font = HEADER_FONT
    cell.fill = HEADER_FILL
    cell.alignment = Alignment(horizontal="center", vertical="center")
    cell.border = BORDER

# Hàng 4: tiêu đề tuần (ngày bắt đầu tuần)
for idx, wk in enumerate(weeks):
    cell = ws.cell(row=4, column=WEEK_START_COL + idx, value=wk.strftime("%d/%m"))
    cell.font = Font(bold=True, size=9)
    cell.fill = PatternFill("solid", fgColor="D9E1F2")
    cell.alignment = Alignment(horizontal="center", vertical="center")
    cell.border = BORDER

# Nhóm việc theo section
SECTION_LABEL = {
    "A": "A. Sản phẩm & Kỹ thuật",
    "B": "B. Marketing (Video AI + Tăng trưởng)",
    "C": "C. Pháp lý & Tuân thủ",
    "D": "D. Kinh doanh & Đối tác",
    "E": "E. Vận hành & Nhân sự",
}

row = 5
for sec_key in ["A", "B", "C", "D", "E"]:
    # Hàng phân cách nhóm
    ws.merge_cells(start_row=row, start_column=1, end_row=row, end_column=WEEK_START_COL + TOTAL_WEEKS - 1)
    cell = ws.cell(row=row, column=1, value=SECTION_LABEL[sec_key])
    cell.font = Font(bold=True, size=11, color="FFFFFF")
    cell.fill = PatternFill("solid", fgColor=SECTION_COLORS[sec_key])
    cell.alignment = Alignment(horizontal="left", vertical="center", indent=1)
    ws.row_dimensions[row].height = 22
    row += 1

    for t in TASKS:
        tid, sec, name, owner, start, dur, dep, ac, risk = t
        if sec != sec_key:
            continue
        end_d = start + timedelta(days=dur)
        ws.cell(row=row, column=1, value=tid).font = Font(bold=True)
        ws.cell(row=row, column=2, value=sec).alignment = Alignment(horizontal="center")
        ws.cell(row=row, column=3, value=name)
        ws.cell(row=row, column=4, value=owner)
        ws.cell(row=row, column=5, value=start.strftime("%d/%m/%Y"))
        ws.cell(row=row, column=6, value=end_d.strftime("%d/%m/%Y"))
        for c in range(1, 7):
            ws.cell(row=row, column=c).border = BORDER

        # Tô thanh tiến độ theo tuần
        bar_fill = PatternFill("solid", fgColor=SECTION_COLORS[sec])
        for idx, wk in enumerate(weeks):
            wk_end = wk + timedelta(days=6)
            if start <= wk_end and end_d >= wk:
                cell = ws.cell(row=row, column=WEEK_START_COL + idx, value="")
                cell.fill = bar_fill
                cell.border = BORDER
            else:
                ws.cell(row=row, column=WEEK_START_COL + idx).border = BORDER
        row += 1

# Hàng mốc quan trọng
ws.merge_cells(start_row=row, start_column=1, end_row=row, end_column=WEEK_START_COL + TOTAL_WEEKS - 1)
cell = ws.cell(row=row, column=1, value="★ CÁC CỘT MỐC QUAN TRỌNG")
cell.font = Font(bold=True, size=11, color="000000")
cell.fill = PatternFill("solid", fgColor=SECTION_COLORS["M"])
cell.alignment = Alignment(horizontal="left", vertical="center", indent=1)
ws.row_dimensions[row].height = 22
row += 1

for mid, mname, mdate, mdep, mac in MILESTONES:
    ws.cell(row=row, column=1, value=mid).font = Font(bold=True)
    ws.cell(row=row, column=3, value=mname)
    ws.cell(row=row, column=5, value=mdate.strftime("%d/%m/%Y"))
    for c in range(1, 7):
        ws.cell(row=row, column=c).border = BORDER
    for idx, wk in enumerate(weeks):
        wk_end = wk + timedelta(days=6)
        if wk <= mdate <= wk_end:
            cell = ws.cell(row=row, column=WEEK_START_COL + idx, value="★")
            cell.fill = PatternFill("solid", fgColor=SECTION_COLORS["M"])
            cell.font = Font(bold=True, size=14)
            cell.alignment = Alignment(horizontal="center", vertical="center")
        cell = ws.cell(row=row, column=WEEK_START_COL + idx)
        cell.border = BORDER
    row += 1

# Độ rộng cột
ws.column_dimensions["A"].width = 6
ws.column_dimensions["B"].width = 7
ws.column_dimensions["C"].width = 55
ws.column_dimensions["D"].width = 24
ws.column_dimensions["E"].width = 13
ws.column_dimensions["F"].width = 13
for idx in range(TOTAL_WEEKS):
    ws.column_dimensions[get_column_letter(WEEK_START_COL + idx)].width = 5

# ════════════ Sheet 2: Chi tiết công việc ════════════
ws2 = wb.create_sheet("2. Chi tiết công việc")
ws2.freeze_panes = "A2"
headers2 = ["Mã", "Nhóm", "Tên công việc", "Người phụ trách",
            "Ngày bắt đầu", "Ngày kết thúc", "Số ngày", "Phụ thuộc việc nào",
            "Tiêu chí hoàn thành", "Mức rủi ro"]
for c, h in enumerate(headers2, 1):
    cell = ws2.cell(row=1, column=c, value=h)
    cell.font = HEADER_FONT
    cell.fill = HEADER_FILL
    cell.alignment = Alignment(horizontal="center", vertical="center")
    cell.border = BORDER

row = 2
for t in TASKS:
    tid, sec, name, owner, start, dur, dep, ac, risk = t
    end_d = start + timedelta(days=dur)
    values = [tid, sec, name, owner,
              start.strftime("%d/%m/%Y"), end_d.strftime("%d/%m/%Y"),
              dur, dep, ac, risk]
    for c, v in enumerate(values, 1):
        cell = ws2.cell(row=row, column=c, value=v)
        cell.border = BORDER
        if c == 10:
            cell.fill = RISK_FILLS.get(risk, PatternFill())
            cell.alignment = Alignment(horizontal="center", vertical="center")
            cell.font = Font(bold=True)
    row += 1

for col, w in zip("ABCDEFGHIJ", [6, 8, 50, 24, 13, 13, 9, 14, 60, 14]):
    ws2.column_dimensions[col].width = w
for r in range(2, row):
    ws2.row_dimensions[r].height = 38
    ws2.cell(row=r, column=9).alignment = Alignment(wrap_text=True, vertical="top")
    ws2.cell(row=r, column=3).alignment = Alignment(wrap_text=True, vertical="center")

# ════════════ Sheet 3: Các cột mốc ════════════
ws3 = wb.create_sheet("3. Các cột mốc")
ws3.freeze_panes = "A2"
headers3 = ["Mã", "Cột mốc", "Ngày mục tiêu", "Phụ thuộc việc nào", "Tiêu chí hoàn thành"]
for c, h in enumerate(headers3, 1):
    cell = ws3.cell(row=1, column=c, value=h)
    cell.font = HEADER_FONT
    cell.fill = HEADER_FILL
    cell.alignment = Alignment(horizontal="center", vertical="center")
    cell.border = BORDER

row = 2
for mid, mname, mdate, mdep, mac in MILESTONES:
    values = [mid, mname, mdate.strftime("%d/%m/%Y"), mdep, mac]
    for c, v in enumerate(values, 1):
        cell = ws3.cell(row=row, column=c, value=v)
        cell.border = BORDER
        if c == 1:
            cell.font = Font(bold=True, size=12)
            cell.fill = PatternFill("solid", fgColor=SECTION_COLORS["M"])
            cell.alignment = Alignment(horizontal="center", vertical="center")
    ws3.row_dimensions[row].height = 32
    row += 1

for col, w in zip("ABCDE", [8, 55, 16, 22, 60]):
    ws3.column_dimensions[col].width = w
for r in range(2, row):
    ws3.cell(row=r, column=2).alignment = Alignment(wrap_text=True, vertical="center")
    ws3.cell(row=r, column=5).alignment = Alignment(wrap_text=True, vertical="center")

# ════════════ Sheet 4: 5 Quyết định tuần đầu ════════════
ws4 = wb.create_sheet("4. Quyết định tuần đầu")
ws4.freeze_panes = "A2"
headers4 = ["Mã", "Cần quyết định gì", "Ai chốt", "Hạn chót",
            "Các lựa chọn", "Hậu quả nếu trễ"]
for c, h in enumerate(headers4, 1):
    cell = ws4.cell(row=1, column=c, value=h)
    cell.font = HEADER_FONT
    cell.fill = HEADER_FILL
    cell.alignment = Alignment(horizontal="center", vertical="center")
    cell.border = BORDER

row = 2
for d in DECISIONS:
    for c, v in enumerate(d, 1):
        cell = ws4.cell(row=row, column=c, value=v)
        cell.border = BORDER
        cell.alignment = Alignment(wrap_text=True, vertical="top")
        if c == 1:
            cell.font = Font(bold=True)
            cell.fill = PatternFill("solid", fgColor="FFC7CE")
            cell.alignment = Alignment(horizontal="center", vertical="center")
    ws4.row_dimensions[row].height = 60
    row += 1

for col, w in zip("ABCDEF", [8, 36, 24, 18, 55, 50]):
    ws4.column_dimensions[col].width = w

# ════════════ Sheet 5: 3 Phương án scope ════════════
ws5 = wb.create_sheet("5. Các phương án scope")
ws5.freeze_panes = "A2"
headers5 = ["Phương án", "Phạm vi công việc", "Ưu điểm", "Nhược điểm",
            "Khả năng làm được", "Khuyến nghị"]
for c, h in enumerate(headers5, 1):
    cell = ws5.cell(row=1, column=c, value=h)
    cell.font = HEADER_FONT
    cell.fill = HEADER_FILL
    cell.alignment = Alignment(horizontal="center", vertical="center")
    cell.border = BORDER

row = 2
for s in SCENARIOS:
    for c, v in enumerate(s, 1):
        cell = ws5.cell(row=row, column=c, value=v)
        cell.border = BORDER
        cell.alignment = Alignment(wrap_text=True, vertical="top")
        if c == 6 and "KHUYẾN NGHỊ" in v:
            cell.fill = PatternFill("solid", fgColor="C6EFCE")
            cell.font = Font(bold=True)
        elif c == 6 and "KHÔNG" in v:
            cell.fill = PatternFill("solid", fgColor="FFC7CE")
        if c == 1:
            cell.font = Font(bold=True, size=11)
    ws5.row_dimensions[row].height = 100
    row += 1

for col, w in zip("ABCDEF", [36, 42, 42, 42, 26, 22]):
    ws5.column_dimensions[col].width = w

# ════════════ Sheet 6: Ngân sách ════════════
ws6 = wb.create_sheet("6. Ngân sách dự kiến")
ws6.freeze_panes = "A2"
headers6 = ["Hạng mục", "Bộ phận", "Chi phí ước lượng", "Ghi chú"]
for c, h in enumerate(headers6, 1):
    cell = ws6.cell(row=1, column=c, value=h)
    cell.font = HEADER_FONT
    cell.fill = HEADER_FILL
    cell.alignment = Alignment(horizontal="center", vertical="center")
    cell.border = BORDER

row = 2
for b in BUDGET:
    for c, v in enumerate(b, 1):
        cell = ws6.cell(row=row, column=c, value=v)
        cell.border = BORDER
        cell.alignment = Alignment(wrap_text=True, vertical="center")
        if "TỔNG" in b[0]:
            cell.font = Font(bold=True, size=12)
            cell.fill = PatternFill("solid", fgColor="FFEB9C")
    ws6.row_dimensions[row].height = 30
    row += 1

for col, w in zip("ABCD", [42, 18, 30, 55]):
    ws6.column_dimensions[col].width = w

# ════════════ Sheet 7: Bản đồ công suất nhân sự ════════════
ws7 = wb.create_sheet("7. Công suất nhân sự")
ws7.freeze_panes = "B2"
ws7["A1"] = "Tỷ lệ công suất sử dụng (%)"
ws7["A1"].font = HEADER_FONT
ws7["A1"].fill = HEADER_FILL
ws7["A1"].alignment = Alignment(horizontal="center", vertical="center")

months_label = ["T7", "T8", "T9", "T10", "T11", "T12"]
for c, m in enumerate(months_label, 2):
    cell = ws7.cell(row=1, column=c, value=m)
    cell.font = HEADER_FONT
    cell.fill = HEADER_FILL
    cell.alignment = Alignment(horizontal="center", vertical="center")
    cell.border = BORDER

ws7["A2"] = "2 lập trình viên (40 điểm/sprint)"
ws7["A2"].font = Font(bold=True)
loads = [48, 70, 50, 70, 60, 45]
for c, val in enumerate(loads, 2):
    cell = ws7.cell(row=2, column=c, value=f"{val}%")
    if val < 50:
        cell.fill = PatternFill("solid", fgColor="C6EFCE")
    elif val < 75:
        cell.fill = PatternFill("solid", fgColor="FFEB9C")
    else:
        cell.fill = PatternFill("solid", fgColor="FFC7CE")
    cell.alignment = Alignment(horizontal="center", vertical="center")
    cell.border = BORDER
    cell.font = Font(bold=True, size=12)

ws7["A3"] = "Đội Video AI (8-12 video/tháng)"
ws7["A3"].font = Font(bold=True)
video_loads = [50, 100, 100, 80, 130, 130]
for c, val in enumerate(video_loads, 2):
    cell = ws7.cell(row=3, column=c, value=f"{val}%")
    if val <= 80:
        cell.fill = PatternFill("solid", fgColor="C6EFCE")
    elif val <= 100:
        cell.fill = PatternFill("solid", fgColor="FFEB9C")
    else:
        cell.fill = PatternFill("solid", fgColor="FFC7CE")
    cell.alignment = Alignment(horizontal="center", vertical="center")
    cell.border = BORDER
    cell.font = Font(bold=True, size=12)

# Ghi chú
ws7["A5"] = ("Ghi chú: Quý 4 (tháng 11+12) cần dồn video AI → đặt thêm công suất hoặc "
             "thuê đối tác phụ. Đóng băng code 15/12 → giảm tải cho lập trình viên.")
ws7["A5"].font = Font(italic=True, color="606060")
ws7.merge_cells("A5:G5")
ws7.row_dimensions[5].height = 36
ws7["A5"].alignment = Alignment(wrap_text=True, vertical="center")

ws7["A7"] = "CHÚ THÍCH MÀU:"
ws7["A7"].font = Font(bold=True)
ws7["A8"] = "Xanh lá = Đủ công suất, làm thoải mái (<50% với dev, ≤80% với video)"
ws7["A8"].fill = PatternFill("solid", fgColor="C6EFCE")
ws7["A9"] = "Vàng = Sát giới hạn, cần theo dõi (50-75% với dev, 81-100% với video)"
ws7["A9"].fill = PatternFill("solid", fgColor="FFEB9C")
ws7["A10"] = "Đỏ = Quá tải, cần giảm việc hoặc tăng người (>75% với dev, >100% với video)"
ws7["A10"].fill = PatternFill("solid", fgColor="FFC7CE")

for col in "ABCDEFG":
    ws7.column_dimensions[col].width = 36 if col == "A" else 12

# ════════════ Sheet 0 (đầu tiên): Hướng dẫn đọc ════════════
ws8 = wb.create_sheet("0. Hướng dẫn đọc", 0)
readme_lines = [
    ("ancu365 — Lộ trình Kinh doanh & Sản phẩm 6 tháng", "title"),
    ("", ""),
    ("Nguồn: plans/260628-2300-business-product-roadmap/", "meta"),
    ("Kết luận: CHẤP NHẬN CÓ ĐIỀU KIỆN (Mức độ sẵn sàng 63.5/100)", "meta"),
    ("Khuyến nghị scope: Phương án B (Thực tế)", "meta"),
    ("Con đường ngắn nhất tới ra mắt: D3 → A2 → A3 → M3 (14 tuần, tháng 7-10)", "meta"),
    ("", ""),
    ("HƯỚNG DẪN ĐỌC TỪNG SHEET", "h2"),
    ("", ""),
    ("Sheet 1 — Biểu đồ Gantt: hình ảnh trực quan 47 công việc và 7 cột mốc trên trục thời gian 26 tuần.", "p"),
    ("    Mỗi nhóm việc có màu riêng:", "p"),
    ("        Xanh dương = Sản phẩm & Kỹ thuật", "p"),
    ("        Cam        = Marketing", "p"),
    ("        Xanh lá    = Pháp lý", "p"),
    ("        Tím        = Kinh doanh & Đối tác", "p"),
    ("        Đỏ         = Vận hành & Nhân sự", "p"),
    ("    Ngôi sao ★ = thời điểm phải đạt cột mốc.", "p"),
    ("", ""),
    ("Sheet 2 — Chi tiết công việc: liệt kê đầy đủ 47 việc với người phụ trách, "
     "việc nó phụ thuộc, tiêu chí hoàn thành và mức rủi ro.", "p"),
    ("    Mức rủi ro:", "p"),
    ("        Xanh = Thấp (làm bình thường)", "p"),
    ("        Vàng = Trung bình (cần theo dõi)", "p"),
    ("        Đỏ   = Cao (phải có phương án dự phòng trước khi bắt đầu)", "p"),
    ("", ""),
    ("Sheet 3 — Các cột mốc: 7 cột mốc quan trọng nhất, dùng làm điểm kiểm tra chính.", "p"),
    ("", ""),
    ("Sheet 4 — Quyết định tuần đầu: 5 quyết định BẮT BUỘC phải chốt trong tuần 01/07 → 07/07.", "p"),
    ("    Trễ 1 quyết định = chặn cả hệ thống → đọc kỹ trước cuộc họp Founder + Chuyên gia ngành.", "p"),
    ("", ""),
    ("Sheet 5 — Các phương án scope: 3 phương án A/B/C, khuyến nghị Phương án B (Thực tế).", "p"),
    ("", ""),
    ("Sheet 6 — Ngân sách dự kiến: chi phí 6 tháng theo hạng mục. Tổng khoảng 1.2-1.8 tỷ VND.", "p"),
    ("", ""),
    ("Sheet 7 — Công suất nhân sự: % công suất sử dụng của lập trình viên và đội video AI theo tháng.", "p"),
    ("    Đỏ = quá tải, vàng = sát giới hạn, xanh = thoải mái.", "p"),
    ("", ""),
    ("3 FILE TÀI LIỆU ĐI KÈM (xem chi tiết hơn):", "h2"),
    ("", ""),
    ("•  phase-00-market-strategy.md  — Phân tích thị trường, khách hàng mục tiêu, mô hình kinh doanh, rủi ro", "p"),
    ("•  phase-01-gantt-timeline.md   — Biểu đồ Gantt dạng Mermaid, công suất, phụ thuộc, phương án", "p"),
    ("•  recommendations.md           — Phân tích codebase + 7 đề xuất bổ sung", "p"),
    ("", ""),
    ("4 ĐỀ XUẤT QUAN TRỌNG NHẤT:", "h2"),
    ("", ""),
    ("1. Đừng cạnh tranh trực tiếp với Mogi/Phongtro123 — chọn ngách 'chỉ phòng đã xác minh + "
     "khai báo tạm trú tự động + tra cứu quy hoạch'.", "p"),
    ("2. Founder phải tự đi tiếp cận 10 chủ nhà đầu tiên — KHÔNG giao cho Sales "
     "(lùi tuyển Sales sang tháng 9).", "p"),
    ("3. Bán module pháp lý (khai báo tạm trú + tra cứu quy hoạch) cho 1-2 phần mềm quản lý nhà trọ "
     "hiện có (Cohousing, Stayhub) - tạo doanh thu B2B.", "p"),
    ("4. Đóng băng code + dừng marketing từ 15/12/2026 đến 28/02/2027 vì Tết âm lịch. "
     "Đặt mục tiêu cuối năm là 500 đơn đặt phòng (giảm từ 1000).", "p"),
    ("", ""),
    ("BƯỚC TIẾP THEO:", "h2"),
    ("", ""),
    ("1. Founder + Chuyên gia ngành dành 90 phút đọc 3 file tài liệu kèm + file Excel này.", "p"),
    ("2. Trả lời 15 câu hỏi còn bỏ ngỏ (10 trong phase-00 + 5 trong recommendations).", "p"),
    ("3. Sau đó chạy lại quy trình lập kế hoạch để chốt phương án cuối cùng + ngân sách cam kết.", "p"),
    ("", ""),
    ("GIẢI THÍCH CÁC TỪ KHÓ DÙNG TRONG FILE:", "h2"),
    ("", ""),
    ("•  SEO              = Tối ưu hoá để lên top Google khi người dùng tìm kiếm", "p"),
    ("•  CCCD             = Căn cước công dân", "p"),
    ("•  PR               = Báo chí, truyền thông", "p"),
    ("•  Founder          = Người sáng lập công ty", "p"),
    ("•  MVP              = Phiên bản tối thiểu khả dụng (chỉ làm tính năng cốt lõi)", "p"),
    ("•  SaaS             = Phần mềm cho thuê theo tháng", "p"),
    ("•  Sprint           = Chu kỳ làm việc 2 tuần của lập trình viên", "p"),
    ("•  Pilot            = Giai đoạn thử nghiệm với khách hàng đầu tiên", "p"),
    ("•  Onboarding       = Quy trình tiếp nhận khách hàng mới / nhân viên mới", "p"),
    ("•  ESOP             = Cổ phần thưởng cho nhân viên", "p"),
    ("•  PCCC             = Phòng cháy chữa cháy", "p"),
    ("•  TMĐT             = Thương mại điện tử", "p"),
    ("•  Nghị định 13/2023 = Quy định về bảo vệ dữ liệu cá nhân", "p"),
    ("•  Affiliate         = Hợp đồng liên kết, mình bán thay đối tác và ăn hoa hồng", "p"),
    ("•  B2B/B2C/B2B2C    = B2B: bán cho doanh nghiệp; B2C: bán cho người tiêu dùng; "
     "B2B2C: bán qua doanh nghiệp khác để tới người tiêu dùng", "p"),
    ("•  KPI              = Chỉ số đánh giá hiệu quả công việc", "p"),
    ("•  CAC              = Chi phí thu hút 1 khách hàng", "p"),
    ("•  LTV              = Giá trị 1 khách hàng tạo ra trong suốt vòng đời", "p"),
    ("•  ROAS             = Tỷ lệ doanh thu thu về so với tiền quảng cáo bỏ ra", "p"),
    ("•  CTR              = Tỷ lệ người nhấp vào quảng cáo", "p"),
    ("•  CPM              = Chi phí để hiển thị quảng cáo 1000 lần", "p"),
]

ws8.column_dimensions["A"].width = 115
for r, (text, style) in enumerate(readme_lines, 1):
    cell = ws8.cell(row=r, column=1, value=text)
    if style == "title":
        cell.font = Font(bold=True, size=16, color="FFFFFF")
        cell.fill = HEADER_FILL
        cell.alignment = Alignment(horizontal="center", vertical="center")
        ws8.row_dimensions[r].height = 32
    elif style == "h2":
        cell.font = Font(bold=True, size=12, color="1F4E78")
        cell.fill = PatternFill("solid", fgColor="D9E1F2")
        ws8.row_dimensions[r].height = 22
    elif style == "meta":
        cell.font = Font(italic=True, size=11)
    else:
        cell.alignment = Alignment(wrap_text=True, vertical="center")
        ws8.row_dimensions[r].height = 20

# Lưu file
out_path = "/Users/ducld/Documents/work/02.duc/16.ancu365/ancu365-app/plans/260628-2300-business-product-roadmap/ancu365-6month-roadmap.xlsx"
wb.save(out_path)
print(f"Đã lưu: {out_path}")
print(f"Các sheet: {wb.sheetnames}")
print(f"Tổng số công việc: {len(TASKS)}")
print(f"Tổng số cột mốc: {len(MILESTONES)}")
