import 'package:flutter/material.dart';

import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/data/services/lich_gio_api.dart';

/// LƯỚI NGÀY × GIỜ dùng chung: cột ngày GHIM bên trái, mốc giờ 00→23 bên trên,
/// mỗi ca là một thanh đặt đúng mốc giờ của hàng ngày đó.
///
/// Tách khỏi [LichGioScreen] vì hồ sơ phòng nhúng đúng lưới này ở dạng 7 ngày.
/// Hai nơi vẽ hai lưới riêng là cách chắc chắn nhất để chúng lệch nhau sau vài
/// lần sửa.
class SoDoGio extends StatefulWidget {
  const SoDoGio({
    super.key,
    required this.ngay,
    this.bayGio,
    this.onTap,
    this.gioCuonToi = 10,
  });

  final List<HangNgay> ngay;
  final DateTime? bayGio;
  final void Function(KhoiGio)? onTap;

  /// Mở ra cuộn sẵn tới giờ này — 0h–8h gần như không có ca, để nó chiếm màn
  /// hình đầu tiên là phí chỗ.
  final int gioCuonToi;

  @override
  State<SoDoGio> createState() => _SoDoGioState();
}

/// Một giờ rộng 30 → cả ngày 720px, kéo ngang hai nhịp là hết. Hẹp hơn thì ca
/// một tiếng mỏng như sợi chỉ, rộng hơn thì phải kéo cả buổi mới tới tối.
const double _rongGio = 30;
const double _rongCotNgay = 62;
const double _caoHang = 44;
const double _caoDauGio = 26;

