import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/ekyc_api.dart';

/// Chụp một ảnh (camera hoặc thư viện) → bytes; null = huỷ. Test tiêm vào.
typedef ChonAnhEkyc = Future<List<int>?> Function(
  BuildContext context, {
  required bool cameraTruoc,
});

/// XÁC MINH CHỦ NHÀ: thông tin + CCCD hai mặt (+ giấy phép kinh doanh nếu có)
/// → Nộp → admin duyệt. CCCD chỉ để tự xác thực thông tin, không eKYC chân
/// dung; thiếu giấy phép vẫn nộp được, chỉ hiện cảnh báo. Route: `/ekyc` (mở từ link `?t=<token>` trên
/// thiết bị khác, không cần đăng nhập) hoặc push từ Cài đặt.
///
/// Ảnh lên thẳng kho nhạy cảm của server; app chỉ biết "đã có / chưa có".
/// API: `/api/ekyc/*`.
class EkycChuNhaScreen extends StatefulWidget {
  const EkycChuNhaScreen({super.key, this.token, this.api, this.chonAnh});

  /// Token trong link — có thì làm eKYC cho người TẠO link, không cần đăng nhập.
  final String? token;
  final EkycApi? api;
  final ChonAnhEkyc? chonAnh;

  @override
  State<EkycChuNhaScreen> createState() => _EkycChuNhaScreenState();
}

