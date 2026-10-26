import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/so_chu_nha_api.dart';
import 'package:house_booking/features/host/so_chu_nha/widgets/so_ui.dart';

/// Màn 13 — IMPORT DỮ LIỆU PHÒNG từ Excel, bốn bước:
/// 1 Tải file mẫu (Excel) · 2 Điền thông tin theo mẫu · 3 Tải file lên (Chọn
/// file Excel) · 4 Kiểm tra & nhập dữ liệu → "Tiếp tục".
///
/// Tải lên xong là server KIỂM TRA (không ghi gì) và trả lỗi từng dòng; chỉ khi
/// không còn dòng lỗi "Tiếp tục" mới nhập thật, tất cả trong một lượt.
/// API: `GET …/mau-nhap-phong.xlsx`, `POST …/toa-nha/{id}/nhap-phong?ghi=`.
class NhapPhongScreen extends StatefulWidget {
  const NhapPhongScreen({
    super.key,
    required this.toaId,
    required this.tenToa,
    this.api = const SoChuNhaApi(),
    this.chonTep,
  });

  final int toaId;
  final String tenToa;
  final SoChuNhaApi api;

  /// Thay bộ chọn tệp trong test: trả (tên, bytes).
  final Future<(String, List<int>)?> Function()? chonTep;

  @override
  State<NhapPhongScreen> createState() => _NhapPhongScreenState();
}

class _NhapPhongScreenState extends State<NhapPhongScreen> {
  String? _tenTep;
  List<int>? _bytes;
  KetQuaNhapCN? _kq;
  bool _dang = false;
  bool _daTaiMau = false;

  int get _buoc {
    if (_kq != null) return 4;
    if (_bytes != null) return 3;
    return _daTaiMau ? 2 : 1;
  }

  Future<void> _taiMau() async {
    await launchUrl(Uri.parse(SoChuNhaApi.linkMauNhap), mode: LaunchMode.externalApplication);
    if (mounted) setState(() => _daTaiMau = true);
  }

