import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';
import 'package:house_booking/features/guest/booking/lich_xem_da_xac_nhan_screen.dart';
import 'package:house_booking/features/shared/viewing_detail_widgets.dart';

/// MÀN 3 — "Sale đề xuất lịch khác" (mockup quy trình KHÁCH THUÊ, 20/09/2026).
///
/// Bên bán báo bận (`status='doi_gio'`) và gửi kèm vài khung giờ. Khách chọn
/// một khung → `/chon-gio` → lịch chuyển `approved` → [LichXemDaXacNhanScreen].
/// Không hợp khung nào thì tự chọn giờ khác từ danh sách còn trống thật
/// (`/gio-trong`), sale làm việc lại với chủ nhà.
///
/// Khung đề xuất có thể bị người khác đặt mất trong lúc khách chưa chọn — server
/// đánh dấu `con_trong=false`, ở đây hiện mờ và không bấm được.
class SaleDeXuatLichScreen extends StatefulWidget {
  const SaleDeXuatLichScreen({
    super.key,
    required this.appointmentId,
    this.api = const LichXemApi(),
    this.moLink,
  });

  final int appointmentId;
  final LichXemApi api;

  /// Chỉ để test bắt link sẽ mở (tel, zalo).
  final Future<void> Function(Uri)? moLink;

  @override
  State<SaleDeXuatLichScreen> createState() => _SaleDeXuatLichScreenState();
}

