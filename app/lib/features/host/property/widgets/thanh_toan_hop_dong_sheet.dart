import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/ho_so_phong_api.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Kỳ thanh toán (ngày thu tiền, hình thức) + tiền cọc đã thu của hợp đồng đang
/// hiệu lực. Mở từ khối "Tài chính & tiền cọc phòng" của hồ sơ phòng; đóng với
/// `true` khi đã lưu. API: `PATCH /api/host/contracts/{id}/thanh-toan`.
class ThanhToanHopDongSheet extends StatefulWidget {
  const ThanhToanHopDongSheet({
    super.key,
    required this.hopDong,
    this.api = const HoSoPhongApi(),
  });

  final HopDongHienTai hopDong;
  final HoSoPhongApi api;

  @override
  State<ThanhToanHopDongSheet> createState() => _ThanhToanHopDongSheetState();
}

class _ThanhToanHopDongSheetState extends State<ThanhToanHopDongSheet> {
  late int? _ngay = widget.hopDong.ngayThanhToan;
  late String? _hinhThuc = widget.hopDong.hinhThucThanhToan;
  late final _coc = TextEditingController(
    text: widget.hopDong.cocDaThu?.toStringAsFixed(0) ?? '',
  );
  bool _dangLuu = false;
  String? _loi;

  static const _nhanNgan = {
    'chuyen_khoan': 'Chuyển khoản',
    'tien_mat': 'Tiền mặt',
    'ca_hai': 'Cả hai',
  };

  @override
  void dispose() {
    _coc.dispose();
    super.dispose();
  }

  Future<void> _luu() async {
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    try {
      final coc = _coc.text.trim();
      await widget.api.capNhatThanhToan(
        widget.hopDong.id,
        ngayThanhToan: _ngay,
        hinhThuc: _hinhThuc,
        // Ô trống = chưa ghi nhận, KHÔNG phải "đã thu 0đ".
        cocDaThu: coc.isEmpty ? null : double.tryParse(coc),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangLuu = false;
        _loi = e is ApiException ? e.message : 'Không lưu được. Thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final coc = widget.hopDong.tienCoc;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(HD.s20, HD.s16, HD.s20, HD.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Kỳ thanh toán & tiền cọc', style: HD.bodyBold(size: 16)),
              const SizedBox(height: HD.s16),
              DropdownButtonFormField<int?>(
                key: const ValueKey('tt-ngay'),
                initialValue: _ngay,
                isDense: true,
                decoration: InputDecoration(
                  labelText: 'Ngày thu tiền hàng tháng',
                  helperText: 'Hoá đơn lập sau đó có hạn đóng vào ngày này',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(HD.r12)),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Chưa đặt')),
                  for (var d = 1; d <= 31; d++)
                    DropdownMenuItem<int?>(
                      value: d,
                      child: Text('Ngày ${d.toString().padLeft(2, '0')} hàng tháng'),
                    ),
                ],
                onChanged: (v) => setState(() => _ngay = v),
              ),
              const SizedBox(height: HD.s16),
              Text('Hình thức thanh toán', style: HD.body(size: 12, color: HD.inkMuted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final e in _nhanNgan.entries)
                    ChoiceChip(
                      key: ValueKey('tt-ht-${e.key}'),
                      label: Text(e.value),
                      selected: _hinhThuc == e.key,
                      // Bấm lại thẻ đang chọn = bỏ chọn (về "chưa khai").
                      onSelected: (chon) => setState(() => _hinhThuc = chon ? e.key : null),
                    ),
                ],
              ),
              const SizedBox(height: HD.s16),
              TextField(
                key: const ValueKey('tt-coc'),
                controller: _coc,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Tiền cọc đã thu (đ)',
                  helperText: coc > 0
                      ? 'Cọc theo hợp đồng: ${PriceFormat.full(coc)} · để trống = chưa ghi nhận'
                      : 'Để trống = chưa ghi nhận',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(HD.r12)),
                  suffixIcon: coc > 0
                      ? TextButton(
                          key: const ValueKey('tt-coc-du'),
                          onPressed: () => setState(() => _coc.text = coc.toStringAsFixed(0)),
                          child: const Text('Đã đóng đủ'),
                        )
                      : null,
                ),
              ),
              if (_loi != null)
                Padding(
                  padding: const EdgeInsets.only(top: HD.s8),
                  child: Text(_loi!, style: HD.body(size: 12, color: HD.negative)),
                ),
              const SizedBox(height: HD.s16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _dangLuu ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Huỷ'),
                    ),
                  ),
                  const SizedBox(width: HD.s12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('luu-thanh-toan'),
                      style: FilledButton.styleFrom(backgroundColor: HD.accent),
                      onPressed: _dangLuu ? null : _luu,
                      child: _dangLuu
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Lưu'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
