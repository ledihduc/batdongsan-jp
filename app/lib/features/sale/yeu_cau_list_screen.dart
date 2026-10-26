import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/sale_yeu_cau_api.dart';
import 'package:house_booking/features/sale/widgets/sale_chung.dart';
import 'package:house_booking/features/sale/yeu_cau_chi_tiet_screen.dart';

/// MÀN 2 — "Danh sách yêu cầu" (mockup VuaNhà 23/09/2026).
///
/// Mỗi thẻ trả lời ba câu: khách nào, đang ở bước nào, VIỆC TIẾP THEO là gì.
/// Câu thứ ba là thứ trước đây không màn nào của sale nói được.
///
/// API: GET /api/sale/yeu-cau?nhom=&q= · POST /api/sale/yeu-cau
class YeuCauListScreen extends StatefulWidget {
  const YeuCauListScreen({
    super.key,
    this.api = const SaleYeuCauApi(),
    this.nhomBanDau = 'tat_ca',
  });

  final SaleYeuCauApi api;
  final String nhomBanDau;

  @override
  State<YeuCauListScreen> createState() => _YeuCauListScreenState();
}

const _nhomNhan = <String, String>{
  'tat_ca': 'Tất cả',
  'lead_moi': 'Lead mới',
  'lich_xem': 'Lịch xem',
  'sau_xem': 'Sau xem',
  'cho_coc': 'Chờ cọc',
  'da_chot': 'Đã chốt',
};

