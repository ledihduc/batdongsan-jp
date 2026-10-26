import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/chu_nha_api.dart';
import 'package:house_booking/features/guest/thue_o/ho_so_thue.dart';
import 'package:house_booking/features/host/chu_nha/widgets/chu_nha_ui.dart';

/// Màn 6 — Tạo hợp đồng sau khi chốt (mockup "Góc nhìn Chủ nhà", 04/10/2026).
///
/// Ba bước: Thông tin · Cọc & thanh toán · Xác nhận. Người thuê là khách của
/// lịch xem (Sale cung cấp hồ sơ) nên chủ nhà chỉ thấy "[ẩn thông tin]" và
/// không phải gõ lại. Gửi xong = hợp đồng NHÁP + đề nghị thuê tới khách; khách
/// xác nhận trên app thì phòng chuyển sang Đang thuê.
///
/// API: `POST /api/host/chu-nha/lich-xem/{id}/hop-dong` rồi
/// `PATCH /api/viewing-appointments/{id}/status` (locked).
class TaoHopDongScreen extends StatefulWidget {
  const TaoHopDongScreen({
    super.key,
    required this.lich,
    this.dienTich,
    this.api = const ChuNhaApi(),
    this.homNay,
  });

  final LichChuNha lich;
  final double? dienTich;
  final ChuNhaApi api;

  /// Chỉ để test ghim "hôm nay".
  final DateTime? homNay;

  @override
  State<TaoHopDongScreen> createState() => _TaoHopDongScreenState();
}

class _TaoHopDongScreenState extends State<TaoHopDongScreen> {
  int _buoc = 0;
  bool _dangGui = false;
  late final _gia = TextEditingController(
    text: widget.lich.giaThue == null ? '' : _so(widget.lich.giaThue!),
  );
  final _thang = TextEditingController(text: '12');
  late final _coc = TextEditingController(
    text: widget.lich.giaThue == null ? '' : _so(widget.lich.giaThue! * 2),
  );
  late DateTime _batDau = () {
    final h = widget.homNay ?? DateTime.now();
    return DateTime(h.year, h.month, h.day).add(const Duration(days: 7));
  }();
  int _ngayTra = 5;
  String _hinhThuc = 'chuyen_khoan';

  @override
  void dispose() {
    _gia.dispose();
    _thang.dispose();
    _coc.dispose();
    super.dispose();
  }

  static String _so(num v) => tienVN(v).replaceAll('đ', '');
  static double _doc(String s) =>
      double.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  double get _giaThue => _doc(_gia.text);
  double get _tienCoc => _doc(_coc.text);
  int get _soThang => int.tryParse(_thang.text.trim()) ?? 0;

  String? get _loiBuoc1 {
    if (_giaThue <= 0) return 'Nhập giá thuê.';
    if (_soThang < 1 || _soThang > 120) {
      return 'Thời hạn thuê từ 1 đến 120 tháng.';
    }
    return null;
  }

  DateTime get _ketThuc {
    final y = _batDau.year + (_batDau.month - 1 + _soThang) ~/ 12;
    final m = (_batDau.month - 1 + _soThang) % 12 + 1;
    final cuoi = DateUtils.getDaysInMonth(y, m);
    return DateTime(
      y,
      m,
      _batDau.day > cuoi ? cuoi : _batDau.day,
    ).subtract(const Duration(days: 1));
  }

