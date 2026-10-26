import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/moi_sale_api.dart';

/// Chủ nhà XEM và chia sẻ mã mời sale của một toà mình tự tạo.
class HopThoaiMaMoiSale extends StatefulWidget {
  const HopThoaiMaMoiSale({
    super.key,
    required this.buildingId,
    required this.tenToa,
    this.api,
  });

  final int buildingId;
  final String tenToa;
  final MoiSaleApi? api;

  @override
  State<HopThoaiMaMoiSale> createState() => _HopThoaiMaMoiSaleState();
}

class _HopThoaiMaMoiSaleState extends State<HopThoaiMaMoiSale> {
  MoiSaleApi get _api => widget.api ?? const MoiSaleApi();

  String? _ma;
  String? _loi;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  Future<void> _nap() async {
    try {
      final ma = await _api.sinhMa(widget.buildingId);
      if (mounted) setState(() => _ma = ma);
    } catch (_) {
      if (mounted) setState(() => _loi = 'Không tạo được mã mời.');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Mời sale phụ trách'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gửi mã này cho sale bạn muốn làm việc cùng. Họ nhập mã là nhận '
          'phụ trách "${widget.tenToa}".',
          style: HD.body(size: 13, color: HD.inkSoft),
        ),
        const SizedBox(height: HD.s12),
        if (_loi != null)
          Text(_loi!, style: HD.body(size: 13, color: HD.negative))
        else if (_ma == null)
          const Center(child: CircularProgressIndicator())
        else
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  _ma!,
                  style: HD.bodyBold(size: 22).copyWith(letterSpacing: 3),
                ),
              ),
              IconButton(
                tooltip: 'Chép mã',
                icon: const Icon(Icons.copy_outlined),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _ma!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã chép mã')),
                  );
                },
              ),
            ],
          ),
        const SizedBox(height: HD.s8),
        // Mã dùng MỘT LẦN — nói trước để chủ nhà không gửi cho ba người rồi
        // thắc mắc vì sao chỉ một người vào được.
        Text(
          'Mã dùng một lần. Muốn mời thêm người thì tạo mã mới.',
          style: HD.body(size: 12, color: HD.inkMuted),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Xong'),
      ),
    ],
  );
}

/// SALE xem mã BÀN GIAO để đưa cho chủ nhà — chiều ngược của mã mời.
///
/// Vì sao cần hộp thoại riêng chứ không in mã ra trang dự án: trang đó là
/// trang CÔNG KHAI. Mã bàn giao mà nằm trong dữ liệu của nó thì bất kỳ ai mở
/// trang cũng chiếm được toà. Mã chỉ lấy khi người đang xem bấm, và lấy qua
/// endpoint có kiểm quyền.
class HopThoaiMaBanGiao extends StatefulWidget {
  const HopThoaiMaBanGiao({
    super.key,
    required this.buildingId,
    required this.tenToa,
    this.api,
  });

  final int buildingId;
  final String tenToa;
  final MoiSaleApi? api;

  @override
  State<HopThoaiMaBanGiao> createState() => _HopThoaiMaBanGiaoState();
}

class _HopThoaiMaBanGiaoState extends State<HopThoaiMaBanGiao> {
  MoiSaleApi get _api => widget.api ?? const MoiSaleApi();

  MaBanGiao? _d;
  String? _loi;
  bool _dangDoi = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  Future<void> _nap() async {
    try {
      final d = await _api.maBanGiao(widget.buildingId);
      if (mounted) setState(() => _d = d);
    } catch (_) {
      if (mounted) setState(() => _loi = 'Không lấy được mã bàn giao.');
    }
  }

  Future<void> _doi() async {
    setState(() => _dangDoi = true);
    try {
      final d = await _api.doiMaBanGiao(widget.buildingId);
      if (mounted) setState(() => _d = d);
    } catch (_) {
      if (mounted) setState(() => _loi = 'Không đổi được mã.');
    } finally {
      if (mounted) setState(() => _dangDoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return AlertDialog(
      title: const Text('Mã bàn giao cho chủ nhà'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gửi mã này cho chủ nhà. Họ nhập mã là nhận "${widget.tenToa}" về '
            'tài khoản của mình — kèm toàn bộ phòng bạn đã dựng.',
            style: HD.body(size: 13, color: HD.inkSoft),
          ),
          const SizedBox(height: HD.s12),
          if (_loi != null)
            Text(_loi!, style: HD.body(size: 13, color: HD.negative))
          else if (d == null)
            const Center(child: CircularProgressIndicator())
          else if (d.daBanGiao)
            // Mã dùng một lần và bị xoá vĩnh viễn — nói rõ thay vì hiện ô trống.
            Text(
              'Toà này đã bàn giao xong. Không còn mã nữa.',
              style: HD.body(size: 13, color: HD.inkSoft),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    d.ma ?? '',
                    style: HD.bodyBold(size: 22).copyWith(letterSpacing: 3),
                  ),
                ),
                IconButton(
                  tooltip: 'Chép mã',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: d.ma ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã chép mã')),
                    );
                  },
                ),
              ],
            ),
          if (d != null && !d.daBanGiao) ...[
            const SizedBox(height: HD.s8),
            Text(
              'Ai có mã cũng nhận được toà. Lỡ gửi nhầm thì đổi mã ngay.',
              style: HD.body(size: 12, color: HD.inkMuted),
            ),
          ],
        ],
      ),
      actions: [
        if (d != null && !d.daBanGiao)
          TextButton(
            onPressed: _dangDoi ? null : _doi,
            child: Text(_dangDoi ? 'Đang đổi…' : 'Đổi mã'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Xong'),
        ),
      ],
    );
  }
}
