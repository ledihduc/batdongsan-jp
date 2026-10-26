import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/don_thue_khach_api.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/data/services/sale_yeu_cau_api.dart';
import 'package:house_booking/features/guest/booking/coc_xac_nhan_thue_screen.dart';
import 'package:house_booking/features/guest/booking/doi_gio_sheet.dart';
import 'package:house_booking/features/guest/quan_ly/phong_dang_thue_screen.dart';
import 'package:house_booking/features/sale/widgets/sale_chung.dart';

/// Chi tiết một đơn thuê dài hạn của khách.
///
/// Đây là màn xử lý trực tiếp: chỉ giữ căn/phòng, trạng thái, lịch hiện tại và
/// hành động cần thiết. Khách không phải mở thêm "phiếu hẹn" hoặc đọc pipeline
/// nội bộ bảy bước.
class DonThueChiTietScreen extends StatefulWidget {
  const DonThueChiTietScreen({
    super.key,
    required this.nguon,
    required this.id,
    this.api = const DonThueKhachApi(),
    this.lichXemApi = const LichXemApi(),
  });

  final String nguon;
  final int id;
  final DonThueKhachApi api;
  final LichXemApi lichXemApi;

  @override
  State<DonThueChiTietScreen> createState() => _DonThueChiTietScreenState();
}

