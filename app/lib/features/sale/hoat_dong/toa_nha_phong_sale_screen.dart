import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/sale_van_hanh_api.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/nhan_sale.dart';
import 'package:house_booking/features/sale/hoat_dong/widgets/sale_ui.dart';

/// Màn 8 — "Tòa nhà & phòng (chỉ xem)" (mockup 05/10/2026): toà đang chọn
/// (bấm › để đổi toà), ba tab Tổng quan · Danh sách phòng · Hình ảnh, chip
/// Tất cả / Trống / Có lịch xem, mỗi phòng: ảnh · tên · m² • loại · giá · nhãn.
/// Sale chỉ XEM — không thấy tiền hợp đồng hay tên người thuê.
/// API: `GET /api/sale/van-hanh/toa-nha` + `/toa-nha/{id}?kenh=`.
class ToaNhaPhongSaleScreen extends StatefulWidget {
  const ToaNhaPhongSaleScreen({
    super.key,
    this.kenh = kKenhDaiHan,
    this.api = const SaleVanHanhApi(),
  });

  final String kenh;
  final SaleVanHanhApi api;

  @override
  State<ToaNhaPhongSaleScreen> createState() => _ToaNhaPhongSaleScreenState();
}

class _ToaNhaPhongSaleScreenState extends State<ToaNhaPhongSaleScreen> {
  int? _toaId;
  int _tab = 1;
  String _loc = 'tat_ca';

