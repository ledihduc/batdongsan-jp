import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';

/// Bộ khối giao diện của SỔ CHỦ NHÀ (mockup chủ nhà 06/10/2026): khung màn
/// tiêu đề giữa, thẻ trắng bo 16, nhãn trạng thái phòng, công tắc Dài hạn |
/// Ngắn hạn, chip tầng, tab gạch chân, nút đỏ / viền đỏ, dòng nhãn–giá trị.
/// Mười bốn màn dùng chung một bộ. Màu chỉ lấy từ `HD` (design_tokens).

abstract final class MauCN {
  static const nen = HD.paper;
  static const the = HD.paperRaised;
  static final vien = HD.hairline.withValues(alpha: 0.5);
  static final bong = HD.ink.withValues(alpha: 0.06);

  static const xanh = HD.svcGreen;
  static const xanhNen = HD.positiveTint;
  static const cam = HD.svcOrange;
  static const camNen = HD.warningTint;
  static const lam = HD.pinBusiness;
  static const lamNen = HD.calendarBooked;
  static const xam = HD.neutral;
  static const xamNen = HD.neutralTint;
  static const tim = HD.svcViolet;
}

const kDaiHan = 'dai_han';
const kNganHan = 'ngan_han';

String nhanLoaiThue(String k) => k == kNganHan ? 'Ngắn hạn' : 'Dài hạn';

String anhDayDuCN(String url) =>
    url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';

String _hai(int n) => n.toString().padLeft(2, '0');

/// 4500000 → "4.500.000đ".
String tienCN(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$bđ';
}

String donViCN(String donVi) => switch (donVi) {
  'thang' => 'tháng',
  'dem' => 'đêm',
  'm2_thang' => 'm²/tháng',
  'tong' => '',
  _ => donVi,
};

/// 4500000 + 'thang' → "4.500.000đ/tháng".
String giaCN(double gia, String donVi) {
  final dv = donViCN(donVi);
  return dv.isEmpty ? tienCN(gia) : '${tienCN(gia)}/$dv';
}

DateTime? ngayTu(String? iso) =>
    iso == null || iso.isEmpty ? null : DateTime.tryParse(iso);

/// '2026-10-05' → '05/10/2026'.
String ngayCN(String? iso) {
  final d = ngayTu(iso);
  return d == null ? '—' : '${_hai(d.day)}/${_hai(d.month)}/${d.year}';
}

/// '2026-10-05' → '05/10'.
String ngayNganCN(String? iso) {
  final d = ngayTu(iso);
  return d == null ? '—' : '${_hai(d.day)}/${_hai(d.month)}';
}

/// '2026-10' → 'Tháng 10/2026'.
String kyCN(String ky) =>
    ky.length >= 7 ? 'Tháng ${ky.substring(5, 7)}/${ky.substring(0, 4)}' : ky;

/// 60.0 → "60"; 58.5 → "58,5".
String soCN(double? v) {
  if (v == null) return '—';
  if (v == v.roundToDouble()) return v.round().toString();
  return v.toStringAsFixed(1).replaceAll('.', ',');
}

void baoCN(BuildContext context, String chu, {bool loi = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(chu),
        backgroundColor: loi ? HD.accentDeep : HD.ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

String loiCN(Object e) => e is ApiException ? e.message : 'Có lỗi xảy ra, thử lại sau';

/// Khung một màn: nền xám nhạt, thanh tiêu đề trắng chữ giữa, nút lùi tròn.
class ManCN extends StatelessWidget {
  const ManCN({
    super.key,
    required this.tieuDe,
    required this.body,
    this.coNutLui = true,
    this.hanhDong = const [],
    this.day,
    this.nen = MauCN.nen,
  });

  final String tieuDe;
  final Widget body;
  final bool coNutLui;
  final List<Widget> hanhDong;

  /// Thanh nút dính đáy (Thu tiền / Tạo hóa đơn…).
  final Widget? day;
  final Color nen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: nen,
      appBar: AppBar(
        backgroundColor: MauCN.the,
        surfaceTintColor: MauCN.the,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: coNutLui
            ? IconButton(
                key: const Key('cn-lui'),
                tooltip: 'Quay lại',
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: HD.ink),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: Text(
          tieuDe,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HD.bodyBold(size: 17, color: HD.ink),
        ),
        actions: [...hanhDong, const SizedBox(width: 4)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: MauCN.vien),
        ),
      ),
      body: SafeArea(top: false, child: body),
      bottomNavigationBar: day == null
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: MauCN.the,
                  border: Border(top: BorderSide(color: MauCN.vien)),
                ),
                child: day,
              ),
            ),
    );
  }
}

/// Tải dữ liệu một lần + kéo để tải lại + lỗi có nút thử lại.
class TaiCN<T> extends StatefulWidget {
  const TaiCN({super.key, required this.tai, required this.dung, this.khoaTai});

