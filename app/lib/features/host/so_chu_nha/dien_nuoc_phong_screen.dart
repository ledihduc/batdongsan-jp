import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/so_chu_nha_api.dart';
import 'package:house_booking/features/guest/thue_o/widgets/thue_o_ui.dart'
    show chonVaTaiAnh;
import 'package:house_booking/features/host/so_chu_nha/widgets/so_ui.dart';

/// Tải một ảnh lên, trả URL — test tiêm vào để khỏi gọi mạng.
typedef TaiAnhCN = Future<String> Function(List<int> bytes, String filename);

/// URL ảnh từ server có thể là đường dẫn tương đối (dữ liệu cũ).
String urlAnhCN(String u) => u.startsWith('http') ? u : '${ApiConfig.baseUrl}$u';

/// Màn 6 — "Điện nước – Phòng 201": tab Tháng này | Lịch sử.
///
/// Tháng này: thẻ Điện và Nước, mỗi thẻ Chỉ số cũ · Chỉ số mới (nhập) · Tiêu
/// thụ (tự tính) → "Lưu chỉ số". Lịch sử: từng tháng, số dùng + thành tiền.
///
/// ĐỒNG BỘ ẢNH với người thuê: hai bên cùng nhìn MỘT dòng chỉ số của tháng.
/// Khách gửi trước → chủ nhà thấy ảnh khách chụp, bấm Duyệt hoặc Yêu cầu chụp
/// lại ngay tại đây; chủ nhà ghi trước (kèm ảnh hoặc không) → khách thấy số
/// và ảnh của chủ nhà, không bị nhắc gửi nữa.
/// API: `GET|POST /api/host/so-chu-nha/phong/{id}/dien-nuoc`,
/// `POST /api/host/dien-nuoc/{reading_id}/duyet|chup-lai`.
class DienNuocPhongScreen extends StatefulWidget {
  const DienNuocPhongScreen({
    super.key,
    required this.roomId,
    this.api = const SoChuNhaApi(),
    this.taiAnh,
  });

  final int roomId;
  final SoChuNhaApi api;
  final TaiAnhCN? taiAnh;

  @override
  State<DienNuocPhongScreen> createState() => _DienNuocPhongScreenState();
}

class _DienNuocPhongScreenState extends State<DienNuocPhongScreen> {
  DienNuocCN? _d;
  Object? _loi;
  int _tab = 0;
  bool _dang = false;