  Future<void> _chonNgay() async {
    final h = widget.homNay ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _batDau,
      firstDate: DateTime(h.year, h.month, h.day),
      lastDate: DateTime(h.year + 2),
    );
    if (d != null) setState(() => _batDau = d);
  }

  void _tiep() {
    if (_buoc == 0) {
      final loi = _loiBuoc1;
      if (loi != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loi)));
        return;
      }
    }
    if (_buoc < 2) {
      setState(() => _buoc++);
      return;
    }
    _gui();
  }

  Future<void> _gui() async {
    setState(() => _dangGui = true);
    try {
      await widget.api.taoHopDong(
        widget.lich.id,
        giaThue: _giaThue,
        soThang: _soThang,
        ngayBatDau: _batDau,
        tienCoc: _tienCoc,
        ngayThanhToan: _ngayTra,
        hinhThuc: _hinhThuc,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const _DaGuiHopDong()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _dangGui = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException
                ? e.message
                : 'Chưa tạo được hợp đồng, thử lại nhé.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _buoc == 0,
    onPopInvokedWithResult: (daPop, _) {
      if (!daPop) setState(() => _buoc--);
    },
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: appBarCN(context, 'Tạo hợp đồng'),
      body: ListView(
        key: const Key('tao-hop-dong'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _ThanhBuoc(buoc: _buoc),
          const SizedBox(height: 18),
          ...switch (_buoc) {
            0 => _buocThongTin(),
            1 => _buocCoc(),
            _ => _buocXacNhan(),
          },
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 48,
            child: FilledButton(
              key: const Key('tiep-tuc'),
              style: FilledButton.styleFrom(
                backgroundColor: HD.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: HD.bodyBold(size: 15),
              ),
              onPressed: _dangGui ? null : _tiep,
              child: _dangGui
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_buoc < 2 ? 'Tiếp tục' : 'Gửi hợp đồng cho khách'),
            ),
          ),
        ),
      ),
    ),
  );

  // ── Bước 1: Thông tin ──────────────────────────────────────────────────────
  List<Widget> _buocThongTin() {
    final dt = widget.dienTich;
    return [
      Text('Thông tin khách thuê', style: HD.bodyBold(size: 15.5)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF4FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: HD.inkSoft, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Thông tin',
                          style: HD.bodyBold(size: 12.5, color: kXanhDuong),
                        ),
                        TextSpan(
                          text: ' được Sale cung cấp',
                          style: HD.body(size: 12.5, color: HD.ink),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final n in const ['Họ tên:', 'Số CCCD:', 'SĐT:'])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          SizedBox(width: 72, child: phuCN(n)),
                          phuCN(kAnThongTin),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Text('Thông tin hợp đồng', style: HD.bodyBold(size: 15.5)),
      const SizedBox(height: 10),
      _Dong(
        'Phòng',
        child: _HopChu(
          dt == null
              ? widget.lich.tenPhong
              : '${widget.lich.tenPhong}  (${dt % 1 == 0 ? dt.toInt() : dt} m²)',
        ),
      ),
      _Dong(
        'Giá thuê',
        child: _O(
          khoa: const Key('o-gia-thue'),
          ctl: _gia,
          duoi: 'đ/tháng',
          tien: true,
          onChanged: () => setState(() {}),
        ),
      ),
      _Dong(
        'Thời hạn thuê',
        child: _O(
          khoa: const Key('o-thoi-han'),
          ctl: _thang,
          duoi: 'tháng',
          onChanged: () => setState(() {}),
        ),
      ),
      _Dong(
        'Ngày bắt đầu',
        child: InkWell(
          key: const Key('o-ngay-bat-dau'),
          onTap: _chonNgay,
          borderRadius: BorderRadius.circular(8),
          child: _HopChu(
            ngayVN(_batDau),
            duoi: const Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: HD.inkSoft,
            ),
          ),
        ),
      ),
      _Dong(
        'Tiền cọc',
        child: _O(
          khoa: const Key('o-tien-coc'),
          ctl: _coc,
          duoi: 'đ',
          tien: true,
          onChanged: () => setState(() {}),
        ),
      ),
      const SizedBox(height: 4),
      phuCN('Ngày thanh toán hàng tháng'),
      const SizedBox(height: 8),
      _ChonNgayTra(
        gia: _ngayTra,
        onChanged: (v) => setState(() => _ngayTra = v),
      ),
    ];
  }

  // ── Bước 2: Cọc & thanh toán ───────────────────────────────────────────────
  List<Widget> _buocCoc() => [
    Text('Hình thức thanh toán', style: HD.bodyBold(size: 15.5)),
    const SizedBox(height: 10),
    for (final (k, nhan, icon) in const [
      ('chuyen_khoan', 'Chuyển khoản', Icons.account_balance_outlined),
      ('tien_mat', 'Tiền mặt', Icons.payments_outlined),
    ])
      TheCN(
        key: Key('hinh-thuc-$k'),
        onTap: () => setState(() => _hinhThuc = k),
        child: Row(
          children: [
            Icon(icon, color: _hinhThuc == k ? HD.accent : HD.inkSoft),
            const SizedBox(width: 12),
            Expanded(child: Text(nhan, style: HD.body(size: 14.5))),
            Icon(
              _hinhThuc == k
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: _hinhThuc == k ? HD.accent : const Color(0xFFC4C8CE),
            ),
          ],
        ),
      ),
    const SizedBox(height: 14),
    Text('Khoản thu khi nhận phòng', style: HD.bodyBold(size: 15.5)),
    const SizedBox(height: 8),
    _TomTat([
      ('Tiền thuê tháng đầu', tienVN(_giaThue)),
      ('Tiền cọc', tienVN(_tienCoc)),
      ('Tổng cần thu', tienVN(_giaThue + _tienCoc)),
    ], damCuoi: true),
    const SizedBox(height: 10),
    phuCN(
      'Hằng tháng thu tiền vào ngày ${hai(_ngayTra)}. Hóa đơn tháng sẽ lập '
      'theo ngày này.',
    ),
  ];

  // ── Bước 3: Xác nhận ───────────────────────────────────────────────────────
  List<Widget> _buocXacNhan() => [
    Text('Xác nhận hợp đồng', style: HD.bodyBold(size: 15.5)),
    const SizedBox(height: 8),
    _TomTat([
      ('Phòng', widget.lich.tenPhong),
      ('Khách thuê', kAnThongTin),
      ('Giá thuê', '${tienVN(_giaThue)}/tháng'),
      ('Thời hạn', '$_soThang tháng'),
      ('Từ ngày', ngayVN(_batDau)),
      ('Đến ngày', ngayVN(_ketThuc)),
      ('Tiền cọc', tienVN(_tienCoc)),
      ('Ngày thanh toán', 'Ngày ${hai(_ngayTra)} hằng tháng'),
      ('Hình thức', _hinhThuc == 'tien_mat' ? 'Tiền mặt' : 'Chuyển khoản'),
    ]),
    const SizedBox(height: 12),
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: kCamCN, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Hợp đồng sẽ được gửi cho khách ký qua app (Sale hỗ trợ). Khách '
              'xác nhận xong, phòng chuyển sang trạng thái Đang thuê.',
              style: HD.body(size: 13, color: HD.ink),
            ),
          ),
        ],
      ),
    ),
  ];
}