  Future<(String, List<int>)?> _chonMacDinh() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    final f = r?.files.single;
    if (f == null || f.bytes == null) return null;
    return (f.name, f.bytes!.toList());
  }

  Future<void> _chon() async {
    final tep = await (widget.chonTep ?? _chonMacDinh)();
    if (tep == null || !mounted) return;
    setState(() {
      _tenTep = tep.$1;
      _bytes = tep.$2;
      _kq = null;
      _dang = true;
    });
    try {
      final kq = await widget.api.nhapPhong(widget.toaId, tep.$2, tep.$1, ghi: false);
      if (mounted) setState(() => _kq = kq);
    } catch (e) {
      if (mounted) baoCN(context, loiCN(e), loi: true);
    } finally {
      if (mounted) setState(() => _dang = false);
    }
  }

  Future<void> _tiepTuc() async {
    final kq = _kq;
    if (kq == null) {
      await _chon();
      return;
    }
    if (kq.soLoi > 0 || kq.tong == 0) {
      await _chon();
      return;
    }
    setState(() => _dang = true);
    try {
      final xong = await widget.api.nhapPhong(widget.toaId, _bytes!, _tenTep ?? 'phong.xlsx', ghi: true);
      if (!mounted) return;
      baoCN(context, 'Đã nhập ${xong.daNhap} phòng vào ${widget.tenToa}');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _dang = false);
      baoCN(context, loiCN(e), loi: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kq = _kq;
    final chuNut = kq == null
        ? 'Tiếp tục'
        : (kq.soLoi > 0 || kq.tong == 0 ? 'Chọn file khác' : 'Nhập ${kq.hopLe} phòng');
    return ManCN(
      tieuDe: 'Import dữ liệu phòng',
      day: NutCN(chuNut, key: const Key('cn-tiep-tuc'), onPressed: _tiepTuc, dangChay: _dang),
      body: ListView(
        key: const Key('cn-nhap-phong'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('Nhập nhiều phòng vào ${widget.tenToa}', style: HD.body(size: 14, color: HD.inkMuted)),
          const SizedBox(height: 14),
          _buocThe(
            1,
            'Tải file mẫu',
            'File Excel (.xlsx) có sẵn các cột cần điền.',
            NutCN(
              'Tải file mẫu',
              key: const Key('cn-tai-mau'),
              kieu: KieuNutCN.vien,
              icon: Icons.download_rounded,
              onPressed: _taiMau,
            ),
          ),
          _buocThe(
            2,
            'Điền thông tin theo mẫu',
            'Mỗi dòng một phòng: Tên phòng · Tầng · Diện tích (m²) · Giá thuê (đ) · Loại thuê (Dài hạn / Ngắn hạn).',
            null,
          ),
          _buocThe(
            3,
            'Tải file lên',
            _tenTep ?? 'Chưa chọn file nào.',
            NutCN(
              _tenTep == null ? 'Chọn file Excel' : 'Chọn file khác',
              key: const Key('cn-chon-file'),
              kieu: KieuNutCN.vien,
              icon: Icons.upload_file_rounded,
              onPressed: _dang ? null : _chon,
            ),
          ),
          _buocThe(4, 'Kiểm tra & nhập dữ liệu', _moTaKiemTra(kq), kq == null ? null : _ketQua(kq), cuoi: true),
        ],
      ),
    );
  }

  String _moTaKiemTra(KetQuaNhapCN? kq) {
    if (_dang && kq == null) return 'Đang kiểm tra file…';
    if (kq == null) return 'Hệ thống kiểm tra từng dòng trước khi nhập.';
    if (kq.tong == 0) return 'File không có dòng phòng nào.';
    if (kq.soLoi == 0) return '${kq.hopLe} phòng hợp lệ, sẵn sàng nhập.';
    return '${kq.hopLe}/${kq.tong} dòng hợp lệ · ${kq.soLoi} dòng lỗi — sửa file rồi tải lại.';
  }

  Widget _ketQua(KetQuaNhapCN kq) {
    final loi = kq.dong.where((d) => d.loi.isNotEmpty).take(20).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            NhanCN('${kq.hopLe} hợp lệ', mau: MauCN.xanh, nen: MauCN.xanhNen),
            const SizedBox(width: 8),
            if (kq.soLoi > 0) NhanCN('${kq.soLoi} lỗi', mau: HD.accent, nen: HD.accentTint),
          ],
        ),
        for (final d in loi)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Dòng ${d.dong}${d.ten.isEmpty ? '' : ' (${d.ten})'}: ${d.loi.join('; ')}',
              key: Key('cn-loi-dong-${d.dong}'),
              style: HD.body(size: 13, color: HD.accentDeep),
            ),
          ),
      ],
    );
  }

  Widget _buocThe(int so, String tieuDe, String moTa, Widget? duoi, {bool cuoi = false}) {
    final xong = so < _buoc;
    final dang = so == _buoc;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: xong || dang ? HD.accent : MauCN.the,
                  shape: BoxShape.circle,
                  border: Border.all(color: xong || dang ? HD.accent : HD.hairline, width: 1.5),
                ),
                child: xong
                    ? const Icon(Icons.check_rounded, size: 18, color: HD.paperRaised)
                    : Text('$so', style: HD.bodyBold(size: 14, color: dang ? HD.paperRaised : HD.inkMuted)),
              ),
              if (!cuoi)
                Expanded(child: Container(width: 2, color: xong ? HD.accent : HD.hairline.withValues(alpha: 0.7))),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TheCN(
              key: Key('cn-buoc-$so'),
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tieuDe, style: HD.bodyBold(size: 15.5, color: HD.ink)),
                  const SizedBox(height: 4),
                  Text(moTa, style: HD.body(size: 13.5, color: HD.inkMuted)),
                  if (duoi != null) ...[const SizedBox(height: 12), duoi],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
