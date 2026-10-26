/// Bỏ dấu tiếng Việt + về chữ thường — để ô tìm kiếm khớp "cau giay" với
/// "Cầu Giấy". Người dùng gõ trên điện thoại rất hay bỏ dấu.
///
/// Đã có hai bản tương tự nằm rải rác (`khongDau` trong sheet chụp công tơ —
/// trả CHỮ HOA để in lên ảnh — và `_khongDau` riêng của màn toà nhà). Bản này ở
/// `core/utils` để màn mới dùng mà không phải import cả một sheet camera.
String boDau(String s) {
  final b = StringBuffer();
  for (final c in s.toLowerCase().runes) {
    b.write(_bang[c] ?? String.fromCharCode(c));
  }
  return b.toString();
}

final Map<int, String> _bang = {
  for (final e in const {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  }.entries)
    for (final r in e.value.runes) r: e.key,
};
