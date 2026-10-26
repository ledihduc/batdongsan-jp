import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/rental_journey_api.dart';
import 'package:house_booking/data/services/sale_yeu_cau_api.dart';
import 'package:house_booking/features/sale/khach_hang_sale_screen.dart';
import 'package:house_booking/features/sale/toa_doanh_thu_sale_screen.dart';
import 'package:house_booking/features/sale/widgets/sale_chung.dart';
import 'package:house_booking/features/sale/yeu_cau_list_screen.dart';

/// MÀN 1 — "Quản lý · Sale" (mockup VuaNhà 23/09/2026).
///
/// Công việc hôm nay của sale trong một màn: bốn con số của phễu yêu cầu,
/// tiền tháng này, rồi lối vào từng cụm.
///
/// Cố ý KHÔNG tự cuộn: khối này nằm trong màn "Quản lý theo vai trò" (tab
/// Sale) vốn đã là một CustomScrollView — lồng hai vùng cuộn là kiểu màn mà
/// ngón tay không biết mình đang kéo cái nào.
///
/// API: GET /api/sale/tong-quan
class BangDieuHanhSale extends StatefulWidget {
  const BangDieuHanhSale({
    super.key,
    this.api = const SaleYeuCauApi(),
    this.lichApi = const RentalJourneyApi(),
    this.hienHero = true,
  });

  final SaleYeuCauApi api;

  /// Hàng lịch xem của sale (xác nhận HỘ chủ nhà). Khách đặt lịch là việc đầu
  /// tiên sale phải thấy — bảng chỉ đếm yêu cầu thì lịch mới bị chìm.
  final RentalJourneyApi lichApi;

  /// Tắt khi nhúng dưới banner của tab Quản lý — banner đã nói đúng câu này.
  final bool hienHero;

  @override
  State<BangDieuHanhSale> createState() => _BangDieuHanhSaleState();
}

class _BangDieuHanhSaleState extends State<BangDieuHanhSale> {
  TongQuanSale? _tq;
  int _lichCho = 0;
  bool _dangTai = true;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    setState(() {
      _dangTai = _tq == null;
      _loi = null;
    });
    try {
      final tq = await widget.api.tongQuan();
      if (!mounted) return;
      setState(() {
        _tq = tq;
        _dangTai = false;
      });
      _napLich();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = e is ApiException ? e.message : 'Chưa tải được số liệu';
      });
    }
  }

  Future<void> _napLich() async {
    try {
      final hang = await widget.lichApi.workQueue(
        view: 'sale',
        status: 'pending',
      );
      if (mounted) setState(() => _lichCho = hang.length);
    } catch (_) {
      // Chỉ là thẻ nhắc — lỗi thì ẩn thẻ, không chặn bảng điều hành.
    }
  }

  // Lịch xem cũng là một nhóm trong danh sách yêu cầu. Đi thẳng vào đúng
  // bộ lọc để Sale không phải qua thêm màn tổng quan cũ rồi mới tìm khách.
  void _moLich() =>
      _mo(YeuCauListScreen(api: widget.api, nhomBanDau: 'lich_xem'));

  Future<void> _mo(Widget man) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => man));
    if (mounted) _nap();
  }

  @override
  Widget build(BuildContext context) {
    final tq = _tq;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.hienHero) _hero(),
        if (_loi != null) SaleBaoLoi(loi: _loi!, onThuLai: _nap),
        if (_dangTai && tq == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(color: HD.accent)),
          ),
        if (tq != null) ...[
          if (_lichCho > 0) ...[_nhacLich(), const SizedBox(height: 14)],
          const SizedBox(height: 4),
          _TieuDe(
            'Tổng quan yêu cầu',
            onXem: () => _mo(const YeuCauListScreen()),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TheSo(
                  key: const Key('sale-o-yeu-cau-moi'),
                  icon: Icons.assignment_outlined,
                  so: '${tq.yeuCauMoi}',
                  nhan: 'Yêu cầu mới',
                  mau: HD.accent,
                  onTap: () => _mo(const YeuCauListScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TheSo(
                  key: const Key('sale-o-dang-xu-ly'),
                  icon: Icons.people_alt_outlined,
                  so: '${tq.dangXuLy}',
                  nhan: 'Đang xử lý',
                  mau: HD.svcOrange,
                  onTap: () => _mo(const YeuCauListScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TheSo(
                  key: const Key('sale-o-cho-xem'),
                  icon: Icons.event_available_outlined,
                  so: '${tq.choXemNha}',
                  nhan: 'Chờ xem nhà',
                  mau: HD.svcBlue,
                  onTap: () =>
                      _mo(const YeuCauListScreen(nhomBanDau: 'lich_xem')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TheSo(
                  key: const Key('sale-o-da-chot'),
                  icon: Icons.check_circle_outline,
                  so: '${tq.daChot}',
                  nhan: 'Đã chốt tháng này',
                  mau: HD.positive,
                  onTap: () =>
                      _mo(const YeuCauListScreen(nhomBanDau: 'da_chot')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _TieuDe(
            'Doanh thu & hoa hồng tháng này',
            onXem: () => _mo(const ToaDoanhThuSaleScreen(moTaiDoanhThu: true)),
          ),
          const SizedBox(height: 10),
          _tien(tq),
          const SizedBox(height: 18),
          Text('Chức năng quản lý', style: HD.bodyBold(size: 18)),
          const SizedBox(height: 10),
          _luoi(),
        ],
      ],
    );
  }

  Widget _nhacLich() => Material(
    color: HD.accent,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      key: const Key('sale-lich-cho-xac-nhan'),
      onTap: _moLich,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            const Icon(Icons.event_available_outlined, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_lichCho lịch xem chờ bạn xác nhận',
                    style: HD.bodyBold(size: 14.5, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Khách vừa đặt — xác nhận hộ chủ nhà hoặc đề xuất giờ khác',
                    style: HD.body(
                      size: 12,
                      color: Colors.white.withValues(alpha: .9),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    ),
  );

  Widget _hero() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFE9EA), Color(0xFFFFF5F5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(HD.r12),
      border: Border.all(color: HD.accent.withValues(alpha: .18)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Công việc Sale hôm nay',
                style: HD.bodyBold(size: 16, color: HD.accent),
              ),
              const SizedBox(height: 4),
              Text(
                'Kết nối đúng người · Chốt thuê thành công',
                style: HD.body(size: 12.5, color: HD.inkSoft),
              ),
            ],
          ),
        ),
        const Icon(Icons.badge_outlined, size: 40, color: HD.accent),
      ],
    ),
  );

  Widget _tien(TongQuanSale tq) => Row(
    children: [
      Expanded(
        child: _TheSo(
          icon: Icons.bar_chart_rounded,
          so: saleTien(tq.doanhThuThang),
          nhan: 'Doanh thu (giá trị hợp đồng)',
          mau: HD.svcViolet,
          coSoNho: true,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _TheSo(
          icon: Icons.percent_rounded,
          so: saleTien(tq.hoaHongDuKien),
          nhan: 'Hoa hồng dự kiến (${tq.phanTramHoaHong}%)',
          mau: HD.svcOrange,
          coSoNho: true,
        ),
      ),
    ],
  );

  Widget _luoi() {
    final muc = <(IconData, String, Color, VoidCallback)>[
      (
        Icons.assignment_outlined,
        'Yêu cầu',
        HD.accent,
        () => _mo(const YeuCauListScreen()),
      ),
      (
        Icons.people_alt_outlined,
        'Khách hàng',
        HD.svcBlue,
        () => _mo(const KhachHangSaleScreen()),
      ),
      (
        Icons.apartment_outlined,
        'Toà liên kết',
        HD.svcViolet,
        () => _mo(const ToaDoanhThuSaleScreen()),
      ),
      (
        Icons.bar_chart_rounded,
        'Doanh thu',
        HD.positive,
        () => _mo(const ToaDoanhThuSaleScreen(moTaiDoanhThu: true)),
      ),
      (Icons.event_note_outlined, 'Lịch xem', HD.svcOrange, _moLich),
    ];
    return Row(
      children: [
        for (var i = 0; i < muc.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _OChucNang(
              key: Key(
                'sale-chuc-nang-'
                '${muc[i].$2.toLowerCase().replaceAll(' ', '-')}',
              ),
              icon: muc[i].$1,
              ten: muc[i].$2,
              mau: muc[i].$3,
              onTap: muc[i].$4,
            ),
          ),
        ],
      ],
    );
  }
}

/// Nền thẻ trắng không viền, bóng rất nhẹ — theo mockup: nổi trên nền xám
/// của màn chứ không kẻ khung.
BoxDecoration _nenThe() => BoxDecoration(
  color: HD.paperRaised,
  borderRadius: BorderRadius.circular(14),
  boxShadow: const [
    BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 3)),
  ],
);

