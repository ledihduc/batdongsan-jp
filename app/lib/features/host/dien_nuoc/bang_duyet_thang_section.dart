import 'package:flutter/material.dart';

import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/dien_nuoc_api.dart';
import 'package:house_booking/features/host/dien_nuoc/dien_nuoc_chung.dart';

/// BẢNG DUYỆT CẢ TOÀ — thân màn Điện nước khi chọn "Tất cả phòng": thẻ số, tiến
/// độ duyệt của toà, tìm / lọc, rồi từng thẻ phòng với số và ảnh công tơ.
///
/// Chủ nhà hai mươi phòng cần duyệt hàng loạt; bắt bấm từng phòng là một buổi
/// tối. Màn chi tiết một phòng (theo mockup) lo phần xem kỹ.
///
/// Phần trăm dưới mỗi thẻ là tỉ lệ trên TỔNG SỐ PHÒNG của tháng, không phải "so
/// với tháng trước" — nên KHÔNG vẽ mũi tên tăng/giảm ở đây.
class BangDuyetThangSection extends StatefulWidget {
  const BangDuyetThangSection({
    super.key,
    required this.bang,
    required this.nhanThangHien,
    required this.onDuyet,
    required this.onChupLai,
    required this.onXem,
  });

  final BangDienNuoc bang;

  /// 'Tháng 9, 2026' — đã dịch sẵn ở màn, khỏi tính hai lần.
  final String nhanThangHien;
  final void Function(DongDienNuoc) onDuyet;
  final void Function(DongDienNuoc) onChupLai;

  /// Mở chi tiết phòng đó (đổi ô chọn phòng ở đầu màn).
  final void Function(DongDienNuoc) onXem;

  @override
  State<BangDuyetThangSection> createState() => _BangDuyetThangSectionState();
}

class _BangDuyetThangSectionState extends State<BangDuyetThangSection> {
  String _loc = 'tat_ca';
  String _tim = '';

  List<DongDienNuoc> get _dong => widget.bang.dong.where((d) {
    final hopLoc = switch (_loc) {
      'cho_duyet' => d.trangThai == 'cho_duyet',
      'da_duyet' => d.trangThai == 'da_duyet',
      'thieu_anh' => d.trangThai == 'thieu_anh' || d.trangThai == 'can_chup_lai',
      _ => true,
    };
    final q = _tim.trim().toLowerCase();
    final hopTim = q.isEmpty ||
        d.maPhong.toLowerCase().contains(q) ||
        d.nguoiThue.toLowerCase().contains(q);
    return hopLoc && hopTim;
  }).toList();