class _DonThueChiTietScreenState extends State<DonThueChiTietScreen> {
  DonThueChiTiet? _d;
  PhieuHen? _phieu;
  String? _loi;
  bool _dangXuLy = false;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    try {
      final d = await widget.api.chiTiet(widget.nguon, widget.id);
      PhieuHen? phieu;
      if (_laLichDangXuLy(d) && d.appointmentId != null) {
        try {
          phieu = await widget.lichXemApi.phieu(d.appointmentId!);
        } catch (_) {
          // Đơn vẫn dùng được khi API phiếu hẹn tạm chậm. Các thao tác bên
          // dưới dùng appointmentId và ngày/giờ đã có trong đơn.
        }
      }
      if (!mounted) return;
      setState(() {
        _d = d;
        _phieu = phieu;
        _loi = null;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _loi = e is ApiException ? e.message : 'Chưa tải được đơn',
        );
      }
    }
  }

  Future<void> _mo(Widget man) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => man));
    if (mounted) await _nap();
  }

  bool _laLichDangXuLy(DonThueChiTiet d) =>
      const {'lead_moi', 'da_lien_he', 'da_xac_nhan_lich'}.contains(d.muc.buoc);

  Future<void> _doiLich(DonThueChiTiet d) async {
    if (_dangXuLy || d.appointmentId == null) return;
    final p = _phieu;
    final moi = await moChonGioKhac(
      context,
      appointmentId: d.appointmentId!,
      api: widget.lichXemApi,
      khachTuDoi: !(p?.choKhachChonGio ?? false),
      ngayHienTai: p?.ngay ?? d.lichNgay ?? '',
      gioHienTai: p?.gio ?? d.lichGio ?? '',
    );
    if (moi == null || !mounted) return;
    setState(() => _phieu = moi);
    await _nap();
  }

  Future<void> _huyLich(DonThueChiTiet d) async {
    if (_dangXuLy || d.appointmentId == null) return;
    final dongY = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Huỷ lịch xem nhà?'),
        content: const Text(
          'Lịch hẹn sẽ được huỷ và bên phụ trách sẽ nhận thông báo ngay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ lịch'),
          ),
          FilledButton(
            key: const Key('don-thue-xac-nhan-huy-lich'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Huỷ lịch'),
          ),
        ],
      ),
    );
    if (dongY != true || !mounted) return;

    setState(() => _dangXuLy = true);
    try {
      final p = await widget.lichXemApi.huy(
        d.appointmentId!,
        lyDo: 'Khách huỷ từ chi tiết đơn thuê',
      );
      if (!mounted) return;
      setState(() => _phieu = p);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã huỷ lịch xem nhà')));
      await _nap();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Chưa huỷ được lịch, thử lại nhé',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),
      appBar: AppBar(title: const Text('Chi tiết đơn thuê')),
      body: d == null
          ? Center(
              child: _loi == null
                  ? const CircularProgressIndicator(color: HD.accent)
                  : SaleBaoLoi(loi: _loi!, onThuLai: _nap),
            )
          : RefreshIndicator(
              color: HD.accent,
              onRefresh: _nap,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _trangThai(d),
                  if (d.can.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _can(d),
                  ],
                  if (d.lichNgay != null && d.lichNgay!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _lich(d),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: d == null ? null : _thanhDuoi(d),
    );
  }

  Widget _trangThai(DonThueChiTiet d) {
    final m = d.muc;
    final mau = m.dong ? HD.inkMuted : saleMauBuoc(m.buoc);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                m.dong ? Icons.cancel_outlined : Icons.check_circle_outline,
                size: 20,
                color: mau,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  m.dong ? 'Đơn đã đóng' : m.nhan,
                  style: HD.bodyBold(size: 16, color: mau),
                ),
              ),
              Text(m.ma, style: HD.body(size: 12, color: HD.inkMuted)),
            ],
          ),
          if (!m.dong && m.viecTiep.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(m.viecTiep, style: HD.body(size: 13.5, color: HD.inkSoft)),
          ],
        ],
      ),
    );
  }

  Widget _lich(DonThueChiTiet d) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: HD.paperRaised,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: HD.hairline),
    ),
    child: Row(
      children: [
        const Icon(Icons.event_outlined, color: HD.svcBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Lịch xem nhà',
            style: HD.body(size: 13, color: HD.inkSoft),
          ),
        ),
        Text(
          '${_ngay(d.lichNgay!)}'
          '${(d.lichGio ?? '').isEmpty ? '' : ' · ${d.lichGio}'}',
          style: HD.bodyBold(size: 13.5),
        ),
      ],
    ),
  );

  String _ngay(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return iso;
    return '${t.day.toString().padLeft(2, '0')}/'
        '${t.month.toString().padLeft(2, '0')}/${t.year}';
  }

  Widget _can(DonThueChiTiet d) {
    final c = d.can.firstWhere((x) => x.khachThich, orElse: () => d.can.first);
    return _TheCan(c: c);
  }

  Widget? _thanhDuoi(DonThueChiTiet d) {
    final m = d.muc;
    if (m.dong) return null;

    if (_laLichDangXuLy(d) && d.appointmentId != null) {
      final coTheSua = _phieu?.huyDuoc ?? true;
      if (!coTheSua) return null;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('don-thue-huy-lich'),
                  onPressed: _dangXuLy ? null : () => _huyLich(d),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HD.accent,
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: HD.accent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Huỷ lịch'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  key: const Key('don-thue-doi-lich'),
                  onPressed: _dangXuLy ? null : () => _doiLich(d),
                  style: FilledButton.styleFrom(
                    backgroundColor: HD.accent,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  icon: const Icon(Icons.edit_calendar_outlined, size: 20),
                  label: Text(
                    _phieu?.choKhachChonGio == true
                        ? 'Chọn giờ khác'
                        : 'Đổi lịch',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final (String, Widget)? nut = switch (m.buoc) {
      'da_chot' when d.contractId != null => (
        'Xem phòng đang thuê',
        PhongDangThueScreen(contractId: d.contractId!),
      ),
      'muon_thue' when d.journeyId != null => (
        'Xem hồ sơ thuê',
        CocXacNhanThueScreen(journeyId: d.journeyId!),
      ),
      'cho_coc' when d.journeyId != null => (
        'Đặt cọc & xác nhận thuê',
        CocXacNhanThueScreen(journeyId: d.journeyId!),
      ),
      _ => null,
    };
    if (nut == null) return null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          key: const Key('don-thue-viec-tiep'),
          style: FilledButton.styleFrom(
            backgroundColor: HD.accent,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onPressed: () => _mo(nut.$2),
          child: Text(
            nut.$1,
            style: HD.bodyBold(size: 15, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _TheCan extends StatelessWidget {
  const _TheCan({required this.c});

  final CanLienQuan c;

  @override
  Widget build(BuildContext context) {
    final anh = c.anh;
    return Container(
      height: 104,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HD.hairline),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 104,
            width: 112,
            child: anh == null || anh.isEmpty
                ? const ColoredBox(
                    color: HD.accentTint,
                    child: Icon(Icons.apartment_rounded, color: HD.accent),
                  )
                : CachedNetworkImage(
                    imageUrl: anh.startsWith('http')
                        ? anh
                        : '${ApiConfig.baseUrl}$anh',
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) =>
                        const ColoredBox(color: HD.accentTint),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    c.ten,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HD.bodyBold(size: 14),
                  ),
                  if (c.diaChi.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      c.diaChi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.body(size: 12, color: HD.inkSoft),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${saleTien(c.gia)}/tháng',
                    style: HD.bodyBold(size: 13.5, color: HD.accent),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
