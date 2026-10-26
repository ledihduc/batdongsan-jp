import 'package:flutter/material.dart';

import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/data/services/ca_thue_api.dart';
import 'package:house_booking/data/services/lich_ngan_han_api.dart';
import 'package:house_booking/data/services/short_stay_api.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/ca_thue_chung.dart'
    show hoiLyDoTuChoi;
import 'package:house_booking/features/host/ngan_han/ca_thue/chi_tiet_ca_thue_screen.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/nhan_phong_screen.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/tra_phong_screen.dart';
import 'package:house_booking/features/host/ngan_han/lich_ngan_han_screen.dart';

/// SỰ KIỆN SẮP TỚI TRONG HÔM NAY — việc của quầy, xếp theo giờ, cả toà.
///
///     15:00  P201 · Trần Thị Mai — Check-in 2 giờ   [Nhận phòng]
///     16:00  P202 · Lê Minh Hoàng — Check-out       [Trả phòng]
///     18:00  P204 · Vệ sinh phòng                   [Hoàn thành]
///
/// Cả toà chứ không riêng phòng đang xem: người trực chỉ có một đôi tay, thứ
/// họ cần là "việc kế tiếp là gì", không phải "phòng này có việc gì". Phòng
/// đang mở được tô đậm để không lẫn.
///
/// Nút bấm mở ĐÚNG quy trình quầy (nhận phòng 3 bước / trả phòng quyết toán)
/// chứ không đổi trạng thái trần — bấm một nút rồi quên thu tiền là mất tiền.
class TheSuKienHomNay extends StatefulWidget {
  const TheSuKienHomNay({
    super.key,
    required this.buildingId,
    this.roomIdNhanManh,
    this.api = const LichNganHanApi(),
    this.shortStayApi = const ShortStayApi(),
    this.caThueApi = const CaThueApi(),
    this.soToiDa = 4,
  });

  final int buildingId;

  /// Phòng đang mở — tô đậm trong danh sách để mắt bắt được ngay.
  final int? roomIdNhanManh;

  final LichNganHanApi api;
  final ShortStayApi shortStayApi;
  final CaThueApi caThueApi;

  /// Hiện tối đa bấy nhiêu việc; còn lại nằm sau "Xem tất cả".
  final int soToiDa;

  @override
  State<TheSuKienHomNay> createState() => _TheSuKienHomNayState();
}

class _TheSuKienHomNayState extends State<TheSuKienHomNay> {
  LichNgay? _lich;
  bool _dangTai = false;
  bool _dangLam = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  Future<void> _nap() async {
    if (_dangTai) return;
    setState(() => _dangTai = true);
    try {
      final l = await widget.api.ngay(widget.buildingId);
      if (mounted) setState(() => _lich = l);
    } catch (_) {
      // Hỏng danh sách việc KHÔNG được làm hỏng cả màn đang chứa nó.
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  void _bao(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _mo(Widget man) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => man));
    if (mounted) await _nap();
  }

  /// Duyệt / từ chối đơn — việc một nhát, làm ngay tại chỗ không mở màn nào.
  Future<void> _quyet(ViecTrongNgay v, {required bool duyet}) async {
    if (_dangLam) return;
    String? lyDo;
    if (!duyet) {
      lyDo = await hoiLyDoTuChoi(context);
      if (lyDo == null || !mounted) return;
    }
    setState(() => _dangLam = true);
    try {
      await widget.shortStayApi.action(
        v.reservationId!,
        duyet ? 'approve' : 'reject',
        lyDo,
      );
      _bao(
        duyet
            ? 'Đã duyệt đơn ${v.maPhong}${v.ten == null ? '' : ' · ${v.ten}'}.'
            : 'Đã từ chối đơn ${v.maPhong}.',
      );
      await _nap();
    } catch (_) {
      _bao(duyet ? 'Không duyệt được đơn.' : 'Không từ chối được đơn.');
    } finally {
      if (mounted) setState(() => _dangLam = false);
    }
  }