class _SoDoGioState extends State<SoDoGio> {
  final _ngang = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_ngang.hasClients) return;
      _ngang.jumpTo(
        (widget.gioCuonToi * _rongGio).clamp(0, _ngang.position.maxScrollExtent),
      );
    });
  }

  @override
  void dispose() {
    _ngang.dispose();
    super.dispose();
  }

  List<HangNgay> get _ngay => widget.ngay;
  DateTime? get bayGio => widget.bayGio;
  void Function(KhoiGio)? get onTap => widget.onTap;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: HD.hairline.withValues(alpha: 0.8)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cột ngày GHIM: kéo tới 22:00 vẫn phải biết đang xem ngày nào.
        SizedBox(
          width: _rongCotNgay,
          child: Column(
            children: [
              Container(
                height: _caoDauGio,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 8),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: HD.hairline, width: 0.6),
                  ),
                ),
                child: Text(
                  'Ngày',
                  style: HD.bodyBold(size: 10, color: HD.inkMuted),
                ),
              ),
              for (final n in _ngay) _oNgay(n),
            ],
          ),
        ),
        Container(
          width: 0.6,
          height: _caoDauGio + _caoHang * _ngay.length,
          color: HD.hairlineStrong,
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _ngang,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _rongGio * 24,
              child: Column(
                children: [
                  _dauGio(),
                  for (final n in _ngay) _hangNgay(n),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _oNgay(HangNgay n) => Container(
    height: _caoHang,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: n.homNay
          ? HD.accentTint
          : (n.cuoiTuan ? HD.paper.withValues(alpha: 0.6) : null),
      border: Border(
        // Vạch đậm mở đầu mỗi tuần — bốn tuần đọc thành bốn khối.
        top: BorderSide(
          color: n.thu == 1 ? HD.hairlineStrong : HD.hairline,
          width: n.thu == 1 ? 1.1 : 0.4,
        ),
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_thu(n.thu)} ${n.ngay.day}/${n.ngay.month}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HD.bodyBold(
                  size: 11,
                  color: n.homNay ? HD.accent : HD.ink,
                ),
              ),
              // Ngày chỉ có phần đuôi của ca hôm trước thì soCa = 0 (ca tính
              // vào ngày nó bắt đầu) nhưng KHÔNG được ghi "trống" — nửa ngày
              // đó phòng vẫn có người.
              Text(
                n.soCa > 0
                    ? '${n.soCa} ca · ${_soGio(n.gioBan)}'
                    : (n.gioBan > 0
                          ? 'ca hôm trước · ${_soGio(n.gioBan)}'
                          : 'trống'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HD.body(
                  size: 9,
                  color: n.soCa == 0 && n.gioBan == 0
                      ? HD.inkMuted
                      : HD.positive,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _dauGio() => Container(
    height: _caoDauGio,
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: HD.hairline, width: 0.6)),
    ),
    child: Row(
      children: [
        for (var h = 0; h < 24; h++)
          Container(
            width: _rongGio,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: h % 6 == 0 ? HD.hairlineStrong : HD.hairline,
                  width: h % 6 == 0 ? 1 : 0.4,
                ),
              ),
            ),
            // Chỉ ghi nhãn 2 giờ một lần, không thì chữ chồng lên nhau.
            child: h.isEven
                ? Text(
                    _hai(h),
                    style: HD.body(size: 9, color: HD.inkMuted),
                  )
                : const SizedBox.shrink(),
          ),
      ],
    ),
  );

  Widget _hangNgay(HangNgay n) {
    final bg = bayGio;
    return SizedBox(
      height: _caoHang,
      child: Stack(
        children: [
          Row(
            children: [
              for (var h = 0; h < 24; h++)
                Container(
                  width: _rongGio,
                  height: _caoHang,
                  decoration: BoxDecoration(
                    color: n.homNay
                        ? HD.accentTint.withValues(alpha: 0.35)
                        : (n.cuoiTuan ? HD.paper.withValues(alpha: 0.45) : null),
                    border: Border(
                      left: BorderSide(
                        color: h % 6 == 0 ? HD.hairlineStrong : HD.hairline,
                        width: h % 6 == 0 ? 1 : 0.4,
                      ),
                      top: BorderSide(
                        color: n.thu == 1 ? HD.hairlineStrong : HD.hairline,
                        width: n.thu == 1 ? 1.1 : 0.4,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (final m in n.muc) _khoi(m),
          if (n.homNay && bg != null)
            Positioned(
              left: (bg.hour + bg.minute / 60) * _rongGio - 1,
              top: 0,
              bottom: 0,
              child: Container(width: 2, color: HD.accent.withValues(alpha: 0.7)),
            ),
        ],
      ),
    );
  }

  Widget _khoi(KhoiGio m) {
    final trai = m.gio * _rongGio;
    final rong = (m.soGio * _rongGio).clamp(22.0, _rongGio * 24);
    final (mau, nen) = m.laChan
        ? (HD.svcBlue, HD.svcBlue.withValues(alpha: 0.14))
        : switch (m.trangThai) {
            'checked_in' => (HD.positive, HD.positiveTint),
            'approved' => (HD.accent, HD.accentTint),
            _ => (HD.svcAmber, HD.warningTint),
          };
    final nhan = m.laChan ? (m.ghiChu ?? 'Dọn phòng') : (m.ten ?? m.nhanKieu);
    return Positioned(
      left: trai,
      top: 4,
      width: rong,
      height: _caoHang - 9,
      child: GestureDetector(
        key: ValueKey('g-${m.loai}-${m.id}'),
        onTap: () => onTap?.call(m),
        child: Tooltip(
          message: '${m.batDau}–${m.ketThuc} · $nhan'
              '${m.tong == null ? '' : ' · ${PriceFormat.full(m.tong!)}'}',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: nen,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(m.tranTruoc ? 0 : 7),
                right: Radius.circular(m.tranSau ? 0 : 7),
              ),
              border: Border.all(color: mau.withValues(alpha: 0.55)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rong >= 58)
                  Text(
                    '${m.batDau} – ${m.ketThuc}',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: HD.bodyBold(size: 8.5, color: mau),
                  ),
                if (rong >= 86)
                  Text(
                    nhan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 8.5, color: HD.inkSoft),
                  ),
                if (rong < 58)
                  Center(
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: mau,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chú thích màu — dùng chung cho mọi nơi vẽ [SoDoGio].
class ChuThichSoDo extends StatelessWidget {
  const ChuThichSoDo({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: HD.s12,
    runSpacing: 6,
    children: [
      for (final (mau, chu) in const [
        (HD.positive, 'Đang ở'),
        (HD.accent, 'Sắp đến'),
        (HD.svcAmber, 'Chờ duyệt'),
        (HD.svcBlue, 'Dọn / khoá'),
      ])
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: mau, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(chu, style: HD.body(size: 11, color: HD.inkMuted)),
          ],
        ),
    ],
  );
}

String _thu(int t) =>
    const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][(t - 1).clamp(0, 6)];

String _hai(int n) => n.toString().padLeft(2, '0');

/// 4.0 → '4h' · 4.5 → '4h30'.
String _soGio(double g) {
  final h = g.floor();
  final p = ((g - h) * 60).round();
  return p == 0 ? '${h}h' : '${h}h$p';
}
