import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/sale_link_api.dart';

/// Mã liên kết của sale + danh sách chủ phòng đã liên kết. Route: push.
/// API: GET /api/sales/me/code · POST .../regenerate · GET /api/sales/me/owners.
///
/// Mã là thứ sale ĐỌC QUA ĐIỆN THOẠI hoặc gửi Zalo, nên nó phải to, đơn cách,
/// giãn ký tự, và có cả nút chép lẫn nút chia sẻ ngay cạnh.
class SaleCodeScreen extends StatefulWidget {
  const SaleCodeScreen({super.key, this.api});

  final SaleLinkApi? api;

  @override
  State<SaleCodeScreen> createState() => _SaleCodeScreenState();
}

class _SaleCodeScreenState extends State<SaleCodeScreen> {
  SaleLinkApi get _api => widget.api ?? const SaleLinkApi();

  MaLienKet? _ma;
  List<LienKet> _chu = const [];
  String? _loi;
  bool _dangTai = true;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final ma = await _api.maCuaToi();
      final chu = await _api.cuaToiBenSale();
      if (!mounted) return;
      setState(() {
        _ma = ma;
        _chu = chu;
        _dangTai = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loi = 'Không tải được mã liên kết';
        _dangTai = false;
      });
    }
  }

  Future<void> _doiMa() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Đổi mã liên kết?'),
        // Nói rõ hai vế: cái gì mất, cái gì còn. Không nói thì người ta sợ mất
        // luôn chủ phòng đã liên kết và không dám bấm.
        content: const Text(
          'Mã cũ sẽ hết hiệu lực ngay — ai chưa kịp nhập thì phải xin mã mới.\n\n'
          'Các chủ phòng ĐÃ liên kết vẫn giữ nguyên, không bị ảnh hưởng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Đổi mã'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final ma = await _api.doiMa();
      if (!mounted) return;
      setState(() => _ma = ma);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã đổi mã')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đổi mã không được')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(title: const Text('Mã liên kết của tôi')),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : _loi != null
          ? DsErrorState(message: _loi!, onRetry: _nap)
          : RefreshIndicator(
              color: HD.accent,
              onRefresh: _nap,
              child: ListView(
                padding: const EdgeInsets.all(HD.s16),
                children: [
                  _TheMa(ma: _ma!.ma, onDoiMa: _doiMa),
                  const SizedBox(height: HD.s24),
                  Row(
                    children: [
                      Text('Toà nhà đã liên kết', style: HD.bodyBold(size: 16)),
                      const SizedBox(width: HD.s8),
                      Text('${_chu.length}', style: HD.caption()),
                    ],
                  ),
                  const SizedBox(height: HD.s12),
                  if (_chu.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(HD.s16),
                      decoration: BoxDecoration(
                        color: HD.paperRaised,
                        borderRadius: BorderRadius.circular(HD.r12),
                        border: Border.all(color: HD.hairline),
                      ),
                      child: Text(
                        'Chưa có toà nhà nào. Gửi mã trên cho chủ nhà để họ '
                        'chọn toà nhà và liên kết với bạn.',
                        style: HD.body(size: 13.5, color: HD.inkMuted),
                      ),
                    )
                  else
                    ..._chu.map(_hang),
                ],
              ),
            ),
    );
  }

  Widget _hang(LienKet lk) {
    return Container(
      margin: const EdgeInsets.only(bottom: HD.s8),
      padding: const EdgeInsets.all(HD.s12),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: HD.accentSoft,
            child: Text(
              lk.tenDoiPhuong.isEmpty ? '?' : lk.tenDoiPhuong[0].toUpperCase(),
              style: HD.bodyBold(size: 15).copyWith(color: HD.accent),
            ),
          ),
          const SizedBox(width: HD.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lk.tenDoiPhuong, style: HD.bodyBold(size: 14.5)),
                Text(
                  lk.buildingName ?? 'Chưa xác định toà nhà',
                  style: HD.caption(),
                ),
              ],
            ),
          ),
          if (lk.trangThai == 'transfer_pending')
            Text('Đang chuyển', style: HD.caption())
          else
            const Icon(Icons.link, size: 16, color: HD.inkMuted),
        ],
      ),
    );
  }
}

class _TheMa extends StatelessWidget {
  const _TheMa({required this.ma, required this.onDoiMa});

  final String ma;
  final VoidCallback onDoiMa;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(HD.s20),
      decoration: BoxDecoration(
        color: HD.accentSoft,
        borderRadius: BorderRadius.circular(HD.r12),
      ),
      child: Column(
        children: [
          Text(
            'Gửi mã này cho chủ phòng',
            style: HD.body(size: 13, color: HD.ink),
          ),
          const SizedBox(height: HD.s12),
          SelectableText(
            ma,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
              color: HD.accent,
            ),
          ),
          const SizedBox(height: HD.s16),
          Row(
            children: [
              Expanded(
                child: DsButton(
                  label: 'Chép mã',
                  icon: Icons.copy_rounded,
                  expand: true,
                  variant: DsButtonVariant.secondary,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: ma));
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Đã chép $ma')));
                  },
                ),
              ),
              const SizedBox(width: HD.s8),
              Expanded(
                child: DsButton(
                  label: 'Chia sẻ',
                  icon: Icons.ios_share,
                  expand: true,
                  onPressed: () => Share.share(
                    'Mã liên kết của tôi trên Vua Nhà: $ma\n'
                    'Bạn tạo tài khoản rồi vào Cá nhân → Liên kết với sale, '
                    'nhập mã này để quản lý phòng của mình.',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: HD.s8),
          TextButton(
            onPressed: onDoiMa,
            child: Text(
              'Đổi mã khác',
              style: HD.body(size: 13, color: HD.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
