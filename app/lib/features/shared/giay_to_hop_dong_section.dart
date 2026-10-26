import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/giay_to_hop_dong_api.dart';
import 'package:house_booking/features/guest/thue_o/widgets/thue_o_ui.dart'
    show chonVaTaiAnh;

/// Tải một ảnh lên, trả URL — test tiêm vào để khỏi gọi mạng.
typedef TaiAnhGiayTo = Future<String> Function(List<int> bytes, String filename);

/// Khối "Giấy tờ hợp đồng" — dùng CHUNG cho chủ nhà (Sổ chủ nhà → Hợp đồng) và
/// khách thuê (Đang thuê → Hợp đồng): hai bên nhìn cùng một bộ tệp.
///
/// Thuê trước, bổ sung sau: thiếu ảnh hợp đồng / minh chứng cọc chỉ hiện dải
/// CẢNH BÁO kèm nút tải lên, không chặn gì. Ai tải cũng được; bên kia nhận
/// thông báo. API: `GET|POST|DELETE /api/hop-dong/{id}/giay-to`.
class GiayToHopDongSection extends StatefulWidget {
  const GiayToHopDongSection({
    super.key,
    required this.contractId,
    this.api = const GiayToHopDongApi(),
    this.taiAnh,
    this.onDoi,
  });

  final int contractId;
  final GiayToHopDongApi api;
  final TaiAnhGiayTo? taiAnh;

  /// Gọi sau khi thêm / gỡ tệp — màn cha nạp lại cảnh báo của nó nếu cần.
  final VoidCallback? onDoi;

  @override
  State<GiayToHopDongSection> createState() => _GiayToHopDongSectionState();
}

class _GiayToHopDongSectionState extends State<GiayToHopDongSection> {
  GiayToHopDong? _d;
  Object? _loi;
  String? _dangTai;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    try {
      final d = await widget.api.xem(widget.contractId);
      if (mounted) setState(() => _d = d);
    } catch (e) {
      if (mounted) setState(() => _loi = e);
    }
  }

  void _bao(String s, {bool loi = false}) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(s), backgroundColor: loi ? HD.negative : null),
  );

  Future<void> _tai(String loai) async {
    setState(() => _dangTai = loai);
    try {
      final url = await chonVaTaiAnh(context, widget.taiAnh ?? const ApiClient().uploadImage);
      if (url == null) return;
      final d = await widget.api.them(widget.contractId, loai, [url]);
      if (!mounted) return;
      setState(() => _d = d);
      _bao('Đã tải ${nhanGiayTo(loai).toLowerCase()} lên — bên kia sẽ nhận thông báo.');
      widget.onDoi?.call();
    } catch (e) {
      if (mounted) _bao(e is ApiException ? e.message : 'Tải lên chưa được, thử lại nhé.', loi: true);
    } finally {
      if (mounted) setState(() => _dangTai = null);
    }
  }

  Future<void> _xoa(TepGiayTo t) async {
    final id = t.id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gỡ tệp này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Thôi')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Gỡ')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final d = await widget.api.xoa(widget.contractId, id);
      if (!mounted) return;
      setState(() => _d = d);
      widget.onDoi?.call();
    } catch (e) {
      if (mounted) _bao(e is ApiException ? e.message : 'Không gỡ được', loi: true);
    }
  }

  Future<void> _mo(TepGiayTo t) async {
    if (t.laPdf) {
      await launchUrl(Uri.parse(t.day), mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InteractiveViewer(
                child: CachedNetworkImage(imageUrl: t.day, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${t.nhanVai}${t.nguoiTai == null ? '' : ' · ${t.nguoiTai}'}',
                style: HD.body(size: 13, color: HD.inkMuted),
              ),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Container(
      key: const Key('giay-to-hop-dong'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Giấy tờ hợp đồng', style: HD.bodyBold(size: 16, color: HD.ink)),
          const SizedBox(height: 10),
          if (d == null)
            _loi != null
                ? Text('Không tải được giấy tờ.', style: HD.body(size: 13, color: HD.negative))
                : const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            if (d.thieu.isNotEmpty) _canhBao(d),
            _nhom(d, kHopDong),
            const SizedBox(height: 12),
            _nhom(d, kMinhChungCoc),
          ],
        ],
      ),
    );
  }

  Widget _canhBao(GiayToHopDong d) => Container(
    key: const Key('giay-to-canh-bao'),
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: HD.warning.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.warning_amber_rounded, color: HD.warning, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Còn thiếu ${d.thieu.map(nhanGiayTo).join(' · ').toLowerCase()}. '
            'Đã thuê vẫn bổ sung được — chụp và tải lên để hai bên có bằng chứng.',
            style: HD.body(size: 13, color: HD.ink),
          ),
        ),
      ],
    ),
  );

  Widget _nhom(GiayToHopDong d, String loai) {
    final ds = d.cua(loai);
    final dangTai = _dangTai == loai;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${nhanGiayTo(loai)}${ds.isEmpty ? ' · chưa có' : ' · ${ds.length} tệp'}',
                style: HD.bodyBold(size: 14, color: ds.isEmpty ? HD.warning : HD.ink),
              ),
            ),
            TextButton.icon(
              key: Key('giay-to-tai-$loai'),
              onPressed: _dangTai != null ? null : () => _tai(loai),
              icon: dangTai
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('Chụp / tải lên'),
            ),
          ],
        ),
        if (ds.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final t in ds) _tep(t)],
          ),
      ],
    );
  }

  Widget _tep(TepGiayTo t) => SizedBox(
    width: 78,
    child: Column(
      children: [
        Stack(
          children: [
            InkWell(
              onTap: () => _mo(t),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: t.laPdf
                    ? Container(
                        width: 78,
                        height: 78,
                        color: HD.paperSunken,
                        child: const Icon(Icons.picture_as_pdf_outlined, color: HD.accent),
                      )
                    : CachedNetworkImage(
                        imageUrl: t.day,
                        width: 78,
                        height: 78,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          width: 78,
                          height: 78,
                          color: HD.paperSunken,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            if (t.xoaDuoc && t.id != null)
              Positioned(
                right: 2,
                top: 2,
                child: InkWell(
                  onTap: () => _xoa(t),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, size: 15),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          t.nhanVai,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HD.body(size: 11, color: HD.inkMuted),
        ),
      ],
    ),
  );
}
