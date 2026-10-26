import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/config/env.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/features/chat/chat_screen.dart';
import 'package:house_booking/features/guest/lich_xem/trang_thai_xem.dart';
import 'package:house_booking/features/guest/thue_o/ho_so_thue.dart';
import 'package:house_booking/providers/wishlist_provider.dart';

/// Khối giao diện của luồng LỊCH XEM PHÒNG phía khách (mockup 04/10/2026):
/// ảnh lớn có nút quay lại · tim · chia sẻ, thẻ "Sale phụ trách", thanh 5 bước,
/// hộp thông báo màu, cặp nút viền + đỏ ở chân trang.

const kVienXem = Color(0xFFEDEEF1);

/// Ảnh lớn đầu màn chi tiết: vuốt được, đếm "1/N", nút quay lại / tim / chia sẻ.
class AnhLichXem extends StatefulWidget {
  const AnhLichXem({super.key, required this.tin});

  final TomTatCan tin;

  @override
  State<AnhLichXem> createState() => _AnhLichXemState();
}

class _AnhLichXemState extends State<AnhLichXem> {
  int _i = 0;
  bool? _thich;

  List<String> get _anh {
    final ds = widget.tin.anhDs.isNotEmpty
        ? widget.tin.anhDs
        : [if (widget.tin.anh != null) widget.tin.anh!];
    return [for (final u in ds) duongDanAnh(u)];
  }

  bool _daThich() {
    if (_thich != null) return _thich!;
    final id = widget.tin.houseId;
    if (id == null) return false;
    try {
      return context.read<WishlistProvider>().isFavorited(id);
    } catch (_) {
      return false; // màn mở ngoài cây Provider (test) — coi như chưa lưu
    }
  }

  Future<void> _boThich() async {
    final id = widget.tin.houseId!;
    final cu = _daThich();
    setState(() => _thich = !cu);
    try {
      const api = ApiClient();
      if (cu) {
        await api.delete('/api/wishlists', queryParameters: {'houseId': id});
      } else {
        await api.post('/api/wishlists', body: {'house_id': id});
      }
    } catch (_) {
      if (mounted) setState(() => _thich = cu);
    }
  }

  Future<void> _chiaSe() async {
    final t = widget.tin;
    final url = Env.housePublicUrl(t.houseId!, t.tieuDe);
    try {
      await Share.share('${t.tieuDe}\n$url');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ds = _anh;
    const nen = ColoredBox(
      color: HD.paperSunken,
      child: Center(
        child: Icon(Icons.apartment_rounded, size: 48, color: HD.inkMuted),
      ),
    );
    final thich = _daThich();
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (ds.isEmpty)
            nen
          else
            PageView.builder(
              key: const Key('anh-lich-xem'),
              itemCount: ds.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) => CachedNetworkImage(
                imageUrl: ds[i],
                fit: BoxFit.cover,
                placeholder: (_, _) => nen,
                errorWidget: (_, _, _) => nen,
              ),
            ),
          Positioned(
            left: 10,
            top: 10,
            child: _NutAnh(
              tooltip: 'Quay lại',
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          if (widget.tin.houseId != null)
            Positioned(
              right: 10,
              top: 10,
              child: Row(
                children: [
                  _NutAnh(
                    key: const Key('lich-xem-tim'),
                    tooltip: thich ? 'Bỏ lưu' : 'Lưu phòng',
                    icon: thich
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    mau: thich ? HD.accent : HD.ink,
                    onTap: _boThich,
                  ),
                  const SizedBox(width: 8),
                  _NutAnh(
                    tooltip: 'Chia sẻ',
                    icon: Icons.share_outlined,
                    onTap: _chiaSe,
                  ),
                ],
              ),
            ),
          if (ds.length > 1)
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(HD.rPill),
                ),
                child: Text(
                  '${_i + 1}/${ds.length}',
                  style: HD.bodyBold(size: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NutAnh extends StatelessWidget {
  const _NutAnh({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.mau = HD.ink,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color mau;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: mau),
        ),
      ),
    ),
  );
}

/// Nhãn trạng thái tròn: "Đã gửi lịch", "Đã xác nhận"…
class NhanBuocXem extends StatelessWidget {
  const NhanBuocXem(this.buoc, {super.key});

  final BuocXem buoc;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: buoc.nen,
      borderRadius: BorderRadius.circular(HD.rPill),
    ),
    child: Text(buoc.chu, style: HD.bodyBold(size: 12, color: buoc.mau)),
  );
}

