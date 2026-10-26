import 'package:flutter/material.dart';

import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/data/models/su_kien_lich_su.dart';

/// Ba mảnh KIỂM SOÁT dùng chung cho phiếu đặt phòng và phiếu hẹn xem
/// (docs/PLAN-DA-DAT.md):
///
///   * [TheTienTrinh] — đơn đang ở bước nào trong 3–4 bước.
///   * [TheSuaDoi]    — đổi giờ / sửa thông tin / huỷ, chỉ nút server cho phép.
///   * [TheLichSu]    — ai làm gì lúc nào, mới nhất trước.

Color mauTong(String tong) => switch (tong) {
  'xac_nhan' || 'dang' => HD.positive,
  'doi' => HD.svcAmber,
  'tu_choi' || 'huy' => HD.negative,
  'xong' => HD.inkSoft,
  'dat' => HD.accent,
  _ => HD.svcAmber,
};

class TheTienTrinh extends StatelessWidget {
  const TheTienTrinh({
    super.key,
    required this.cacBuoc,
    required this.buoc,
    this.dong = false,
  });

  final List<String> cacBuoc;

  /// 1-based: đang đứng ở bước này.
  final int buoc;

  /// Đơn đã huỷ / bị từ chối — vẽ xám, không tô tiến độ.
  final bool dong;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('tien-trinh'),
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cacBuoc.length; i++) ...[
          Expanded(child: _buoc(i)),
        ],
      ],
    ),
  );

  Widget _buoc(int i) {
    final xong = !dong && i < buoc;
    final hienTai = !dong && i == buoc - 1;
    final mau = dong ? HD.hairlineStrong : (xong ? HD.accent : HD.hairline);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 3,
                color: i == 0 ? Colors.transparent : (xong ? HD.accent : HD.hairline),
              ),
            ),
            Container(
              width: hienTai ? 22 : 18,
              height: hienTai ? 22 : 18,
              decoration: BoxDecoration(
                color: xong ? HD.accent : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: mau, width: 2),
              ),
              child: xong
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            Expanded(
              child: Container(
                height: 3,
                color: i == cacBuoc.length - 1
                    ? Colors.transparent
                    : (!dong && i < buoc - 1 ? HD.accent : HD.hairline),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          cacBuoc[i],
          textAlign: TextAlign.center,
          style: hienTai
              ? HD.bodyBold(size: 11, color: HD.accent)
              : HD.body(size: 11, color: xong ? HD.ink : HD.inkMuted),
        ),
      ],
    );
  }
}

class TheSuaDoi extends StatelessWidget {
  const TheSuaDoi({
    super.key,
    this.onDoiGio,
    this.onSuaThongTin,
    this.onHuy,
    this.khoaDoiGio = const Key('sua-doi-gio'),
    this.khoaSua = const Key('sua-thong-tin'),
    this.khoaHuy = const Key('sua-huy'),
    this.nhanDoiGio = 'Đổi giờ',
    this.ghiChu,
  });

  final VoidCallback? onDoiGio;
  final VoidCallback? onSuaThongTin;
  final VoidCallback? onHuy;
  final Key khoaDoiGio;
  final Key khoaSua;
  final Key khoaHuy;
  final String nhanDoiGio;

  /// "Đổi giờ xong đơn sẽ chờ sale xác nhận lại" — nói trước hệ quả.
  final String? ghiChu;

  @override
  Widget build(BuildContext context) {
    final nut = <Widget>[
      if (onDoiGio != null)
        _nut(khoaDoiGio, Icons.event_repeat, nhanDoiGio, onDoiGio!, HD.accent),
      if (onSuaThongTin != null)
        _nut(khoaSua, Icons.edit_outlined, 'Sửa thông tin', onSuaThongTin!, HD.ink),
      if (onHuy != null)
        _nut(khoaHuy, Icons.event_busy_outlined, 'Huỷ', onHuy!, HD.accentDeep),
    ];
    if (nut.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('CẦN THAY ĐỔI?', style: HD.bodyBold(size: 11, color: HD.inkMuted)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < nut.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: nut[i]),
              ],
            ],
          ),
          if (ghiChu != null) ...[
            const SizedBox(height: 8),
            Text(ghiChu!, style: HD.body(size: 11.5, color: HD.inkMuted)),
          ],
        ],
      ),
    );
  }

  Widget _nut(Key khoa, IconData icon, String nhan, VoidCallback onTap, Color mau) =>
      SizedBox(
        height: 44,
        child: OutlinedButton.icon(
          key: khoa,
          onPressed: onTap,
          icon: Icon(icon, size: 17),
          label: FittedBox(child: Text(nhan)),
          style: OutlinedButton.styleFrom(
            foregroundColor: mau,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            side: BorderSide(color: mau.withValues(alpha: 0.35)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: HD.bodyBold(size: 13),
          ),
        ),
      );
}