class _EkycChuNhaScreenState extends State<EkycChuNhaScreen> {
  late final EkycApi _api = widget.api ?? EkycApi(token: widget.token);
  HoSoEkyc? _hs;
  Object? _loi;
  bool _dang = false;
  String? _dangTai;
  final _hoTen = TextEditingController();
  final _cccd = TextEditingController();
  final _tenKd = TextEditingController();
  final _soKd = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nap();
  }

  @override
  void dispose() {
    for (final c in [_hoTen, _cccd, _tenKd, _soKd]) {
      c.dispose();
    }
    super.dispose();
  }

  void _dat(HoSoEkyc h) {
    _hs = h;
    _hoTen.text = h.hoTen;
    _tenKd.text = h.tenKinhDoanh;
    _soKd.text = h.soGpkd;
    _cccd.clear();
  }

  Future<void> _nap() async {
    try {
      final h = await _api.xem();
      if (mounted) setState(() => _dat(h));
    } catch (e) {
      if (mounted) setState(() => _loi = e);
    }
  }

  void _bao(String s, {bool loi = false}) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(s), backgroundColor: loi ? HD.negative : null),
  );

  String _loiChu(Object e) => e is ApiException ? e.message : 'Có lỗi, thử lại nhé.';

  Future<void> _lam(Future<HoSoEkyc> Function() viec, String xong) async {
    setState(() => _dang = true);
    try {
      final h = await viec();
      if (!mounted) return;
      setState(() => _dat(h));
      _bao(xong);
    } catch (e) {
      if (mounted) _bao(_loiChu(e), loi: true);
    } finally {
      if (mounted) setState(() => _dang = false);
    }
  }

  Future<void> _luuThongTin() => _lam(
    () => _api.luuThongTin(
      hoTen: _hoTen.text,
      soCccd: _cccd.text,
      tenKinhDoanh: _tenKd.text,
      soGpkd: _soKd.text,
    ),
    'Đã lưu thông tin',
  );

  Future<List<int>?> _chonMacDinh(BuildContext context, {required bool cameraTruoc}) async {
    final nguon = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp bằng camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn ảnh có sẵn'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (nguon == null) return null;
    final f = await ImagePicker().pickImage(
      source: nguon,
      preferredCameraDevice: cameraTruoc ? CameraDevice.front : CameraDevice.rear,
      maxWidth: 1800,
      imageQuality: 85,
    );
    return f?.readAsBytes();
  }

  Future<void> _chup(String loai, bool cameraTruoc) async {
    final bytes = await (widget.chonAnh ?? _chonMacDinh)(context, cameraTruoc: cameraTruoc);
    if (bytes == null || !mounted) return;
    setState(() => _dangTai = loai);
    try {
      final h = await _api.guiAnh(loai, bytes);
      if (mounted) setState(() => _dat(h));
    } catch (e) {
      if (mounted) _bao(_loiChu(e), loi: true);
    } finally {
      if (mounted) setState(() => _dangTai = null);
    }
  }

  Future<void> _guiLink() async {
    try {
      final url = await _api.taoLink();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Làm eKYC trên điện thoại'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Quét mã bằng điện thoại để chụp CCCD và chân dung. Link dùng trong 24 giờ.'),
              const SizedBox(height: 12),
              SizedBox(
                width: 200,
                height: 200,
                child: QrImageView(key: const Key('ekyc-link-qr'), data: url, backgroundColor: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép link')));
              },
              child: const Text('Sao chép link'),
            ),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Xong')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) _bao(_loiChu(e), loi: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = _hs;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(title: const Text('Xác minh chủ nhà')),
      bottomNavigationBar: h != null && h.suaDuoc
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                key: const Key('ekyc-nop'),
                onPressed: _dang || h.thieu.isNotEmpty ? null : () => _lam(_api.nop, 'Đã nộp — admin sẽ duyệt sớm'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: HD.accent),
                child: Text(h.thieu.isEmpty ? 'Nộp hồ sơ xác minh' : 'Còn thiếu ${h.thieu.length} mục'),
              ),
            )
          : null,
      body: h == null
          ? Center(
              child: _loi != null
                  ? Padding(padding: const EdgeInsets.all(24), child: Text(_loiChu(_loi!), textAlign: TextAlign.center))
                  : const CircularProgressIndicator(),
            )
          : ListView(
              key: const Key('ekyc-chu-nha'),
              padding: const EdgeInsets.all(16),
              children: [
                _trangThai(h),
                // Không chặn nộp: thiếu giấy phép kinh doanh chỉ nhắc.
                if (h.canhBao.isNotEmpty && h.trangThai != 'da_duyet') ...[
                  const SizedBox(height: 10),
                  Container(
                    key: const Key('ekyc-canh-bao'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: HD.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: HD.warning, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${h.canhBao.join(' · ')}. Vẫn nộp được — hồ sơ sẽ ghi '
                            '"chưa có giấy phép kinh doanh".',
                            style: HD.body(size: 13, color: HD.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (widget.token == null && h.suaDuoc) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const Key('ekyc-tao-link'),
                    onPressed: _guiLink,
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Làm trên điện thoại (link / mã QR)'),
                  ),
                ],
                const SizedBox(height: 14),
                _the('1. Thông tin', [
                  _o(_hoTen, 'Họ tên (như trên CCCD)', const Key('ekyc-ho-ten'), h.suaDuoc),
                  _o(
                    _cccd,
                    h.soCccdCuoi.isEmpty ? 'Số CCCD (12 số)' : 'Số CCCD — đã lưu ••••${h.soCccdCuoi} (bỏ trống để giữ)',
                    const Key('ekyc-cccd'),
                    h.suaDuoc,
                    so: true,
                  ),
                  _o(_tenKd, 'Tên hộ / doanh nghiệp kinh doanh (nếu có)', const Key('ekyc-ten-kd'), h.suaDuoc),
                  _o(_soKd, 'Số giấy phép kinh doanh (nếu có)', const Key('ekyc-so-kd'), h.suaDuoc),
                  if (h.suaDuoc)
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonal(
                        key: const Key('ekyc-luu-thong-tin'),
                        onPressed: _dang ? null : _luuThongTin,
                        child: const Text('Lưu thông tin'),
                      ),
                    ),
                ]),
                const SizedBox(height: 14),
                _the('2. Ảnh giấy tờ', [
                  for (final a in cacAnhEkyc) _dongAnh(h, a),
                ]),
                const SizedBox(height: 10),
                Text(
                  'CCCD chỉ dùng để xác thực thông tin chủ nhà. Ảnh được lưu trong '
                  'kho bảo mật, chỉ admin duyệt hồ sơ mới mở được (mỗi lần mở đều '
                  'ghi nhật ký).',
                  style: HD.body(size: 12.5, color: HD.inkMuted),
                ),
              ],
            ),
    );
  }

  Widget _trangThai(HoSoEkyc h) {
    final (chu, mau, phu) = switch (h.trangThai) {
      'cho_duyet' => ('Đã nộp · chờ admin duyệt', HD.warning, 'Thường trong 48 giờ.'),
      'da_duyet' => ('Đã xác minh', HD.positive, 'Tài khoản có huy hiệu chủ nhà đã xác minh.'),
      'tu_choi' => ('Cần bổ sung', HD.negative, h.lyDoTuChoi ?? ''),
      _ => ('Chưa nộp', HD.inkSoft, 'Điền họ tên, số CCCD và chụp hai mặt CCCD rồi bấm Nộp.'),
    };
    return Container(
      key: const Key('ekyc-trang-thai'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(chu, style: HD.bodyBold(size: 15.5, color: mau)),
          if (phu.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(phu, style: HD.body(size: 13.5, color: HD.ink)),
          ],
        ],
      ),
    );
  }

  Widget _the(String tieuDe, List<Widget> con) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: HD.hairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tieuDe, style: HD.bodyBold(size: 16, color: HD.ink)),
        const SizedBox(height: 10),
        ...con,
      ],
    ),
  );

  Widget _o(TextEditingController c, String nhan, Key k, bool sua, {bool so = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      key: k,
      controller: c,
      enabled: sua,
      keyboardType: so ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: nhan, border: const OutlineInputBorder()),
    ),
  );

  Widget _dongAnh(HoSoEkyc h, (String, String, String, bool) a) {
    final co = h.anh[a.$1] == true;
    final dangTai = _dangTai == a.$1;
    return ListTile(
      key: Key('ekyc-anh-${a.$1}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        co ? Icons.check_circle : Icons.radio_button_unchecked,
        color: co ? HD.positive : HD.inkMuted,
      ),
      title: Text(a.$2, style: HD.bodyBold(size: 14.5, color: HD.ink)),
      subtitle: Text(a.$3, style: HD.body(size: 12.5, color: HD.inkMuted)),
      trailing: !h.suaDuoc
          ? null
          : dangTai
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
          : TextButton(
              key: Key('ekyc-chup-${a.$1}'),
              onPressed: _dangTai != null ? null : () => _chup(a.$1, a.$4),
              child: Text(co ? 'Chụp lại' : 'Chụp'),
            ),
    );
  }
}
