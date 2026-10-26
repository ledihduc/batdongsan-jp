import 'package:house_booking/features/sale/hoat_dong/widgets/sale_ui.dart';

/// Chữ + tông của nhãn trạng thái trên mọi màn sale — một chỗ duy nhất để
/// thẻ danh sách, màn chi tiết và tổng quan nói cùng một chữ.

/// Lịch xem / đơn đặt phòng (màn 5, chi tiết).
(String, String) nhanLich(String nhan) => switch (nhan) {
  'cho_xac_nhan' => ('Chờ xác nhận', 'cam'),
  'cho_khach_chon_gio' => ('Chờ khách chọn giờ', 'cam'),
  'da_xac_nhan' => ('Đã xác nhận', 'xanh'),
  'da_xem' => ('Đã xem', 'xanh'),
  'da_chot' => ('Đã chốt', 'tim'),
  'khong_chot' => ('Không chốt', 'xam'),
  'het_han' => ('Hết hạn', 'xam'),
  'da_huy' => ('Đã hủy', 'do'),
  // Ngắn hạn
  'cho_chu_xac_nhan' => ('Chờ chủ xác nhận', 'cam'),
  'dang_o' => ('Đang ở', 'lam'),
  'da_tra_phong' => ('Đã trả phòng', 'xam'),
  _ => (nhan, 'xam'),
};

/// Bài đăng (màn 4).
(String, String) nhanBaiDang(String tt, String kenh) => switch (tt) {
  'dang_dang' => ('Đang đăng', 'xanh'),
  'co_lich_xem' => (kenh == kKenhNganHan ? 'Có đơn đặt' : 'Có lịch xem', 'do'),
  'cho_chot' => (kenh == kKenhNganHan ? 'Chờ xác nhận' : 'Chờ chốt', 'cam'),
  'da_dong' => ('Đã đóng', 'xam'),
  'da_an' => ('Đã ẩn', 'xam'),
  'cho_duyet' => ('Chờ duyệt', 'cam'),
  'bi_tu_choi' => ('Bị từ chối', 'do'),
  _ => (tt, 'xam'),
};

/// Khách (màn 6) — màu chữ của trạng thái ngay dưới tên.
(String, String) nhanKhach(String tt) => switch (tt) {
  'moi' => ('Mới', 'lam'),
  'dang_tu_van' => ('Đang tư vấn', 'xanh'),
  'da_xem' => ('Đã xem', 'xam'),
  'cho_chot' => ('Chờ chốt', 'cam'),
  'da_chot' => ('Đã chốt', 'tim'),
  'sap_den' => ('Sắp đến', 'lam'),
  'dang_o' => ('Đang ở', 'xanh'),
  'da_o' => ('Đã ở', 'xam'),
  _ => (tt, 'xam'),
};

/// Phòng (màn 8).
(String, String) nhanPhong(String tt) => switch (tt) {
  'trong' => ('Trống', 'xanh'),
  'co_lich_xem' => ('Có lịch xem', 'do'),
  'dang_thue' => ('Đang thuê', 'xanh'),
  'bao_tri' => ('Bảo trì', 'xam'),
  _ => (tt, 'xam'),
};

/// Hợp đồng (màn 9).
(String, String) nhanHopDong(String nhan) => switch (nhan) {
  'cho_chu_xac_nhan' => ('Chờ chủ xác nhận', 'cam'),
  'dang_ky_hop_dong' => ('Đang ký hợp đồng', 'xanh'),
  'hoan_tat' => ('Hoàn tất', 'xanh'),
  'da_ket_thuc' => ('Đã kết thúc', 'xam'),
  _ => (nhan, 'xam'),
};
