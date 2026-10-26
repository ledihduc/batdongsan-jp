import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/so_chu_nha_api.dart';
import 'package:house_booking/features/host/so_chu_nha/widgets/so_ui.dart';

/// Màn 12 — THÊM / SỬA PHÒNG.
///
/// Thêm ảnh → Tên phòng → Tầng (danh sách tầng của toà) → Diện tích → Giá
/// thuê → Loại thuê (Dài hạn / Ngắn hạn) → Lưu. Đổi loại thuê khi sửa = bật
/// kênh mới, tắt kênh cũ (server).
/// API: `GET …/toa-nha/{id}/form-phong`, `POST …/toa-nha/{id}/phong`, `PUT …/phong/{id}`.
class SuaPhongScreen extends StatefulWidget {
  const SuaPhongScreen({
    super.key,
    required this.toaId,
    this.roomId,
    this.tangMacDinh,
    this.api = const SoChuNhaApi(),
    this.chonAnh,
  });

  final int toaId;

  /// `null` = thêm phòng mới.
  final int? roomId;

  /// Thêm phòng từ khối một tầng / "Thêm tầng mới" → chọn sẵn tầng đó.
  final String? tangMacDinh;
  final SoChuNhaApi api;

  /// Thay bộ chọn ảnh trong test.
  final Future<List<XFile>> Function()? chonAnh;

  @override
  State<SuaPhongScreen> createState() => _SuaPhongScreenState();
}

class _SuaPhongScreenState extends State<SuaPhongScreen> {
  final _ten = TextEditingController();
  final _dienTich = TextEditingController();
  final _gia = TextEditingController();
  List<String> _cacTang = const [];
  String? _tang;
  String _loai = kDaiHan;
  final List<String> _anh = [];
  bool _napXong = false;
  bool _dangLuu = false;
  bool _dangTaiAnh = false;
  Object? _loi;

  bool get _sua => widget.roomId != null;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  @override
  void dispose() {
    _ten.dispose();
    _dienTich.dispose();
    _gia.dispose();
    super.dispose();
  }

  Future<void> _nap() async {
    try {
      final f = await widget.api.formPhong(widget.toaId, roomId: widget.roomId);
      if (!mounted) return;
      setState(() {
        _cacTang = f.tang;
        final p = f.phong;
        if (p != null) {
          _ten.text = p.ten;
          _tang = p.tang;
          _dienTich.text = p.dienTich == null ? '' : soCN(p.dienTich);
          _gia.text = p.gia <= 0 ? '' : tienCN(p.gia).replaceAll('đ', '');
          _loai = p.loaiThue == kNganHan ? kNganHan : kDaiHan;
          _anh.addAll(p.anh);
        }
        if (p == null && widget.tangMacDinh != null) _tang = widget.tangMacDinh;
        if (_tang != null && !_cacTang.contains(_tang)) _cacTang = [..._cacTang, _tang!];
        _napXong = true;
      });
    } catch (e) {
      if (mounted) setState(() => _loi = e);
    }
  }

  Future<void> _themAnh() async {
    final ds = await (widget.chonAnh ?? () => ImagePicker().pickMultiImage(imageQuality: 80))();
    if (ds.isEmpty || !mounted) return;
    setState(() => _dangTaiAnh = true);
    try {
      for (final x in ds.take(12 - _anh.length)) {
        final url = await widget.api.taiAnh(await x.readAsBytes(), x.name);
        if (!mounted) return;
        setState(() => _anh.add(url));
      }
    } catch (e) {
      if (mounted) baoCN(context, loiCN(e), loi: true);
    } finally {
      if (mounted) setState(() => _dangTaiAnh = false);
    }
  }

