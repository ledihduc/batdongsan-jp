import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/chat/chat_screen.dart';

/// Bộ khối giao diện của tab "Hoạt động" phía SALE (mockup 05/10/2026):
/// thanh tiêu đề giữa, công tắc Dài hạn/Ngắn hạn, dải chip lọc, nhãn trạng
/// thái, thẻ trắng, ảnh vuông, avatar, nút tròn gọi/nhắn. Mười màn dùng chung
/// một bộ để trông như một ứng dụng. Màu chỉ lấy từ `HD` (design_tokens).

abstract final class SaleMau {
  static const nen = HD.paperRaised;
  static const nenXam = HD.paper;
  static final vien = HD.hairline.withValues(alpha: 0.45);
  static final bong = HD.ink.withValues(alpha: 0.05);

  static const xanh = HD.svcGreen;
  static const xanhNen = HD.positiveTint;
  static const cam = HD.svcAmber;
  static const camNen = HD.warningTint;
  static const camDam = HD.svcOrange;
  static const lam = HD.pinBusiness;
  static const lamNen = HD.calendarBooked;
  static final lamNhat = HD.calendarBooked.withValues(alpha: 0.55);
  static const tim = HD.svcViolet;
  static const xam = HD.neutral;
  static const xamNen = HD.neutralTint;
}

const kKenhDaiHan = 'dai_han';
const kKenhNganHan = 'ngan_han';

String nhanKenh(String kenh) => kenh == kKenhNganHan ? 'Ngắn hạn' : 'Dài hạn';

/// Ảnh từ server có thể là đường dẫn tương đối `/uploads/...`.
String anhDayDu(String url) =>
    url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';

String _hai(int n) => n.toString().padLeft(2, '0');

/// 4500000 → "4.500.000đ".
String tienSale(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}${b}đ';
}

/// 4500000 + "tháng" → "4.500.000đ/tháng".
String giaSale(double? gia, String donVi) {
  if (gia == null || gia <= 0) return 'Giá liên hệ';
  return donVi.isEmpty ? tienSale(gia) : '${tienSale(gia)}/$donVi';
}

String ngayThang(DateTime d) => '${_hai(d.day)}/${_hai(d.month)}';
String ngayDayDu(DateTime d) => '${ngayThang(d)}/${d.year}';
String gioPhut(DateTime d) => '${_hai(d.hour)}:${_hai(d.minute)}';

/// "09:00-09:30" → "09:00 - 09:30".
String khungGio(String gio) =>
    gio.split('-').map((s) => s.trim()).where((s) => s.isNotEmpty).join(' - ');

/// "28 m²" (bỏ ".0").
String dienTichSale(double? m2) {
  if (m2 == null || m2 <= 0) return '';
  return '${m2 % 1 == 0 ? m2.toInt() : m2} m²';
}

Future<void> goiSo(BuildContext context, String sdt) async {
  final so = sdt.replaceAll(RegExp(r'[^0-9+]'), '');
  if (so.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chưa có số điện thoại')),
    );
    return;
  }
  await launchUrl(Uri(scheme: 'tel', path: so));
}

Future<void> nhanTinVoi(
  BuildContext context, {
  required int? userId,
  required String ten,
  String? anh,
}) async {
  if (userId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Khách này chưa có tài khoản để nhắn tin')),
    );
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          ChatScreen(peerId: userId, peerName: ten, peerAvatar: anh ?? ''),
    ),
  );
}

// ── Khung trang ──────────────────────────────────────────────────────────────
/// Trang con: nút quay lại trái, tiêu đề đậm giữa (phần ngoặc nhạt hơn).
class TrangSale extends StatelessWidget {
  const TrangSale({
    super.key,
    required this.tieuDe,
    required this.body,
    this.phuDe,
    this.coNutLui = true,
    this.nutNoi,
  });

  final String tieuDe;

