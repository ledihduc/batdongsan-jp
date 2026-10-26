import 'package:flutter/material.dart';

import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/data/services/ca_thue_api.dart';
import 'package:house_booking/data/services/lich_gio_api.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/chi_tiet_ca_thue_screen.dart';
import 'package:house_booking/features/host/ngan_han/lich_gio_screen.dart';
import 'package:house_booking/features/host/ngan_han/so_do_gio.dart';

/// THẺ LỊCH PHÒNG trong hồ sơ phòng ngắn hạn — thay ba tab "Hôm nay / Ngày mai
/// / Ngày kia" (12/09/2026).
///
/// Ba tab chỉ nhìn được ba ngày, mà nhận đặt trước thì phải thấy cả tháng. Thẻ
/// này gồm ba tầng, đọc từ thô tới mịn:
///
///   1. CỤC LỊCH 4 tuần (4 hàng × 7 cột) — ngày nào có khách, ngày nào trống,
///      thanh nhỏ dưới mỗi ô cho biết kín cỡ nào;
///   2. SƠ ĐỒ GIỜ của đúng ngày đang chọn — khe trống nằm ở giờ nào;
///   3. DANH SÁCH ca của ngày đó — ai, kiểu gì, bao nhiêu tiền.
///
/// Tầng 1 và 2 lấy từ `lich-gio` (một lượt, 28 ngày). Tầng 3 dùng dữ liệu của
/// chính hồ sơ phòng để tiền và tên khách đi theo đúng quyền đã tính ở đó.
class TheLichPhong extends StatefulWidget {
  const TheLichPhong({
    super.key,
    required this.roomId,
    required this.ngayChon,
    required this.onChonNgay,
    required this.child,
    this.api = const LichGioApi(),
    this.caThueApi = const CaThueApi(),
    this.soTuan = 4,
  });

  final int roomId;

  /// 'YYYY-MM-DD' đang xem — do màn cha giữ, thẻ chỉ báo khi người dùng đổi.
  final String ngayChon;
  final void Function(String ngay) onChonNgay;

  /// Phần dưới (danh sách ca + hai nút) do màn cha dựng, vì nó cần tiền và
  /// quyền của hồ sơ phòng.
  final Widget child;

  final LichGioApi api;
  final CaThueApi caThueApi;
  final int soTuan;

  @override
  State<TheLichPhong> createState() => _TheLichPhongState();
}

class _TheLichPhongState extends State<TheLichPhong> {
  LichGio? _lich;
  bool _dangTai = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  @override
  void didUpdateWidget(TheLichPhong cu) {
    super.didUpdateWidget(cu);
    // Người dùng nhảy sang ngày ngoài cửa sổ 4 tuần đang tải -> nạp lại.
    if (widget.ngayChon != cu.ngayChon && !_trongCuaSo(widget.ngayChon)) {
      _nap();
    }
  }

  bool _trongCuaSo(String iso) {
    final l = _lich;
    final d = DateTime.tryParse(iso);
    if (l == null || d == null) return false;
    return !d.isBefore(l.tuNgay) && !d.isAfter(l.denNgay);
  }

