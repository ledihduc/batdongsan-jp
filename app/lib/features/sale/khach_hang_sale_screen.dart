import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/sale_yeu_cau_api.dart';
import 'package:house_booking/features/sale/widgets/sale_chung.dart';

/// MÀN 4 — "Khách hàng" của sale (mockup VuaNhà 23/09/2026).
///
/// Sổ khách gồm CẢ người chưa có tài khoản: sale gặp khách qua Zalo/điện
/// thoại trước khi họ cài app, bắt phải có tài khoản mới ghi được thì dữ liệu
/// đó vĩnh viễn nằm trong sổ tay riêng.
///
/// API: GET /api/sale/khach?tab=&q= · POST /api/sale/khach
class KhachHangSaleScreen extends StatefulWidget {
  const KhachHangSaleScreen({super.key, this.api = const SaleYeuCauApi()});

  final SaleYeuCauApi api;

  @override
  State<KhachHangSaleScreen> createState() => _KhachHangSaleScreenState();
}

class _KhachHangSaleScreenState extends State<KhachHangSaleScreen> {
  final _tim = TextEditingController();
  String _tab = 'dang_theo';
  SoKhachSale? _so;
  bool _dangTai = true;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  @override
  void dispose() {
    _tim.dispose();
    super.dispose();
  }

  Future<void> _nap() async {
    try {
      final s = await widget.api.khach(tab: _tab, q: _tim.text.trim());
      if (!mounted) return;
      setState(() {
        _so = s;
        _dangTai = false;
        _loi = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = e is ApiException ? e.message : 'Chưa tải được sổ khách';
      });
    }
  }