  final Future<T> Function() tai;
  final Widget Function(BuildContext context, T d, Future<void> Function() taiLai) dung;

  /// Đổi giá trị này là tải lại (vd đổi Dài hạn → Ngắn hạn).
  final Object? khoaTai;

  @override
  State<TaiCN<T>> createState() => _TaiCNState<T>();
}

class _TaiCNState<T> extends State<TaiCN<T>> {
  late Future<T> _f = widget.tai();
  T? _cu;

  @override
  void didUpdateWidget(covariant TaiCN<T> old) {
    super.didUpdateWidget(old);
    if (old.khoaTai != widget.khoaTai) _f = widget.tai();
  }

  Future<void> _taiLai() async {
    final f = widget.tai();
    setState(() => _f = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _f,
      builder: (context, s) {
        if (s.hasData) {
          _cu = s.data;
          return widget.dung(context, s.data as T, _taiLai);
        }
        if (s.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 40, color: HD.inkMuted),
                  const SizedBox(height: 10),
                  Text(
                    loiCN(s.error!),
                    textAlign: TextAlign.center,
                    style: HD.body(color: HD.inkSoft),
                  ),
                  const SizedBox(height: 12),
                  NutCN('Thử lại', kieu: KieuNutCN.vien, onPressed: _taiLai, rong: false),
                ],
              ),
            ),
          );
        }
        final cu = _cu;
        if (cu != null) return widget.dung(context, cu, _taiLai);
        return const Center(child: CircularProgressIndicator(color: HD.accent));
      },
    );
  }
}

/// Thẻ trắng bo góc 16, viền mảnh, bóng nhẹ.
class TheCN extends StatelessWidget {
  const TheCN({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    // Bóng nằm ở Container NGOÀI (vẽ trước, dưới nền trắng). Đặt bóng vào
    // Container bên trong InkWell là nó vẽ ĐÈ lên Material và thẻ ngả xám.
    return Padding(
      padding: margin,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: MauCN.bong, blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Material(
          color: MauCN.the,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MauCN.vien),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ảnh bo góc; không có ảnh thì ô xám có biểu tượng.
class AnhCN extends StatelessWidget {
  const AnhCN({super.key, required this.url, this.rong = 72, this.cao, this.bo = 12});

  final String? url;
  final double rong;
  final double? cao;
  final double bo;

  @override
  Widget build(BuildContext context) {
    final h = cao ?? rong;
    final u = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(bo),
      child: SizedBox(
        width: rong,
        height: h,
        child: u == null || u.isEmpty
            ? Container(
                color: HD.paperSunken,
                alignment: Alignment.center,
                child: Icon(Icons.meeting_room_outlined, color: HD.inkMuted, size: h * 0.36),
              )
            : CachedNetworkImage(
                imageUrl: anhDayDuCN(u),
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Container(color: HD.paperSunken),
                placeholder: (_, _) => Container(color: HD.paperSunken),
              ),
      ),
    );
  }
}

/// Nhãn trạng thái phòng: Đang thuê · Sắp thu · Sắp hết hạn · Trống …
class NhanCN extends StatelessWidget {
  const NhanCN(this.chu, {super.key, required this.mau, required this.nen});

  factory NhanCN.trangThai(String tt, {Key? key}) {
    final (chu, mau, nen) = switch (tt) {
      'dang_thue' => ('Đang thuê', MauCN.xanh, MauCN.xanhNen),
      'sap_thu' => ('Sắp thu', MauCN.cam, MauCN.camNen),
      'sap_het_han' => ('Sắp hết hạn', HD.accent, HD.accentTint),
      'sap_vao' => ('Sắp vào ở', MauCN.lam, MauCN.lamNen),
      'bao_tri' => ('Bảo trì', MauCN.xam, MauCN.xamNen),
      'da_thu' => ('Đã thu', MauCN.xanh, MauCN.xanhNen),
      'thu_mot_phan' => ('Thu một phần', MauCN.cam, MauCN.camNen),
      'chua_thu' => ('Chưa thu', HD.accent, HD.accentTint),
      'dang_hieu_luc' => ('Đang hiệu lực', MauCN.xanh, MauCN.xanhNen),
      'het_han' => ('Hết hạn', MauCN.xam, MauCN.xamNen),
      'da_cham_dut' => ('Đã chấm dứt', MauCN.xam, MauCN.xamNen),
      _ => ('Trống', MauCN.lam, MauCN.lamNen),
    };
    return NhanCN(chu, key: key, mau: mau, nen: nen);
  }

  final String chu;
  final Color mau;
  final Color nen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: nen, borderRadius: BorderRadius.circular(20)),
      child: Text(chu, style: HD.bodyBold(size: 12, color: mau)),
    );
  }
}