class _ThanhBuoc extends StatelessWidget {
  const _ThanhBuoc({required this.buoc});

  final int buoc;

  @override
  Widget build(BuildContext context) {
    const ten = ['Thông tin', 'Cọc & thanh toán', 'Xác nhận'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: i == 0
                          ? const SizedBox()
                          : Container(
                              height: 1.5,
                              color: i <= buoc ? HD.accent : kVienCN,
                            ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i <= buoc ? HD.accent : const Color(0xFFE9EAEE),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: HD.bodyBold(
                          size: 11.5,
                          color: i <= buoc ? Colors.white : HD.inkMuted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: i == 2
                          ? const SizedBox()
                          : Container(
                              height: 1.5,
                              color: i < buoc ? HD.accent : kVienCN,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  ten[i],
                  textAlign: TextAlign.center,
                  style: HD.body(
                    size: 11.5,
                    color: i == buoc ? HD.ink : HD.inkMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Một dòng "nhãn — ô nhập" như mockup.
class _Dong extends StatelessWidget {
  const _Dong(this.nhan, {required this.child});

  final String nhan;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        SizedBox(width: 104, child: phuCN(nhan)),
        Expanded(child: child),
      ],
    ),
  );
}

class _HopChu extends StatelessWidget {
  const _HopChu(this.chu, {this.duoi});

  final String chu;
  final Widget? duoi;

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFDDE0E5)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            chu,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HD.body(size: 13.5, color: HD.ink),
          ),
        ),
        ?duoi,
      ],
    ),
  );
}