/// Ảnh đại diện tròn (chữ cái đầu khi không có ảnh).
class AnhDaiDien extends StatelessWidget {
  const AnhDaiDien({super.key, required this.ten, this.anh, this.co = 44});

  final String ten;
  final String? anh;
  final double co;

  @override
  Widget build(BuildContext context) {
    final chu = ten.trim().isEmpty
        ? '?'
        : ten.trim().split(RegExp(r'\s+')).last.characters.first.toUpperCase();
    final macDinh = Container(
      width: co,
      height: co,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: HD.accentTint,
        shape: BoxShape.circle,
      ),
      child: Text(chu, style: HD.bodyBold(size: co * 0.4, color: HD.accent)),
    );
    if (anh == null || anh!.isEmpty) return macDinh;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: duongDanAnh(anh!),
        width: co,
        height: co,
        fit: BoxFit.cover,
        placeholder: (_, _) => macDinh,
        errorWidget: (_, _, _) => macDinh,
      ),
    );
  }
}

/// Thẻ "Sale phụ trách": ảnh · tên · ★ điểm (N lượt xem) · gọi · nhắn.
class TheSalePhuTrach extends StatelessWidget {
  const TheSalePhuTrach({
    super.key,
    required this.sale,
    required this.onNhan,
  });

  final SalePhuTrach sale;
  final VoidCallback onNhan;

  @override
  Widget build(BuildContext context) {
    final sdt = sale.sdtDaChe ? '' : sale.sdt;
    final luot = '${sale.soLanXemXong} lượt xem';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kVienXem),
      ),
      child: Row(
        children: [
          AnhDaiDien(ten: sale.ten, anh: sale.anh),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sale phụ trách',
                  style: HD.body(size: 12, color: HD.inkMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  sale.ten,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HD.bodyBold(size: 15, color: HD.ink),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (sale.danhGia != null) ...[
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: Color(0xFFF5A524),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        sale.danhGia!.toStringAsFixed(1),
                        style: HD.bodyBold(size: 12.5, color: HD.ink),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        sale.danhGia != null ? '($luot)' : luot,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HD.body(size: 12.5, color: HD.inkMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _NutTronLienHe(
            key: const Key('sale-goi'),
            tooltip: sdt.isEmpty ? 'Chưa có số điện thoại' : 'Gọi $sdt',
            icon: Icons.call_outlined,
            onTap: sdt.isEmpty
                ? null
                : () => launchUrl(Uri(scheme: 'tel', path: sdt)),
          ),
          _NutTronLienHe(
            key: const Key('sale-nhan'),
            tooltip: 'Nhắn tin',
            icon: Icons.chat_bubble_outline_rounded,
            onTap: onNhan,
          ),
        ],
      ),
    );
  }
}

