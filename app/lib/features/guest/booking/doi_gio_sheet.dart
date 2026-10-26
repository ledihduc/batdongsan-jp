import 'package:flutter/material.dart';

import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';

/// BẬN GIỜ NÀY — hai tấm sheet của cùng một cuộc đổi giờ (15/09/2026).
///
///   * [moXinDoiGio]   — sale/chủ nhà bận: chọn NHIỀU giờ rảnh (tối đa 5) +
///                        lý do, gửi cho khách.
///   * [moChonGioKhac] — khách không ưng giờ đề xuất: chọn MỘT giờ trống bất kỳ.
///
/// Cả hai lấy giờ từ `GET …/gio-trong` — đúng bộ khung giờ của tin/phòng, đã bỏ
/// giờ đã có người đặt và giờ vừa báo bận. Không cho gõ tay: gõ tay là trúng
/// giờ đóng hoặc giờ của người khác, và chỉ biết khi server từ chối.

/// Tối đa bấy nhiêu giờ đề xuất — khớp `DE_XUAT_TOI_DA` ở backend.
const kDeXuatToiDa = 5;

const _lyDoNhanh = [
  'Có việc đột xuất',
  'Đang dẫn khách khác',
  'Phòng đang dọn/sửa',
];

/// Trả phiếu đã chuyển `doi_gio`, hoặc null nếu người dùng đóng sheet.
Future<PhieuHen?> moXinDoiGio(
  BuildContext context, {
  required int appointmentId,
  required String ngayHienTai,
  required String gioHienTai,
  LichXemApi api = const LichXemApi(),
}) => showModalBottomSheet<PhieuHen>(
  context: context,
  isScrollControlled: true,
  // Mở từ màn nằm trong Navigator của TAB: không lên navigator gốc thì thanh
  // điều hướng dưới đè mất nút gửi.
  useRootNavigator: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => _SheetGio(
    appointmentId: appointmentId,
    api: api,
    nhieu: true,
    ngayHienTai: ngayHienTai,
    gioHienTai: gioHienTai,
  ),
);

/// Khách tự chọn một giờ trống khác. Trả phiếu sau khi đã chọn xong.
///
/// [khachTuDoi] = khách tự đổi lịch đang chờ/đã duyệt (không phải chọn lại sau
/// khi bên bán báo bận) → gọi `khach-doi-lich`, lịch về chờ duyệt lại.
Future<PhieuHen?> moChonGioKhac(
  BuildContext context, {
  required int appointmentId,
  LichXemApi api = const LichXemApi(),
  bool khachTuDoi = false,
  String ngayHienTai = '',
  String gioHienTai = '',
}) => showModalBottomSheet<PhieuHen>(
  context: context,
  isScrollControlled: true,
  // Mở từ màn nằm trong Navigator của TAB: không lên navigator gốc thì thanh
  // điều hướng dưới đè mất nút gửi.
  useRootNavigator: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => _SheetGio(
    appointmentId: appointmentId,
    api: api,
    nhieu: false,
    khachTuDoi: khachTuDoi,
    ngayHienTai: ngayHienTai,
    gioHienTai: gioHienTai,
  ),
);

class _SheetGio extends StatefulWidget {
  const _SheetGio({
    required this.appointmentId,
    required this.api,
    required this.nhieu,
    this.ngayHienTai = '',
    this.gioHienTai = '',
    this.khachTuDoi = false,
  });

  final bool khachTuDoi;
  final int appointmentId;
  final LichXemApi api;

  /// true = bên bán chọn nhiều giờ đề xuất; false = khách chọn một giờ.
  final bool nhieu;
  final String ngayHienTai;
  final String gioHienTai;

  @override
  State<_SheetGio> createState() => _SheetGioState();
}

class _SheetGioState extends State<_SheetGio> {
  List<NgayTrong>? _ngay;
  String? _loi;
  int _ngayDangXem = 0;
  final List<GioDeXuat> _chon = [];
  final _lyDo = TextEditingController();
  bool _dangGui = false;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  @override
  void dispose() {
    _lyDo.dispose();
    super.dispose();
  }