class _YeuCauListScreenState extends State<YeuCauListScreen> {
  final _tim = TextEditingController();
  late String _nhom = widget.nhomBanDau;
  BangYeuCau? _bang;
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
    setState(() {
      _dangTai = _bang == null;
      _loi = null;
    });
    try {
      final b = await widget.api.danhSach(nhom: _nhom, q: _tim.text.trim());
      if (!mounted) return;
      setState(() {
        _bang = b;
        _dangTai = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangTai = false;
        _loi = e is ApiException ? e.message : 'Chưa tải được danh sách';
      });
    }
  }

  Future<void> _moChiTiet(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => YeuCauChiTietScreen(yeuCauId: id)),
    );
    if (mounted) _nap();
  }

  Future<void> _taoMoi() async {
    final tao = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetTaoYeuCau(api: widget.api),
    );
    if (tao == true && mounted) _nap();
  }

  @override
  Widget build(BuildContext context) {
    final bang = _bang;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: HD.paperRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: HD.ink),
        title: Text('Yêu cầu', style: HD.bodyBold(size: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              key: const Key('sale-tao-yeu-cau'),
              onPressed: _taoMoi,
              style: FilledButton.styleFrom(
                backgroundColor: HD.accent,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: const Icon(Icons.add, size: 17, color: Colors.white),
              label: Text(
                'Tạo yêu cầu',
                style: HD.bodyBold(size: 12.5, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              key: const Key('sale-tim-yeu-cau'),
              controller: _tim,
              onSubmitted: (_) => _nap(),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên khách, SĐT, khu vực, mã…',
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
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final e in _nhomNhan.entries)
                  SaleChipLoc(
                    nhan: e.value,
                    so: bang?.soCua(e.key) ?? 0,
                    chon: _nhom == e.key,
                    onTap: () {
                      setState(() => _nhom = e.key);
                      _nap();
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: HD.accent,
              onRefresh: _nap,
              child: _dangTai && bang == null
                  ? const Center(
                      child: CircularProgressIndicator(color: HD.accent),
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        if (_loi != null)
                          SaleBaoLoi(loi: _loi!, onThuLai: _nap),
                        if (bang != null && bang.danhSach.isEmpty)
                          SaleRong(
                            icon: Icons.assignment_outlined,
                            tieuDe: _nhom == 'tat_ca'
                                ? 'Chưa có yêu cầu nào'
                                : 'Không có yêu cầu ở nhóm này',
                            mo:
                                'Bấm "Tạo yêu cầu" để ghi lại một khách đang '
                                'tìm nhà — kể cả khách mới nhắn Zalo.',
                            nut: FilledButton(
                              onPressed: _taoMoi,
                              style: FilledButton.styleFrom(
                                backgroundColor: HD.accent,
                              ),
                              child: const Text('Tạo yêu cầu'),
                            ),
                          ),
                        for (final m in bang?.danhSach ?? const <MucYeuCau>[])
                          _The(muc: m, onTap: () => _moChiTiet(m.id)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _The extends StatelessWidget {
  const _The({required this.muc, required this.onTap});

  final MucYeuCau muc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mau = saleMauBuoc(muc.trangThai);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        key: Key('sale-yeu-cau-${muc.id}'),
        borderRadius: BorderRadius.circular(HD.r12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: HD.paperRaised,
            borderRadius: BorderRadius.circular(HD.r12),
            border: Border.all(color: HD.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    muc.ma,
                    style: HD.bodyBold(size: 11.5, color: HD.inkMuted),
                  ),
                  const Spacer(),
                  SaleNhan(chu: muc.nhan, mau: mau),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SaleAnhKhach(ten: muc.khach, kichThuoc: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(muc.khach, style: HD.bodyBold(size: 14)),
                        if (muc.sdt.isNotEmpty)
                          Text(
                            muc.sdt,
                            style: HD.body(size: 12, color: HD.accent),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (muc.loaiCan.isNotEmpty) muc.loaiCan,
                            if (muc.khuVuc.isNotEmpty) muc.khuVuc,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HD.body(size: 12, color: HD.inkSoft),
                        ),
                        if (muc.nganSach.isNotEmpty)
                          Text(
                            'Ngân sách ${muc.nganSach}',
                            style: HD.body(size: 12, color: HD.inkMuted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: HD.paperSunken,
                  borderRadius: BorderRadius.circular(HD.r8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 15, color: mau),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Việc tiếp theo: ${muc.viecTiep}',
                        style: HD.bodyBold(size: 12, color: HD.inkSoft),
                      ),
                    ),
                    Text(
                      saleTruoc(muc.capNhat),
                      style: HD.body(size: 11, color: HD.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "+ Tạo yêu cầu" — khách chưa có tài khoản vẫn ghi được (chốt 23/09/2026):
/// sale gặp khách qua Zalo trước khi họ cài app.
class _SheetTaoYeuCau extends StatefulWidget {
  const _SheetTaoYeuCau({required this.api});

  final SaleYeuCauApi api;

  @override
  State<_SheetTaoYeuCau> createState() => _SheetTaoYeuCauState();
}

class _SheetTaoYeuCauState extends State<_SheetTaoYeuCau> {
  final _ten = TextEditingController();
  final _sdt = TextEditingController();
  final _loai = TextEditingController();
  final _khu = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();
  bool _dangGui = false;
  String? _loi;

  @override
  void dispose() {
    _ten.dispose();
    _sdt.dispose();
    _loai.dispose();
    _khu.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  int? _trieu(TextEditingController c) {
    final s = c.text.trim().replaceAll(',', '.');
    if (s.isEmpty) return null;
    final v = double.tryParse(s);
    return v == null ? null : (v * 1000000).round();
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
      await widget.api.tao(
        hoTen: _ten.text.trim(),
        sdt: _sdt.text.trim(),
        loaiCan: _loai.text.trim(),
        khuVuc: _khu.text.trim(),
        nganSachMin: _trieu(_min),
        nganSachMax: _trieu(_max),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangGui = false;
        _loi = e is ApiException ? e.message : 'Chưa tạo được yêu cầu';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: HD.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: HD.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Tạo yêu cầu mới', style: HD.bodyBold(size: 16)),
            const SizedBox(height: 4),
            Text(
              'Khách chưa có tài khoản vẫn ghi được — trùng SĐT thì hệ thống '
              'tự gộp vào khách cũ.',
              style: HD.body(size: 12, color: HD.inkMuted),
            ),
            const SizedBox(height: 14),
            _o(_ten, 'Tên khách', khoa: 'sale-yc-ten'),
            const SizedBox(height: 10),
            _o(
              _sdt,
              'Số điện thoại',
              khoa: 'sale-yc-sdt',
              kieu: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            _o(_loai, 'Loại căn (VD: Căn hộ 2 phòng ngủ)'),
            const SizedBox(height: 10),
            _o(_khu, 'Khu vực quan tâm'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _o(
                    _min,
                    'Ngân sách từ (triệu)',
                    khoa: 'sale-yc-min',
                    kieu: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _o(
                    _max,
                    'đến (triệu)',
                    khoa: 'sale-yc-max',
                    kieu: TextInputType.number,
                  ),
                ),
              ],
            ),
            if (_loi != null) ...[
              const SizedBox(height: 10),
              Text(_loi!, style: HD.body(size: 12.5, color: HD.negative)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                key: const Key('sale-yc-luu'),
                onPressed: _dangGui ? null : _gui,
                style: FilledButton.styleFrom(backgroundColor: HD.accent),
                child: _dangGui
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Tạo yêu cầu',
                        style: HD.bodyBold(size: 15, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
