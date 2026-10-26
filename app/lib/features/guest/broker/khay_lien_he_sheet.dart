import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/sale_lien_he_api.dart';

/// Khay bật/tắt liên hệ công khai — hai công tắc đổi thứ KHÁCH nhìn thấy.
///
/// Pop `true` khi có thay đổi để trang ngoài nạp lại.
class KhayLienHeSheet extends StatefulWidget {
  const KhayLienHeSheet({super.key, this.api});

  /// Chỉ để test bơm dữ liệu giả.
  final SaleLienHeApi? api;

  @override
  State<KhayLienHeSheet> createState() => _KhayLienHeSheetState();
}

class _KhayLienHeSheetState extends State<KhayLienHeSheet> {
  bool _khongPhaiNguoiBan = false;
  SaleLienHeApi get _api => widget.api ?? const SaleLienHeApi();

  final _zaloCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  LienHeCongKhai? _hienTai;
  bool _dangTai = true;
  bool _dangLuu = false;
  bool _choGoi = false;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  @override
  void dispose() {
    _zaloCtrl.dispose();
    _facebookCtrl.dispose();
    super.dispose();
  }

  Future<void> _nap() async {
    try {
      final d = await _api.xem();
      if (!mounted) return;
      setState(() {
        _hienTai = d;
        _choGoi = d.choGoi;
        _zaloCtrl.text = d.zalo ?? '';
        _facebookCtrl.text = d.facebook ?? '';
        _dangTai = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        // 403 = tài khoản KHÁCH: liên hệ công khai chỉ dành cho người bán.
        // Trước đây vẫn vẽ form, gõ xong bấm Lưu mới báo "Yêu cầu thất bại".
        _khongPhaiNguoiBan = e is ApiException && e.statusCode == 403;
      });
    }
  }

  Future<void> _luu() async {
    setState(() => _dangLuu = true);
    try {
      await _api.sua(
        choGoi: _choGoi,
        zalo: _zaloCtrl.text.trim(),
        facebook: _facebookCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _dangLuu = false);
      AppFeedback.error(
        context,
        e is ApiException ? e.message : 'Chưa lưu được liên hệ. Thử lại sau.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final coSo = _hienTai?.coSoDienThoai ?? false;
    // TỰ VẼ NỀN bằng DsBottomSheet. `showDsBottomSheet` đặt
    // `backgroundColor: Colors.transparent` và trông chờ nội dung tự dựng
    // khung — thiếu bước này thì khay trong suốt, chữ đè lên danh sách phía
    // sau và đọc không ra chữ nào.
    return DsBottomSheet(
      title: 'Liên hệ công khai',
      padding: EdgeInsets.only(
        left: HD.s16,
        right: HD.s16,
        top: HD.s8,
        bottom: HD.s24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _dangTai
          ? const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            )
          : _khongPhaiNguoiBan
          ? Padding(
              key: const Key('lien-he-chi-danh-cho-sale'),
              padding: const EdgeInsets.symmetric(vertical: HD.s12),
              child: Text(
                'Zalo, Facebook và nút Gọi công khai dành cho tài khoản Sale. '
                'Tài khoản này đang là tài khoản khách — đăng ký làm Sale để '
                'có trang bán hàng với các phím liên hệ này.',
                style: HD.body(size: 13.5, color: HD.ink),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mặc định số của bạn được giấu. Bật lên thì khách xem trang '
                  'thấy nút Gọi.',
                  style: HD.body(size: 12.5, color: HD.inkMuted),
                ),
                const SizedBox(height: HD.s12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: HD.accent,
                  value: _choGoi,
                  // Không có số thì khoá công tắc: bật lên cũng không hiện nút
                  // Gọi, mà người bán lại tưởng đã bật xong.
                  onChanged: coSo ? (v) => setState(() => _choGoi = v) : null,
                  title: Text('Cho khách gọi trực tiếp', style: HD.body()),
                  subtitle: coSo
                      ? null
                      : Text(
                          'Tài khoản chưa có số điện thoại — thêm ở "Sửa hồ sơ".',
                          style: HD.caption(),
                        ),
                ),
                const SizedBox(height: HD.s8),
                DsTextField(
                  controller: _zaloCtrl,
                  label: 'Zalo',
                  hint: 'Số hoặc id Zalo — để trống là ẩn nút Zalo',
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: HD.s12),
                DsTextField(
                  controller: _facebookCtrl,
                  label: 'Facebook',
                  hint: 'Link trang cá nhân hoặc username Facebook',
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: HD.s8),
                Text(
                  'Gọi, Zalo và Facebook sẽ xuất hiện thành phím liên hệ nhanh '
                  'trên Trang Sale của bạn.',
                  style: HD.caption(),
                ),
                const SizedBox(height: HD.s16),
                DsButton(
                  label: 'Lưu',
                  expand: true,
                  isLoading: _dangLuu,
                  onPressed: _dangLuu ? null : _luu,
                ),
              ],
            ),
    );
  }
}
