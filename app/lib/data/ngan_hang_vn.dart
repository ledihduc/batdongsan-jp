/// Ngân hàng nhận chuyển khoản VietQR — BIN NAPAS (nguồn: api.vietqr.io/v2/banks,
/// 14/10/2026). Sinh tự động; backend có bản y hệt ở
/// `app/services/ngan_hang_vn.py`. Đổi thì đổi cả hai.
library;

class NganHangVN {
  const NganHangVN(this.bin, this.ma, this.tenNgan, this.ten);

  final String bin;
  final String ma;
  final String tenNgan;
  final String ten;
}

const dsNganHangVN = <NganHangVN>[
  NganHangVN('970425', 'ABB', 'ABBANK', 'Ngân hàng TMCP An Bình'),
  NganHangVN('970416', 'ACB', 'ACB', 'Ngân hàng TMCP Á Châu'),
  NganHangVN('970405', 'VBA', 'Agribank', 'Ngân hàng Nông nghiệp và Phát triển Nông thôn Việt Nam'),
  NganHangVN('970409', 'BAB', 'BacABank', 'Ngân hàng TMCP Bắc Á'),
  NganHangVN('970438', 'BVB', 'BaoVietBank', 'Ngân hàng TMCP Bảo Việt'),
  NganHangVN('970418', 'BIDV', 'BIDV', 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam'),
  NganHangVN('546034', 'CAKE', 'CAKE', 'TMCP Việt Nam Thịnh Vượng - Ngân hàng số CAKE by VPBank'),
  NganHangVN('970444', 'CBB', 'CBBank', 'Ngân hàng Thương mại trách nhiệm hữu hạn một thành viên Ngoại thương Công nghệ số (Vietcombank Neo Limited)'),
  NganHangVN('422589', 'CIMB', 'CIMB', 'Ngân hàng TNHH MTV CIMB Việt Nam'),
  NganHangVN('970446', 'COOPBANK', 'COOPBANK', 'Ngân hàng Hợp tác xã Việt Nam'),
  NganHangVN('970431', 'EIB', 'Eximbank', 'Ngân hàng TMCP Xuất Nhập khẩu Việt Nam'),
  NganHangVN('970437', 'HDB', 'HDBank', 'Ngân hàng TMCP Phát triển Thành phố Hồ Chí Minh'),
  NganHangVN('970434', 'IVB', 'IndovinaBank', 'Ngân hàng TNHH Indovina'),
  NganHangVN('668888', 'KBank', 'KBank', 'Ngân hàng Đại chúng TNHH Kasikornbank'),
  NganHangVN('970452', 'KLB', 'KienLongBank', 'Ngân hàng TMCP Kiên Long'),
  NganHangVN('970463', 'KBHCM', 'KookminHCM', 'Ngân hàng Kookmin - Chi nhánh Thành phố Hồ Chí Minh'),
  NganHangVN('970462', 'KBHN', 'KookminHN', 'Ngân hàng Kookmin - Chi nhánh Hà Nội'),
  NganHangVN('970449', 'LPB', 'LPBank', 'Ngân hàng TMCP Lộc Phát Việt Nam'),
  NganHangVN('970422', 'MB', 'MBBank', 'Ngân hàng TMCP Quân đội'),
  NganHangVN('970414', 'MBV', 'MBV', 'Ngân hàng TNHH MTV Việt Nam Hiện Đại'),
  NganHangVN('971025', 'momo', 'MoMo', 'CTCP Dịch Vụ Di Động Trực Tuyến'),
  NganHangVN('970426', 'MSB', 'MSB', 'Ngân hàng TMCP Hàng Hải'),
  NganHangVN('971032', 'MVAS', 'MVAS', 'Trung tâm Dịch vụ số Mobifone – Chi nhánh Tổng Công ty viễn thông Mobifone'),
  NganHangVN('970428', 'NAB', 'NamABank', 'Ngân hàng TMCP Nam Á'),
  NganHangVN('970419', 'NCB', 'NCB', 'Ngân hàng TMCP Quốc Dân'),
  NganHangVN('970448', 'OCB', 'OCB', 'Ngân hàng TMCP Phương Đông'),
  NganHangVN('970430', 'PGB', 'PGBank', 'Ngân hàng TMCP Thịnh vượng và Phát triển'),
  NganHangVN('970412', 'PVCB', 'PVcomBank', 'Ngân hàng TMCP Đại Chúng Việt Nam'),
  NganHangVN('971133', 'PVDB', 'PVcomBank Pay', 'Ngân hàng số PVcomBank'),
  NganHangVN('970403', 'STB', 'Sacombank', 'Ngân hàng TMCP Sài Gòn Tài Lộc'),
  NganHangVN('970400', 'SGICB', 'SaigonBank', 'Ngân hàng TMCP Sài Gòn Công Thương'),
  NganHangVN('970429', 'SCB', 'SCB', 'Ngân hàng TMCP Sài Gòn'),
  NganHangVN('970440', 'SEAB', 'SeABank', 'Ngân hàng TMCP Đông Nam Á'),
  NganHangVN('970443', 'SHB', 'SHB', 'Ngân hàng TMCP Sài Gòn - Hà Nội'),
  NganHangVN('970424', 'SHBVN', 'ShinhanBank', 'Ngân hàng TNHH MTV Shinhan Việt Nam'),
  NganHangVN('970407', 'TCB', 'Techcombank', 'Ngân hàng TMCP Kỹ thương Việt Nam'),
  NganHangVN('963388', 'TIMO', 'Timo', 'Ngân hàng số Timo by Ban Viet Bank (Timo by Ban Viet Bank)'),
  NganHangVN('970423', 'TPB', 'TPBank', 'Ngân hàng TMCP Tiên Phong'),
  NganHangVN('546035', 'Ubank', 'Ubank', 'TMCP Việt Nam Thịnh Vượng - Ngân hàng số Ubank by VPBank'),
  NganHangVN('970441', 'VIB', 'VIB', 'Ngân hàng TMCP Quốc tế Việt Nam'),
  NganHangVN('970427', 'VAB', 'VietABank', 'Ngân hàng TMCP Việt Á'),
  NganHangVN('970433', 'VIETBANK', 'VietBank', 'Ngân hàng TMCP Việt Nam Thương Tín'),
  NganHangVN('970454', 'VCCB', 'VietCapitalBank', 'Ngân hàng TMCP Bản Việt'),
  NganHangVN('970436', 'VCB', 'Vietcombank', 'Ngân hàng TMCP Ngoại Thương Việt Nam'),
  NganHangVN('970415', 'ICB', 'VietinBank', 'Ngân hàng TMCP Công thương Việt Nam'),
  NganHangVN('970432', 'VPB', 'VPBank', 'Ngân hàng TMCP Việt Nam Thịnh Vượng'),
  NganHangVN('970457', 'WVN', 'Woori', 'Ngân hàng TNHH MTV Woori Việt Nam'),
];

NganHangVN? nganHangTheoBin(String? bin) {
  for (final n in dsNganHangVN) {
    if (n.bin == bin) return n;
  }
  return null;
}
