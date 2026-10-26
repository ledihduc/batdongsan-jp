import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:house_booking/core/utils/viet_qr.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/guest/thue_o/ho_so_thue.dart';
import 'package:house_booking/features/guest/thue_o/widgets/thue_o_ui.dart';

/// Màn 5 — Chi tiết hóa đơn (mockup 04/10/2026): tiêu đề kỳ + huy hiệu → số
/// tiền, hạn → nội dung, phòng → "Chi tiết hóa đơn" (mở/đóng) → Thanh toán:
/// phương thức "Chuyển khoản ngân hàng" → "Thanh toán ngay".
///
/// App KHÔNG tự trừ tiền: "Thanh toán ngay" mở thông tin chuyển khoản (tài
/// khoản của phòng → toà → hồ sơ chủ nhà) kèm mã VietQR điền sẵn số tiền và
/// nội dung; chủ nhà xác nhận đã nhận ở phía họ.
class KhachChiTietHoaDonScreen extends StatefulWidget {
  const KhachChiTietHoaDonScreen({
    super.key,
    required this.hoSo,
    required this.hoaDon,
  });

  final HoSoThue hoSo;
  final HoaDonThue hoaDon;

  @override
  State<KhachChiTietHoaDonScreen> createState() =>
      _KhachChiTietHoaDonScreenState();
}

class _KhachChiTietHoaDonScreenState extends State<KhachChiTietHoaDonScreen> {
  bool _moChiTiet = false;

  /// Nội dung chuyển khoản KHÔNG dấu, ≤ 25 ký tự — y hệt chuỗi trong mã QR,
  /// để chép tay hay quét mã thì chủ nhà vẫn đối chiếu được cùng một dòng.
  String get _noiDungCk {
    final ma = widget.hoSo.maPhong;
    final so = widget.hoaDon.so;
    return noiDungCkAscii(
      [
        if (ma.isNotEmpty) ma,
        'TT HD ${widget.hoaDon.ky.replaceAll('/', ' ')}',
        if (so.isNotEmpty) so,
      ].join(' '),
    );
  }

  int get _conPhaiTra =>
      (widget.hoaDon.tong - widget.hoaDon.daTra).clamp(0, double.infinity).round();

