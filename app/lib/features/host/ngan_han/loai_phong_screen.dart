import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/loai_phong_api.dart';

/// LOẠI PHÒNG (hạng phòng) của một toà lưu trú ngắn hạn.
///
/// Route: không — `Navigator.push` từ menu tên toà ở Sổ phòng.
/// API: [LoaiPhongApi] (`/api/host/buildings/{id}/loai-phong`).
///
/// Vì sao màn này tồn tại: khách đặt homestay/khách sạn chọn **hạng phòng**
/// ("Studio VIP"), số phòng do lễ tân gán lúc nhận. Nên câu hỏi điều hành là
/// "hạng này còn mấy phòng trống", và giá phải khai MỘT lần cho cả hạng — mười
/// phòng giống hệt nhau mà gõ giá mười lần thì sai một phòng không ai thấy.
///
/// Phòng chưa xếp hạng hiện thành một khối riêng ở cuối: đó là phòng khách
/// không đặt được theo hạng, im lặng bỏ qua là mất hàng mà không biết.
class LoaiPhongScreen extends StatefulWidget {
  const LoaiPhongScreen({
    super.key,
    required this.buildingId,
    this.tenToa = '',
    this.api = const LoaiPhongApi(),
  });

  final int buildingId;
  final String tenToa;
  final LoaiPhongApi api;

  @override
  State<LoaiPhongScreen> createState() => _LoaiPhongScreenState();
}