  Future<void> _lam(ViecTrongNgay v) async {
    if (_dangLam) return;
    switch (v.loai) {
      case 'cho_duyet':
        await _mo(
          ChiTietCaThueScreen(
            reservationId: v.reservationId!,
            api: widget.caThueApi,
            shortStayApi: widget.shortStayApi,
          ),
        );
      case 'nhan_phong':
        await _mo(
          NhanPhongScreen(
            reservationId: v.reservationId!,
            api: widget.caThueApi,
          ),
        );
      case 'tra_phong':
        await _mo(
          TraPhongScreen(
            reservationId: v.reservationId!,
            api: widget.caThueApi,
          ),
        );
      case 'don_xong':
        setState(() => _dangLam = true);
        try {
          await widget.shortStayApi.unblock(v.roomId, v.blockId!);
          _bao('Phòng ${v.maPhong} đã dọn xong.');
          await _nap();
        } catch (_) {
          _bao('Không bỏ được khoá dọn.');
        } finally {
          if (mounted) setState(() => _dangLam = false);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _lich;
    final viec = l?.viec ?? const <ViecTrongNgay>[];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HD.hairline.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sự kiện sắp tới trong hôm nay',
                  style: HD.bodyBold(size: 14, color: HD.ink),
                ),
              ),
              if (viec.isNotEmpty)
                InkWell(
                  key: const ValueKey('su-kien-xem-tat-ca'),
                  onTap: () => _mo(
                    LichNganHanScreen(
                      buildingId: widget.buildingId,
                      caThueApi: widget.caThueApi,
                      shortStayApi: widget.shortStayApi,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Xem tất cả',
                        style: HD.bodyBold(size: 12, color: HD.accent),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: HD.accent,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (l == null)
            SizedBox(
              height: 56,
              child: Center(
                child: _dangTai
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Chưa tải được việc trong ngày.',
                        style: HD.body(size: 12, color: HD.inkMuted),
                      ),
              ),
            )
          else if (viec.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: HD.s12),
              child: Text(
                'Hôm nay không có việc nào: không ai nhận phòng, trả phòng '
                'hay chờ dọn.',
                style: HD.body(size: 12, color: HD.inkMuted),
              ),
            )
          else
            for (final v in viec.take(widget.soToiDa))
              _MucSuKien(
                viec: v,
                bayGio: l.bayGio ?? DateTime.now(),
                nhanManh: v.roomId == widget.roomIdNhanManh,
                onLam: _dangLam ? null : () => _lam(v),
                onDuyet: _dangLam ? null : () => _quyet(v, duyet: true),
                onTuChoi: _dangLam ? null : () => _quyet(v, duyet: false),
              ),
          if (viec.length > widget.soToiDa)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Còn ${viec.length - widget.soToiDa} việc nữa trong hôm nay.',
                style: HD.body(size: 11, color: HD.inkMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _MucSuKien extends StatelessWidget {
  const _MucSuKien({
    required this.viec,
    required this.bayGio,
    required this.nhanManh,
    this.onLam,
    this.onDuyet,
    this.onTuChoi,
  });

  final ViecTrongNgay viec;
  final DateTime bayGio;
  final bool nhanManh;
  final VoidCallback? onLam;
  final VoidCallback? onDuyet;
  final VoidCallback? onTuChoi;

  @override
  Widget build(BuildContext context) {
    if (viec.laChoDuyet) return _choDuyet();
    final (icon, mau, moTa, nut) = switch (viec.loai) {
      'nhan_phong' => (
        Icons.login,
        HD.accent,
        'Check-in${viec.nhanKieu.isEmpty ? '' : ' · ${viec.nhanKieu.toLowerCase()}'}',
        'Nhận phòng',
      ),
      'tra_phong' => (
        Icons.logout,
        viec.quaGio ? HD.negative : HD.positive,
        viec.quaGio ? 'Check-out · đã quá giờ' : 'Check-out',
        'Trả phòng',
      ),
      _ => (
        Icons.cleaning_services_outlined,
        HD.svcBlue,
        viec.ghiChu ?? 'Vệ sinh phòng',
        'Hoàn thành',
      ),
    };
    final lech = viec.luc.difference(bayGio);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      // Viền TRÁI màu + bo góc là hai thứ Flutter không cho đi cùng nhau
      // ("borderRadius can only be given on borders with uniform colors"), nên
      // vạch màu là một ô riêng chứ không phải BorderSide.
      decoration: BoxDecoration(
        color: nhanManh ? mau.withValues(alpha: 0.06) : null,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline.withValues(alpha: 0.6), width: 0.6),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: mau,
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _gio(viec.luc),
                  style: HD.bodyBold(size: 13, color: mau),
                ),
                Text(
                  _conBao(lech),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: HD.body(size: 9, color: HD.inkMuted),
                ),
              ],
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: mau.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: mau),
          ),
          const SizedBox(width: HD.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viec.ten == null
                      ? viec.maPhong
                      : '${viec.maPhong} · ${viec.ten}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.bodyBold(
                    size: 12.5,
                    color: nhanManh ? HD.ink : HD.inkSoft,
                  ),
                ),
                Text(
                  moTa,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.body(
                    size: 10.5,
                    color: viec.quaGio ? HD.negative : HD.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            key: ValueKey('su-kien-${viec.loai}-${viec.reservationId ?? viec.blockId}'),
            onPressed: onLam,
            style: OutlinedButton.styleFrom(
              foregroundColor: mau,
              side: BorderSide(color: mau.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              textStyle: HD.bodyBold(size: 11.5),
            ),
            child: Text(nut),
          ),
        ],
      ),
    );
  }
}