  @override
  Widget build(BuildContext context) {
    final b = widget.bang;
    final dong = _dong;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _theSo(b),
        const SizedBox(height: HD.s12),
        _tienDo(b),
        const SizedBox(height: HD.s12),
        _timVaLoc(),
        const SizedBox(height: HD.s12),
        if (b.tongPhong == 0)
          const DienNuocRong('Toà này chưa có phòng nào đang có hợp đồng dài hạn.')
        else if (dong.isEmpty)
          const DienNuocRong('Không có phòng nào khớp bộ lọc.')
        else
          for (final d in dong)
            _ThePhong(
              d: d,
              onDuyet: () => widget.onDuyet(d),
              onChupLai: () => widget.onChupLai(d),
              onXem: () => widget.onXem(d),
            ),
      ],
    );
  }

  String _tyLe(int so, int tong) =>
      tong == 0 ? '' : '${(so / tong * 100).toStringAsFixed(1)}% số phòng';

  Widget _theSo(BangDienNuoc b) => Container(
    padding: const EdgeInsets.all(HD.s12),
    decoration: BoxDecoration(
      color: HD.accentTint,
      borderRadius: BorderRadius.circular(HD.r12),
      border: Border.all(color: HD.hairline),
    ),
    child: LayoutBuilder(
      builder: (_, c) {
        final o = [
          _O(
            icon: Icons.assignment_turned_in_outlined,
            mau: HD.positive,
            so: '${b.daGui}',
            nhan: 'Phòng đã gửi chỉ số',
            phu: _tyLe(b.daGui, b.tongPhong),
          ),
          _O(
            icon: Icons.schedule,
            mau: HD.svcOrange,
            so: '${b.choDuyet}',
            nhan: 'Chờ duyệt',
            phu: _tyLe(b.choDuyet, b.tongPhong),
          ),
          _O(
            icon: Icons.image_not_supported_outlined,
            mau: HD.negative,
            so: '${b.thieuAnh}',
            nhan: 'Thiếu ảnh',
            phu: _tyLe(b.thieuAnh, b.tongPhong),
          ),
          _O(
            icon: Icons.account_balance_wallet_outlined,
            mau: HD.accent,
            so: PriceFormat.full(b.tongTamTinh),
            nhan: 'Tổng tạm tính',
            phu: '',
          ),
        ];
        final cot = c.maxWidth >= 560 ? 4 : 2;
        return Wrap(
          children: [
            for (final x in o)
              SizedBox(width: (c.maxWidth / cot).floorToDouble(), child: x),
          ],
        );
      },
    ),
  );

  Widget _tienDo(BangDienNuoc b) {
    final xong = b.tongPhong > 0 && b.daDuyet == b.tongPhong;
    return Container(
      padding: const EdgeInsets.all(HD.s12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(HD.r12),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tiến độ duyệt ${widget.nhanThangHien.toLowerCase()}',
                  style: HD.bodyBold(size: 15),
                ),
              ),
              if (b.chuaGui > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HD.s8,
                    vertical: HD.s4,
                  ),
                  decoration: BoxDecoration(
                    color: HD.accentTint,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule, size: 14, color: HD.accent),
                      const SizedBox(width: 4),
                      Text(
                        'Còn ${b.chuaGui} phòng chưa gửi',
                        style: HD.body(size: 12, color: HD.accent),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: HD.s12),
          Row(
            children: [
              _Buoc(
                nhan: 'Người thuê gửi chỉ số',
                phu: '${b.daGui}/${b.tongPhong} phòng',
                trangThai: b.daGui > 0 ? _TT.xong : _TT.cho,
              ),
              _Noi(xong: b.daGui > 0),
              _Buoc(
                nhan: 'Chủ nhà duyệt',
                phu: '${b.choDuyet} phòng',
                trangThai: xong
                    ? _TT.xong
                    : (b.choDuyet > 0 ? _TT.dangLam : _TT.cho),
              ),
              _Noi(xong: xong),
              _Buoc(
                nhan: 'Hoàn tất',
                phu: '${b.daDuyet}/${b.tongPhong} phòng',
                trangThai: xong ? _TT.xong : _TT.cho,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timVaLoc() => Wrap(
    spacing: HD.s8,
    runSpacing: HD.s8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: 280,
        child: TextField(
          onChanged: (v) => setState(() => _tim = v),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search),
            hintText: 'Tìm phòng, tên khách thuê...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HD.r12),
              borderSide: const BorderSide(color: HD.hairline),
            ),
          ),
        ),
      ),
      for (final (k, nhan) in const [
        ('tat_ca', 'Tất cả'),
        ('cho_duyet', 'Chờ duyệt'),
        ('da_duyet', 'Đã duyệt'),
        ('thieu_anh', 'Thiếu ảnh'),
      ])
        ChoiceChip(
          label: Text(nhan),
          selected: _loc == k,
          selectedColor: HD.accent,
          labelStyle: TextStyle(color: _loc == k ? Colors.white : HD.ink),
          onSelected: (_) => setState(() => _loc = k),
        ),
    ],
  );
}

enum _TT { xong, dangLam, cho }

class _O extends StatelessWidget {
  const _O({
    required this.icon,
    required this.mau,
    required this.so,
    required this.nhan,
    required this.phu,
  });

  final IconData icon;
  final Color mau;
  final String so;
  final String nhan;
  final String phu;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(HD.s8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: mau.withValues(alpha: 0.12),
          child: Icon(icon, size: 18, color: mau),
        ),
        const SizedBox(height: HD.s4),
        Text(so, style: HD.bodyBold(size: 20)),
        Text(nhan, style: HD.body(size: 12, color: HD.inkMuted)),
        if (phu.isNotEmpty) Text(phu, style: HD.body(size: 11, color: mau)),
      ],
    ),
  );
}

class _Buoc extends StatelessWidget {
  const _Buoc({required this.nhan, required this.phu, required this.trangThai});

  final String nhan;
  final String phu;
  final _TT trangThai;

  @override
  Widget build(BuildContext context) {
    final mau = switch (trangThai) {
      _TT.xong || _TT.dangLam => HD.accent,
      _TT.cho => HD.inkMuted,
    };
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: trangThai == _TT.xong ? HD.accent : Colors.white,
              border: Border.all(color: mau, width: 2),
            ),
            child: trangThai == _TT.xong
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : (trangThai == _TT.dangLam
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: HD.accent,
                            ),
                          ),
                        )
                      : null),
          ),
          const SizedBox(height: HD.s4),
          Text(
            nhan,
            textAlign: TextAlign.center,
            style: HD.body(
              size: 12,
              color: trangThai == _TT.dangLam ? HD.accent : HD.ink,
            ),
          ),
          Text(phu, style: HD.body(size: 11, color: HD.inkMuted)),
        ],
      ),
    );
  }
}

class _Noi extends StatelessWidget {
  const _Noi({required this.xong});

  final bool xong;

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 2,
    margin: const EdgeInsets.only(bottom: 34),
    color: xong ? HD.accent : HD.hairline,
  );
}