  /// "(Dài hạn)", "(chỉ xem)" — in nhạt hơn ngay sau tiêu đề.
  final String? phuDe;
  final Widget body;
  final bool coNutLui;
  final Widget? nutNoi;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SaleMau.nen,
    appBar: AppBar(
      backgroundColor: SaleMau.nen,
      surfaceTintColor: SaleMau.nen,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: coNutLui
          ? IconButton(
              tooltip: 'Quay lại',
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: HD.ink,
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: tieuDe, style: HD.bodyBold(size: 18, color: HD.ink)),
            if (phuDe != null)
              TextSpan(
                text: ' $phuDe',
                style: HD.body(size: 17, color: HD.inkSoft),
              ),
          ],
        ),
      ),
    ),
    body: body,
    floatingActionButton: nutNoi,
  );
}

/// Công tắc hai ô (Dài hạn | Ngắn hạn, Khách hàng | Chủ nhà…): ô chọn nền
/// đỏ chữ trắng, ô kia nền xám nhạt.
class CongTacHaiO extends StatelessWidget {
  const CongTacHaiO({
    super.key,
    required this.trai,
    required this.phai,
    required this.chonTrai,
    required this.onChon,
    this.khoaTrai = const Key('cong-tac-trai'),
    this.khoaPhai = const Key('cong-tac-phai'),
  });

  final String trai;
  final String phai;
  final bool chonTrai;
  final ValueChanged<bool> onChon;
  final Key khoaTrai;
  final Key khoaPhai;

  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: SaleMau.nenXam,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        _o(trai, chonTrai, () => onChon(true), khoaTrai),
        _o(phai, !chonTrai, () => onChon(false), khoaPhai),
      ],
    ),
  );

  Widget _o(String chu, bool chon, VoidCallback onTap, Key khoa) => Expanded(
    child: Material(
      color: chon ? HD.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: khoa,
        borderRadius: BorderRadius.circular(10),
        onTap: chon ? null : onTap,
        child: Center(
          child: Text(
            chu,
            style: chon
                ? HD.bodyBold(size: 15, color: Colors.white)
                : HD.body(size: 15, color: HD.inkMuted),
          ),
        ),
      ),
    ),
  );
}

/// Dải chip lọc cuộn ngang: "Tất cả (24)" · "Đang đăng (12)" …
class DaiChipSale extends StatelessWidget {
  const DaiChipSale({
    super.key,
    required this.chip,
    required this.chon,
    required this.onChon,
    this.hienSo = true,
  });