  Future<void> _luu() async {
    final ten = _ten.text.trim();
    final gia = docSoCN(_gia.text);
    final dt = docSoCN(_dienTich.text);
    if (ten.isEmpty) {
      baoCN(context, 'Nhập tên phòng', loi: true);
      return;
    }
    if (gia == null) {
      baoCN(context, 'Nhập giá thuê', loi: true);
      return;
    }
    final vao = PhongVaoCN(ten: ten, tang: _tang, dienTich: dt, gia: gia, loaiThue: _loai, anh: _anh);
    setState(() => _dangLuu = true);
    try {
      if (_sua) {
        await widget.api.suaPhong(widget.roomId!, vao);
      } else {
        await widget.api.themPhong(widget.toaId, vao);
      }
      if (!mounted) return;
      baoCN(context, _sua ? 'Đã lưu phòng' : 'Đã thêm $ten');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _dangLuu = false);
      baoCN(context, loiCN(e), loi: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ManCN(
      tieuDe: _sua ? 'Sửa phòng' : 'Thêm phòng',
      day: _napXong
          ? NutCN('Lưu', key: const Key('cn-luu-phong'), onPressed: _luu, dangChay: _dangLuu)
          : null,
      body: !_napXong
          ? (_loi != null
                ? RongCN(loiCN(_loi!), icon: Icons.cloud_off_rounded)
                : const Center(child: CircularProgressIndicator(color: HD.accent)))
          : ListView(
              key: const Key('cn-form-phong'),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _khoiAnh(),
                const SizedBox(height: 18),
                ONhapCN(nhan: 'Tên phòng', ctrl: _ten, goiY: 'VD: Phòng 101', khoa: const Key('cn-ten-phong')),
                const SizedBox(height: 16),
                Text('Tầng', style: HD.bodyBold(size: 14, color: HD.ink)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: const Key('cn-tang'),
                  initialValue: _tang,
                  isExpanded: true,
                  hint: Text('Chọn tầng', style: HD.body(size: 15, color: HD.inkMuted)),
                  decoration: kieuONhapCN(),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: HD.inkMuted),
                  items: [
                    for (final t in _cacTang)
                      DropdownMenuItem(
                        value: t,
                        child: Text(
                          RegExp(r'^\d+$').hasMatch(t) ? 'Tầng $t' : t,
                          style: HD.body(size: 15, color: HD.ink),
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _tang = v),
                ),
                const SizedBox(height: 16),
                ONhapCN(nhan: 'Diện tích', ctrl: _dienTich, so: true, duoi: 'm²', goiY: 'VD: 25', khoa: const Key('cn-dien-tich')),
                const SizedBox(height: 16),
                ONhapCN(
                  nhan: 'Giá thuê',
                  ctrl: _gia,
                  so: true,
                  duoi: _loai == kNganHan ? 'đ/đêm' : 'đ/tháng',
                  goiY: 'VD: 4.500.000',
                  khoa: const Key('cn-gia-thue'),
                ),
                const SizedBox(height: 16),
                Text('Loại thuê', style: HD.bodyBold(size: 14, color: HD.ink)),
                const SizedBox(height: 6),
                RadioGroup<String>(
                  groupValue: _loai,
                  onChanged: (v) => setState(() => _loai = v ?? _loai),
                  child: Row(
                    children: [
                      for (final (ma, ten) in const [(kDaiHan, 'Dài hạn'), (kNganHan, 'Ngắn hạn')])
                        Expanded(
                          child: InkWell(
                            key: Key('cn-loai-$ma'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => _loai = ma),
                            child: Row(
                              children: [
                                Radio<String>(value: ma, activeColor: HD.accent),
                                Text(ten, style: HD.body(size: 15, color: HD.ink)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _khoiAnh() {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          InkWell(
            key: const Key('cn-them-anh'),
            borderRadius: BorderRadius.circular(12),
            onTap: _dangTaiAnh || _anh.length >= 12 ? null : _themAnh,
            child: Container(
              width: 96,
              decoration: BoxDecoration(
                color: HD.accentTint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HD.accent.withValues(alpha: 0.5)),
              ),
              child: _dangTaiAnh
                  ? const Center(
                      child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: HD.accent)),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo_outlined, color: HD.accent),
                        const SizedBox(height: 6),
                        Text('Thêm ảnh', style: HD.bodyBold(size: 12.5, color: HD.accent)),
                        Text('${_anh.length}/12', style: HD.body(size: 11, color: HD.inkMuted)),
                      ],
                    ),
            ),
          ),
          for (var i = 0; i < _anh.length; i++)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Stack(
                children: [
                  AnhCN(url: _anh[i], rong: 96, bo: 12),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      key: Key('cn-xoa-anh-$i'),
                      onTap: () => setState(() => _anh.removeAt(i)),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(color: HD.ink.withValues(alpha: 0.6), shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 15, color: HD.paperRaised),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
