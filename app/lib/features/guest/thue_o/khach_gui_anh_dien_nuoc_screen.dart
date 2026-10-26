import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/dien_nuoc_api.dart';
import 'package:house_booking/features/guest/thue_o/widgets/thue_o_ui.dart';

typedef TaiAnhFn = Future<String> Function(List<int> bytes, String filename);

/// Màn 7 — Gửi ảnh chỉ số điện nước (mockup 04/10/2026): ảnh chỉ số điện ·
/// ảnh chỉ số nước · nút "Gửi" → màn 8 "Đã gửi thành công".
///
/// Dưới mỗi ảnh có ô SỐ đọc trên đồng hồ: hoá đơn tính từ số, ảnh là bằng
/// chứng để chủ nhà duyệt — thiếu số thì chủ nhà không lập được hoá đơn.
class KhachGuiAnhDienNuocScreen extends StatefulWidget {
  const KhachGuiAnhDienNuocScreen({
    super.key,
    required this.contractId,
    required this.thang,
    this.nuocTheoNguoi = false,
    this.api = const DienNuocApi(),
    this.upload,
  });

  final int contractId;

  /// "2024-10".
  final String thang;

  /// Nước tính theo người: không có công tơ nước, chỉ gửi ảnh điện.
  final bool nuocTheoNguoi;
  final DienNuocApi api;
  final TaiAnhFn? upload;

  @override
  State<KhachGuiAnhDienNuocScreen> createState() =>
      _KhachGuiAnhDienNuocScreenState();
}

class _KhachGuiAnhDienNuocScreenState extends State<KhachGuiAnhDienNuocScreen> {
  String? _anhDien;
  String? _anhNuoc;
  bool _taiDien = false;
  bool _taiNuoc = false;
  bool _dangGui = false;
  final _soDien = TextEditingController();
  final _soNuoc = TextEditingController();

  @override
  void dispose() {
    _soDien.dispose();
    _soNuoc.dispose();
    super.dispose();
  }

  TaiAnhFn get _upload => widget.upload ?? const ApiClient().uploadImage;

  Future<void> _chon(bool dien) async {
    setState(() => dien ? _taiDien = true : _taiNuoc = true);
    try {
      final url = await chonVaTaiAnh(context, _upload);
      if (url != null && mounted) {
        setState(() => dien ? _anhDien = url : _anhNuoc = url);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tải ảnh lên chưa được, thử lại nhé.')),
        );
      }
    } finally {
      if (mounted) setState(() => dien ? _taiDien = false : _taiNuoc = false);
    }
  }

  double? _so(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  bool get _du =>
      _anhDien != null &&
      _so(_soDien) != null &&
      (widget.nuocTheoNguoi || (_anhNuoc != null && _so(_soNuoc) != null));

  Future<void> _gui() async {
    if (!_du) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.nuocTheoNguoi
                ? 'Cần ảnh và chỉ số đồng hồ điện.'
                : 'Cần đủ ảnh và chỉ số của cả đồng hồ điện và nước.',
          ),
        ),
      );
      return;
    }
    setState(() => _dangGui = true);
    try {
      await widget.api.gui(
        contractId: widget.contractId,
        dien: _so(_soDien)!,
        nuoc: widget.nuocTheoNguoi ? 0 : _so(_soNuoc)!,
        anhDien: _anhDien,
        anhNuoc: widget.nuocTheoNguoi ? null : _anhNuoc,
      );
      if (!mounted) return;
      final p = widget.thang.split('-');
      final ky = p.length == 2 ? '${p[1]}/${p[0]}' : widget.thang;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ManThanhCong(
            icon: Icons.assignment_outlined,
            tieuDe: 'Đã gửi thành công',
            loiNhan: 'Thông tin chỉ số điện nước tháng $ky đã được gửi.',
          ),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _dangGui = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gửi chưa được: $e')));
      }
    }
  }

  Widget _khoi({
    required String tieuDe,
    required bool dien,
    required String? url,
    required bool dangTai,
    required TextEditingController so,
    required String donVi,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(tieuDe, style: HD.bodyBold(size: 15, color: HD.ink)),
      const SizedBox(height: 10),
      OChonAnh(
        key: Key('chon-anh-${dien ? 'dien' : 'nuoc'}'),
        url: url,
        dangTai: dangTai,
        onChon: () => _chon(dien),
        onXoa: () => setState(() => dien ? _anhDien = null : _anhNuoc = null),
      ),
      const SizedBox(height: 10),
      TextField(
        key: Key('so-${dien ? 'dien' : 'nuoc'}'),
        controller: so,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          isDense: true,
          labelText: 'Chỉ số trên đồng hồ',
          suffixText: donVi,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => TrangThueO(
    tieuDe: widget.nuocTheoNguoi ? 'Gửi ảnh chỉ số điện' : 'Gửi ảnh chỉ số điện nước',
    duoi: NutDo(
      'Gửi',
      key: const Key('gui-chi-so'),
      dangChay: _dangGui,
      onPressed: _du ? _gui : null,
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _khoi(
          tieuDe: 'Ảnh chỉ số điện',
          dien: true,
          url: _anhDien,
          dangTai: _taiDien,
          so: _soDien,
          donVi: 'kWh',
        ),
        const SizedBox(height: 22),
        if (widget.nuocTheoNguoi)
          Container(
            key: const Key('nuoc-theo-nguoi'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: HD.paperSunken.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.water_drop_outlined, color: HD.inkMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nước của phòng tính theo số người ở — không cần chụp đồng hồ nước.',
                    style: HD.body(size: 13.5, color: HD.inkSoft),
                  ),
                ),
              ],
            ),
          )
        else
        _khoi(
          tieuDe: 'Ảnh chỉ số nước',
          dien: false,
          url: _anhNuoc,
          dangTai: _taiNuoc,
          so: _soNuoc,
          donVi: 'm³',
        ),
      ],
    ),
  );
}