  Future<void> _nap() async {
    if (_dangTai) return;
    setState(() => _dangTai = true);
    try {
      final l = await widget.api.lay(
        widget.roomId,
        tuNgay: widget.ngayChon,
        soTuan: widget.soTuan,
      );
      if (mounted) setState(() => _lich = l);
    } catch (_) {
      // Cục lịch hỏng KHÔNG được làm hỏng cả hồ sơ phòng: im lặng, phần dưới
      // vẫn đọc được. Người dùng còn nguyên đường vào sơ đồ đầy đủ.
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    final l = _lich;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (l == null)
          SizedBox(
            height: 90,
            child: Center(
              child: _dangTai
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Chưa tải được lịch phòng.',
                      style: HD.body(size: 12, color: HD.inkMuted),
                    ),
            ),
          )
        else ...[
          _cucLich(l),
          const SizedBox(height: HD.s12),
          _soDoGio(l),
          const SizedBox(height: HD.s12),
        ],
        widget.child,
        if (l != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('xem-so-do-4-tuan'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LichGioScreen(
                    roomId: widget.roomId,
                    api: widget.api,
                    caThueApi: widget.caThueApi,
                  ),
                ),
              ),
              icon: const Icon(Icons.open_in_full, size: 15),
              label: Text(
                'Xem sơ đồ ${l.soTuan} tuần',
                style: HD.bodyBold(size: 12),
              ),
              style: TextButton.styleFrom(foregroundColor: HD.svcIndigo),
            ),
          ),
        ],
      ],
    );
  }

  // ── Tầng 1: cục lịch 4 tuần ───────────────────────────────────────────────

  Widget _cucLich(LichGio l) => Container(
    padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
    decoration: BoxDecoration(
      color: HD.paper,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Row(
          children: [
            for (final t in const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'])
              Expanded(
                child: Text(
                  t,
                  textAlign: TextAlign.center,
                  style: HD.body(size: 9.5, color: HD.inkMuted),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var tuan = 0; tuan * 7 < l.ngay.length; tuan++)
          Row(
            children: [
              for (var i = tuan * 7; i < (tuan + 1) * 7 && i < l.ngay.length; i++)
                Expanded(child: _oNgay(l.ngay[i])),
            ],
          ),
      ],
    ),
  );

  Widget _oNgay(HangNgay n) {
    final chon = _iso(n.ngay) == widget.ngayChon;
    final co = n.gioBan > 0;
    return InkWell(
      key: ValueKey('o-lich-${_iso(n.ngay)}'),
      onTap: () => widget.onChonNgay(_iso(n.ngay)),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: chon ? HD.accent : (n.cuoiTuan ? Colors.white : null),
          borderRadius: BorderRadius.circular(10),
          border: n.homNay && !chon
              ? Border.all(color: HD.accent, width: 1.2)
              : null,
        ),
        child: Column(
          children: [
            Text(
              '${n.ngay.day}',
              style: HD.bodyBold(
                size: 12,
                color: chon ? Colors.white : HD.ink,
              ),
            ),
            const SizedBox(height: 3),
            // Thanh nhỏ = kín cỡ nào trong ngày. Không có ca thì vẫn chừa chỗ
            // để các ô không nhảy cao thấp khác nhau.
            Container(
              height: 3,
              width: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                color: chon
                    ? Colors.white.withValues(alpha: 0.35)
                    : HD.hairline.withValues(alpha: 0.7),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: co ? (n.tyLe / 100).clamp(0.12, 1.0) : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    color: chon
                        ? Colors.white
                        : (n.tyLe >= 60 ? HD.negative : HD.positive),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tầng 2: sơ đồ giờ, bảy ngày kể từ ngày đang chọn ──────────────────────
  //
  // Dùng chung lưới [SoDoGio] với màn sơ đồ đầy đủ: hai nơi vẽ hai lưới riêng
  // là cách chắc chắn nhất để chúng lệch nhau sau vài lần sửa.

  List<HangNgay> _bayNgay(LichGio l) {
    final i = l.ngay.indexWhere((n) => _iso(n.ngay) == widget.ngayChon);
    final dau = i < 0 ? 0 : i;
    return l.ngay.sublist(dau, (dau + 7).clamp(0, l.ngay.length));
  }

  Widget _soDoGio(LichGio l) {
    final ds = _bayNgay(l);
    final n = ds.isEmpty ? null : ds.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              _nhanNgay(n?.ngay ?? DateTime.parse(widget.ngayChon)),
              style: HD.bodyBold(size: 11.5, color: HD.inkSoft),
            ),
            const Spacer(),
            Text(
              n == null || n.gioBan == 0
                  ? 'trống cả ngày'
                  : '${n.soCa > 0 ? '${n.soCa} ca · ' : ''}${_soGio(n.gioBan)} đã bán',
              style: HD.body(
                size: 11,
                color: (n?.gioBan ?? 0) > 0 ? HD.positive : HD.inkMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SoDoGio(
          ngay: ds,
          bayGio: l.bayGio,
          onTap: (m) {
            if (m.laChan) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChiTietCaThueScreen(
                  reservationId: m.id,
                  api: widget.caThueApi,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

String _hai(int n) => n.toString().padLeft(2, '0');

String _iso(DateTime d) => '${d.year}-${_hai(d.month)}-${_hai(d.day)}';

String _nhanNgay(DateTime d) {
  const thu = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
  return '${thu[(d.weekday - 1).clamp(0, 6)]} ${d.day}/${d.month}';
}

/// 4.0 → '4h' · 4.5 → '4h30'.
String _soGio(double g) {
  final h = g.floor();
  final p = ((g - h) * 60).round();
  return p == 0 ? '${h}h' : '${h}h$p';
}

/// Định dạng tiền dùng lại ở thẻ cha — để một chỗ khỏi lệch.
String tienNgay(double v) => PriceFormat.full(v);
