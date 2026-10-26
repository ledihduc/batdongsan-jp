import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/dang_thue_api.dart';
import 'package:house_booking/features/guest/thue_o/widgets/thue_o_ui.dart';

/// Màn 9 — Báo sự cố (mockup 04/10/2026): Loại sự cố* · Mô tả chi tiết* ·
/// Hình ảnh (nếu có) · "Gửi yêu cầu" → màn 10 "Đã gửi yêu cầu".
///
/// API: `POST /api/guest/dang-thue/{contractId}/su-co` — ghi vào sổ sửa chữa
/// của chủ nhà (trạng thái "đang xử lý").
class KhachBaoSuCoScreen extends StatefulWidget {
  const KhachBaoSuCoScreen({
    super.key,
    required this.contractId,
    this.api = const DangThueApi(),
    this.upload,
  });

  final int contractId;
  final DangThueApi api;
  final Future<String> Function(List<int> bytes, String filename)? upload;

  @override
  State<KhachBaoSuCoScreen> createState() => _KhachBaoSuCoScreenState();
}

/// Khớp `LOAI_SU_CO` ở backend.
const kLoaiSuCo = [
  'Điện',
  'Nước',
  'Điều hoà',
  'Internet',
  'Nội thất',
  'Khoá cửa',
  'Khác',
];

class _KhachBaoSuCoScreenState extends State<KhachBaoSuCoScreen> {
  String? _loai;
  final _moTa = TextEditingController();
  final List<String> _anh = [];
  bool _taiAnh = false;
  bool _dangGui = false;

  @override
  void dispose() {
    _moTa.dispose();
    super.dispose();
  }

  bool get _du => _loai != null && _moTa.text.trim().length >= 5;

  Future<void> _themAnh() async {
    setState(() => _taiAnh = true);
    try {
      final url = await chonVaTaiAnh(
        context,
        widget.upload ?? const ApiClient().uploadImage,
      );
      if (url != null && mounted) setState(() => _anh.add(url));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tải ảnh lên chưa được, thử lại nhé.')),
        );
      }
    } finally {
      if (mounted) setState(() => _taiAnh = false);
    }
  }

  Future<void> _gui() async {
    setState(() => _dangGui = true);
    try {
      await widget.api.baoSuCo(
        contractId: widget.contractId,
        loai: _loai!,
        moTa: _moTa.text.trim(),
        anh: _anh,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ManThanhCong(
            icon: Icons.build_rounded,
            tieuDe: 'Đã gửi yêu cầu',
            loiNhan:
                'Yêu cầu hỗ trợ của bạn đã được gửi.\n'
                'Chúng tôi sẽ liên hệ sớm nhất.',
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

  Widget _nhan(String chu, {bool batBuoc = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text.rich(
      TextSpan(
        text: chu,
        style: HD.body(size: 13.5, color: HD.inkSoft),
        children: [
          if (batBuoc)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: HD.accent),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => TrangThueO(
    tieuDe: 'Báo sự cố',
    duoi: NutDo(
      'Gửi yêu cầu',
      key: const Key('gui-su-co'),
      dangChay: _dangGui,
      onPressed: _du ? _gui : null,
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _nhan('Loại sự cố', batBuoc: true),
        DropdownButtonFormField<String>(
          key: const Key('loai-su-co'),
          initialValue: _loai,
          isExpanded: true,
          hint: const Text('Chọn loại sự cố'),
          items: [
            for (final l in kLoaiSuCo)
              DropdownMenuItem(value: l, child: Text(l)),
          ],
          onChanged: (v) => setState(() => _loai = v),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 18),
        _nhan('Mô tả chi tiết', batBuoc: true),
        TextField(
          key: const Key('mo-ta-su-co'),
          controller: _moTa,
          minLines: 3,
          maxLines: 6,
          maxLength: 1000,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Nhập mô tả sự cố…',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 10),
        _nhan('Hình ảnh (nếu có)'),
        if (_anh.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _anh.length; i++)
                  SizedBox(
                    width: 96,
                    child: AnhDaChon(
                      url: _anh[i],
                      cao: 80,
                      onXoa: () => setState(() => _anh.removeAt(i)),
                    ),
                  ),
              ],
            ),
          ),
        if (_anh.length < 6)
          OChonAnh(
            key: const Key('them-anh-su-co'),
            cao: 110,
            dangTai: _taiAnh,
            onChon: _themAnh,
          ),
      ],
    ),
  );
}
