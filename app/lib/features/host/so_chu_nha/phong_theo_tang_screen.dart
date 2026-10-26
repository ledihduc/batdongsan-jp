import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/so_chu_nha_api.dart';
import 'package:house_booking/features/host/so_chu_nha/tai_khoan_nhan_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/nhap_phong_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/setup_tang_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/sua_phong_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/thong_tin_phong_screen.dart';
import 'package:house_booking/features/host/so_chu_nha/widgets/so_ui.dart';

/// Màn 3 — danh sách phòng của một toà, lọc theo tầng. Tiêu đề = tên toà.
///
/// Chip "Tất cả (28)" · "Tầng 1 (6)" …; mỗi dòng: ảnh · "Phòng 101" ·
/// "25 m² · Dài hạn" · giá · nhãn Đang thuê / Sắp thu / Trống / Sắp hết hạn
/// kèm dòng đỏ nhỏ "Thu tiền 05/10" / "Hết hạn 20/10".
/// API: `GET /api/host/so-chu-nha/toa-nha/{id}/phong`.
class PhongTheoTangScreen extends StatefulWidget {
  const PhongTheoTangScreen({
    super.key,
    required this.toaId,
    required this.tenToa,
    this.api = const SoChuNhaApi(),
  });

  final int toaId;
  final String tenToa;
  final SoChuNhaApi api;

  @override
  State<PhongTheoTangScreen> createState() => _PhongTheoTangScreenState();
}

class _PhongTheoTangScreenState extends State<PhongTheoTangScreen> {
  int _lan = 0;
  int _chip = 0;