  Future<void> _doiToa(List<ToaSale> ds) async {
    final chon = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: SaleMau.nen,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('Chọn tòa nhà', style: HD.bodyBold(size: 17, color: HD.ink)),
            const SizedBox(height: 8),
            for (final t in ds)
              ListTile(
                key: Key('chon-toa-${t.id}'),
                contentPadding: EdgeInsets.zero,
                leading: AnhSale(url: t.anh, co: 44),
                title: Text(t.ten, style: HD.bodyBold(size: 14.5, color: HD.ink)),
                subtitle: Text(
                  '${t.diaChi} · ${t.soPhong} phòng',
                  style: HD.body(size: 12.5, color: HD.inkMuted),
                ),
                trailing: t.id == _toaId
                    ? const Icon(Icons.check_rounded, color: HD.accent)
                    : null,
                onTap: () => Navigator.of(ctx).pop(t.id),
              ),
          ],
        ),
      ),
    );
    if (chon != null && chon != _toaId) {
      setState(() {
        _toaId = chon;
        _loc = 'tat_ca';
      });
    }
  }

  @override
  Widget build(BuildContext context) => TrangSale(
    tieuDe: 'Tòa nhà & phòng',
    phuDe: '(chỉ xem)',
    body: TaiSale<List<ToaSale>>(
      tai: widget.api.toaNha,
      dung: (context, ds, _) {
        if (ds.isEmpty) {
          return const RongSale(
            chu: 'Bạn chưa phụ trách tòa nhà nào. Khi chủ nhà liên kết với bạn, '
                'tòa của họ sẽ hiện ở đây.',
            icon: Icons.apartment_outlined,
          );
        }
        final toa = ds.firstWhere((t) => t.id == _toaId, orElse: () => ds.first);
        _toaId = toa.id;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dauToa(toa, ds),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: _BaTab(
                tabs: const ['Tổng quan', 'Danh sách phòng', 'Hình ảnh'],
                chon: _tab,
                onChon: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: TaiSale<ChiTietToaSale>(
                khoaTai: '${toa.id}-${widget.kenh}',
                tai: () => widget.api.chiTietToa(toa.id, widget.kenh),
                dung: (context, ct, taiLai) => switch (_tab) {
                  0 => _tongQuan(ct),
                  2 => _hinhAnh(ct),
                  _ => _danhSachPhong(ct, taiLai),
                },
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _dauToa(ToaSale t, List<ToaSale> ds) => InkWell(
    key: const Key('dau-toa'),
    onTap: ds.length > 1 ? () => _doiToa(ds) : null,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
      child: Row(
        children: [
          AnhSale(url: t.anh, co: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.ten, style: HD.bodyBold(size: 17, color: HD.ink)),
                const SizedBox(height: 4),
                DongIconSale(icon: Icons.location_on_rounded, chu: t.diaChi),
              ],
            ),
          ),
          if (ds.length > 1)
            const Icon(Icons.chevron_right_rounded, color: HD.inkMuted),
        ],
      ),
    ),
  );

  Widget _danhSachPhong(ChiTietToaSale ct, Future<void> Function() taiLai) {
    final ds = _loc == 'tat_ca'
        ? ct.phong
        : [for (final p in ct.phong) if (p.trangThai == _loc) p];
    return Column(
      children: [
        DaiChipSale(
          chip: [for (final c in ct.chip) (c.khoa, c.nhan, c.so)],
          chon: _loc,
          onChon: (k) => setState(() => _loc = k),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: RefreshIndicator(
            color: HD.accent,
            onRefresh: taiLai,
            child: ds.isEmpty
                ? ListView(
                    children: [
                      RongSale(
                        chu: ct.phong.isEmpty
                            ? 'Tòa này chưa có phòng ${nhanKenh(widget.kenh).toLowerCase()}.'
                            : 'Không có phòng nào ở mục này.',
                        icon: Icons.meeting_room_outlined,
                      ),
                    ],
                  )
                : ListView.builder(
                    key: const Key('ds-phong-sale'),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: ds.length,
                    itemBuilder: (_, i) => _DongPhong(p: ds[i]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _tongQuan(ChiTietToaSale ct) {
    int dem(String k) => ct.chip.firstWhere(
      (c) => c.khoa == k,
      orElse: () => const ChipLoc(khoa: '', nhan: ''),
    ).so;
    return ListView(
      key: const Key('tong-quan-toa'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Row(
          children: [
            _oSo('${ct.tongPhong}', 'Tổng phòng', HD.ink, SaleMau.nenXam),
            const SizedBox(width: 8),
            _oSo('${dem('trong')}', 'Trống', SaleMau.xanh, SaleMau.xanhNen),
            const SizedBox(width: 8),
            _oSo('${dem('dang_thue')}', 'Đang thuê', SaleMau.lam, SaleMau.lamNen),
            const SizedBox(width: 8),
            _oSo('${dem('co_lich_xem')}', 'Có lịch xem', HD.accent, HD.accentTint),
          ],
        ),
        const SizedBox(height: 12),
        TheSale(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dong('Địa chỉ', ct.diaChiDayDu.isEmpty ? ct.toa.diaChi : ct.diaChiDayDu),
              if (ct.giaDien != null) _dong('Giá điện', '${tienSale(ct.giaDien!)}/kWh'),
              if (ct.giaNuoc != null) _dong('Giá nước', '${tienSale(ct.giaNuoc!)}/m³'),
              if (ct.phiDichVu != null)
                _dong('Phí dịch vụ', '${tienSale(ct.phiDichVu!)}/tháng', cuoi: true),
            ],
          ),
        ),
        if (ct.chuNhaTen.isNotEmpty)
          TheSale(
            child: Row(
              children: [
                AvatarSale(ten: ct.chuNhaTen, co: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chủ nhà', style: HD.body(size: 12, color: HD.inkMuted)),
                      Text(ct.chuNhaTen, style: HD.bodyBold(size: 15, color: HD.ink)),
                    ],
                  ),
                ),
                NutTronSale(
                  icon: Icons.call_rounded,
                  tooltip: 'Gọi chủ nhà',
                  onTap: () => goiSo(context, ct.chuNhaSdt),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _oSo(String so, String nhan, Color mau, Color nen) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: nen, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(so, style: HD.bodyBold(size: 18, color: mau)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(nhan, style: HD.body(size: 11.5, color: HD.inkSoft)),
          ),
        ],
      ),
    ),
  );

  Widget _dong(String nhan, String giaTri, {bool cuoi = false}) => Padding(
    padding: EdgeInsets.only(bottom: cuoi ? 0 : 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(nhan, style: HD.body(size: 13.5, color: HD.inkMuted)),
        ),
        Expanded(child: Text(giaTri, style: HD.body(size: 13.5, color: HD.ink))),
      ],
    ),
  );

  Widget _hinhAnh(ChiTietToaSale ct) => ct.anh.isEmpty
      ? const RongSale(chu: 'Tòa này chưa có hình ảnh.', icon: Icons.photo_outlined)
      : GridView.builder(
          key: const Key('anh-toa'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: ct.anh.length,
          itemBuilder: (_, i) => LayoutBuilder(
            builder: (_, c) => AnhSale(url: ct.anh[i], co: c.maxWidth),
          ),
        );
}

/// Ba tab trên nền xám: tab chọn nền trắng, chữ đỏ, gạch chân đỏ.
class _BaTab extends StatelessWidget {
  const _BaTab({required this.tabs, required this.chon, required this.onChon});

  final List<String> tabs;
  final int chon;
  final ValueChanged<int> onChon;

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: SaleMau.nenXam,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        for (var i = 0; i < tabs.length; i++)
          Expanded(
            child: GestureDetector(
              key: Key('tab-toa-$i'),
              onTap: () => onChon(i),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == chon ? SaleMau.nen : null,
                  borderRadius: BorderRadius.circular(8),
                  border: i == chon
                      ? const Border(bottom: BorderSide(color: HD.accent, width: 2))
                      : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      tabs[i],
                      style: i == chon
                          ? HD.bodyBold(size: 14, color: HD.accent)
                          : HD.body(size: 14, color: HD.inkSoft),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _DongPhong extends StatelessWidget {
  const _DongPhong({required this.p});

  final PhongSale p;

  @override
  Widget build(BuildContext context) {
    final (chu, tong) = nhanPhong(p.trangThai);
    final thongSo = [
      if (p.dienTich != null) dienTichSale(p.dienTich),
      if (p.loai.isNotEmpty) p.loai,
    ].join(' • ');
    return Padding(
      key: Key('phong-${p.id}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnhSale(url: p.anh, co: 92, cao: 70),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(p.ten, style: HD.bodyBold(size: 15, color: HD.ink)),
                    ),
                    NhanSale.tong(chu, tong),
                  ],
                ),
                const SizedBox(height: 3),
                if (thongSo.isNotEmpty)
                  Text(thongSo, style: HD.body(size: 13, color: HD.inkMuted)),
                const SizedBox(height: 2),
                Text(
                  giaSale(p.gia, p.donVi),
                  style: HD.body(size: 13, color: HD.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
