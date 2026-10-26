import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/utils/viet_qr.dart';

void main() {
  test('khớp từng ký tự với mã mẫu của img.vietqr.io (VCB, 150.000đ)', () {
    // Giải mã từ https://img.vietqr.io/image/970436-0011001234567-qr_only.png
    //   ?amount=150000&addInfo=HD%20P101%20T10 (14/10/2026).
    expect(
      chuoiVietQr(bin: '970436', soTaiKhoan: '0011001234567', soTien: 150000, noiDung: 'HD P101 T10'),
      '00020101021238570010A00000072701270006970436011300110012345670208QRIBFTTA'
      '530370454061500005802VN62150811HD P101 T106304411C',
    );
  });

  test('không số tiền → QR tĩnh, không có trường 54', () {
    final s = chuoiVietQr(bin: '970407', soTaiKhoan: '123456789');
    expect(s.substring(6, 12), '010211');
    expect(s.contains('5406'), isFalse);
  });

  test('nội dung chuyển khoản bỏ dấu, bỏ ký tự lạ, tối đa 25 ký tự', () {
    expect(noiDungCkAscii('Phòng 101 · TT HĐ tháng 10/2026 Đạt'), 'Phong 101 TT HD thang 102');
    expect(noiDungCkAscii('Đức'), 'Duc');
  });
}