  Future<void> _day(Widget man) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => man));
    if (mounted) setState(() => _lan++);
  }

  Future<void> _menuThem() async {
    final chon = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: MauCN.the,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const Key('cn-menu-them-phong'),
                leading: const OIconCN(Icons.add_home_outlined, mau: HD.accent, nen: HD.accentTint),
                title: Text('Thêm phòng', style: HD.bodyBold(size: 15, color: HD.ink)),
                subtitle: Text('Nhập từng phòng', style: HD.body(size: 13, color: HD.inkMuted)),
                onTap: () => Navigator.pop(context, 'them'),
              ),
              ListTile(
                key: const Key('cn-menu-nhap'),
                leading: const OIconCN(Icons.upload_file_outlined, mau: MauCN.xanh, nen: MauCN.xanhNen),
                title: Text('Import dữ liệu phòng', style: HD.bodyBold(size: 15, color: HD.ink)),
                subtitle: Text('Nhập nhiều phòng từ file Excel', style: HD.body(size: 13, color: HD.inkMuted)),
                onTap: () => Navigator.pop(context, 'nhap'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || chon == null) return;
    if (chon == 'them') {
      await _day(SuaPhongScreen(toaId: widget.toaId, api: widget.api));
    } else {
      await _day(NhapPhongScreen(toaId: widget.toaId, tenToa: widget.tenToa, api: widget.api));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ManCN(
      tieuDe: widget.tenToa,
      hanhDong: [
        IconButton(
          key: const Key('cn-tai-khoan-toa'),
          tooltip: 'Tài khoản nhận tiền',
          onPressed: () => _day(TaiKhoanNhanScreen.toa(toaId: widget.toaId, api: widget.api)),
          icon: const Icon(Icons.account_balance_outlined, color: HD.ink, size: 24),
        ),
        IconButton(
          key: const Key('cn-setup-tang'),
          tooltip: 'Setup tầng',
          onPressed: () => _day(SetupTangScreen(toaId: widget.toaId, api: widget.api)),
          icon: const Icon(Icons.layers_outlined, color: HD.ink, size: 24),
        ),
        IconButton(
          key: const Key('cn-them-phong'),
          tooltip: 'Thêm phòng',
          onPressed: _menuThem,
          icon: const Icon(Icons.add_circle_outline_rounded, color: HD.accent, size: 26),
        ),
      ],
      body: TaiCN<PhongCuaToaCN>(
        khoaTai: _lan,
        tai: () => widget.api.phongCuaToa(widget.toaId),
        dung: (context, d, taiLai) {
          final chip = [
            'Tất cả (${d.phong.length})',
            for (final t in d.tang) '${t.nhan} (${t.so})',
          ];
          final chon = _chip.clamp(0, chip.length - 1);
          final cacTang = chon == 0 ? d.tang : [d.tang[chon - 1]];
          return Column(
            children: [
              const SizedBox(height: 12),
              DaiChipCN(chip: chip, chon: chon, onChon: (i) => setState(() => _chip = i)),
              const SizedBox(height: 6),
              Expanded(
                child: RefreshIndicator(
                  color: HD.accent,
                  onRefresh: taiLai,
                  child: ListView(
                    key: const Key('cn-ds-phong'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (d.phong.isEmpty)
                        const RongCN('Chưa có phòng nào.\nBấm + để thêm phòng hoặc import từ Excel.', icon: Icons.meeting_room_outlined),
                      if (chon == 0 && d.tang.any((t) => t.ten == 'Khác')) _nhacSetup(d),
                      for (final t in cacTang) ...[
                        _dauTang(t),
                        for (final p in d.phong.where((p) => p.tang == t.ten)) _dong(p),
                        const SizedBox(height: 8),
                      ],
                      if (chon == 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: NutCN(
                            'Thêm tầng mới (Tầng ${d.tangMoi})',
                            key: const Key('cn-them-tang'),
                            kieu: KieuNutCN.vien,
                            icon: Icons.add_rounded,
                            onPressed: () => _day(
                              SuaPhongScreen(toaId: widget.toaId, tangMacDinh: d.tangMoi, api: widget.api),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _nhacSetup(PhongCuaToaCN d) {
    final n = d.tang.firstWhere((t) => t.ten == 'Khác').so;
    return Material(
      color: MauCN.camNen,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const Key('cn-nhac-setup-tang'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => _day(SetupTangScreen(toaId: widget.toaId, api: widget.api)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.layers_outlined, color: MauCN.cam),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$n phòng chưa xếp tầng',
                  style: HD.bodyBold(size: 14, color: HD.ink),
                ),
              ),
              Text('Setup tầng', style: HD.bodyBold(size: 14, color: HD.accent)),
              const Icon(Icons.chevron_right_rounded, color: HD.accent),
            ],
          ),
        ),
      ),
    );
  }

  /// Tiêu đề khối một tầng: nhãn tầng · số phòng · đang thuê · trống · nút +
  /// thêm phòng vào ĐÚNG tầng này.
  Widget _dauTang(TangCN t) {
    return Padding(
      key: Key('cn-tang-${t.ten}'),
      padding: const EdgeInsets.fromLTRB(2, 10, 0, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: HD.accent, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.layers_outlined, size: 15, color: HD.paperRaised),
                const SizedBox(width: 5),
                Text(t.ten == 'Khác' ? 'Chưa xếp tầng' : t.nhan, style: HD.bodyBold(size: 13.5, color: HD.paperRaised)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${t.so} phòng', style: HD.body(size: 13, color: HD.inkSoft)),
                  TextSpan(text: ' · ', style: HD.body(size: 13, color: HD.inkMuted)),
                  TextSpan(text: '${t.dangThue} đang thuê', style: HD.bodyBold(size: 13, color: MauCN.xanh)),
                  if (t.trong > 0) ...[
                    TextSpan(text: ' · ', style: HD.body(size: 13, color: HD.inkMuted)),
                    TextSpan(text: '${t.trong} trống', style: HD.bodyBold(size: 13, color: MauCN.lam)),
                  ],
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            key: Key('cn-them-phong-tang-${t.ten}'),
            tooltip: 'Thêm phòng vào ${t.nhan.toLowerCase()}',
            visualDensity: VisualDensity.compact,
            onPressed: () => _day(SuaPhongScreen(toaId: widget.toaId, tangMacDinh: t.ten, api: widget.api)),
            icon: const Icon(Icons.add_circle_outline_rounded, color: HD.accent, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _dong(ThePhongCN p) {
    final phu = [
      if (p.dienTich != null) '${soCN(p.dienTich)} m²',
      nhanLoaiThue(p.loaiThue),
    ].join(' · ');
    return TheCN(
      key: Key('cn-phong-${p.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      onTap: () => _day(ThongTinPhongScreen(roomId: p.id, api: widget.api)),
      child: Column(
        children: [
          Row(
            children: [
              AnhCN(url: p.anh, rong: 74, bo: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.ten, style: HD.bodyBold(size: 15.5, color: HD.ink)),
                    const SizedBox(height: 3),
                    Text(phu, style: HD.body(size: 13, color: HD.inkMuted)),
                    const SizedBox(height: 5),
                    Text(giaCN(p.gia, p.donVi), style: HD.bodyBold(size: 14, color: HD.accent)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  NhanCN.trangThai(p.trangThai),
                  if (p.ghiChu != null) ...[
                    const SizedBox(height: 6),
                    Text(p.ghiChu!, style: HD.body(size: 12, color: HD.accent)),
                  ],
                ],
              ),
            ],
          ),
          if (p.khach != null) _nguoiThue(p),
        ],
      ),
    );
  }

  /// Khối người thuê dưới thẻ: tên · ngày lập HĐ · hết hạn HĐ (còn N ngày) ·
  /// hạn trả tiền phòng (còn N ngày). Ngắn hạn: giờ trả phòng (còn N giờ).
  Widget _nguoiThue(ThePhongCN p) {
    String con(int? n, String donVi) {
      if (n == null) return '';
      if (n < 0) return 'quá ${-n} $donVi';
      if (n == 0) return 'hôm nay';
      return 'còn $n $donVi';
    }

    Color mauCon(int? n, int canhBao) =>
        n == null ? HD.inkSoft : (n < 0 ? HD.accent : (n <= canhBao ? MauCN.cam : HD.inkSoft));

    final dong = <(IconData, String, String, String, Color)>[
      if (p.hdLap != null) (Icons.edit_document, 'Lập HĐ', ngayCN(p.hdLap), '', HD.inkSoft),
      if (p.hdHetHan != null)
        (Icons.event_busy_outlined, 'Hết hạn HĐ', ngayCN(p.hdHetHan), con(p.hdConNgay, 'ngày'), mauCon(p.hdConNgay, 30)),
      if (p.thuTienNgay != null)
        (Icons.payments_outlined, 'Trả tiền phòng', ngayCN(p.thuTienNgay), con(p.thuTienConNgay, 'ngày'), mauCon(p.thuTienConNgay, 5)),
      if (p.traPhongLuc != null) (Icons.logout_rounded, 'Trả phòng', _gioNgay(p.traPhongLuc!), _conGio(p.traPhongConGio), _mauGio(p.traPhongConGio)),
      // Thuê trước, bổ sung sau — nhắc phần giấy tờ còn thiếu của hợp đồng.
      if (p.thieuGiayTo.isNotEmpty)
        (
          Icons.warning_amber_rounded,
          'Giấy tờ',
          '',
          'Thiếu ${p.thieuGiayTo.map((x) => x == 'hop_dong' ? 'HĐ' : 'cọc').join(' · ')}',
          MauCN.cam,
        ),
    ];
    return Container(
      key: Key('cn-nguoi-thue-${p.id}'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(color: MauCN.nen, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 17, color: HD.ink),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  p.khach!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.bodyBold(size: 14, color: HD.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final d in dong)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(d.$1, size: 15, color: HD.inkMuted),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 104,
                    child: Text(d.$2, style: HD.body(size: 12.5, color: HD.inkMuted)),
                  ),
                  Text(d.$3, style: HD.body(size: 12.5, color: HD.ink)),
                  const Spacer(),
                  if (d.$4.isNotEmpty) Text(d.$4, style: HD.bodyBold(size: 12.5, color: d.$5)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Giờ còn tới lúc trả phòng; âm = quá giờ mà chưa bấm trả phòng.
  String _conGio(int? g) {
    if (g == null) return '';
    if (g < 0) return -g >= 24 ? 'quá hạn ${-g ~/ 24} ngày' : 'quá hạn ${-g} giờ';
    if (g == 0) return 'sắp trả';
    return g >= 24 ? 'còn ${g ~/ 24} ngày' : 'còn $g giờ';
  }

  Color _mauGio(int? g) => g == null ? HD.inkSoft : (g < 0 ? HD.accent : (g <= 2 ? MauCN.cam : HD.inkSoft));

  /// ISO giờ địa phương → "12:00 07/10".
  String _gioNgay(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    String h(int n) => n.toString().padLeft(2, '0');
    return '${h(d.hour)}:${h(d.minute)} ${h(d.day)}/${h(d.month)}';
  }
}
