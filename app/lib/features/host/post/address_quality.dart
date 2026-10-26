/// Đánh giá chất lượng địa chỉ do reverse geocode trả về.
///
/// Tách khỏi `post_house_screen.dart` để test được: màn đăng tin là god-file
/// phụ thuộc bản đồ + image picker + mạng nên rất khó dựng trong widget test,
/// còn quy tắc dưới đây là logic thuần, sai là người dùng đăng tin không có
/// số nhà và không ai tìm thấy.
library;

final _danhTuDuong =
    RegExp(r'(đường|phố|ngõ|hẻm|quốc lộ|tỉnh lộ|đại lộ)', caseSensitive: false);
final _batDauBangSo = RegExp(r'^\s*\d');

/// BẪY: "Thành phố Cần Thơ" chứa chữ "phố" nên bộ nhận dạng tên đường sẽ tưởng
/// địa chỉ đã có đường — trong khi đây chỉ là cấp tỉnh. Cắt các cụm chỉ đơn vị
/// hành chính TRƯỚC khi dò danh từ chỉ đường. (Test bắt được ca này.)
final _capHanhChinh =
    RegExp(r'(thành phố|tp\.?\s|thị xã|thị trấn)', caseSensitive: false);

/// Địa chỉ có "thô" không — tức chỉ tới cấp phường/xã, thiếu số nhà và tên đường?
///
/// Dữ liệu OSM ở đô thị VN thường có số nhà + tên đường; ở vùng ven/nông thôn
/// thường chỉ có phường/tỉnh. Khi thô thì phải nhắc chủ nhà bổ sung.
///
/// Coi là ĐỦ CHI TIẾT khi có ÍT NHẤT MỘT trong hai dấu hiệu:
///   - bắt đầu bằng số (số nhà: "63 Lý Tự Trọng..."), hoặc
///   - có danh từ chỉ đường ("Đường", "Phố", "Hẻm"...).
bool laDiaChiTho(String diaChi) {
  if (diaChi.trim().isEmpty) return true;
  final khongCapHanhChinh = diaChi.replaceAll(_capHanhChinh, ' ');
  return !_danhTuDuong.hasMatch(khongCapHanhChinh) &&
      !_batDauBangSo.hasMatch(diaChi);
}