  /// (khoá, nhãn, số)
  final List<(String, String, int)> chip;
  final String chon;
  final ValueChanged<String> onChon;
  final bool hienSo;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: chip.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final (khoa, nhan, so) = chip[i];
        final dangChon = khoa == chon;
        return Material(
          color: dangChon ? HD.accent : SaleMau.nenXam,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            key: Key('chip-$khoa'),
            borderRadius: BorderRadius.circular(10),
            onTap: () => onChon(khoa),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: Text(
                  hienSo ? '$nhan ($so)' : nhan,
                  style: dangChon
                      ? HD.bodyBold(size: 13.5, color: Colors.white)
                      : HD.body(size: 13.5, color: HD.inkSoft),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Nhãn trạng thái bo góc nhỏ ở góc phải thẻ.
class NhanSale extends StatelessWidget {
  const NhanSale(this.chu, {super.key, required this.mau, required this.nen});

  final String chu;
  final Color mau;
  final Color nen;

  factory NhanSale.tong(String chu, String tong) {
    final (m, n) = mauTong(tong);
    return NhanSale(chu, mau: m, nen: n);
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: nen,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      chu,
      maxLines: 1,
      style: HD.bodyBold(size: 11.5, color: mau),
    ),
  );
}

/// (màu chữ, màu nền) theo tông server trả: cam · lam · xanh · do · xam · tim.
(Color, Color) mauTong(String tong) => switch (tong) {
  'xanh' => (SaleMau.xanh, SaleMau.xanhNen),
  'lam' => (SaleMau.lam, SaleMau.lamNen),
  'do' => (HD.accent, HD.accentTint),
  'xam' => (SaleMau.xam, SaleMau.xamNen),
  'tim' => (SaleMau.tim, SaleMau.lamNen),
  _ => (SaleMau.cam, SaleMau.camNen),
};

/// Thẻ trắng bo 14, viền rất nhạt + bóng mờ.
class TheSale extends StatelessWidget {
  const TheSale({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(12),
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    decoration: BoxDecoration(
      color: SaleMau.nen,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: SaleMau.vien),
      boxShadow: [
        BoxShadow(color: SaleMau.bong, blurRadius: 12, offset: const Offset(0, 3)),
      ],
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

/// Ảnh vuông bo góc; thiếu ảnh thì ô xám có biểu tượng phòng.
class AnhSale extends StatelessWidget {
  const AnhSale({super.key, this.url, this.co = 88, this.cao});

  final String? url;
  final double co;
  final double? cao;

  @override
  Widget build(BuildContext context) {
    final nen = Container(
      color: SaleMau.nenXam,
      alignment: Alignment.center,
      child: const Icon(Icons.bed_outlined, color: HD.inkMuted, size: 28),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: co,
        height: cao ?? co,
        child: url == null
            ? nen
            : CachedNetworkImage(
                imageUrl: anhDayDu(url!),
                fit: BoxFit.cover,
                placeholder: (_, _) => nen,
                errorWidget: (_, _, _) => nen,
              ),
      ),
    );
  }
}

/// Avatar tròn; thiếu ảnh thì chữ cái cuối của tên trên nền đỏ nhạt.
class AvatarSale extends StatelessWidget {
  const AvatarSale({super.key, required this.ten, this.url, this.co = 46});

  final String ten;
  final String? url;
  final double co;

  @override
  Widget build(BuildContext context) {
    final t = ten.trim();
    final chu = t.isEmpty ? '?' : t.split(RegExp(r'\s+')).last.characters.first.toUpperCase();
    final nen = Container(
      width: co,
      height: co,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: HD.accentTint, shape: BoxShape.circle),
      child: Text(chu, style: HD.bodyBold(size: co * 0.4, color: HD.accent)),
    );
    if (url == null) return nen;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: anhDayDu(url!),
        width: co,
        height: co,
        fit: BoxFit.cover,
        placeholder: (_, _) => nen,
        errorWidget: (_, _, _) => nen,
      ),
    );
  }
}

/// Nút tròn nền đỏ nhạt, icon đỏ (gọi / nhắn).
class NutTronSale extends StatelessWidget {
  const NutTronSale({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.co = 42,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double co;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: HD.accentTint,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: co,
          height: co,
          child: Icon(icon, size: co * 0.48, color: HD.accent),
        ),
      ),
    ),
  );
}

/// Dòng icon nhỏ + chữ xám: "08/10 • 09:00 - 09:30", "Quận 7, TP.HCM".
class DongIconSale extends StatelessWidget {
  const DongIconSale({
    super.key,
    required this.icon,
    required this.chu,
    this.mau = HD.inkMuted,
    this.co = 13,
  });

  final IconData icon;
  final String chu;
  final Color mau;
  final double co;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: co + 2, color: mau),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          chu,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HD.body(size: co, color: mau),
        ),
      ),
    ],
  );
}

/// Ô tìm kiếm nền xám bo tròn.
class OTimSale extends StatelessWidget {
  const OTimSale({super.key, required this.goiY, required this.onDoi});

  final String goiY;
  final ValueChanged<String> onDoi;