  /// Ảnh chủ nhà VỪA chụp trong lượt này (chưa lưu) — ghi kèm khi "Lưu chỉ số".
  String? _anhDienMoi;
  String? _anhNuocMoi;
  bool _taiDien = false;
  bool _taiNuoc = false;
  final _dien = TextEditingController();
  final _nuoc = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tai();
    _dien.addListener(() => setState(() {}));
    _nuoc.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _dien.dispose();
    _nuoc.dispose();
    super.dispose();
  }

  void _nap(DienNuocCN d) {
    _d = d;
    _anhDienMoi = null;
    _anhNuocMoi = null;
    _dien.text = d.dien.moi == null ? '' : soCN(d.dien.moi);
    _nuoc.text = d.nuoc.moi == null ? '' : soCN(d.nuoc.moi);
  }

  Future<void> _tai() async {
    try {
      final d = await widget.api.dienNuoc(widget.roomId);
      if (mounted) setState(() => _nap(d));
    } catch (e) {
      if (mounted) setState(() => _loi = e);
    }
  }

  Future<void> _luu() async {
    final theoNguoi = _d?.nuocTheoNguoi ?? false;
    final dien = docSoCN(_dien.text);
    final nuoc = theoNguoi ? 0.0 : docSoCN(_nuoc.text);
    if (dien == null || nuoc == null) {
      baoCN(context, theoNguoi ? 'Nhập chỉ số điện mới' : 'Nhập đủ chỉ số điện và nước mới', loi: true);
      return;
    }
    setState(() => _dang = true);
    try {
      final d = await widget.api.luuChiSo(
        widget.roomId,
        dien: dien,
        nuoc: nuoc,
        anhDien: _anhDienMoi,
        anhNuoc: theoNguoi ? null : _anhNuocMoi,
      );
      if (!mounted) return;
      setState(() {
        _nap(d);
        _dang = false;
      });
      baoCN(context, 'Đã lưu chỉ số tháng này');
    } catch (e) {
      if (!mounted) return;
      setState(() => _dang = false);
      baoCN(context, loiCN(e), loi: true);
    }
  }

  Future<void> _chupAnh(bool dien) async {
    setState(() => dien ? _taiDien = true : _taiNuoc = true);
    try {
      final url = await chonVaTaiAnh(context, widget.taiAnh ?? const ApiClient().uploadImage);
      if (url != null && mounted) {
        setState(() => dien ? _anhDienMoi = url : _anhNuocMoi = url);
      }
    } catch (_) {
      if (mounted) baoCN(context, 'Tải ảnh lên chưa được, thử lại nhé.', loi: true);
    } finally {
      if (mounted) setState(() => dien ? _taiDien = false : _taiNuoc = false);
    }
  }

  Future<void> _duyet(DienNuocCN d) => _duyetId(d.readingId);

  Future<void> _duyetId(int? id) async {
    if (id == null) return;
    setState(() => _dang = true);
    try {
      await widget.api.duyetChiSo(id);
      final moi = await widget.api.dienNuoc(widget.roomId);
      if (!mounted) return;
      setState(() {
        _nap(moi);
        _dang = false;
      });
      baoCN(context, 'Đã duyệt chỉ số khách gửi');
    } catch (e) {
      if (!mounted) return;
      setState(() => _dang = false);
      baoCN(context, loiCN(e), loi: true);
    }
  }

  Future<void> _traVe(DienNuocCN d) async {
    final id = d.readingId;
    if (id == null) return;
    final lyDo = await showDialog<String>(context: context, builder: (_) => const _HoiLyDo());
    if (lyDo == null || !mounted) return;
    setState(() => _dang = true);
    try {
      await widget.api.yeuCauChupLai(id, lyDo);
      final moi = await widget.api.dienNuoc(widget.roomId);
      if (!mounted) return;
      setState(() {
        _nap(moi);
        _dang = false;
      });
      baoCN(context, 'Đã nhắn khách chụp lại');
    } catch (e) {
      if (!mounted) return;
      setState(() => _dang = false);
      baoCN(context, loiCN(e), loi: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return ManCN(
      tieuDe: d == null ? 'Điện nước' : 'Điện nước – ${d.tenPhong}',
      day: d != null && _tab == 0
          ? NutCN('Lưu chỉ số', key: const Key('cn-luu-chi-so'), onPressed: _luu, dangChay: _dang)
          : null,
      body: d == null
          ? (_loi != null
                ? RongCN(loiCN(_loi!), icon: Icons.cloud_off_rounded)
                : const Center(child: CircularProgressIndicator(color: HD.accent)))
          : Column(
              children: [
                TabCN(tab: const ['Tháng này', 'Lịch sử'], chon: _tab, onChon: (i) => setState(() => _tab = i)),
                Expanded(child: _tab == 0 ? _thangNay(d) : _lichSu(d)),
              ],
            ),
    );
  }

  Widget _thangNay(DienNuocCN d) {
    return ListView(
      key: const Key('cn-dien-nuoc-thang-nay'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Chỉ số ${kyCN(d.thang).toLowerCase()}', style: HD.bodyBold(size: 16.5, color: HD.ink)),
            ),
            if (d.trangThai == 'da_duyet')
              const NhanCN('Đã chốt', mau: MauCN.xanh, nen: MauCN.xanhNen)
            else if (d.trangThai == 'cho_duyet' || d.trangThai == 'thieu_anh')
              const NhanCN('Khách đã gửi', mau: MauCN.cam, nen: MauCN.camNen)
            else if (d.trangThai == 'can_chup_lai')
              const NhanCN('Chờ khách chụp lại', mau: MauCN.cam, nen: MauCN.camNen),
          ],
        ),
        const SizedBox(height: 12),
        if (d.khachChoDuyet) _theKhachGui(d),
        if (d.trangThai == 'can_chup_lai' && (d.lyDoTraVe ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Đã nhắn khách: ${d.lyDoTraVe}',
              key: const Key('cn-dn-ly-do'),
              style: HD.body(size: 13, color: MauCN.cam),
            ),
          ),
        _theChiSo(
          ten: 'Điện',
          icon: Icons.bolt_rounded,
          mau: MauCN.cam,
          donVi: 'kWh',
          gia: d.giaDien,
          cu: d.dien.cu,
          ctrl: _dien,
          khoa: const Key('cn-dien-moi'),
          anh: _anhDienMoi ?? d.anhDien,
          nhanAnh: _anhDienMoi != null ? 'Ảnh bạn vừa chụp' : _nhanAnh(d),
          dangTai: _taiDien,
          onChup: () => _chupAnh(true),
          khoaAnh: const Key('cn-anh-dien'),
        ),
        const SizedBox(height: 12),
        if (d.nuocTheoNguoi)
          TheCN(
            key: const Key('cn-nuoc-theo-nguoi'),
            child: Row(
              children: [
                OIconCN(Icons.water_drop_outlined, mau: MauCN.lam, nen: MauCN.lam.withValues(alpha: 0.12), co: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nước · tính theo người', style: HD.bodyBold(size: 15, color: HD.ink)),
                      const SizedBox(height: 2),
                      Text(
                        '${d.soNguoi} người × ${tienCN(d.giaNuoc)} — không cần ghi chỉ số',
                        style: HD.body(size: 13, color: HD.inkMuted),
                      ),
                    ],
                  ),
                ),
                Text(tienCN(d.soNguoi * d.giaNuoc), style: HD.bodyBold(size: 15, color: MauCN.lam)),
              ],
            ),
          )
        else
          _theChiSo(
            ten: 'Nước',
            icon: Icons.water_drop_outlined,
            mau: MauCN.lam,
            donVi: 'm³',
            gia: d.giaNuoc,
            cu: d.nuoc.cu,
            ctrl: _nuoc,
            khoa: const Key('cn-nuoc-moi'),
            anh: _anhNuocMoi ?? d.anhNuoc,
            nhanAnh: _anhNuocMoi != null ? 'Ảnh bạn vừa chụp' : _nhanAnh(d),
            dangTai: _taiNuoc,
            onChup: () => _chupAnh(false),
            khoaAnh: const Key('cn-anh-nuoc'),
          ),
      ],
    );
  }

  Widget _theChiSo({
    required String ten,
    required IconData icon,
    required Color mau,
    required String donVi,
    required double gia,
    required double? cu,
    required TextEditingController ctrl,
    required Key khoa,
    required String? anh,
    required String nhanAnh,
    required bool dangTai,
    required VoidCallback onChup,
    required Key khoaAnh,
  }) {
    final moi = docSoCN(ctrl.text);
    final dung = moi != null && cu != null ? (moi - cu).clamp(0, double.infinity).toDouble() : null;
    return TheCN(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OIconCN(icon, mau: mau, nen: mau.withValues(alpha: 0.12), co: 38),
              const SizedBox(width: 10),
              Expanded(child: Text(ten, style: HD.bodyBold(size: 16, color: HD.ink))),
              Text('${tienCN(gia)}/$donVi', style: HD.body(size: 13.5, color: HD.inkMuted)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _cot('Chỉ số cũ', Text(soCN(cu), style: HD.bodyBold(size: 18, color: HD.ink)))),
              const SizedBox(width: 10),
              Expanded(
                child: _cot(
                  'Chỉ số mới',
                  TextField(
                    key: khoa,
                    controller: ctrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: HD.bodyBold(size: 18, color: HD.ink),
                    decoration: kieuONhapCN(goiY: 'Nhập'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _cot(
                  'Tiêu thụ',
                  Text(
                    dung == null ? '—' : '${soCN(dung)} $donVi',
                    style: HD.bodyBold(size: 18, color: mau),
                  ),
                ),
              ),
            ],
          ),
          if (dung != null) ...[
            const SizedBox(height: 10),
            Text(
              'Thành tiền ≈ ${tienCN(dung * gia)}',
              style: HD.body(size: 13, color: HD.inkMuted),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (anh != null) ...[
                _AnhCongTo(url: anh, nhan: nhanAnh),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  key: khoaAnh,
                  onPressed: dangTai || _dang ? null : onChup,
                  icon: dangTai
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(anh == null ? 'Chụp ảnh công tơ' : 'Chụp lại ảnh'),
                  style: OutlinedButton.styleFrom(foregroundColor: mau),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _nhanAnh(DienNuocCN d) => switch (d.nguoiGhi) {
    'khach' => 'Ảnh khách gửi',
    'chu_nha' => 'Ảnh chủ nhà',
    _ => '',
  };

  /// Khách đã gửi, đang chờ chủ nhà: ai gửi + Duyệt / Yêu cầu chụp lại.
  Widget _theKhachGui(DienNuocCN d) => Container(
    key: const Key('cn-dn-khach-gui'),
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: MauCN.camNen, borderRadius: BorderRadius.circular(12)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${d.tenNguoiGui.isEmpty ? 'Khách' : d.tenNguoiGui} đã gửi chỉ số và ảnh công tơ. '
          'Xem ảnh bên dưới rồi duyệt — hoặc sửa số rồi bấm "Lưu chỉ số".',
          style: HD.body(size: 13.5, color: HD.ink),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('cn-dn-chup-lai'),
                onPressed: _dang ? null : () => _traVe(d),
                style: OutlinedButton.styleFrom(foregroundColor: MauCN.cam),
                child: const Text('Yêu cầu chụp lại'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                key: const Key('cn-dn-duyet'),
                onPressed: _dang ? null : () => _duyet(d),
                style: FilledButton.styleFrom(backgroundColor: MauCN.xanh),
                child: const Text('Duyệt'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _cot(String nhan, Widget giaTri) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(nhan, style: HD.body(size: 12.5, color: HD.inkMuted)),
      const SizedBox(height: 6),
      SizedBox(height: 48, child: Center(child: giaTri)),
    ],
  );

  Widget _lichSu(DienNuocCN d) {
    if (d.lichSu.isEmpty) {
      return const RongCN('Chưa có lịch sử chỉ số.', icon: Icons.history_rounded);
    }
    return ListView(
      key: const Key('cn-dien-nuoc-lich-su'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        for (final t in d.lichSu)
          TheCN(
            margin: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const OIconCN(Icons.calendar_month_outlined, mau: HD.accent, nen: HD.accentTint, co: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kyCN(t.thang), style: HD.bodyBold(size: 15, color: HD.ink)),
                      const SizedBox(height: 3),
                      Text(
                        'Điện ${soCN(t.dienDung)} kWh · Nước ${soCN(t.nuocDung)} m³',
                        style: HD.body(size: 13, color: HD.inkMuted),
                      ),
                      if (t.nguoiGhi != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          t.nguoiGhi == 'khach' ? 'Khách gửi' : 'Chủ nhà ghi',
                          style: HD.body(size: 12, color: HD.inkMuted),
                        ),
                      ],
                      if (t.khachChoDuyet && t.readingId != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: Key('cn-dn-duyet-${t.thang}'),
                            onPressed: _dang ? null : () => _duyetId(t.readingId),
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text('Khách gửi · chờ duyệt — Duyệt'),
                            style: TextButton.styleFrom(foregroundColor: MauCN.xanh, padding: EdgeInsets.zero),
                          ),
                        ),
                      if (t.anhDien != null || t.anhNuoc != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (t.anhDien != null) _AnhCongTo(url: t.anhDien!, nhan: 'Điện', co: 44),
                            if (t.anhDien != null && t.anhNuoc != null) const SizedBox(width: 6),
                            if (t.anhNuoc != null) _AnhCongTo(url: t.anhNuoc!, nhan: 'Nước', co: 44),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  t.thanhTien == null ? '—' : tienCN(t.thanhTien!),
                  style: HD.bodyBold(size: 14.5, color: HD.ink),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Ảnh công tơ thu nhỏ — bấm để xem to (đọc số trên ảnh).
class _AnhCongTo extends StatelessWidget {
  const _AnhCongTo({required this.url, required this.nhan, this.co = 64});

  final String url;
  final String nhan;
  final double co;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (nhan.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(nhan, style: HD.bodyBold(size: 14.5, color: HD.ink)),
              ),
            InteractiveViewer(
              child: CachedNetworkImage(imageUrl: urlAnhCN(url), fit: BoxFit.contain),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          ],
        ),
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: urlAnhCN(url),
            width: co,
            height: co,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => Container(
              width: co,
              height: co,
              color: HD.paperSunken,
              child: const Icon(Icons.broken_image_outlined, size: 18),
            ),
          ),
        ),
        if (nhan.isNotEmpty && co >= 60) ...[
          const SizedBox(height: 3),
          Text(nhan, style: HD.body(size: 11, color: HD.inkMuted)),
        ],
      ],
    ),
  );
}

/// Hỏi lý do trả về — khách đọc đúng câu này trong thông báo.
class _HoiLyDo extends StatefulWidget {
  const _HoiLyDo();

  @override
  State<_HoiLyDo> createState() => _HoiLyDoState();
}

class _HoiLyDoState extends State<_HoiLyDo> {
  final _ctrl = TextEditingController(text: 'Ảnh công tơ chưa rõ số, vui lòng chụp lại');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Yêu cầu khách chụp lại'),
    content: TextField(
      key: const Key('cn-dn-ly-do-o'),
      controller: _ctrl,
      maxLines: 2,
      decoration: const InputDecoration(hintText: 'Lý do'),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Thôi')),
      FilledButton(
        key: const Key('cn-dn-gui-ly-do'),
        onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
        child: const Text('Gửi'),
      ),
    ],
  );
}