/// Lịch sử thay đổi — tự tải, hiện 4 dòng mới nhất, bấm để xem hết.
class TheLichSu extends StatefulWidget {
  const TheLichSu({super.key, required this.tai, this.phienBan = 0});

  final Future<List<SuKienLichSu>> Function() tai;

  /// Tăng lên mỗi khi phiếu vừa đổi (đổi giờ, sửa, huỷ) để tải lại.
  final int phienBan;

  @override
  State<TheLichSu> createState() => _TheLichSuState();
}

class _TheLichSuState extends State<TheLichSu> {
  List<SuKienLichSu>? _ds;
  bool _loi = false;
  bool _moHet = false;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  @override
  void didUpdateWidget(covariant TheLichSu old) {
    super.didUpdateWidget(old);
    if (old.phienBan != widget.phienBan) _nap();
  }

  Future<void> _nap() async {
    try {
      final ds = await widget.tai();
      if (mounted) {
        setState(() {
          _ds = ds;
          _loi = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loi = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = _ds;
    final hien = ds == null ? const <SuKienLichSu>[] : (_moHet ? ds : ds.take(4).toList());
    return Container(
      key: const Key('lich-su-thay-doi'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.history, size: 20, color: HD.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Lịch sử thay đổi', style: HD.bodyBold(size: 15)),
              ),
              if (ds != null)
                Text('${ds.length} mục', style: HD.body(size: 12, color: HD.inkMuted)),
            ],
          ),
          const SizedBox(height: 12),
          if (ds == null && !_loi)
            const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_loi)
            TextButton(onPressed: _nap, child: const Text('Không tải được · thử lại'))
          else
            for (var i = 0; i < hien.length; i++)
              _dong(hien[i], cuoi: i == hien.length - 1),
          if (ds != null && ds.length > 4)
            TextButton(
              key: const Key('lich-su-xem-het'),
              onPressed: () => setState(() => _moHet = !_moHet),
              child: Text(_moHet ? 'Thu gọn' : 'Xem tất cả ${ds.length} mục'),
            ),
        ],
      ),
    );
  }

  Widget _dong(SuKienLichSu e, {required bool cuoi}) {
    final mau = mauTong(e.tong);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                const SizedBox(height: 3),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: mau.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: mau, width: 2),
                  ),
                ),
                if (!cuoi)
                  Expanded(child: Container(width: 2, color: HD.hairline)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: cuoi ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(e.tieuDe, style: HD.bodyBold(size: 13.5, color: HD.ink)),
                      ),
                      Text(
                        luc(e.luc),
                        style: HD.body(size: 11, color: HD.inkMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    e.ai.ten,
                    style: HD.bodyBold(
                      size: 11.5,
                      color: e.ai.laBan ? HD.accent : HD.inkSoft,
                    ),
                  ),
                  if (e.chiTiet.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(e.chiTiet, style: HD.body(size: 12, color: HD.inkSoft)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _hai(int n) => n.toString().padLeft(2, '0');

/// "14:05 · 16/09" (giờ máy người xem).
String luc(DateTime? t) =>
    t == null ? '' : '${_hai(t.hour)}:${_hai(t.minute)} · ${_hai(t.day)}/${_hai(t.month)}';

/// "vừa xong" / "5 phút trước" / "3 giờ trước" / "2 ngày trước".
String truoc(DateTime? t, {DateTime? bayGio}) {
  if (t == null) return '';
  final d = (bayGio ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'vừa xong';
  if (d.inMinutes < 60) return '${d.inMinutes} phút trước';
  if (d.inHours < 24) return '${d.inHours} giờ trước';
  if (d.inDays < 30) return '${d.inDays} ngày trước';
  return '${_hai(t.day)}/${_hai(t.month)}/${t.year}';
}