class _NutTronLienHe extends StatelessWidget {
  const _NutTronLienHe({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Tooltip(
      message: tooltip,
      child: Material(
        color: HD.accentTint,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 19,
              color: onTap == null ? HD.inkMuted : HD.accent,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Thanh 5 bước: chấm tròn nối nhau, bước đã qua tô đỏ có dấu ✓, bước hiện
/// tại viền đỏ, bước sau xám.
class ThanhBuocXem extends StatelessWidget {
  const ThanhBuocXem({super.key, required this.buoc});

  final BuocXem buoc;

  @override
  Widget build(BuildContext context) {
    final hienTai = buoc.buocHienTai;
    return Row(
      key: const Key('thanh-buoc-xem'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < kTenBuoc.length; i++)
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: 26,
                  child: Row(
                    children: [
                      Expanded(
                        child: i == 0
                            ? const SizedBox()
                            : Container(
                                height: 2,
                                color: i <= hienTai
                                    ? HD.accent
                                    : const Color(0xFFE3E5E9),
                              ),
                      ),
                      _ChamBuoc(xong: i < hienTai, dangO: i == hienTai),
                      Expanded(
                        child: i == kTenBuoc.length - 1
                            ? const SizedBox()
                            : Container(
                                height: 2,
                                color: i < hienTai
                                    ? HD.accent
                                    : const Color(0xFFE3E5E9),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    kTenBuoc[i],
                    textAlign: TextAlign.center,
                    style: i <= hienTai
                        ? HD.bodyBold(size: 11, color: HD.ink)
                        : HD.body(size: 11, color: HD.inkMuted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ChamBuoc extends StatelessWidget {
  const _ChamBuoc({required this.xong, required this.dangO});

  final bool xong;
  final bool dangO;

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: xong ? HD.accent : Colors.white,
      shape: BoxShape.circle,
      border: Border.all(
        color: xong || dangO ? HD.accent : const Color(0xFFD5D8DD),
        width: 2,
      ),
    ),
    child: xong
        ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
        : dangO
        ? Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: HD.accent,
                shape: BoxShape.circle,
              ),
            ),
          )
        : null,
  );
}

/// Hộp thông báo có icon: vàng (chờ), xanh lá (đã xác nhận), xanh dương…
class HopThongBao extends StatelessWidget {
  const HopThongBao({
    super.key,
    required this.icon,
    required this.chu,
    required this.mau,
    required this.nen,
  });

  final IconData icon;
  final String chu;
  final Color mau;
  final Color nen;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: nen,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: mau),
        const SizedBox(width: 10),
        Expanded(
          child: Text(chu, style: HD.body(size: 13.5, color: HD.ink)),
        ),
      ],
    ),
  );
}

/// Cặp nút chân trang: trái viền xám, phải nền đỏ.
class HaiNutChan extends StatelessWidget {
  const HaiNutChan({
    super.key,
    required this.trai,
    required this.onTrai,
    required this.phai,
    required this.onPhai,
    this.khoaTrai = const Key('nut-trai'),
    this.khoaPhai = const Key('nut-phai'),
    this.dangChay = false,
  });

  final String trai;
  final VoidCallback? onTrai;
  final String phai;
  final VoidCallback? onPhai;
  final Key khoaTrai;
  final Key khoaPhai;
  final bool dangChay;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kVienXem)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                key: khoaTrai,
                style: OutlinedButton.styleFrom(
                  foregroundColor: HD.ink,
                  side: const BorderSide(color: Color(0xFFD5D8DD)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: HD.bodyBold(size: 14.5),
                ),
                onPressed: dangChay ? null : onTrai,
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(trai)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 46,
              child: FilledButton(
                key: khoaPhai,
                style: FilledButton.styleFrom(
                  backgroundColor: HD.accent,
                  disabledBackgroundColor: HD.accent.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: HD.bodyBold(size: 14.5),
                ),
                onPressed: dangChay ? null : onPhai,
                child: dangChay
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : FittedBox(fit: BoxFit.scaleDown, child: Text(phai)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Mở khung chat với sale, kèm thẻ tin đang hẹn xem.
Future<void> nhanTinSale(
  BuildContext context,
  SalePhuTrach sale,
  TomTatCan tin,
) => Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => ChatScreen(
      peerId: sale.id,
      peerName: sale.ten,
      peerAvatar: sale.anh ?? '',
      houseId: tin.houseId,
      houseTitle: tin.tieuDe,
      houseImage: tin.anh,
      housePrice: tin.gia,
    ),
  ),
);