class _LoaiPhongScreenState extends State<LoaiPhongScreen> {
  BangLoaiPhong? _bang;
  bool _dangTai = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nap());
  }

  Future<void> _nap() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final b = await widget.api.danhSach(widget.buildingId);
      if (mounted) setState(() => _bang = b);
    } catch (e) {
      if (mounted) {
        setState(() => _loi = e is ApiException ? e.message : 'Không tải được loại phòng');
      }
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  void _bao(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _moForm({LoaiPhong? sua}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => HopThoaiLoaiPhong(
        buildingId: widget.buildingId,
        api: widget.api,
        hang: sua,
        phongCoThe: [
          ...?_bang?.chuaXepHang,
          ...?sua?.phong,
        ],
      ),
    );
    if (ok == true && mounted) {
      _bao(sua == null ? 'Đã tạo hạng phòng.' : 'Đã lưu hạng phòng.');
      await _nap();
    }
  }

  Future<void> _ganPhong(LoaiPhong hang) async {
    final chon = {for (final p in hang.phong) p.id};
    final ra = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HopThoaiGanPhong(
        hang: hang,
        chuaXep: _bang?.chuaXepHang ?? const [],
        daChon: chon,
      ),
    );
    if (ra == null) return;
    try {
      final so = await widget.api.ganPhong(hang.id, ra.toList());
      if (!mounted) return;
      _bao('Hạng "${hang.ten}" nay có $so phòng.');
      await _nap();
    } catch (e) {
      if (mounted) _bao(e is ApiException ? e.message : 'Không gán được phòng');
    }
  }

  Future<void> _xoa(LoaiPhong hang) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Xoá hạng "${hang.ten}"?'),
        content: Text(
          hang.soPhong == 0
              ? 'Hạng này chưa có phòng nào.'
              : '${hang.soPhong} phòng sẽ trở về "chưa xếp hạng" — phòng KHÔNG bị xoá, '
                    'nhưng khách sẽ không đặt được theo hạng cho tới khi xếp lại.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Huỷ')),
          TextButton(
            key: const ValueKey('xac-nhan-xoa-hang'),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Xoá hạng'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.xoa(hang.id);
      if (!mounted) return;
      _bao('Đã xoá hạng "${hang.ten}".');
      await _nap();
    } catch (e) {
      if (mounted) _bao(e is ApiException ? e.message : 'Không xoá được hạng');
    }
  }

  Future<void> _batTat(LoaiPhong hang, bool bat) async {
    try {
      await widget.api.sua(hang.id, {'dang_ban': bat});
      if (!mounted) return;
      _bao(bat ? 'Hạng "${hang.ten}" mở bán lại.' : 'Đã ngừng bán hạng "${hang.ten}".');
      await _nap();
    } catch (e) {
      if (mounted) _bao(e is ApiException ? e.message : 'Không đổi được trạng thái');
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _bang;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Loại phòng', style: HD.bodyBold(size: 17)),
            if (widget.tenToa.isNotEmpty)
              Text(
                widget.tenToa,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HD.body(size: 11, color: HD.inkMuted),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('them-hang'),
        backgroundColor: HD.accent,
        foregroundColor: Colors.white,
        onPressed: () => _moForm(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm hạng'),
      ),
      body: RefreshIndicator(
        color: HD.accent,
        onRefresh: _nap,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
          children: [
            if (_dangTai && b != null)
              const Padding(
                padding: EdgeInsets.only(bottom: HD.s8),
                child: LinearProgressIndicator(minHeight: 2, color: HD.accent),
              ),
            if (_loi != null)
              Text(_loi!, style: HD.body(size: 13, color: HD.negative))
            else if (b == null)
              const Padding(
                padding: EdgeInsets.all(HD.s32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _tomTat(b),
              const SizedBox(height: 14),
              if (b.loaiPhong.isEmpty)
                _trong()
              else
                for (final h in b.loaiPhong) ...[
                  _TheHang(
                    hang: h,
                    onSua: () => _moForm(sua: h),
                    onGan: () => _ganPhong(h),
                    onXoa: () => _xoa(h),
                    onBatTat: (v) => _batTat(h, v),
                  ),
                  const SizedBox(height: 12),
                ],
              if (b.chuaXepHang.isNotEmpty) _chuaXep(b),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tomTat(BangLoaiPhong b) {
    final trong = b.loaiPhong.fold<int>(0, (t, h) => t + h.trong);
    final khach = b.loaiPhong.fold<int>(0, (t, h) => t + h.dangCoKhach);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HD.hairline.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          for (final (nhan, so, mau) in [
            ('Hạng phòng', '${b.loaiPhong.length}', HD.svcIndigo),
            ('Tổng phòng', '${b.tongPhong}', HD.ink),
            ('Đang có khách', '$khach', HD.accent),
            ('Trống', '$trong', HD.positive),
          ])
            Expanded(
              child: Column(
                children: [
                  Text(so, style: HD.bodyBold(size: 19, color: mau)),
                  Text(
                    nhan,
                    textAlign: TextAlign.center,
                    style: HD.body(size: 10.5, color: HD.inkMuted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _trong() => Container(
    padding: const EdgeInsets.all(HD.s16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: HD.hairline.withValues(alpha: 0.8)),
    ),
    child: Column(
      children: [
        const Icon(Icons.category_outlined, size: 34, color: HD.inkMuted),
        const SizedBox(height: HD.s8),
        Text('Chưa có hạng phòng nào', style: HD.bodyBold(size: 14)),
        const SizedBox(height: 4),
        Text(
          'Khách đặt theo HẠNG ("Studio VIP", "Phòng đôi"), không chọn số phòng. '
          'Gom các phòng giống nhau vào một hạng để khai giá một lần và biết '
          'hạng nào còn phòng.',
          textAlign: TextAlign.center,
          style: HD.body(size: 12, color: HD.inkSoft),
        ),
      ],
    ),
  );

  Widget _chuaXep(BangLoaiPhong b) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: HD.warningTint,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: HD.warning.withValues(alpha: 0.5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 18, color: HD.svcAmber),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${b.chuaXepHang.length} phòng chưa xếp hạng',
                style: HD.bodyBold(size: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Khách không đặt được những phòng này theo hạng. Mở một hạng rồi xếp '
          'chúng vào, hoặc tạo hạng mới.',
          style: HD.body(size: 12, color: HD.inkSoft),
        ),
        const SizedBox(height: HD.s8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in b.chuaXepHang)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: HD.hairline),
                ),
                child: Text(p.ma, style: HD.bodyBold(size: 12)),
              ),
          ],
        ),
      ],
    ),
  );
}

class _TheHang extends StatelessWidget {
  const _TheHang({
    required this.hang,
    required this.onSua,
    required this.onGan,
    required this.onXoa,
    required this.onBatTat,
  });

  final LoaiPhong hang;
  final VoidCallback onSua;
  final VoidCallback onGan;
  final VoidCallback onXoa;
  final void Function(bool) onBatTat;

  @override
  Widget build(BuildContext context) {
    final phu = [
      if (hang.giuong != null) hang.giuong!,
      '${hang.sucChua} khách',
      if (hang.dienTich != null) '${hang.dienTich!.toStringAsFixed(0)} m²',
    ].join(' • ');
    return Container(
      key: ValueKey('hang-${hang.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hang.dangBan
              ? HD.hairline.withValues(alpha: 0.8)
              : HD.hairlineStrong,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            hang.ten,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HD.bodyBold(size: 15),
                          ),
                        ),
                        if (!hang.dangBan) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: HD.s8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: HD.paperSunken,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'Ngừng bán',
                              style: HD.bodyBold(size: 10.5, color: HD.inkMuted),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(phu, style: HD.body(size: 11.5, color: HD.inkMuted)),
                  ],
                ),
              ),
              Switch(
                key: ValueKey('bat-hang-${hang.id}'),
                value: hang.dangBan,
                activeThumbColor: Colors.white,
                activeTrackColor: HD.accent,
                onChanged: onBatTat,
              ),
            ],
          ),
          const SizedBox(height: HD.s8),
          Wrap(
            spacing: HD.s8,
            runSpacing: 6,
            children: [
              for (final (gia, don) in [
                (hang.giaGioHieuLuc, 'giờ'),
                (hang.giaDemHieuLuc, 'đêm'),
                (hang.giaNgayHieuLuc, 'ngày'),
              ])
                if (gia != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: HD.accentTint,
                      borderRadius: BorderRadius.circular(HD.r8),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: PriceFormat.full(gia),
                            style: HD.bodyBold(size: 12.5, color: HD.accent),
                          ),
                          TextSpan(
                            text: '/$don',
                            style: HD.body(size: 11, color: HD.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (hang.giaGioHieuLuc == null &&
                  hang.giaDemHieuLuc == null &&
                  hang.giaNgayHieuLuc == null)
                Text(
                  'Chưa khai giá — hạng chưa bán được',
                  style: HD.body(size: 12, color: HD.negative),
                ),
            ],
          ),
          const SizedBox(height: HD.s12),
          Row(
            children: [
              _O(so: '${hang.soPhong}', nhan: 'phòng', mau: HD.ink),
              _O(so: '${hang.trong}', nhan: 'trống', mau: HD.positive),
              _O(so: '${hang.dangCoKhach}', nhan: 'có khách', mau: HD.accent),
              if (hang.baoTri > 0)
                _O(so: '${hang.baoTri}', nhan: 'bảo trì', mau: HD.svcAmber),
            ],
          ),
          if (hang.phong.isNotEmpty) ...[
            const SizedBox(height: HD.s8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in hang.phong)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.coKhach
                          ? HD.accentTint
                          : p.baoTri
                          ? HD.warningTint
                          : HD.positiveTint,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      p.ma,
                      style: HD.bodyBold(
                        size: 11.5,
                        color: p.coKhach
                            ? HD.accent
                            : p.baoTri
                            ? HD.svcAmber
                            : HD.positive,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const Divider(height: HD.s24, color: HD.hairline),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  key: ValueKey('sua-hang-${hang.id}'),
                  onPressed: onSua,
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Sửa hạng'),
                  style: TextButton.styleFrom(
                    foregroundColor: HD.ink,
                    textStyle: HD.bodyBold(size: 12),
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  key: ValueKey('gan-phong-${hang.id}'),
                  onPressed: onGan,
                  icon: const Icon(Icons.meeting_room_outlined, size: 15),
                  label: const Text('Xếp phòng'),
                  style: TextButton.styleFrom(
                    foregroundColor: HD.svcIndigo,
                    textStyle: HD.bodyBold(size: 12),
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('xoa-hang-${hang.id}'),
                tooltip: 'Xoá hạng',
                onPressed: onXoa,
                icon: const Icon(Icons.delete_outline, size: 18, color: HD.negative),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _O extends StatelessWidget {
  const _O({required this.so, required this.nhan, required this.mau});

  final String so;
  final String nhan;
  final Color mau;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(so, style: HD.bodyBold(size: 16, color: mau)),
        Text(nhan, style: HD.body(size: 10.5, color: HD.inkMuted)),
      ],
    ),
  );
}

/// Tích chọn phòng thuộc hạng. Danh sách gồm phòng CHƯA xếp + phòng đang thuộc
/// hạng này — phòng của hạng khác không hiện, tránh giật phòng của nhau.
class _HopThoaiGanPhong extends StatefulWidget {
  const _HopThoaiGanPhong({
    required this.hang,
    required this.chuaXep,
    required this.daChon,
  });

  final LoaiPhong hang;
  final List<PhongTrongHang> chuaXep;
  final Set<int> daChon;

  @override
  State<_HopThoaiGanPhong> createState() => _HopThoaiGanPhongState();
}

class _HopThoaiGanPhongState extends State<_HopThoaiGanPhong> {
  late final Set<int> _chon = {...widget.daChon};

  @override
  Widget build(BuildContext context) {
    final ds = [...widget.hang.phong, ...widget.chuaXep]
      ..sort((a, b) => a.ma.compareTo(b.ma));
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Xếp phòng vào "${widget.hang.ten}"',
                    style: HD.bodyBold(size: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Flexible(
            child: ds.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(HD.s16),
                    child: Text(
                      'Toà này chưa có phòng nào để xếp.',
                      style: HD.body(size: 13, color: HD.inkMuted),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final p in ds)
                        CheckboxListTile(
                          key: ValueKey('chon-phong-${p.id}'),
                          value: _chon.contains(p.id),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _chon.add(p.id);
                            } else {
                              _chon.remove(p.id);
                            }
                          }),
                          title: Text(p.ma, style: HD.bodyBold(size: 14)),
                          subtitle: Text(
                            p.coKhach
                                ? 'Đang có khách'
                                : p.baoTri
                                ? 'Bảo trì'
                                : 'Trống',
                            style: HD.body(size: 11.5, color: HD.inkMuted),
                          ),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(HD.s16),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                key: const ValueKey('luu-gan-phong'),
                onPressed: () => Navigator.pop(context, _chon),
                style: FilledButton.styleFrom(
                  backgroundColor: HD.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(HD.r12),
                  ),
                ),
                child: Text('Xếp ${_chon.length} phòng vào hạng'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tạo / sửa một hạng phòng.
class HopThoaiLoaiPhong extends StatefulWidget {
  const HopThoaiLoaiPhong({
    super.key,
    required this.buildingId,
    this.api = const LoaiPhongApi(),
    this.hang,
    this.phongCoThe = const [],
  });

  final int buildingId;
  final LoaiPhongApi api;

  /// `null` = tạo mới.
  final LoaiPhong? hang;

  /// Phòng có thể xếp vào hạng ngay lúc tạo (phòng chưa xếp hạng).
  final List<PhongTrongHang> phongCoThe;

  @override
  State<HopThoaiLoaiPhong> createState() => _HopThoaiLoaiPhongState();
}

class _HopThoaiLoaiPhongState extends State<HopThoaiLoaiPhong> {
  late final _ten = TextEditingController(text: widget.hang?.ten ?? '');
  late final _giuong = TextEditingController(text: widget.hang?.giuong ?? '');
  late final _dienTich = TextEditingController(text: _so(widget.hang?.dienTich));
  late final _moTa = TextEditingController(text: widget.hang?.moTa ?? '');
  late final _gio = TextEditingController(text: _so(widget.hang?.giaTheoGio));
  late final _dem = TextEditingController(text: _so(widget.hang?.giaQuaDem));
  late final _ngay = TextEditingController(text: _so(widget.hang?.giaTheoNgay));

  late int _sucChua = widget.hang?.sucChua ?? 2;
  late final Set<int> _chon = {for (final p in widget.hang?.phong ?? const []) p.id};
  bool _dangLuu = false;
  String? _loi;

  static String _so(double? v) => v == null ? '' : v.toStringAsFixed(0);

  @override
  void dispose() {
    for (final c in [_ten, _giuong, _dienTich, _moTa, _gio, _dem, _ngay]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _luu() async {
    if (_ten.text.trim().isEmpty) {
      setState(() => _loi = 'Hạng phòng phải có tên');
      return;
    }
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    try {
      final gio = double.tryParse(_gio.text.trim());
      final dem = double.tryParse(_dem.text.trim());
      final ngay = double.tryParse(_ngay.text.trim());
      final cu = widget.hang;
      if (cu == null) {
        await widget.api.tao(
          widget.buildingId,
          ten: _ten.text.trim(),
          moTa: _moTa.text.trim().isEmpty ? null : _moTa.text.trim(),
          sucChua: _sucChua,
          dienTich: double.tryParse(_dienTich.text.trim()),
          giuong: _giuong.text.trim().isEmpty ? null : _giuong.text.trim(),
          giaTheoGio: gio,
          giaQuaDem: dem,
          giaTheoNgay: ngay,
          roomIds: _chon.toList(),
        );
      } else {
        await widget.api.sua(cu.id, {
          'ten': _ten.text.trim(),
          'mo_ta': _moTa.text.trim(),
          'suc_chua': _sucChua,
          if (double.tryParse(_dienTich.text.trim()) != null)
            'dien_tich': double.parse(_dienTich.text.trim()),
          'giuong': _giuong.text.trim(),
          if (gio != null) 'gia_theo_gio': gio,
          if (dem != null) 'gia_qua_dem': dem,
          if (ngay != null) 'gia_theo_ngay': ngay,
        });
        await widget.api.ganPhong(cu.id, _chon.toList());
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangLuu = false;
        _loi = e is ApiException ? e.message : 'Không lưu được hạng phòng';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = [...?widget.hang?.phong, ...widget.phongCoThe];
    final duyNhat = {for (final p in ds) p.id: p}.values.toList()
      ..sort((a, b) => a.ma.compareTo(b.ma));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s16, HD.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.category_outlined, color: HD.accent),
                  const SizedBox(width: HD.s8),
                  Expanded(
                    child: Text(
                      widget.hang == null ? 'Thêm hạng phòng' : 'Sửa hạng phòng',
                      style: HD.bodyBold(size: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              _o(_ten, 'Tên hạng', goiY: 'VD: Studio VIP, Phòng đôi hướng vườn'),
              const SizedBox(height: HD.s8),
              Row(
                children: [
                  Expanded(
                    child: _o(_giuong, 'Loại giường', goiY: 'VD: King 1m8'),
                  ),
                  const SizedBox(width: HD.s8),
                  Expanded(
                    child: _o(
                      _dienTich,
                      'Diện tích (m²)',
                      kieu: TextInputType.number,
                      chiSo: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: HD.s8),
              Row(
                children: [
                  Text('Sức chứa', style: HD.bodyBold(size: 13)),
                  const Spacer(),
                  IconButton(
                    key: const ValueKey('suc-chua-giam'),
                    onPressed: _sucChua <= 1 ? null : () => setState(() => _sucChua--),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$_sucChua khách', style: HD.bodyBold(size: 14)),
                  IconButton(
                    key: const ValueKey('suc-chua-tang'),
                    onPressed: _sucChua >= 20 ? null : () => setState(() => _sucChua++),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const Divider(height: HD.s24, color: HD.hairline),
              Text(
                'Giá của hạng — bỏ trống nghĩa là KHÔNG bán hình thức đó',
                style: HD.body(size: 12, color: HD.inkSoft),
              ),
              const SizedBox(height: HD.s8),
              Row(
                children: [
                  Expanded(
                    child: _o(_gio, 'đ/giờ', kieu: TextInputType.number, chiSo: true),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _o(_dem, 'đ/đêm', kieu: TextInputType.number, chiSo: true),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _o(_ngay, 'đ/ngày', kieu: TextInputType.number, chiSo: true),
                  ),
                ],
              ),
              const SizedBox(height: HD.s8),
              _o(_moTa, 'Mô tả ngắn', goiY: 'Hiện cho khách khi chọn hạng'),
              if (duyNhat.isNotEmpty) ...[
                const Divider(height: HD.s24, color: HD.hairline),
                Text('Phòng thuộc hạng này', style: HD.bodyBold(size: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in duyNhat)
                      FilterChip(
                        key: ValueKey('chon-phong-${p.id}'),
                        label: Text(p.ma),
                        selected: _chon.contains(p.id),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _chon.add(p.id);
                          } else {
                            _chon.remove(p.id);
                          }
                        }),
                      ),
                  ],
                ),
              ],
              if (_loi != null) ...[
                const SizedBox(height: HD.s8),
                Text(_loi!, style: HD.body(size: 13, color: HD.negative)),
              ],
              const SizedBox(height: HD.s12),
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  key: const ValueKey('luu-hang'),
                  onPressed: _dangLuu ? null : _luu,
                  style: FilledButton.styleFrom(
                    backgroundColor: HD.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(HD.r12),
                    ),
                  ),
                  icon: _dangLuu
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(_dangLuu ? 'Đang lưu…' : 'Lưu hạng phòng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _o(
    TextEditingController c,
    String nhan, {
    TextInputType? kieu,
    bool chiSo = false,
    String? goiY,
  }) => TextField(
    controller: c,
    keyboardType: kieu,
    inputFormatters: chiSo ? [FilteringTextInputFormatter.digitsOnly] : null,
    decoration: InputDecoration(
      labelText: nhan,
      hintText: goiY,
      hintStyle: HD.body(size: 11.5, color: HD.inkMuted),
      border: const OutlineInputBorder(),
      isDense: true,
    ),
  );
}