  @override
  Widget build(BuildContext context) => TextField(
    key: const Key('o-tim'),
    onChanged: onDoi,
    style: HD.body(size: 14.5, color: HD.ink),
    decoration: InputDecoration(
      isDense: true,
      hintText: goiY,
      hintStyle: HD.body(size: 14.5, color: HD.inkMuted),
      prefixIcon: const Icon(Icons.search_rounded, color: HD.inkMuted),
      filled: true,
      fillColor: SaleMau.nenXam,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

enum KieuNutSale { do_, vienDo, lam, vienXam }

/// Nút trong thẻ: đỏ đặc, viền đỏ, xanh dương đặc, viền xám chữ đỏ.
class NutSale extends StatelessWidget {
  const NutSale(
    this.chu, {
    super.key,
    required this.kieu,
    required this.onPressed,
    this.cao = 40,
  });

  final String chu;
  final KieuNutSale kieu;
  final VoidCallback? onPressed;
  final double cao;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(9));
    final chuStyle = HD.bodyBold(size: 14);
    final noiDung = FittedBox(fit: BoxFit.scaleDown, child: Text(chu));
    return SizedBox(
      height: cao,
      width: double.infinity,
      child: switch (kieu) {
        KieuNutSale.do_ || KieuNutSale.lam => FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: kieu == KieuNutSale.lam ? SaleMau.lam : HD.accent,
            foregroundColor: Colors.white,
            shape: shape,
            textStyle: chuStyle,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: onPressed,
          child: noiDung,
        ),
        KieuNutSale.vienDo || KieuNutSale.vienXam => OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: HD.accent,
            side: BorderSide(
              color: kieu == KieuNutSale.vienDo ? HD.accent : HD.hairline,
            ),
            shape: shape,
            textStyle: chuStyle,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: onPressed,
          child: noiDung,
        ),
      },
    );
  }
}

/// Khối trống có lời giải thích (không vẽ màn trắng).
class RongSale extends StatelessWidget {
  const RongSale({super.key, required this.chu, this.icon = Icons.inbox_outlined});

  final String chu;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40, color: HD.hairlineStrong),
        const SizedBox(height: 10),
        Text(
          chu,
          textAlign: TextAlign.center,
          style: HD.body(size: 14, color: HD.inkMuted),
        ),
      ],
    ),
  );
}

/// Tải dữ liệu một lần + kéo để tải lại + báo lỗi có nút Thử lại.
class TaiSale<T> extends StatefulWidget {
  const TaiSale({
    super.key,
    required this.tai,
    required this.dung,
    this.khoaTai,
  });

  final Future<T> Function() tai;
  final Widget Function(BuildContext context, T data, Future<void> Function() taiLai)
  dung;

  /// Đổi khoá (vd. đổi kênh) → tải lại từ đầu.
  final Object? khoaTai;

  @override
  State<TaiSale<T>> createState() => _TaiSaleState<T>();
}

class _TaiSaleState<T> extends State<TaiSale<T>> {
  T? _data;
  String? _loi;
  int _lan = 0;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  @override
  void didUpdateWidget(covariant TaiSale<T> old) {
    super.didUpdateWidget(old);
    if (old.khoaTai != widget.khoaTai) {
      setState(() => _data = null);
      _nap();
    }
  }

  Future<void> _nap() async {
    final lan = ++_lan;
    setState(() => _loi = null);
    try {
      final d = await widget.tai();
      if (mounted && lan == _lan) setState(() => _data = d);
    } catch (e) {
      if (mounted && lan == _lan) {
        setState(() => _loi = 'Chưa tải được dữ liệu. Kiểm tra mạng rồi thử lại.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d != null) return widget.dung(context, d, _nap);
    if (_loi == null) {
      return const Center(child: CircularProgressIndicator(color: HD.accent));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loi!,
              textAlign: TextAlign.center,
              style: HD.body(size: 14, color: HD.inkMuted),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('thu-lai'),
              onPressed: _nap,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

void baoSale(BuildContext context, String chu) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(chu)));
}
