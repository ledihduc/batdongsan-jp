import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/ca_thue_api.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/ca_thue_chung.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/tra_phong_screen.dart';

/// KHÁCH ĐANG Ở — dựng theo mockup "Quản lý đang ở & dịch vụ" (12/09/2026).
///
/// Màn trực trong lúc khách còn trong phòng: còn bao lâu · gia hạn nhanh ·
/// ghi minibar/dịch vụ · tạm tính phải thu khi rời. Từ đây bấm sang thủ tục
/// trả phòng.
///
/// Gia hạn luôn đi qua server (giờ trả được làm tròn lên giờ chẵn theo luật
/// chung) — màn KHÔNG tự cộng giờ rồi hiển thị, vì như vậy hai nơi sẽ ra hai
/// giờ trả khác nhau.
class DangOScreen extends StatefulWidget {
  const DangOScreen({
    super.key,
    required this.reservationId,
    this.api = const CaThueApi(),
  });

  final int reservationId;
  final CaThueApi api;

  @override
  State<DangOScreen> createState() => _DangOScreenState();
}

class _DangOScreenState extends State<DangOScreen> {
  CaThue? _ca;
  bool _dangTai = false;
  bool _dangLam = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  Future<void> _nap() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final ca = await widget.api.lay(widget.reservationId);
      if (mounted) setState(() => _ca = ca);
    } catch (e) {
      if (mounted) {
        setState(
          () => _loi = e is ApiException ? e.message : 'Không tải được ca thuê',
        );
      }
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  void _bao(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _lam(Future<void> Function() viec, String xong) async {
    if (_dangLam) return;
    setState(() => _dangLam = true);
    try {
      await viec();
      if (!mounted) return;
      _bao(xong);
      await _nap();
    } catch (e) {
      if (mounted) _bao(e is ApiException ? e.message : 'Không thực hiện được');
    } finally {
      if (mounted) setState(() => _dangLam = false);
    }
  }

  Future<void> _giaHan(CaThue ca, int phut) => _lam(
    () => widget.api.giaHan(ca.id, themPhut: phut),
    'Đã gia hạn ${doDai(phut)} — giờ trả làm tròn lên giờ chẵn.',
  );

  Future<void> _themPhuThu(CaThue ca) async {
    final m = await hoiPhuThu(context, tenPhong: ca.phong.ma);
    if (m == null || !mounted) return;
    await _lam(
      () => widget.api.themPhuThu(
        ca.id,
        ten: m.ten,
        donGia: m.donGia,
        soLuong: m.soLuong,
        loai: m.loai,
      ),
      'Đã ghi "${m.ten}" vào ca thuê.',
    );
  }

  Future<void> _xoaPhuThu(CaThue ca, PhuThuCa p) => _lam(
    () => widget.api.xoaPhuThu(ca.id, p.id),
    'Đã gỡ "${p.ten}".',
  );

  Future<void> _ghiQuaGio(CaThue ca, DeXuatQuaGio q) => _lam(
    () => widget.api.themPhuThu(
      ca.id,
      ten: q.ten,
      donGia: q.donGia ?? 0,
      soLuong: q.soGio.toDouble(),
      loai: 'qua_gio',
    ),
    'Đã ghi phụ thu quá giờ.',
  );

  Future<void> _sangTraPhong(CaThue ca) async {
    final xong = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TraPhongScreen(reservationId: ca.id, api: widget.api),
      ),
    );
    if (!mounted) return;
    if (xong == true) {
      Navigator.of(context).pop(true);
    } else {
      await _nap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ca = _ca;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        title: Text('Khách đang ở', style: HD.bodyBold(size: 16)),
        actions: [
          IconButton(
            key: const Key('dang-o-tai-lai'),
            onPressed: _dangTai ? null : _nap,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ],
      ),
      body: ca == null
          ? Center(
              child: _dangTai
                  ? const CircularProgressIndicator()
                  : Text(
                      _loi ?? 'Không có dữ liệu',
                      style: HD.body(color: HD.inkMuted),
                    ),
            )
          : RefreshIndicator(
              onRefresh: _nap,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(HD.s16, HD.s16, HD.s16, 24),
                children: [
                  _theDongHo(ca),
                  const SizedBox(height: HD.s12),
                  _theGiaHan(ca),
                  if (ca.deXuatQuaGio != null && ca.xemTaiChinh) ...[
                    const SizedBox(height: HD.s12),
                    _theQuaGio(ca, ca.deXuatQuaGio!),
                  ],
                  const SizedBox(height: HD.s12),
                  _theMinibar(ca),
                  if (ca.xemTaiChinh && ca.tien != null) ...[
                    const SizedBox(height: HD.s12),
                    _theTamTinh(ca),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: ca == null ? null : _thanhDuoi(ca),
    );
  }

  // ── Đồng hồ lưu trú ───────────────────────────────────────────────────────

  Widget _theDongHo(CaThue ca) {
    final td = ca.tienDo;
    final quaGio = td.quaGio;
    final mau = quaGio
        ? HD.negative
        : (td.conPhut <= 30 ? HD.warning : HD.positive);
    return Container(
      padding: const EdgeInsets.all(HD.s16),
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
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: HD.accentTint,
                  borderRadius: BorderRadius.circular(HD.r12),
                ),
                child: const Icon(
                  Icons.meeting_room,
                  color: HD.accent,
                  size: 21,
                ),
              ),
              const SizedBox(width: HD.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phòng ${ca.phong.ma}',
                      style: HD.bodyBold(size: 16, color: HD.ink),
                    ),
                    Text(
                      [
                        if (ca.khachTen != null) 'Khách: ${ca.khachTen}',
                        if (ca.khachSdt != null) ca.khachSdt!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.body(size: 11.5, color: HD.inkMuted),
                    ),
                  ],
                ),
              ),
              ChipTrangThai(ca),
            ],
          ),
          const SizedBox(height: HD.s16),
          Row(
            children: [
              Expanded(
                child: ONhanh(
                  nhan: 'Đã ở',
                  so: doDaiNgan(td.daOPhut),
                  icon: Icons.login,
                ),
              ),
              const SizedBox(width: HD.s8),
              Expanded(
                child: ONhanh(
                  nhan: 'Gói thuê',
                  so: doDaiNgan(td.tongPhut),
                  phu: '${gioPhut(ca.vao)} → ${gioPhut(ca.ra)}',
                  icon: Icons.timer_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: HD.s12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (td.phanTram / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: HD.paperSunken,
              valueColor: AlwaysStoppedAnimation(mau),
            ),
          ),
          const SizedBox(height: HD.s8),
          Row(
            children: [
              Icon(
                quaGio ? Icons.running_with_errors : Icons.hourglass_bottom,
                size: 16,
                color: mau,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  quaGio
                      ? 'Đã quá giờ trả ${doDai(ca.bayGio.difference(ca.ra).inMinutes)}'
                      : 'Còn ${doDai(td.conPhut)} nữa trả phòng',
                  key: const Key('dang-o-con-lai'),
                  style: HD.bodyBold(size: 13.5, color: mau),
                ),
              ),
              Text(
                'Trả ${gioPhut(ca.ra)}',
                style: HD.body(size: 11.5, color: HD.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Gia hạn nhanh ─────────────────────────────────────────────────────────

  Widget _theGiaHan(CaThue ca) => TheCa(
    tieuDe: 'GIA HẠN NHANH',
    cham: HD.warning,
    phai: ca.giaGio == null
        ? null
        : Text(
            '${tien(ca.giaGio!)}/giờ',
            style: HD.body(size: 11, color: HD.inkMuted),
          ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final p in const [30, 60, 120]) ...[
              if (p != 30) const SizedBox(width: HD.s8),
              Expanded(
                child: OutlinedButton(
                  key: Key('dang-o-gia-han-$p'),
                  onPressed: _dangLam ? null : () => _giaHan(ca, p),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HD.warning,
                    side: BorderSide(color: HD.warning.withValues(alpha: 0.45)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(HD.r12),
                    ),
                    textStyle: HD.bodyBold(size: 12.5),
                  ),
                  child: Text(p < 60 ? '+$p phút' : '+${p ~/ 60} giờ'),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: HD.s8),
        Text(
          'Giờ trả mới luôn làm tròn LÊN giờ chẵn — khách dư thời gian, không '
          'bao giờ thiếu.',
          style: HD.body(size: 11, color: HD.inkMuted),
        ),
      ],
    ),
  );

  Widget _theQuaGio(CaThue ca, DeXuatQuaGio q) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: HD.negativeTint,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: HD.negative.withValues(alpha: 0.25)),
    ),
    child: Row(
      children: [
        const Icon(Icons.timer_off_outlined, color: HD.negative, size: 22),
        const SizedBox(width: HD.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Khách ở lố ${doDai(q.phut)}',
                style: HD.bodyBold(size: 13.5, color: HD.negative),
              ),
              Text(
                q.deXuat == null
                    ? 'Chưa có giá theo giờ để tính phụ thu.'
                    : 'Đề xuất phụ thu ${tien(q.deXuat!)} (${q.soGio} giờ)',
                style: HD.body(size: 11.5, color: HD.inkSoft),
              ),
            ],
          ),
        ),
        if (q.deXuat != null)
          FilledButton(
            key: const Key('dang-o-ghi-qua-gio'),
            onPressed: _dangLam ? null : () => _ghiQuaGio(ca, q),
            style: FilledButton.styleFrom(
              backgroundColor: HD.negative,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle: HD.bodyBold(size: 12),
            ),
            child: const Text('Ghi'),
          ),
      ],
    ),
  );

  // ── Minibar & dịch vụ ─────────────────────────────────────────────────────

  Widget _theMinibar(CaThue ca) {
    final ds = ca.phuThu;
    return TheCa(
      tieuDe: 'MINI-BAR & DỊCH VỤ PHÒNG',
      cham: HD.pinStayShort,
      phai: Text(
        ds.isEmpty ? 'Chưa có' : '${ds.length} món',
        style: HD.body(size: 11, color: HD.inkMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!ca.xemTaiChinh)
            Text(
              'Tài khoản này không xem được tiền của phòng.',
              style: HD.body(size: 12, color: HD.inkMuted),
            )
          else if (ds.isEmpty)
            Text(
              'Khách chưa dùng gì thêm.',
              style: HD.body(size: 12.5, color: HD.inkMuted),
            )
          else
            for (final p in ds)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(_iconPhuThu(p.loai), size: 17, color: HD.inkMuted),
                    const SizedBox(width: HD.s8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.ten,
                            style: HD.bodyBold(size: 13, color: HD.ink),
                          ),
                          Text(
                            '${tien(p.donGia)} × ${p.soLuong.toStringAsFixed(0)}',
                            style: HD.body(size: 11, color: HD.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      tien(p.thanhTien),
                      style: HD.bodyBold(size: 13, color: HD.ink),
                    ),
                    IconButton(
                      key: Key('dang-o-xoa-phu-thu-${p.id}'),
                      onPressed: _dangLam ? null : () => _xoaPhuThu(ca, p),
                      icon: const Icon(Icons.close, size: 16),
                      color: HD.inkMuted,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Gỡ khoản này',
                    ),
                  ],
                ),
              ),
          if (ca.xemTaiChinh) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              key: const Key('dang-o-them-phu-thu'),
              onPressed: _dangLam ? null : () => _themPhuThu(ca),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Thêm đồ uống / dịch vụ'),
              style: TextButton.styleFrom(
                foregroundColor: HD.accent,
                textStyle: HD.bodyBold(size: 12.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static IconData _iconPhuThu(String loai) => switch (loai) {
    'qua_gio' => Icons.more_time,
    'boi_thuong' => Icons.report_gmailerrorred,
    'minibar' => Icons.local_drink,
    _ => Icons.room_service_outlined,
  };

  // ── Tạm tính ──────────────────────────────────────────────────────────────

  Widget _theTamTinh(CaThue ca) {
    final t = ca.tien!;
    return TheCa(
      tieuDe: 'TẠM TÍNH KHI RỜI PHÒNG',
      cham: HD.positive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HangTien(
            'Tiền phòng (${ca.nhanKieu.toLowerCase()})',
            tien(t.tienPhong),
          ),
          if (t.phuThu > 0)
            HangTien('Phụ thu & dịch vụ', '+${tien(t.phuThu)}'),
          if (t.daThu > 0)
            HangTien('Đã cọc / đã thu', '-${tien(t.daThu)}', mau: HD.positive),
          const Divider(height: 18, color: HD.hairline),
          Container(
            padding: const EdgeInsets.all(HD.s12),
            decoration: BoxDecoration(
              color: t.conLai > 0 ? HD.accentTint : HD.positiveTint,
              borderRadius: BorderRadius.circular(HD.r12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.conLai >= 0
                        ? 'CẦN THANH TOÁN KHI RỜI'
                        : 'HOÀN LẠI KHÁCH KHI RỜI',
                    style: HD.bodyBold(size: 12, color: HD.inkSoft),
                  ),
                ),
                Text(
                  tien(t.conLai),
                  key: const Key('dang-o-tam-tinh'),
                  style: HD.bodyBold(
                    size: 18,
                    color: t.conLai > 0 ? HD.accent : HD.positive,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thanhDuoi(CaThue ca) => SafeArea(
    minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
    child: Row(
      children: [
        if (ca.xemTaiChinh) ...[
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('dang-o-nut-phu-thu'),
              onPressed: _dangLam ? null : () => _themPhuThu(ca),
              icon: const Icon(Icons.post_add, size: 17),
              label: const Text('Thêm phụ thu'),
              style: OutlinedButton.styleFrom(
                foregroundColor: HD.accent,
                side: BorderSide(color: HD.accent.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(HD.r12),
                ),
                textStyle: HD.bodyBold(size: 12.5),
              ),
            ),
          ),
          const SizedBox(width: HD.s8),
        ],
        Expanded(
          child: SizedBox(
            height: 50,
            child: FilledButton.icon(
              key: const Key('dang-o-tra-phong'),
              onPressed: _dangLam ? null : () => _sangTraPhong(ca),
              icon: const Icon(Icons.receipt_long, size: 18),
              label: Text(
                'Thủ tục check-out',
                style: HD.bodyBold(size: 13.5, color: Colors.white),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: HD.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(HD.r12),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Một khoản phụ thu người trực vừa nhập.
class KhoanPhuThu {
  const KhoanPhuThu(this.ten, this.donGia, this.soLuong, this.loai);

  final String ten;
  final double donGia;
  final double soLuong;
  final String loai;
}

/// Gợi ý những món hay ghi nhất ở quầy — bấm là điền sẵn, vẫn sửa được giá.
const _goiY = <(String, double, String, IconData)>[
  ('Nước suối 500ml', 10000, 'minibar', Icons.local_drink),
  ('Bia lon', 25000, 'minibar', Icons.sports_bar),
  ('Mì ly', 20000, 'minibar', Icons.ramen_dining),
  ('Giặt ủi gấp', 35000, 'dich_vu', Icons.local_laundry_service),
  ('Phụ thu mất thẻ', 50000, 'boi_thuong', Icons.key_off),
];

/// Bảng "Thêm phụ thu & dịch vụ" — mockup mở từ đáy màn.
Future<KhoanPhuThu?> hoiPhuThu(
  BuildContext context, {
  required String tenPhong,
}) {
  final ten = TextEditingController();
  final gia = TextEditingController();
  final sl = TextEditingController(text: '1');
  var loai = 'dich_vu';
  return showModalBottomSheet<KhoanPhuThu>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: StatefulBuilder(
        builder: (ctx, setSt) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(HD.s16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Thêm phụ thu & dịch vụ P.$tenPhong',
                        style: HD.bodyBold(size: 15),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: HD.s8),
                Wrap(
                  spacing: HD.s8,
                  runSpacing: HD.s8,
                  children: [
                    for (final g in _goiY)
                      ActionChip(
                        key: Key('phu-thu-goi-y-${g.$1}'),
                        avatar: Icon(g.$4, size: 15, color: HD.accent),
                        label: Text(
                          '${g.$1} · ${tien(g.$2)}',
                          style: HD.body(size: 11.5),
                        ),
                        onPressed: () => setSt(() {
                          ten.text = g.$1;
                          gia.text = g.$2.toStringAsFixed(0);
                          loai = g.$3;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: HD.s16),
                TextField(
                  key: const Key('phu-thu-ten'),
                  controller: ten,
                  style: HD.body(size: 13.5),
                  decoration: const InputDecoration(labelText: 'Tên khoản'),
                ),
                const SizedBox(height: HD.s8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        key: const Key('phu-thu-don-gia'),
                        controller: gia,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: HD.body(size: 13.5),
                        decoration: const InputDecoration(
                          labelText: 'Đơn giá',
                          suffixText: 'đ',
                        ),
                      ),
                    ),
                    const SizedBox(width: HD.s8),
                    Expanded(
                      child: TextField(
                        key: const Key('phu-thu-so-luong'),
                        controller: sl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: HD.body(size: 13.5),
                        decoration: const InputDecoration(
                          labelText: 'Số lượng',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: HD.s16),
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    key: const Key('phu-thu-luu'),
                    onPressed: () {
                      final g =
                          double.tryParse(gia.text.trim().replaceAll('.', '')) ??
                          0;
                      final s = double.tryParse(sl.text.trim()) ?? 1;
                      if (ten.text.trim().isEmpty || g <= 0 || s <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Nhập tên khoản và đơn giá.'),
                          ),
                        );
                        return;
                      }
                      Navigator.of(
                        ctx,
                      ).pop(KhoanPhuThu(ten.text.trim(), g, s, loai));
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: HD.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(HD.r12),
                      ),
                    ),
                    child: Text(
                      'Ghi vào ca thuê',
                      style: HD.bodyBold(size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