enum KieuNutCN { do_, vien, xam }

/// Nút cao 48, bo 12: đỏ đặc / viền đỏ / xám.
class NutCN extends StatelessWidget {
  const NutCN(
    this.chu, {
    super.key,
    required this.onPressed,
    this.kieu = KieuNutCN.do_,
    this.icon,
    this.rong = true,
    this.dangChay = false,
  });

  final String chu;
  final VoidCallback? onPressed;
  final KieuNutCN kieu;
  final IconData? icon;
  final bool rong;
  final bool dangChay;

  @override
  Widget build(BuildContext context) {
    final mauChu = switch (kieu) {
      KieuNutCN.do_ => HD.paperRaised,
      KieuNutCN.vien => HD.accent,
      KieuNutCN.xam => HD.inkSoft,
    };
    final noi = dangChay
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: mauChu),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 19, color: mauChu), const SizedBox(width: 6)],
              Flexible(
                child: Text(
                  chu,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.bodyBold(size: 15, color: mauChu),
                ),
              ),
            ],
          );
    final hinh = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final nut = switch (kieu) {
      KieuNutCN.do_ => FilledButton(
        onPressed: dangChay ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: HD.accent,
          disabledBackgroundColor: HD.accent.withValues(alpha: 0.45),
          minimumSize: const Size(0, 48),
          shape: hinh,
        ),
        child: noi,
      ),
      KieuNutCN.vien => OutlinedButton(
        onPressed: dangChay ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: HD.accent,
          side: const BorderSide(color: HD.accent, width: 1.3),
          minimumSize: const Size(0, 48),
          shape: hinh,
        ),
        child: noi,
      ),
      KieuNutCN.xam => OutlinedButton(
        onPressed: dangChay ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: HD.inkSoft,
          side: BorderSide(color: HD.hairline),
          minimumSize: const Size(0, 48),
          shape: hinh,
        ),
        child: noi,
      ),
    };
    return rong ? SizedBox(width: double.infinity, child: nut) : nut;
  }
}

/// Hai nút cạnh nhau ở đáy màn (vd "Thu tiền" viền | "Tạo hóa đơn" đỏ).
class HaiNutCN extends StatelessWidget {
  const HaiNutCN({super.key, required this.trai, required this.phai});

  final Widget trai;
  final Widget phai;

  @override
  Widget build(BuildContext context) => Row(
    children: [Expanded(child: trai), const SizedBox(width: 12), Expanded(child: phai)],
  );
}

/// Công tắc hai ô bo tròn — ô đang chọn nền đỏ chữ trắng.
class CongTacCN extends StatelessWidget {
  const CongTacCN({
    super.key,
    required this.cacO,
    required this.chon,
    required this.onChon,
    this.khoa = const [],
  });

