import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/sale_van_hanh_api.dart';
import 'package:house_booking/features/host/post/post_house_screen.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/nhan_sale.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/sale_ui.dart';

/// Màn 4 — "Bài đăng của tôi" (mockup 05/10/2026): tin sale đăng theo kênh,
/// chip trạng thái, mỗi thẻ có giá · diện tích · loại · khu vực và ba con số
/// hiệu quả (khách · lịch xem · chờ chốt). Nút nổi "+ Đăng tin mới".
/// API: `GET /api/sale/van-hanh/bai-dang?kenh=`.
class BaiDangCuaToiScreen extends StatefulWidget {
  const BaiDangCuaToiScreen({
    super.key,
    this.kenh = kKenhDaiHan,
    this.api = const SaleVanHanhApi(),
    this.moDangTin,
    this.moTin,
  });

  final String kenh;
  final SaleVanHanhApi api;

  /// Mở màn đăng tin (test tiêm để không dựng cả form đăng tin).
  final Future<void> Function(BuildContext context)? moDangTin;

  /// Mở trang tin công khai.
  final void Function(BuildContext context, int houseId)? moTin;

  @override
  State<BaiDangCuaToiScreen> createState() => _BaiDangCuaToiScreenState();
}

class _BaiDangCuaToiScreenState extends State<BaiDangCuaToiScreen> {
  late String _kenh = widget.kenh;
  String _loc = 'tat_ca';
  int _lan = 0;

  Future<void> _dangTin() async {
    final mo = widget.moDangTin;
    if (mo != null) {
      await mo(context);
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PostHouseScreen()),
      );
    }
    if (mounted) setState(() => _lan++);
  }

  void _xemTin(int id) {
    final mo = widget.moTin;
    if (mo != null) return mo(context, id);
    context.push('/house/$id');
  }

  @override
  Widget build(BuildContext context) => TrangSale(
    tieuDe: 'Bài đăng của tôi',
    nutNoi: FloatingActionButton.extended(
      key: const Key('dang-tin-moi'),
      backgroundColor: HD.accent,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onPressed: _dangTin,
      icon: const Icon(Icons.add_rounded),
      label: Text('Đăng tin mới', style: HD.bodyBold(size: 15, color: Colors.white)),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: CongTacHaiO(
            trai: 'Dài hạn',
            phai: 'Ngắn hạn',
            chonTrai: _kenh == kKenhDaiHan,
            onChon: (trai) => setState(() {
              _kenh = trai ? kKenhDaiHan : kKenhNganHan;
              _loc = 'tat_ca';
            }),
          ),
        ),
        Expanded(
          child: TaiSale<DanhSachSale<BaiDangSale>>(
            khoaTai: '$_kenh-$_lan',
            tai: () => widget.api.baiDang(_kenh),
            dung: (context, d, taiLai) {
              final ds = _loc == 'tat_ca'
                  ? d.ds
                  : [for (final b in d.ds) if (b.nhom.contains(_loc)) b];
              return Column(
                children: [
                  DaiChipSale(
                    chip: [for (final c in d.chip) (c.khoa, c.nhan, c.so)],
                    chon: _loc,
                    onChon: (k) => setState(() => _loc = k),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: RefreshIndicator(
                      color: HD.accent,
                      onRefresh: taiLai,
                      child: ds.isEmpty
                          ? ListView(
                              children: [
                                RongSale(
                                  chu: d.ds.isEmpty
                                      ? 'Bạn chưa có tin ${nhanKenh(_kenh).toLowerCase()} nào. '
                                            'Bấm "Đăng tin mới" để bắt đầu.'
                                      : 'Không có tin nào ở mục này.',
                                  icon: Icons.article_outlined,
                                ),
                              ],
                            )
                          : ListView.builder(
                              key: const Key('ds-bai-dang'),
                              // Chừa chỗ cho nút nổi "Đăng tin mới".
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                              itemCount: ds.length,
                              itemBuilder: (_, i) => _TheBaiDang(
                                b: ds[i],
                                kenh: _kenh,
                                onTap: () => _xemTin(ds[i].id),
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _TheBaiDang extends StatelessWidget {
  const _TheBaiDang({required this.b, required this.kenh, required this.onTap});

  final BaiDangSale b;
  final String kenh;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (chu, tong) = nhanBaiDang(b.trangThai, kenh);
    final ngan = kenh == kKenhNganHan;
    return TheSale(
      key: Key('the-bai-dang-${b.id}'),
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnhSale(url: b.anh, co: 92),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            b.tieuDe,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: HD.bodyBold(size: 14.5, color: HD.ink),
                          ),
                        ),
                        const SizedBox(width: 6),
                        NhanSale.tong(chu, tong),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      giaSale(b.gia, b.donVi),
                      style: HD.bodyBold(size: 15, color: HD.inkSoft),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (b.dienTich != null)
                          _ThongSo(Icons.square_foot_rounded, dienTichSale(b.dienTich)),
                        if (b.loai.isNotEmpty)
                          _ThongSo(Icons.meeting_room_outlined, b.loai),
                        if (b.khuVuc.isNotEmpty)
                          _ThongSo(Icons.location_city_outlined, b.khuVuc),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _HieuQua(Icons.person_outline_rounded, '${b.soKhach} khách')),
              Expanded(
                child: _HieuQua(
                  Icons.event_available_outlined,
                  '${b.soLichXem} ${ngan ? 'đơn đặt' : 'lịch xem'}',
                ),
              ),
              Expanded(
                child: _HieuQua(
                  Icons.handshake_outlined,
                  '${b.soChoChot} ${ngan ? 'chờ xác nhận' : 'chờ chốt'}',
                  noiBat: b.soChoChot > 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThongSo extends StatelessWidget {
  const _ThongSo(this.icon, this.chu);

  final IconData icon;
  final String chu;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: HD.inkMuted),
      const SizedBox(width: 3),
      Text(chu, style: HD.body(size: 12.5, color: HD.inkMuted)),
    ],
  );
}

class _HieuQua extends StatelessWidget {
  const _HieuQua(this.icon, this.chu, {this.noiBat = false});

  final IconData icon;
  final String chu;
  final bool noiBat;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 15, color: noiBat ? HD.accent : HD.inkMuted),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          chu,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HD.body(size: 12.5, color: noiBat ? HD.accent : HD.inkSoft),
        ),
      ),
    ],
  );
}