class _ThePhong extends StatelessWidget {
  const _ThePhong({
    required this.d,
    required this.onDuyet,
    required this.onChupLai,
    required this.onXem,
  });

  final DongDienNuoc d;
  final VoidCallback onDuyet;
  final VoidCallback onChupLai;
  final VoidCallback onXem;

  @override
  Widget build(BuildContext context) {
    final n = nhanTrangThaiChiSo(d.trangThai);
    final daGui = d.readingId != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: HD.s12),
      child: Container(
        padding: const EdgeInsets.all(HD.s12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(HD.r12),
          border: Border.all(color: HD.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(d.maPhong, style: HD.bodyBold(size: 20)),
                const SizedBox(width: HD.s8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HD.s8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: n.mau.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(n.icon, size: 14, color: n.mau),
                      const SizedBox(width: 4),
                      Text(n.chu, style: HD.body(size: 12, color: n.mau)),
                    ],
                  ),
                ),
                const SizedBox(width: HD.s8),
                Expanded(
                  child: Text(
                    d.capNhat == null ? '' : 'Cập nhật: ${ngayGioVN(d.capNhat)}',
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: HD.body(size: 11, color: HD.inkMuted),
                  ),
                ),
              ],
            ),
            if (d.nguoiThue.isNotEmpty)
              Text(d.nguoiThue, style: HD.body(size: 14)),
            if (d.hopDongDen.isNotEmpty)
              Text(
                'HĐ đến ${ngayVN(d.hopDongDen)}',
                style: HD.body(size: 12, color: HD.inkMuted),
              ),
            const SizedBox(height: HD.s8),
            if (!daGui)
              Text(
                'Chưa gửi chỉ số tháng này.',
                style: HD.body(size: 13, color: HD.inkMuted),
              )
            else
              LayoutBuilder(
                builder: (_, c) {
                  final so = Row(
                    children: [
                      _SoDo(
                        icon: Icons.bolt,
                        mau: HD.negative,
                        nhan: 'Điện (kWh)',
                        so: soDienNuoc(d.dienDung ?? d.dienMoi),
                        phu: '(${soDienNuoc(d.dienCu)} → ${soDienNuoc(d.dienMoi)})',
                      ),
                      _SoDo(
                        icon: Icons.water_drop,
                        mau: HD.svcBlue,
                        nhan: 'Nước (m³)',
                        so: soDienNuoc(d.nuocDung ?? d.nuocMoi),
                        phu: '(${soDienNuoc(d.nuocCu)} → ${soDienNuoc(d.nuocMoi)})',
                      ),
                      _SoDo(
                        icon: Icons.account_balance_wallet_outlined,
                        mau: HD.accent,
                        nhan: 'Thành tiền',
                        so: d.thanhTien == null
                            ? '—'
                            : PriceFormat.full(d.thanhTien!),
                        phu: '',
                      ),
                    ],
                  );
                  final anh = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnhCongTo(
                        url: d.anhDien,
                        nhan: 'điện',
                        mau: HD.negative,
                        rong: 96,
                        nhanDuoi: true,
                      ),
                      const SizedBox(width: HD.s8),
                      AnhCongTo(
                        url: d.anhNuoc,
                        nhan: 'nước',
                        mau: HD.svcBlue,
                        rong: 96,
                        nhanDuoi: true,
                      ),
                    ],
                  );
                  return c.maxWidth >= 620
                      ? Row(children: [Expanded(child: so), anh])
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [so, const SizedBox(height: HD.s8), anh],
                        );
                },
              ),
            const SizedBox(height: HD.s8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onXem,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Xem chi tiết'),
                ),
                if (daGui && d.trangThai != 'da_duyet') ...[
                  const SizedBox(width: HD.s8),
                  // Thiếu ảnh / đã bị trả về thì nút chính là CHỤP LẠI, không
                  // phải Duyệt: duyệt một con số không có ảnh đối chiếu là tự
                  // bỏ đi lý do tồn tại của cả luồng này.
                  if (d.trangThai == 'cho_duyet')
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: HD.accent),
                      onPressed: onDuyet,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Duyệt'),
                    )
                  else if (d.trangThai == 'thieu_anh')
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: HD.accentTint,
                        foregroundColor: HD.accent,
                      ),
                      onPressed: onChupLai,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yêu cầu chụp lại'),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SoDo extends StatelessWidget {
  const _SoDo({
    required this.icon,
    required this.mau,
    required this.nhan,
    required this.so,
    required this.phu,
  });

  final IconData icon;
  final Color mau;
  final String nhan;
  final String so;
  final String phu;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: mau),
        const SizedBox(width: 4),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nhan, style: HD.body(size: 12, color: HD.inkMuted)),
              Text(so, style: HD.bodyBold(size: 16)),
              if (phu.isNotEmpty)
                Text(phu, style: HD.body(size: 11, color: HD.inkMuted)),
            ],
          ),
        ),
      ],
    ),
  );
}