  final List<String> cacO;
  final int chon;
  final ValueChanged<int> onChon;
  final List<Key> khoa;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: HD.paperSunken.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cacO.length; i++)
            Expanded(
              child: GestureDetector(
                key: i < khoa.length ? khoa[i] : null,
                behavior: HitTestBehavior.opaque,
                onTap: () => onChon(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == chon ? HD.accent : HD.paperSunken.withValues(alpha: 0),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    cacO[i],
                    style: i == chon
                        ? HD.bodyBold(size: 14.5, color: HD.paperRaised)
                        : HD.body(size: 14.5, color: HD.inkSoft),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dải chip cuộn ngang — chip chọn viền + chữ đỏ nền hồng nhạt.
class DaiChipCN extends StatelessWidget {
  const DaiChipCN({super.key, required this.chip, required this.chon, required this.onChon});

  final List<String> chip;
  final int chon;
  final ValueChanged<int> onChon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chip.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final dang = i == chon;
          return GestureDetector(
            key: Key('chip-$i'),
            onTap: () => onChon(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: dang ? HD.accentTint : MauCN.the,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: dang ? HD.accent : HD.hairline),
              ),
              child: Text(
                chip[i],
                style: dang
                    ? HD.bodyBold(size: 13.5, color: HD.accent)
                    : HD.body(size: 13.5, color: HD.inkSoft),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Tab gạch chân đỏ (Tháng này | Lịch sử, Thu tiền | Chi phí …).
class TabCN extends StatelessWidget {
  const TabCN({super.key, required this.tab, required this.chon, required this.onChon});

  final List<String> tab;
  final int chon;
  final ValueChanged<int> onChon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MauCN.the,
      child: Row(
        children: [
          for (var i = 0; i < tab.length; i++)
            Expanded(
              child: InkWell(
                key: Key('tab-$i'),
                onTap: () => onChon(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == chon ? HD.accent : MauCN.vien,
                        width: i == chon ? 2.5 : 1,
                      ),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tab[i],
                      style: i == chon
                          ? HD.bodyBold(size: 14.5, color: HD.accent)
                          : HD.body(size: 14.5, color: HD.inkMuted),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dòng "Nhãn ............ Giá trị".
class DongCN extends StatelessWidget {
  const DongCN(this.nhan, this.giaTri, {super.key, this.dam = false, this.mau, this.dem = 10});

  final String nhan;
  final String giaTri;
  final bool dam;
  final Color? mau;
  final double dem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dem),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(nhan, style: HD.body(size: 14.5, color: HD.inkMuted))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              giaTri,
              textAlign: TextAlign.right,
              style: dam
                  ? HD.bodyBold(size: 14.5, color: mau ?? HD.ink)
                  : HD.body(size: 14.5, color: mau ?? HD.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiêu đề khối + chữ đỏ bên phải ("Xem tất cả").
class TieuDeKhoiCN extends StatelessWidget {
  const TieuDeKhoiCN(this.chu, {super.key, this.phai, this.onPhai});

  final String chu;
  final String? phai;
  final VoidCallback? onPhai;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(chu, style: HD.bodyBold(size: 16.5, color: HD.ink))),
          if (phai != null)
            InkWell(
              onTap: onPhai,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: Text(phai!, style: HD.bodyBold(size: 13.5, color: HD.accent)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Màn rỗng nhẹ nhàng.
class RongCN extends StatelessWidget {
  const RongCN(this.chu, {super.key, this.icon = Icons.inbox_outlined});

  final String chu;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 40, color: HD.hairlineStrong),
          const SizedBox(height: 10),
          Text(chu, textAlign: TextAlign.center, style: HD.body(color: HD.inkMuted)),
        ],
      ),
    );
  }
}

/// Ô vuông icon bo góc nền nhạt (đầu dòng việc / dịch vụ).
class OIconCN extends StatelessWidget {
  const OIconCN(this.icon, {super.key, required this.mau, required this.nen, this.co = 40});

  final IconData icon;
  final Color mau;
  final Color nen;
  final double co;

  @override
  Widget build(BuildContext context) => Container(
    width: co,
    height: co,
    decoration: BoxDecoration(color: nen, borderRadius: BorderRadius.circular(co * 0.3)),
    alignment: Alignment.center,
    child: Icon(icon, color: mau, size: co * 0.52),
  );
}

/// Icon + màu của một dịch vụ theo tên.
(IconData, Color) bieuTuongDichVu(String ma, String ten) {
  final t = ten.toLowerCase();
  if (ma == 'dien' || t.contains('điện')) return (Icons.bolt_rounded, MauCN.cam);
  if (ma == 'nuoc' || t.contains('nước')) return (Icons.water_drop_outlined, MauCN.lam);
  if (t.contains('internet') || t.contains('wifi') || t.contains('mạng')) {
    return (Icons.wifi_rounded, MauCN.tim);
  }
  if (t.contains('xe')) return (Icons.two_wheeler_rounded, MauCN.xanh);
  if (t.contains('vệ sinh') || t.contains('rác')) {
    return (Icons.cleaning_services_outlined, HD.svcTeal);
  }
  return (Icons.room_service_outlined, HD.accent);
}

/// Ô nhập số / chữ kiểu form của mockup: nhãn trên, ô bo 12 viền xám.
class ONhapCN extends StatelessWidget {
  const ONhapCN({
    super.key,
    required this.nhan,
    required this.ctrl,
    this.goiY,
    this.so = false,
    this.duoi,
    this.khoa,
  });

  final String nhan;
  final TextEditingController ctrl;
  final String? goiY;
  final bool so;
  final String? duoi;
  final Key? khoa;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nhan, style: HD.bodyBold(size: 14, color: HD.ink)),
        const SizedBox(height: 8),
        TextField(
          key: khoa,
          controller: ctrl,
          keyboardType: so ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          style: HD.body(size: 15, color: HD.ink),
          decoration: kieuONhapCN(goiY: goiY, duoi: duoi),
        ),
      ],
    );
  }
}

InputDecoration kieuONhapCN({String? goiY, String? duoi}) => InputDecoration(
  hintText: goiY,
  hintStyle: HD.body(size: 15, color: HD.inkMuted),
  suffixText: duoi,
  suffixStyle: HD.body(size: 14, color: HD.inkMuted),
  filled: true,
  fillColor: MauCN.the,
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: HD.hairline),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: HD.hairline),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: HD.accent, width: 1.4),
  ),
);

/// Đọc số người dùng gõ: "4.500.000" → 4500000; "58,5" → 58.5.
double? docSoCN(String s) {
  final t = s.trim().replaceAll(' ', '').replaceAll('đ', '');
  if (t.isEmpty) return null;
  if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
    return double.tryParse(t.replaceAll('.', ''));
  }
  return double.tryParse(t.replaceAll(',', '.'));
}
