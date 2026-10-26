import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/ca_thue_api.dart';
import 'package:house_booking/features/host/ngan_han/ca_thue/ca_thue_chung.dart';

/// QUY TRÌNH CHECK-IN 3 BƯỚC — dựng theo mockup "Tiếp đón lưu trú" (12/09/2026).
///
///     1. Xác thực khách → 2. Bàn giao phòng & khoá → 3. Quyết toán thu tiền
///
/// Chia ba bước vì ba bước này người trực làm bằng ba việc khác nhau (nhìn
/// giấy tờ · đi mở phòng · cầm tiền); gộp một biểu mẫu dài thì bước giữa luôn
/// bị bỏ qua. Bấm xong bước 3 mới thật sự `check_in` — đồng hồ lưu trú bắt đầu
/// tính từ đúng lúc đó.
///
/// Mọi thứ tick ở bước 1 và 2 đều được ghi vào GHI CHÚ của ca (`nhan_phong`
/// nhận `ghi_chu`) — không tick cho vui rồi mất.
class NhanPhongScreen extends StatefulWidget {
  const NhanPhongScreen({
    super.key,
    required this.reservationId,
    this.api = const CaThueApi(),
  });

  final int reservationId;
  final CaThueApi api;

  @override
  State<NhanPhongScreen> createState() => _NhanPhongScreenState();
}

class _NhanPhongScreenState extends State<NhanPhongScreen> {
  static const _tenBuoc = ['Xác thực khách', 'Bàn giao khoá', 'Thanh toán'];

  /// Mục bàn giao — tên ngắn để ghi thẳng vào ghi chú ca.
  static const _mucBanGiao = [
    ('khoa', 'Khoá & thẻ phòng', 'Đã giao chìa/thẻ, hướng dẫn mở cửa', Icons.key),
    ('dien', 'Điện, điều hoà & TV', 'Bật thử, hoạt động bình thường', Icons.mode_fan_off),
    ('do', 'Đồ dùng & minibar', 'Đủ khăn, nước, đồ uống trong tủ', Icons.kitchen),
  ];

  CaThue? _ca;
  bool _dangTai = false;
  bool _dangLam = false;
  String? _loi;

  int _buoc = 0;
  bool _daDoiChieu = false;
  final Set<String> _daBanGiao = {};
  final _ghiChuBanGiao = TextEditingController();
  final _soThu = TextEditingController();
  String _hinhThuc = 'tien_mat';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  @override
  void dispose() {
    _ghiChuBanGiao.dispose();
    _soThu.dispose();
    super.dispose();
  }

  Future<void> _nap() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final ca = await widget.api.lay(widget.reservationId);
      if (!mounted) return;
      setState(() {
        _ca = ca;
        final con = ca.tien?.conLai ?? 0;
        if (_soThu.text.isEmpty && con > 0) {
          _soThu.text = con.toStringAsFixed(0);
        }
      });
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

  bool get _quaDuocBuoc {
    if (_buoc == 0) return _daDoiChieu;
    if (_buoc == 1) return _daBanGiao.length == _mucBanGiao.length;
    return true;
  }

  String _ghiChu() {
    final phan = <String>[
      if (_daDoiChieu) 'Đã đối chiếu giấy tờ khách',
      if (_daBanGiao.length == _mucBanGiao.length)
        'Bàn giao đủ: ${_mucBanGiao.map((e) => e.$2.toLowerCase()).join(', ')}'
      else if (_daBanGiao.isNotEmpty)
        'Bàn giao: ${_mucBanGiao.where((e) => _daBanGiao.contains(e.$1)).map((e) => e.$2.toLowerCase()).join(', ')}',
      if (_ghiChuBanGiao.text.trim().isNotEmpty) _ghiChuBanGiao.text.trim(),
    ];
    return 'Check-in: ${phan.join(' · ')}';
  }