  Future<void> _thanhToan() {
    final tk = widget.hoSo.taiKhoan;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Chuyển khoản ngân hàng', style: HD.bodyBold(size: 17)),
              const SizedBox(height: 12),
              if (tk == null)
                Text(
                  'Chủ nhà chưa khai báo tài khoản nhận tiền trên ứng dụng. '
                  'Vui lòng liên hệ chủ nhà / quản lý để nhận thông tin chuyển '
                  'khoản.',
                  style: HD.body(size: 13.5, color: HD.inkMuted),
                )
              else ...[
                // Có BIN NAPAS (chủ nhà chọn ngân hàng trong danh sách) → mã
                // VietQR điền sẵn số tiền + nội dung; app ngân hàng nào cũng quét.
                if ('${tk['bin'] ?? ''}'.isNotEmpty) ...[
                  Center(
                    child: QrImageView(
                      key: const Key('hoa-don-vietqr'),
                      data: chuoiVietQr(
                        bin: '${tk['bin']}',
                        soTaiKhoan: '${tk['so_tai_khoan'] ?? ''}',
                        soTien: _conPhaiTra,
                        noiDung: _noiDungCk,
                      ),
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  Text(
                    'Mở app ngân hàng → Quét QR. Số tiền và nội dung đã điền sẵn.',
                    textAlign: TextAlign.center,
                    style: HD.body(size: 12.5, color: HD.inkMuted),
                  ),
                  const SizedBox(height: 10),
                ],
                _DongSao('Ngân hàng', '${tk['ngan_hang'] ?? ''}'),
                _DongSao('Số tài khoản', '${tk['so_tai_khoan'] ?? ''}'),
                _DongSao('Chủ tài khoản', '${tk['chu_tai_khoan'] ?? ''}'),
                _DongSao(
                  'Số tiền',
                  tienVN(widget.hoaDon.tong - widget.hoaDon.daTra),
                ),
                _DongSao('Nội dung', _noiDungCk),
                const SizedBox(height: 10),
                Text(
                  'Sau khi chuyển khoản, chủ nhà sẽ xác nhận và hóa đơn chuyển '
                  'sang "Đã thanh toán".',
                  style: HD.body(size: 12.5, color: HD.inkMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hoaDon;
    final daTra = h.daThanhToan;
    return TrangThueO(
      tieuDe: 'Chi tiết hóa đơn',
      duoi: daTra
          ? null
          : NutDo(
              'Thanh toán ngay',
              key: const Key('thanh-toan-ngay'),
              onPressed: _thanhToan,
            ),
      body: ListView(
        key: const Key('chi-tiet-hoa-don'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          KhoiTrang(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TieuDeKhoi(
                  'Hóa đơn tháng ${h.ky}',
                  phai: daTra
                      ? NhanTron.xanh('Đã thanh toán')
                      : h.quaHan
                      ? NhanTron.cam('Quá hạn')
                      : NhanTron.cam('Chưa thanh toán'),
                ),
                DongThongTin(
                  'Số tiền',
                  tienVN(h.tong),
                  giaDam: true,
                  mauGia: HD.accent,
                ),
                DongThongTin('Hạn thanh toán', ngayVN(h.han)),
                DongThongTin('Nội dung', 'Tiền phòng tháng ${h.ky}'),
                DongThongTin('Phòng', widget.hoSo.tieuDe, vach: false),
              ],
            ),
          ),
          KhoiTrang(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  key: const Key('mo-chi-tiet-hoa-don'),
                  title: Text(
                    'Chi tiết hóa đơn',
                    style: HD.body(size: 14.5, color: HD.ink),
                  ),
                  trailing: Icon(
                    _moChiTiet
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                  onTap: () => setState(() => _moChiTiet = !_moChiTiet),
                ),
                if (_moChiTiet)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                    child: Column(
                      children: [
                        if (h.so.isNotEmpty) DongThongTin('Số hóa đơn', h.so),
                        DongThongTin('Tổng cộng', tienVN(h.tong)),
                        DongThongTin('Đã thanh toán', tienVN(h.daTra)),
                        DongThongTin(
                          'Còn phải trả',
                          tienVN((h.tong - h.daTra).clamp(0, double.infinity)),
                          giaDam: true,
                          vach: false,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!daTra) ...[
            const SizedBox(height: 8),
            Text('Thanh toán', style: HD.bodyBold(size: 17, color: HD.ink)),
            const SizedBox(height: 4),
            Text(
              'Phương thức thanh toán',
              style: HD.body(size: 13, color: HD.inkMuted),
            ),
            const SizedBox(height: 10),
            KhoiTrang(
              padding: EdgeInsets.zero,
              child: ListTile(
                key: const Key('phuong-thuc-chuyen-khoan'),
                leading: const Icon(
                  Icons.account_balance_outlined,
                  color: HD.inkSoft,
                ),
                title: Text(
                  'Chuyển khoản ngân hàng',
                  style: HD.body(size: 14.5, color: HD.ink),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _thanhToan,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dòng nhãn–giá trị có nút sao chép (số tài khoản, nội dung CK).
class _DongSao extends StatelessWidget {
  const _DongSao(this.nhan, this.gia);

  final String nhan;
  final String gia;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(nhan, style: HD.body(size: 13, color: HD.inkMuted)),
        ),
        Expanded(
          child: Text(gia, style: HD.bodyBold(size: 14, color: HD.ink)),
        ),
        IconButton(
          tooltip: 'Sao chép',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.copy_rounded, size: 18),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: gia));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Đã sao chép $nhan')));
          },
        ),
      ],
    ),
  );
}
