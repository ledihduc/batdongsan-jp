/// Chuỗi VietQR (chuẩn EMVCo / NAPAS 247) để vẽ mã QR chuyển khoản NGAY trong
/// app — không gọi dịch vụ ngoài, số tài khoản không rời máy.
///
/// Đã đối chiếu từng ký tự với ảnh mẫu của img.vietqr.io (xem test
/// `test/core/viet_qr_test.dart`). Quét bằng app ngân hàng bất kỳ: điền sẵn
/// ngân hàng, số TK, số tiền, nội dung — người chuyển vẫn thấy tên chủ TK để
/// đối chiếu trước khi bấm.
library;

String _tlv(String tag, String v) => '$tag${v.length.toString().padLeft(2, '0')}$v';

String _crc16(String s) {
  var c = 0xFFFF;
  for (final b in s.codeUnits) {
    c ^= b << 8;
    for (var i = 0; i < 8; i++) {
      c = (c & 0x8000) != 0 ? ((c << 1) ^ 0x1021) : (c << 1);
      c &= 0xFFFF;
    }
  }
  return c.toRadixString(16).toUpperCase().padLeft(4, '0');
}

/// Bỏ dấu tiếng Việt + ký tự lạ, cắt 25 ký tự — nội dung chuyển khoản mà
/// ngân hàng nào cũng nhận nguyên vẹn.
String noiDungCkAscii(String s, {int toiDa = 25}) {
  const co = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const khong = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final thuong = ch.toLowerCase();
    final i = co.indexOf(thuong);
    var r = i >= 0 ? khong[i] : ch;
    if (i >= 0 && ch != thuong) r = r.toUpperCase();
    if (RegExp(r'[A-Za-z0-9 ]').hasMatch(r)) b.write(r);
  }
  final kq = b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  return kq.length > toiDa ? kq.substring(0, toiDa).trim() : kq;
}

/// [soTien] null hoặc ≤ 0 → QR tĩnh (người chuyển tự nhập tiền).
String chuoiVietQr({
  required String bin,
  required String soTaiKhoan,
  int? soTien,
  String? noiDung,
}) {
  final coTien = soTien != null && soTien > 0;
  final tk = _tlv(
    '38',
    _tlv('00', 'A000000727') +
        _tlv('01', _tlv('00', bin) + _tlv('01', soTaiKhoan)) +
        _tlv('02', 'QRIBFTTA'),
  );
  final p = StringBuffer()
    ..write(_tlv('00', '01'))
    ..write(_tlv('01', coTien ? '12' : '11'))
    ..write(tk)
    ..write(_tlv('53', '704'));
  if (coTien) p.write(_tlv('54', '$soTien'));
  p.write(_tlv('58', 'VN'));
  if (noiDung != null && noiDung.isNotEmpty) p.write(_tlv('62', _tlv('08', noiDung)));
  p.write('6304');
  final s = p.toString();
  return s + _crc16(s);
}