  Future<void> _xacNhan(CaThue ca) async {
    final thu = double.tryParse(_soThu.text.trim().replaceAll('.', '')) ?? 0;
    setState(() => _dangLam = true);
    try {
      await widget.api.nhanPhong(
        ca.id,
        thu: thu,
        hinhThuc: _hinhThuc,
        ghiChu: _ghiChu(),
      );
      if (!mounted) return;
      _bao('Đã nhận phòng ${ca.phong.ma}. Đồng hồ lưu trú bắt đầu chạy.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        _bao(e is ApiException ? e.message : 'Không hoàn tất check-in được');
        setState(() => _dangLam = false);
      }
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
        title: Text('Quy trình check-in', style: HD.bodyBold(size: 16)),
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
          : Column(
              children: [
                _dau(ca),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      HD.s16,
                      HD.s12,
                      HD.s16,
                      24,
                    ),
                    children: [
                      if (_buoc == 0) _buocKhach(ca),
                      if (_buoc == 1) _buocBanGiao(ca),
                      if (_buoc == 2) _buocTien(ca),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: ca == null ? null : _thanhDuoi(ca),
    );
  }

  Widget _dau(CaThue ca) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Tiếp đón lưu trú • P.${ca.phong.ma}',
                style: HD.bodyBold(size: 13.5, color: HD.ink),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: HD.accentTint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Bước ${_buoc + 1}/3',
                key: const Key('nhan-phong-buoc'),
                style: HD.bodyBold(size: 11, color: HD.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: HD.s12),
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _buoc ? HD.accent : HD.paperSunken,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${i + 1}. ${_tenBuoc[i]}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.body(
                        size: 10.5,
                        color: i <= _buoc ? HD.accent : HD.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );

  // ── Bước 1 ────────────────────────────────────────────────────────────────

  Widget _buocKhach(CaThue ca) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TheCa(
        tieuDe: 'THÔNG TIN KHÁCH LƯU TRÚ',
        cham: HD.pinBusiness,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HangTien(
              'Khách đại diện',
              ca.khachTen ?? '—',
              icon: Icons.person_outline,
            ),
            HangTien(
              'Số điện thoại',
              ca.khachSdt ?? '—',
              icon: Icons.call_outlined,
            ),
            HangTien(
              'Gói thuê',
              '${ca.nhanKieu} · ${gioPhut(ca.vao)} → ${gioPhut(ca.ra)}',
              icon: Icons.timer_outlined,
            ),
            if (ca.phong.sucChua != null)
              HangTien(
                'Sức chứa phòng',
                '${ca.phong.sucChua} khách',
                icon: Icons.groups_outlined,
              ),
          ],
        ),
      ),
      const SizedBox(height: HD.s12),
      _oTick(
        khoa: const Key('nhan-phong-doi-chieu'),
        bat: _daDoiChieu,
        tieuDe: 'Đã đối chiếu giấy tờ tuỳ thân',
        phu: 'CCCD/hộ chiếu trùng với người đứng tên đặt phòng. Bắt buộc theo '
            'quy định khai báo lưu trú.',
        icon: Icons.badge_outlined,
        doi: (v) => setState(() => _daDoiChieu = v),
      ),
    ],
  );

  // ── Bước 2 ────────────────────────────────────────────────────────────────

  Widget _buocBanGiao(CaThue ca) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final m in _mucBanGiao) ...[
        _oTick(
          khoa: Key('nhan-phong-ban-giao-${m.$1}'),
          bat: _daBanGiao.contains(m.$1),
          tieuDe: m.$2,
          phu: m.$3,
          icon: m.$4,
          doi: (v) => setState(
            () => v ? _daBanGiao.add(m.$1) : _daBanGiao.remove(m.$1),
          ),
        ),
        const SizedBox(height: HD.s8),
      ],
      const SizedBox(height: 4),
      TheCa(
        tieuDe: 'GHI CHÚ BÀN GIAO',
        cham: HD.warning,
        child: TextField(
          key: const Key('nhan-phong-ghi-chu'),
          controller: _ghiChuBanGiao,
          maxLines: 3,
          style: HD.body(size: 13),
          decoration: InputDecoration(
            hintText: 'Thẻ số 08, khách xin thêm 1 gối, wifi tầng 2…',
            hintStyle: HD.body(size: 12.5, color: HD.inkMuted),
            filled: true,
            fillColor: HD.paperSunken,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HD.r12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    ],
  );

  // ── Bước 3 ────────────────────────────────────────────────────────────────

  Widget _buocTien(CaThue ca) {
    if (!ca.xemTaiChinh || ca.tien == null) {
      return TheCa(
        tieuDe: 'QUYẾT TOÁN NHẬN PHÒNG',
        child: Text(
          'Tài khoản này không xem được tiền của phòng. Bấm xác nhận để nhận '
          'phòng, phần thu tiền do chủ nhà thực hiện.',
          style: HD.body(size: 12.5, color: HD.inkMuted),
        ),
      );
    }
    final t = ca.tien!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TheCa(
          tieuDe: 'QUYẾT TOÁN NHẬN PHÒNG',
          cham: HD.positive,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HangTien('Tiền phòng', tien(t.tienPhong)),
              if (t.phuThu > 0) HangTien('Phụ thu đã ghi', '+${tien(t.phuThu)}'),
              if (t.daThu > 0)
                HangTien(
                  'Đã cọc / đã thu trước',
                  '-${tien(t.daThu)}',
                  mau: HD.positive,
                ),
              const Divider(height: 18, color: HD.hairline),
              HangTien(
                'Cần thu khi nhận phòng',
                tien(t.conLai),
                dam: true,
                mau: t.conLai > 0 ? HD.accent : HD.positive,
              ),
            ],
          ),
        ),
        const SizedBox(height: HD.s12),
        TheCa(
          tieuDe: 'THU TẠI QUẦY',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _nutHinhThuc(
                      'tien_mat',
                      'Tiền mặt',
                      Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width: HD.s8),
                  Expanded(
                    child: _nutHinhThuc(
                      'chuyen_khoan',
                      'Chuyển khoản',
                      Icons.qr_code_2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: HD.s12),
              TextField(
                key: const Key('nhan-phong-so-thu'),
                controller: _soThu,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: HD.bodyBold(size: 16),
                decoration: InputDecoration(
                  labelText: 'Số tiền thực thu',
                  suffixText: 'đ',
                  helperText: 'Để 0 nếu khách chưa trả gì lúc nhận phòng.',
                  helperStyle: HD.body(size: 11, color: HD.inkMuted),
                  filled: true,
                  fillColor: HD.paperSunken,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(HD.r12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _nutHinhThuc(String ma, String chu, IconData icon) {
    final chon = _hinhThuc == ma;
    return InkWell(
      key: Key('nhan-phong-ht-$ma'),
      onTap: () => setState(() => _hinhThuc = ma),
      borderRadius: BorderRadius.circular(HD.r12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: chon ? HD.accentTint : HD.paperSunken,
          borderRadius: BorderRadius.circular(HD.r12),
          border: Border.all(
            color: chon ? HD.accent : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: chon ? HD.accent : HD.inkMuted),
            const SizedBox(height: 4),
            Text(
              chu,
              style: HD.bodyBold(
                size: 12,
                color: chon ? HD.accent : HD.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _oTick({
    required Key khoa,
    required bool bat,
    required String tieuDe,
    required String phu,
    required IconData icon,
    required ValueChanged<bool> doi,
  }) => InkWell(
    key: khoa,
    onTap: () => doi(!bat),
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: bat ? HD.positive : HD.hairline.withValues(alpha: 0.8),
          width: bat ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bat ? HD.positiveTint : HD.paperSunken,
              borderRadius: BorderRadius.circular(HD.r12),
            ),
            child: Icon(icon, size: 19, color: bat ? HD.positive : HD.inkMuted),
          ),
          const SizedBox(width: HD.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tieuDe, style: HD.bodyBold(size: 13.5, color: HD.ink)),
                Text(phu, style: HD.body(size: 11.5, color: HD.inkMuted)),
              ],
            ),
          ),
          Icon(
            bat ? Icons.check_circle : Icons.radio_button_unchecked,
            color: bat ? HD.positive : HD.hairlineStrong,
            size: 22,
          ),
        ],
      ),
    ),
  );

  Widget _thanhDuoi(CaThue ca) => SafeArea(
    minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
    child: Row(
      children: [
        if (_buoc > 0) ...[
          OutlinedButton(
            key: const Key('nhan-phong-lui'),
            onPressed: _dangLam ? null : () => setState(() => _buoc--),
            style: OutlinedButton.styleFrom(
              foregroundColor: HD.inkSoft,
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(HD.r12),
              ),
            ),
            child: const Text('Quay lại'),
          ),
          const SizedBox(width: HD.s8),
        ],
        Expanded(
          child: SizedBox(
            height: 50,
            child: FilledButton.icon(
              key: const Key('nhan-phong-tiep'),
              onPressed: !_quaDuocBuoc || _dangLam
                  ? null
                  : () => _buoc == 2
                        ? _xacNhan(ca)
                        : setState(() => _buoc++),
              icon: Icon(
                _buoc == 2 ? Icons.verified_user : Icons.arrow_forward,
                size: 19,
              ),
              label: Text(
                _buoc == 2 ? 'Xác nhận khách đã nhận phòng' : 'Tiếp tục',
                style: HD.bodyBold(size: 14.5, color: Colors.white),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _buoc == 2 ? HD.positive : HD.accent,
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