  Future<void> _them() async {
    final xong = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetThemKhach(api: widget.api),
    );
    if (xong == true && mounted) _nap();
  }

  @override
  Widget build(BuildContext context) {
    final so = _so;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: HD.paperRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: HD.ink),
        title: Text('Khách hàng', style: HD.bodyBold(size: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              key: const Key('sale-them-khach'),
              onPressed: _them,
              style: FilledButton.styleFrom(
                backgroundColor: HD.accent,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: const Icon(
                Icons.person_add_alt,
                size: 16,
                color: Colors.white,
              ),
              label: Text(
                'Thêm KH',
                style: HD.bodyBold(size: 12.5, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : RefreshIndicator(
              color: HD.accent,
              onRefresh: _nap,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                children: [
                  TextField(
                    key: const Key('sale-tim-khach'),
                    controller: _tim,
                    onSubmitted: (_) => _nap(),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên, SĐT, khu vực…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: HD.paperRaised,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(HD.rPill),
                        borderSide: const BorderSide(color: HD.hairline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(HD.rPill),
                        borderSide: const BorderSide(color: HD.hairline),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (so != null) _ba(so),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _chip('dang_theo', 'Đang theo', so?.dangTuVan ?? 0),
                      _chip('da_thue', 'Đã thuê', so?.daThue ?? 0),
                      _chip('tat_ca', 'Tất cả', so?.tongKhach ?? 0),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loi != null) SaleBaoLoi(loi: _loi!, onThuLai: _nap),
                  if (so != null && so.danhSach.isEmpty)
                    SaleRong(
                      icon: Icons.people_alt_outlined,
                      tieuDe: 'Chưa có khách nào ở mục này',
                      mo:
                          'Thêm khách để lưu đầu mối — kể cả khách cũ đã thuê '
                          'xong, để lần sau còn gọi lại.',
                      nut: FilledButton(
                        onPressed: _them,
                        style: FilledButton.styleFrom(
                          backgroundColor: HD.accent,
                        ),
                        child: const Text('Thêm khách'),
                      ),
                    ),
                  for (final k in so?.danhSach ?? const <KhachSale>[]) _the(k),
                ],
              ),
            ),
    );
  }

  Widget _ba(SoKhachSale so) => Row(
    children: [
      Expanded(
        child: SaleOSo(
          icon: Icons.groups_outlined,
          so: '${so.tongKhach}',
          nhan: 'Tổng khách',
          mau: HD.accent,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: SaleOSo(
          icon: Icons.support_agent,
          so: '${so.dangTuVan}',
          nhan: 'Đang tư vấn',
          mau: HD.svcOrange,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: SaleOSo(
          icon: Icons.verified_outlined,
          so: '${so.daThue}',
          nhan: 'Đã thuê',
          mau: HD.positive,
        ),
      ),
    ],
  );

  Widget _chip(String ma, String nhan, int so) => SaleChipLoc(
    nhan: nhan,
    so: so,
    chon: _tab == ma,
    onTap: () {
      setState(() => _tab = ma);
      _nap();
    },
  );

  Widget _the(KhachSale k) {
    final mau = switch (k.trangThai) {
      'da_thue' => HD.positive,
      'muon_thue' => HD.accent,
      'ngung' => HD.inkMuted,
      _ => HD.svcOrange,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        key: Key('sale-khach-${k.id}'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HD.paperRaised,
          borderRadius: BorderRadius.circular(HD.r12),
          border: Border.all(color: HD.hairline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SaleAnhKhach(ten: k.hoTen),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          k.hoTen,
                          overflow: TextOverflow.ellipsis,
                          style: HD.bodyBold(size: 14),
                        ),
                      ),
                      SaleNhan(chu: k.nhan, mau: mau),
                    ],
                  ),
                  if (k.sdt.isNotEmpty)
                    Text(k.sdt, style: HD.body(size: 12.5, color: HD.accent)),
                  if (k.khuVuc.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 13,
                          color: HD.inkMuted,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            k.khuVuc,
                            overflow: TextOverflow.ellipsis,
                            style: HD.body(size: 12, color: HD.inkMuted),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      '${k.soYeuCau} yêu cầu',
                      if (k.ganNhat.isNotEmpty) 'Gần nhất: ${k.ganNhat}',
                      if (!k.coTaiKhoan) 'Chưa có tài khoản',
                    ].join(' · '),
                    style: HD.body(size: 11.5, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetThemKhach extends StatefulWidget {
  const _SheetThemKhach({required this.api});

  final SaleYeuCauApi api;

  @override
  State<_SheetThemKhach> createState() => _SheetThemKhachState();
}

class _SheetThemKhachState extends State<_SheetThemKhach> {
  final _ten = TextEditingController();
  final _sdt = TextEditingController();
  final _khu = TextEditingController();
  bool _dangGui = false;
  String? _loi;

  @override
  void dispose() {
    _ten.dispose();
    _sdt.dispose();
    _khu.dispose();
    super.dispose();
  }

  Future<void> _gui() async {
    if (_ten.text.trim().isEmpty) {
      setState(() => _loi = 'Nhập tên khách');
      return;
    }
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      await widget.api.themKhach(
        hoTen: _ten.text.trim(),
        sdt: _sdt.text.trim(),
        khuVuc: _khu.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangGui = false;
        _loi = e is ApiException ? e.message : 'Chưa thêm được khách';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Container(
      decoration: const BoxDecoration(
        color: HD.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Thêm khách', style: HD.bodyBold(size: 16)),
          const SizedBox(height: 4),
          Text(
            'Trùng số điện thoại thì gộp vào khách cũ, không tạo bản ghi thứ hai.',
            style: HD.body(size: 12, color: HD.inkMuted),
          ),
          const SizedBox(height: 14),
          _o(_ten, 'Tên khách', khoa: 'sale-kh-ten'),
          const SizedBox(height: 10),
          _o(
            _sdt,
            'Số điện thoại',
            khoa: 'sale-kh-sdt',
            kieu: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          _o(_khu, 'Khu vực quan tâm'),
          if (_loi != null) ...[
            const SizedBox(height: 10),
            Text(_loi!, style: HD.body(size: 12.5, color: HD.negative)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              key: const Key('sale-kh-luu'),
              onPressed: _dangGui ? null : _gui,
              style: FilledButton.styleFrom(backgroundColor: HD.accent),
              child: Text(
                'Lưu khách',
                style: HD.bodyBold(size: 15, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _o(
    TextEditingController c,
    String nhan, {
    String? khoa,
    TextInputType? kieu,
  }) => TextField(
    key: khoa == null ? null : Key(khoa),
    controller: c,
    keyboardType: kieu,
    decoration: InputDecoration(
      labelText: nhan,
      isDense: true,
      filled: true,
      fillColor: HD.paperRaised,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HD.r12),
        borderSide: const BorderSide(color: HD.hairline),
      ),
    ),
  );
}