extension on _MucSuKien {
  /// Đơn chờ duyệt: nền vàng, ghi rõ qua sale nào, hai nút ngay tại chỗ.
  /// Bấm vào thân dòng thì mở chi tiết đơn để xem kỹ trước khi quyết.
  Widget _choDuyet() => InkWell(
    key: ValueKey('su-kien-cho-duyet-${viec.reservationId}'),
    onTap: onLam,
    borderRadius: BorderRadius.circular(HD.r12),
    child: Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: HD.warningTint,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.warning.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: HD.warning,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'ĐƠN MỚI',
                  style: HD.bodyBold(size: 9.5, color: Colors.white),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  viec.ten == null
                      ? viec.maPhong
                      : '${viec.maPhong} · ${viec.ten}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.bodyBold(size: 12.5, color: HD.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              '${viec.nhanKieu} · nhận ${_gio(viec.luc)} ${viec.luc.day}/${viec.luc.month}',
              if (viec.sale != null) 'qua sale ${viec.sale}',
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: HD.body(size: 11, color: HD.inkSoft),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: ValueKey('tu-choi-${viec.reservationId}'),
                  onPressed: onTuChoi,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HD.negative,
                    side: BorderSide(color: HD.negative.withValues(alpha: 0.45)),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: HD.bodyBold(size: 12),
                  ),
                  child: const Text('Từ chối'),
                ),
              ),
              const SizedBox(width: HD.s8),
              Expanded(
                child: FilledButton(
                  key: ValueKey('duyet-${viec.reservationId}'),
                  onPressed: onDuyet,
                  style: FilledButton.styleFrom(
                    backgroundColor: HD.positive,
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: HD.bodyBold(size: 12),
                  ),
                  child: const Text('Duyệt đơn'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

String _hai(int n) => n.toString().padLeft(2, '0');

String _gio(DateTime d) => '${_hai(d.hour)}:${_hai(d.minute)}';

/// 135 phút → 'Trong 2 giờ 15'. Âm → 'Quá 15 phút'.
String _conBao(Duration d) {
  final phut = d.inMinutes;
  final p = phut.abs();
  final chu = p < 60
      ? '$p phút'
      : (p % 60 == 0 ? '${p ~/ 60} giờ' : '${p ~/ 60} giờ ${p % 60}');
  return phut < 0 ? 'Quá $chu' : 'Trong $chu';
}
