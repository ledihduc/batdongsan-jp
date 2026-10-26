import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/chu_nha_api.dart';
import 'package:house_booking/features/host/chu_nha/tao_hop_dong_screen.dart';
import 'package:house_booking/features/host/chu_nha/widgets/chu_nha_ui.dart';

/// Màn 5 — Quyết định sau khi xem (mockup "Góc nhìn Chủ nhà", 04/10/2026).
///
/// "Khách đã xem phòng" → thẻ tóm tắt → Kết quả xem phòng: Khách muốn thuê
/// (sang Tạo hợp đồng) / Khách không thuê (khép lịch, phòng về Trống) → ghi chú
/// → Xác nhận. Trả `true` khi đã ghi.
///
/// API: `POST /api/host/chu-nha/lich-xem/{id}/ket-qua`.
class QuyetDinhSauXemScreen extends StatefulWidget {
  const QuyetDinhSauXemScreen({
    super.key,
    required this.lich,
    this.api = const ChuNhaApi(),
  });

  final LichChuNha lich;
  final ChuNhaApi api;

  @override
  State<QuyetDinhSauXemScreen> createState() => _QuyetDinhSauXemScreenState();
}

class _QuyetDinhSauXemScreenState extends State<QuyetDinhSauXemScreen> {
  bool? _muonThue;
  bool _dangGui = false;
  final _ghiChu = TextEditingController();

  @override
  void dispose() {
    _ghiChu.dispose();
    super.dispose();
  }

  Future<void> _xacNhan() async {
    final muon = _muonThue;
    if (muon == null) return;
    setState(() => _dangGui = true);
    try {
      await widget.api.ghiKetQua(
        widget.lich.id,
        muonThue: muon,
        ghiChu: _ghiChu.text.trim(),
      );
      if (!mounted) return;
      if (muon) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                TaoHopDongScreen(lich: widget.lich, api: widget.api),
          ),
          result: true,
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã ghi nhận · phòng trở lại Trống')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _dangGui = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException
                ? e.message
                : 'Chưa ghi được kết quả, thử lại nhé.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.lich;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: appBarCN(context, 'Quyết định sau khi xem'),
      body: ListView(
        key: const Key('quyet-dinh-sau-xem'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const _DauTichXanh(),
          const SizedBox(height: 14),
          Text(
            'Khách đã xem phòng',
            textAlign: TextAlign.center,
            style: HD.bodyBold(size: 19, color: HD.ink),
          ),
          const SizedBox(height: 6),
          Text(
            'Bạn đánh giá kết quả buổi xem để Sale cập nhật.',
            textAlign: TextAlign.center,
            style: HD.body(size: 13, color: HD.inkMuted),
          ),
          const SizedBox(height: 16),
          TheCN(
            child: Row(
              children: [
                AnhNhoCN(url: m.anh, rong: 72, cao: 58),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.tenPhong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HD.bodyBold(size: 14.5, color: HD.ink),
                      ),
                      const SizedBox(height: 3),
                      phuCN(lucHenCN(m), maxLines: 1),
                      if (m.sale != null) ...[
                        const SizedBox(height: 2),
                        phuCN('Sale: ${m.sale!.ten}', maxLines: 1),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Kết quả xem phòng', style: HD.bodyBold(size: 15)),
          const SizedBox(height: 10),
          _LuaChon(
            key: const Key('khach-muon-thue'),
            chon: _muonThue == true,
            mau: HD.positive,
            nen: const Color(0xFFEFF9F1),
            icon: Icons.check_rounded,
            tieuDe: 'Khách muốn thuê',
            phu: 'Chuyển sang bước xác nhận chốt (hợp đồng).',
            muiTen: true,
            onTap: () => setState(() => _muonThue = true),
          ),
          const SizedBox(height: 10),
          _LuaChon(
            key: const Key('khach-khong-thue'),
            chon: _muonThue == false,
            mau: HD.accent,
            nen: const Color(0xFFFFF1F1),
            icon: Icons.priority_high_rounded,
            tieuDe: 'Khách không thuê',
            phu: 'Kết thúc lịch xem, phòng trở lại trạng thái Trống.',
            onTap: () => setState(() => _muonThue = false),
          ),
          const SizedBox(height: 18),
          phuCN('Ghi chú thêm (nếu có)'),
          const SizedBox(height: 8),
          TextField(
            key: const Key('ghi-chu-ket-qua'),
            controller: _ghiChu,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Nhập ghi chú...',
              hintStyle: HD.body(size: 13, color: HD.inkMuted),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFDDE0E5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: HD.accent),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 48,
            child: FilledButton(
              key: const Key('xac-nhan-ket-qua'),
              style: FilledButton.styleFrom(
                backgroundColor: HD.accent,
                disabledBackgroundColor: HD.accent.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: HD.bodyBold(size: 15),
              ),
              onPressed: _muonThue == null || _dangGui ? null : _xacNhan,
              child: _dangGui
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Xác nhận'),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dấu tích xanh giữa mấy mảnh hoa giấy — như mockup.
class _DauTichXanh extends StatelessWidget {
  const _DauTichXanh();

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 110,
      height: 70,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (dx, dy, c) in const [
            (8.0, 14.0, HD.accent),
            (16.0, 46.0, Color(0xFFF5A524)),
            (92.0, 10.0, Color(0xFF22C55E)),
            (98.0, 44.0, HD.accent),
          ])
            Positioned(
              left: dx,
              top: dy,
              child: Transform.rotate(
                angle: 0.6,
                child: Container(width: 5, height: 5, color: c),
              ),
            ),
          Positioned(
            left: 27,
            top: 3,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: HD.positive,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LuaChon extends StatelessWidget {
  const _LuaChon({
    super.key,
    required this.chon,
    required this.mau,
    required this.nen,
    required this.icon,
    required this.tieuDe,
    required this.phu,
    required this.onTap,
    this.muiTen = false,
  });

  final bool chon;
  final Color mau;
  final Color nen;
  final IconData icon;
  final String tieuDe;
  final String phu;
  final VoidCallback onTap;
  final bool muiTen;

  @override
  Widget build(BuildContext context) => Material(
    color: nen,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: chon ? mau : mau.withValues(alpha: 0.25),
            width: chon ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: mau, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tieuDe, style: HD.bodyBold(size: 14.5, color: mau)),
                  const SizedBox(height: 3),
                  phuCN(phu),
                ],
              ),
            ),
            if (chon)
              Icon(Icons.check_circle_rounded, color: mau)
            else if (muiTen)
              Icon(Icons.chevron_right_rounded, color: mau),
          ],
        ),
      ),
    ),
  );
}