  Future<void> _nap() async {
    try {
      final ds = await widget.api.gioTrong(widget.appointmentId);
      if (!mounted) return;
      setState(() {
        // Mở đúng NGÀY khách đã hẹn: bận 10:00 thì thường vẫn rảnh buổi chiều
        // cùng ngày — đỡ khách phải dời cả ngày.
        if (_ngay == null) {
          final i = ds.indexWhere((d) => d.ngay == widget.ngayHienTai);
          if (i >= 0) _ngayDangXem = i;
        }
        _ngay = ds;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _loi = e is ApiException ? e.message : 'Không tải được giờ trống',
        );
      }
    }
  }

  void _bam(GioDeXuat g) {
    setState(() {
      if (_chon.contains(g)) {
        _chon.remove(g);
      } else if (!widget.nhieu) {
        _chon
          ..clear()
          ..add(g);
      } else if (_chon.length < kDeXuatToiDa) {
        _chon.add(g);
      }
    });
  }

  Future<void> _gui() async {
    if (_chon.isEmpty || _dangGui) return;
    setState(() => _dangGui = true);
    try {
      final p = widget.nhieu
          ? await widget.api.doiGio(
              widget.appointmentId,
              deXuat: List.of(_chon),
              lyDo: _lyDo.text.trim(),
            )
          : widget.khachTuDoi
          ? await widget.api.khachDoiLich(widget.appointmentId, _chon.first)
          : await widget.api.chonGio(widget.appointmentId, _chon.first);
      if (mounted) Navigator.of(context).pop(p);
    } catch (e) {
      if (!mounted) return;
      setState(() => _dangGui = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Không gửi được, thử lại nhé',
          ),
        ),
      );
      // Giờ vừa bị người khác đặt mất → nạp lại cho khỏi bấm trúng lần nữa.
      _chon.clear();
      _nap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cao = MediaQuery.sizeOf(context).height * 0.86;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: cao),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                children: [_dau(), const SizedBox(height: 16), ..._than()],
              ),
            ),
            _chan(),
          ],
        ),
      ),
    );
  }

  Widget _dau() {
    final khi = _ngayGio(widget.ngayHienTai, widget.gioHienTai);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.nhieu ? HD.warningTint : HD.accentTint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.nhieu ? Icons.event_busy : Icons.schedule,
                size: 20,
                color: widget.nhieu ? HD.svcAmber : HD.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.nhieu
                    ? 'Bận giờ này? Đề xuất giờ khác'
                    : (widget.khachTuDoi
                          ? 'Đổi lịch xem nhà'
                          : 'Chọn giờ xem khác'),
                style: HD.bodyBold(size: 18),
              ),
            ),
            IconButton(
              key: const Key('doi-gio-dong'),
              tooltip: 'Đóng',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: HD.inkMuted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.nhieu
              ? '${khi.isEmpty ? 'Khách đã hẹn' : 'Khách hẹn $khi'}. Chọn những giờ '
                    'bạn rảnh (tối đa $kDeXuatToiDa) — khách sẽ chọn lại một giờ, '
                    'giờ cũ được nhả cho người khác.'
              : widget.khachTuDoi
              ? '${khi.isEmpty ? 'Lịch hiện tại' : 'Lịch hiện tại $khi'}. Chọn giờ mới — '
                    'bên bán sẽ duyệt lại, giờ cũ được nhả cho người khác.'
              : 'Giờ bên bán đề xuất được xác nhận ngay. Chọn giờ khác thì chờ '
                    'bên bán duyệt lại.',
          style: HD.body(size: 13, color: HD.inkMuted),
        ),
      ],
    );
  }

  List<Widget> _than() {
    final ds = _ngay;
    if (ds == null) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: _loi == null
                ? const CircularProgressIndicator(color: HD.accent)
                : Text(_loi!, style: HD.body(color: HD.inkMuted)),
          ),
        ),
      ];
    }
    if (ds.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'Bảy ngày tới không còn giờ trống nào. Mở thêm khung giờ xem nhà '
            'trong cài đặt lịch rồi thử lại.',
            textAlign: TextAlign.center,
            style: HD.body(size: 13, color: HD.inkMuted),
          ),
        ),
      ];
    }
    final i = _ngayDangXem.clamp(0, ds.length - 1);
    final ngay = ds[i];
    return [
      SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: ds.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, j) => _oNgay(ds[j], j == i, () {
            setState(() => _ngayDangXem = j);
          }),
        ),
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final g in ngay.gio) _oGio(GioDeXuat(ngay: ngay.ngay, gio: g)),
        ],
      ),
      if (widget.nhieu && _chon.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          'ĐÃ CHỌN ${_chon.length}/$kDeXuatToiDa',
          style: HD.bodyBold(size: 11, color: HD.inkMuted),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final g in _chon)
              InputChip(
                label: Text(_ngayGio(g.ngay, g.gio)),
                labelStyle: HD.bodyBold(size: 12, color: HD.accent),
                backgroundColor: HD.accentTint,
                side: BorderSide.none,
                onDeleted: () => _bam(g),
                deleteIconColor: HD.accent,
              ),
          ],
        ),
      ],
      if (widget.nhieu) ...[
        const SizedBox(height: 16),
        Text(
          'LÝ DO (không bắt buộc)',
          style: HD.bodyBold(size: 11, color: HD.inkMuted),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in _lyDoNhanh)
              ChoiceChip(
                label: Text(s),
                selected: _lyDo.text == s,
                onSelected: (_) => setState(() => _lyDo.text = s),
                labelStyle: HD.body(size: 12),
                selectedColor: HD.accentTint,
                showCheckmark: false,
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('doi-gio-ly-do'),
          controller: _lyDo,
          maxLength: 200,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Nhắn khách vài chữ…',
            counterText: '',
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF6F7FB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    ];
  }

  Widget _oNgay(NgayTrong n, bool dangXem, VoidCallback onTap) {
    final d = DateTime.tryParse(n.ngay);
    final daChon = _chon.where((g) => g.ngay == n.ngay).length;
    return InkWell(
      key: Key('doi-gio-ngay-${n.ngay}'),
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 58,
        decoration: BoxDecoration(
          color: dangXem ? HD.accent : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: dangXem ? HD.accent : HD.hairline),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    d == null ? '' : _thuNgan(d),
                    style: HD.body(
                      size: 11,
                      color: dangXem ? Colors.white70 : HD.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    d == null ? n.ngay : '${_hai(d.day)}/${_hai(d.month)}',
                    style: HD.bodyBold(
                      size: 14,
                      color: dangXem ? Colors.white : HD.ink,
                    ),
                  ),
                ],
              ),
            ),
            if (daChon > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: dangXem ? HD.ink : HD.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$daChon',
                    style: HD.bodyBold(size: 10, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _oGio(GioDeXuat g) {
    final chon = _chon.contains(g);
    final day = widget.nhieu && !chon && _chon.length >= kDeXuatToiDa;
    return InkWell(
      key: Key('doi-gio-o-${g.ngay}-${g.batDau}'),
      borderRadius: BorderRadius.circular(12),
      onTap: day ? null : () => _bam(g),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 74,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: chon
              ? HD.accent
              : (day ? const Color(0xFFF3F4F6) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: chon ? HD.accent : HD.hairline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (chon) ...[
              const Icon(Icons.check, size: 14, color: Colors.white),
              const SizedBox(width: 3),
            ],
            Text(
              g.batDau,
              style: HD.bodyBold(
                size: 13,
                color: chon ? Colors.white : (day ? HD.inkMuted : HD.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chan() {
    final so = _chon.length;
    final nhan = widget.nhieu
        ? (so == 0 ? 'Chọn ít nhất 1 giờ rảnh' : 'Gửi $so giờ cho khách chọn')
        : (so == 0
              ? 'Chọn một giờ'
              : 'Chọn ${_ngayGio(_chon.first.ngay, _chon.first.gio)}');
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: HD.hairline)),
        ),
        child: SizedBox(
          height: 50,
          child: FilledButton(
            key: Key(widget.nhieu ? 'doi-gio-gui' : 'chon-gio-xac-nhan'),
            onPressed: so == 0 || _dangGui ? null : _gui,
            style: FilledButton.styleFrom(
              backgroundColor: HD.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: HD.bodyBold(size: 15),
            ),
            child: _dangGui
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(nhan),
          ),
        ),
      ),
    );
  }
}

String _hai(int n) => n.toString().padLeft(2, '0');

String _thuNgan(DateTime d) =>
    const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][d.weekday - 1];

/// '14:00 · T4 17/09' — cách in một giờ trên một ngày, dùng chung cả hai phía.
String ngayGioNgan(String ngay, String gio) => _ngayGio(ngay, gio);

String _ngayGio(String ngay, String gio) {
  final d = DateTime.tryParse(ngay);
  final bd = gio.split('-').first;
  if (d == null) return bd;
  return '$bd · ${_thuNgan(d)} ${_hai(d.day)}/${_hai(d.month)}';
}