class _SaleDeXuatLichScreenState extends State<SaleDeXuatLichScreen> {
  PhieuHen? _phieu;
  GioDeXuat? _chon;
  bool _dangTai = true;
  bool _dangGui = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    try {
      final p = await widget.api.phieu(widget.appointmentId);
      if (!mounted) return;
      final ds = p.doiGio?.deXuat ?? const <GioDeXuat>[];
      setState(() {
        _phieu = p;
        _dangTai = false;
        _chon = ds.where((g) => g.conTrong).isEmpty
            ? null
            : ds.firstWhere((g) => g.conTrong);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = 'Chưa tải được lịch đề xuất. Kéo xuống để thử lại.';
      });
    }
  }

  Future<void> _mo(Uri uri) async {
    if (widget.moLink != null) return widget.moLink!(uri);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _dongY() async {
    final g = _chon;
    if (g == null || _dangGui) return;
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      await widget.api.chonGio(widget.appointmentId, g);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LichXemDaXacNhanScreen(
            appointmentId: widget.appointmentId,
            api: widget.api,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangGui = false;
        _loi = 'Khung giờ này vừa có người đặt. Chọn khung khác giúp em.';
      });
    }
  }

  Future<void> _chonGioKhac() async {
    final ngay = await showModalBottomSheet<List<NgayTrong>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SheetGioKhac(id: widget.appointmentId, api: widget.api),
    );
    if (ngay != null && mounted) await _nap();
  }

  @override
  Widget build(BuildContext context) {
    final p = _phieu;
    final ds = p?.doiGio?.deXuat ?? const <GioDeXuat>[];
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: HD.accent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
        title: Text(
          'Chi tiết xếp lịch',
          style: HD.bodyBold(size: 17, color: Colors.white),
        ),
      ),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : RefreshIndicator(
              color: HD.accent,
              onRefresh: _nap,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(HD.s16, 0, HD.s16, HD.s24),
                children: [
                  const ViewingJourneyProgress(
                    labels: ['Gửi yêu cầu', 'Xếp lịch', 'Đi xem', 'Chốt thuê'],
                    icons: [
                      Icons.check,
                      Icons.event_available,
                      Icons.directions_walk,
                      Icons.handshake,
                    ],
                    current: 1,
                  ),
                  const SizedBox(height: HD.s16),
                  _dongSale(p),
                  const SizedBox(height: HD.s16),
                  _loiNhan(p),
                  const SizedBox(height: HD.s16),
                  Text('Lịch xem được đề xuất', style: HD.bodyBold(size: 15)),
                  const SizedBox(height: HD.s8),
                  if (ds.isEmpty)
                    Text(
                      'Bên bán chưa gửi khung giờ nào. Bạn có thể tự chọn giờ khác.',
                      style: HD.body(size: 12.5, color: HD.inkMuted),
                    ),
                  for (var i = 0; i < ds.length; i++) ...[
                    _oDeXuat(ds[i], goiY: i == 0),
                    const SizedBox(height: HD.s8),
                  ],
                  const SizedBox(height: HD.s4),
                  _hopGoiY(),
                  if (_loi != null) ...[
                    const SizedBox(height: HD.s12),
                    Text(_loi!, style: HD.body(size: 12.5, color: HD.negative)),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: _dangTai ? null : _nut(),
    );
  }

  Widget _dongSale(PhieuHen? p) {
    final s = p?.sale;
    final so = (s?.sdt ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final goiDuoc = s != null && !s.sdtDaChe && so.isNotEmpty;
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: HD.paperSunken,
          backgroundImage: (s?.anh != null && s!.anh!.isNotEmpty)
              ? CachedNetworkImageProvider(
                  s.anh!.startsWith('http')
                      ? s.anh!
                      : '${ApiConfig.baseUrl}${s.anh}',
                )
              : null,
          child: (s?.anh == null || s!.anh!.isEmpty)
              ? const Icon(Icons.person, color: HD.inkMuted)
              : null,
        ),
        const SizedBox(width: HD.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s?.ten ?? 'Sale phụ trách', style: HD.bodyBold(size: 15)),
              Text(
                'Chuyên viên tư vấn Vua Nhà',
                style: HD.body(size: 12, color: HD.inkMuted),
              ),
            ],
          ),
        ),
        _nutTron(
          key: const Key('de-xuat-goi'),
          icon: Icons.call,
          bat: goiDuoc,
          onTap: () => _mo(Uri(scheme: 'tel', path: so)),
        ),
        const SizedBox(width: HD.s8),
        _nutTron(
          key: const Key('de-xuat-zalo'),
          icon: Icons.chat_bubble,
          bat: goiDuoc,
          onTap: () => _mo(Uri.https('zalo.me', '/$so')),
        ),
      ],
    );
  }

  Widget _nutTron({
    required Key key,
    required IconData icon,
    required bool bat,
    required VoidCallback onTap,
  }) => InkWell(
    key: key,
    onTap: bat ? onTap : null,
    borderRadius: BorderRadius.circular(HD.rPill),
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: HD.accentTint, shape: BoxShape.circle),
      child: Icon(icon, size: 17, color: bat ? HD.accent : HD.inkMuted),
    ),
  );

  Widget _loiNhan(PhieuHen? p) {
    final ly = (p?.doiGio?.lyDo ?? '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(HD.s12),
      decoration: BoxDecoration(
        color: HD.paperSunken,
        borderRadius: BorderRadius.circular(HD.r12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ly.isEmpty
                ? 'Chủ nhà bận vào khung giờ bạn chọn. Em xin đề xuất một số '
                      'lịch khác phù hợp nhé!'
                : ly,
            style: HD.body(size: 13, color: HD.ink),
          ),
        ],
      ),
    );
  }

  Widget _oDeXuat(GioDeXuat g, {required bool goiY}) {
    final chon = _chon == g;
    final dung = g.conTrong;
    return InkWell(
      key: Key('de-xuat-${g.ngay}-${g.gio}'),
      onTap: dung ? () => setState(() => _chon = g) : null,
      borderRadius: BorderRadius.circular(HD.r12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HD.s12,
          vertical: HD.s12,
        ),
        decoration: BoxDecoration(
          color: HD.paperRaised,
          borderRadius: BorderRadius.circular(HD.r12),
          border: Border.all(
            color: chon ? HD.accent : HD.hairline,
            width: chon ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              chon ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20,
              color: chon ? HD.accent : (dung ? HD.inkMuted : HD.hairline),
            ),
            const SizedBox(width: HD.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _ngayDep(g.ngay),
                    style: HD.bodyBold(
                      size: 14,
                      color: dung ? HD.ink : HD.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    g.gio.replaceAll('-', ' - '),
                    style: HD.body(size: 12.5, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
            if (!dung)
              Text(
                'Đã có người đặt',
                style: HD.body(size: 11, color: HD.inkMuted),
              )
            else if (goiY)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: HD.positiveTint,
                  borderRadius: BorderRadius.circular(HD.rPill),
                ),
                child: Text(
                  'Phù hợp nhất',
                  style: HD.bodyBold(size: 11, color: HD.positive),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _hopGoiY() => Container(
    padding: const EdgeInsets.all(HD.s12),
    decoration: BoxDecoration(
      color: HD.svcBlue.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(HD.r12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 16, color: HD.svcBlue),
        const SizedBox(width: HD.s8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Không thấy thời gian phù hợp?',
                style: HD.bodyBold(size: 12.5, color: HD.ink),
              ),
              const SizedBox(height: 2),
              Text(
                'Bạn có thể chọn giờ khác, sale sẽ tiếp tục làm việc với chủ '
                'nhà để sắp xếp.',
                style: HD.body(size: 12.5, color: HD.inkSoft),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _nut() => SafeArea(
    minimum: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, HD.s12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('de-xuat-nhan-sale-bottom'),
                style: viewingOutlineButton(),
                onPressed: () {
                  final s = _phieu?.sale;
                  final so = (s?.sdt ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                  if (s != null && !s.sdtDaChe && so.isNotEmpty) {
                    _mo(Uri.https('zalo.me', '/$so'));
                  }
                },
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Nhắn Sale'),
              ),
            ),
            const SizedBox(width: HD.s8),
            Expanded(
              child: FilledButton.icon(
                key: const Key('de-xuat-dong-y'),
                style: viewingPrimaryButton(),
                onPressed: _chon == null || _dangGui ? null : _dongY,
                icon: const Icon(Icons.event_available, size: 18),
                label: Text(_dangGui ? 'Đang xác nhận' : 'Xác nhận lịch'),
              ),
            ),
          ],
        ),
        const SizedBox(height: HD.s8),
        SizedBox(
          height: 40,
          width: double.infinity,
          child: TextButton(
            key: const Key('de-xuat-gio-khac'),
            onPressed: _dangGui ? null : _chonGioKhac,
            child: Text(
              'Không phù hợp? Chọn giờ khác',
              style: HD.bodyBold(size: 13, color: HD.accent),
            ),
          ),
        ),
      ],
    ),
  );

  static String _ngayDep(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final thu = d.weekday == DateTime.sunday
        ? 'Chủ nhật'
        : 'Thứ ${d.weekday + 1}';
    return '$thu, ${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}';
  }
}

/// Tự chọn giờ khác: chỉ hiện giờ server còn nhận (`/gio-trong`).
class _SheetGioKhac extends StatefulWidget {
  const _SheetGioKhac({required this.id, required this.api});

  final int id;
  final LichXemApi api;

  @override
  State<_SheetGioKhac> createState() => _SheetGioKhacState();
}

class _SheetGioKhacState extends State<_SheetGioKhac> {
  List<NgayTrong> _ngay = const [];
  bool _dangTai = true;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    try {
      final ds = await widget.api.gioTrong(widget.id);
      if (!mounted) return;
      setState(() {
        _ngay = ds;
        _dangTai = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = 'Chưa tải được giờ trống.';
      });
    }
  }

  Future<void> _chon(NgayTrong n, String gio) async {
    try {
      await widget.api.khachDoiLich(
        widget.id,
        GioDeXuat(ngay: n.ngay, gio: gio),
      );
      if (mounted) Navigator.of(context).pop(_ngay);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loi = 'Giờ này vừa có người đặt. Chọn giờ khác giúp em.');
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * 0.8,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s8, HD.s8),
          child: Row(
            children: [
              Expanded(
                child: Text('Chọn giờ khác', style: HD.bodyBold(size: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        if (_loi != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HD.s16),
            child: Text(_loi!, style: HD.body(size: 12.5, color: HD.negative)),
          ),
        Expanded(
          child: _dangTai
              ? const Center(child: CircularProgressIndicator(color: HD.accent))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(HD.s16, 0, HD.s16, HD.s16),
                  children: [
                    for (final n in _ngay) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                          top: HD.s12,
                          bottom: HD.s8,
                        ),
                        child: Text(
                          _SaleDeXuatLichScreenState._ngayDep(n.ngay),
                          style: HD.bodyBold(size: 13),
                        ),
                      ),
                      Wrap(
                        spacing: HD.s8,
                        runSpacing: HD.s8,
                        children: [
                          for (final g in n.gio)
                            OutlinedButton(
                              key: Key('gio-khac-${n.ngay}-$g'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: HD.hairline),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(HD.r8),
                                ),
                              ),
                              onPressed: () => _chon(n, g),
                              child: Text(
                                g.replaceAll('-', ' - '),
                                style: HD.body(size: 12.5, color: HD.ink),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
        ),
      ],
    ),
  );
}
