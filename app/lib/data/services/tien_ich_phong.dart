/// Danh mục tiện ích của phòng — bản sao NHÃN của `app/services/tien_ich_phong.py`.
///
/// Hai danh sách, cố ý không gộp:
///
///     dichVuGom      phí dịch vụ hàng tháng BAO GỒM gì
///     doTrongPhong   phòng có sẵn ĐỒ gì, không tính tiền
///
/// Gộp làm một thì không trả lời được "trả tiền dịch vụ để lấy cái gì" — máy
/// giặt chung ở tầng trệt (nằm trong phí dịch vụ) khác hẳn máy giặt riêng trong
/// phòng, mà tên gọi thì y hệt nhau.
///
/// App chỉ giữ NHÃN; danh sách key hợp lệ do server quyết. Key server chưa biết
/// bị loại im lặng chứ không báo lỗi, nên app mới hơn server vẫn dùng được.
library;

/// Phí dịch vụ hàng tháng bao gồm những gì.
const Map<String, String> kDichVuGom = {
  'gui_xe': 'Gửi xe',
  'rac': 'Rác',
  'internet': 'Internet / wifi',
  'thang_may': 'Thang máy',
  've_sinh': 'Vệ sinh chung',
  'bao_ve': 'Bảo vệ / an ninh',
  'nuoc_nong': 'Nước nóng trung tâm',
};

/// Đồ có sẵn trong phòng, không tính tiền riêng.
const Map<String, String> kDoTrongPhong = {
  'giuong': 'Giường',
  'tu_quan_ao': 'Tủ quần áo',
  'ban_ghe': 'Bàn ghế',
  'dieu_hoa': 'Điều hoà',
  'nong_lanh': 'Bình nóng lạnh',
  'may_giat': 'Máy giặt',
  'tu_lanh': 'Tủ lạnh',
  'bep': 'Bếp',
  'gac_xep': 'Gác xép',
  'ban_cong': 'Ban công',
  'wc_rieng': 'Vệ sinh khép kín',
};

/// Key → nhãn, bỏ qua key lạ (server có thể biết nhiều hơn app).
List<String> tenTienIch(Iterable<String> keys, Map<String, String> tu) =>
    [for (final k in keys) if (tu.containsKey(k)) tu[k]!];