class _O extends StatelessWidget {
  const _O({
    required this.khoa,
    required this.ctl,
    required this.duoi,
    required this.onChanged,
    this.tien = false,
  });

  final Key khoa;
  final TextEditingController ctl;
  final String duoi;
  final VoidCallback onChanged;
  final bool tien;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: TextField(
      key: khoa,
      controller: ctl,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        if (tien) _DinhDangTien(),
      ],
      onChanged: (_) => onChanged(),
      style: HD.body(size: 13.5, color: HD.ink),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        suffixIcon: Container(
          width: 64,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFF4F5F7),
            borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
          ),
          child: Text(duoi, style: HD.body(size: 12.5, color: HD.inkMuted)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDDE0E5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: HD.accent),
        ),
      ),
    ),
  );
}

/// 4500000 → "4.500.000" ngay khi gõ.
class _DinhDangTien extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue cu, TextEditingValue moi) {
    final so = moi.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (so.isEmpty) return const TextEditingValue();
    final chu = tienVN(int.parse(so)).replaceAll('đ', '');
    return TextEditingValue(
      text: chu,
      selection: TextSelection.collapsed(offset: chu.length),
    );
  }
}

class _ChonNgayTra extends StatelessWidget {
  const _ChonNgayTra({required this.gia, required this.onChanged});

  final int gia;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFDDE0E5)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        key: const Key('o-ngay-tra'),
        value: gia,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        style: HD.body(size: 13.5, color: HD.ink),
        items: [
          for (var d = 1; d <= 28; d++)
            DropdownMenuItem(value: d, child: Text('Ngày ${hai(d)}')),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    ),
  );
}

class _TomTat extends StatelessWidget {
  const _TomTat(this.dong, {this.damCuoi = false});

  final List<(String, String)> dong;
  final bool damCuoi;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: kNenCN,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        for (var i = 0; i < dong.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Expanded(child: phuCN(dong[i].$1)),
                Flexible(
                  child: Text(
                    dong[i].$2,
                    key: Key('tom-tat-${dong[i].$1}'),
                    textAlign: TextAlign.right,
                    style: damCuoi && i == dong.length - 1
                        ? HD.bodyBold(size: 15, color: HD.accent)
                        : HD.bodyBold(size: 13.5, color: HD.ink),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Gửi xong: hợp đồng nháp đã sang tay khách.
class _DaGuiHopDong extends StatelessWidget {
  const _DaGuiHopDong();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Spacer(flex: 2),
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: HD.positiveTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                color: HD.positive,
                size: 46,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Đã gửi hợp đồng cho khách',
              textAlign: TextAlign.center,
              style: HD.bodyBold(size: 20, color: HD.ink),
            ),
            const SizedBox(height: 10),
            Text(
              'Khách sẽ ký hợp đồng qua app (Sale hỗ trợ). Khi khách xác nhận, '
              'phòng chuyển sang trạng thái Đang thuê.',
              textAlign: TextAlign.center,
              style: HD.body(size: 14, color: HD.inkMuted),
            ),
            const Spacer(flex: 3),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton(
                key: const Key('ve-tong-quan'),
                style: FilledButton.styleFrom(
                  backgroundColor: HD.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Về trang trước'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}