class _TieuDe extends StatelessWidget {
  const _TieuDe(this.ten, {required this.onXem});

  final String ten;
  final VoidCallback onXem;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(ten, style: HD.bodyBold(size: 18))),
      InkWell(
        onTap: onXem,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Xem chi tiết',
                style: HD.body(size: 12.5, color: HD.accent),
              ),
              const Icon(Icons.chevron_right, size: 18, color: HD.accent),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Ô số nằm ngang: ô icon màu nhạt · số to + nhãn · mũi tên (nếu bấm được).
class _TheSo extends StatelessWidget {
  const _TheSo({
    super.key,
    required this.icon,
    required this.so,
    required this.nhan,
    required this.mau,
    this.onTap,
    this.coSoNho = false,
  });

  final IconData icon;
  final String so;
  final String nhan;
  final Color mau;
  final VoidCallback? onTap;

  /// Số tiền dài ("152,4 triệu") dùng cỡ nhỏ hơn số đếm.
  final bool coSoNho;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: _nenThe(),
        padding: const EdgeInsets.fromLTRB(12, 13, 8, 13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: mau.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: mau),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      so,
                      maxLines: 1,
                      style: HD.bodyBold(size: coSoNho ? 18 : 22),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Một dòng, co chữ khi hẹp: nhãn xuống dòng làm hai thẻ
                  // cùng hàng cao thấp lệch nhau.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      nhan,
                      maxLines: 1,
                      style: HD.body(size: 12.5, color: HD.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, size: 20, color: HD.inkMuted),
          ],
        ),
      ),
    ),
  );
}

class _OChucNang extends StatelessWidget {
  const _OChucNang({
    super.key,
    required this.icon,
    required this.ten,
    required this.mau,
    required this.onTap,
  });

  final IconData icon;
  final String ten;
  final Color mau;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: _nenThe(),
        padding: const EdgeInsets.fromLTRB(3, 12, 3, 11),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: mau.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 21, color: mau),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                ten,
                maxLines: 1,
                style: HD.body(size: 12.5, color: HD.ink),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
