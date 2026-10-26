import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/cho_thue_ngoai_api.dart';

/// ĐÃ CHO THUÊ NGOÀI APP — chủ nhà tự tìm được khách (Facebook, Zalo, môi giới,
/// người quen) và muốn app thôi rao phòng, sổ phòng đếm đúng.
///
/// Route: không — `showModalBottomSheet` từ Hồ sơ phòng.
/// API: [ChoThueNgoaiApi] (`/api/host/rooms/{id}/cho-thue-ngoai`).
///
/// Mọi ô ĐỀU không bắt buộc: chủ nhà thường bấm khi đang đứng ở hành lang vừa
/// giao chìa khoá. Thiếu giá thì lấy giá phòng đang rao, thiếu tên thì ghi
/// "Khách thuê ngoài app", thiếu ngày thì tính từ hôm nay — khai thêm lúc nào
/// cũng được ở Hồ sơ phòng. Bắt điền đủ form ở bước này là chủ nhà bỏ qua luôn,
/// và phòng đã cho thuê vẫn nằm trên chợ.
class HopThoaiChoThueNgoai extends StatefulWidget {
  const HopThoaiChoThueNgoai({
    super.key,
    required this.roomId,
    required this.maPhong,
    this.giaPhong,
    this.api = const ChoThueNgoaiApi(),
  });

  final int roomId;
  final String maPhong;

  /// Giá phòng đang rao — điền sẵn để khỏi gõ lại con số app đã biết.
  final double? giaPhong;
  final ChoThueNgoaiApi api;

  @override
  State<HopThoaiChoThueNgoai> createState() => _HopThoaiChoThueNgoaiState();
}

class _HopThoaiChoThueNgoaiState extends State<HopThoaiChoThueNgoai> {
  late final _ten = TextEditingController();
  late final _sdt = TextEditingController();
  late final _gia = TextEditingController(
    text: (widget.giaPhong ?? 0) > 0 ? widget.giaPhong!.toStringAsFixed(0) : '',
  );
  late final _coc = TextEditingController();
  late final _ghiChu = TextEditingController();

  late DateTime _batDau = DateTime.now();
  int _soThang = 12;
  int _ngayThanhToan = 5;
  bool _dangLuu = false;
  String? _loi;

  @override
  void dispose() {
    _ten.dispose();
    _sdt.dispose();
    _gia.dispose();
    _coc.dispose();
    _ghiChu.dispose();
    super.dispose();
  }

  String get _ngayISO =>
      '${_batDau.year}-${_hai(_batDau.month)}-${_hai(_batDau.day)}';

  static String _hai(int n) => n.toString().padLeft(2, '0');

  Future<void> _chonNgay() async {
    final n = DateTime.now();
    final ra = await showDatePicker(
      context: context,
      initialDate: _batDau,
      // Cho lùi một năm: chủ nhà thường đánh dấu sau khi khách đã ở được ít lâu.
      firstDate: DateTime(n.year - 1),
      lastDate: DateTime(n.year + 2),
    );
    if (ra != null) setState(() => _batDau = ra);
  }

  Future<void> _luu() async {
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    try {
      final kq = await widget.api.danhDau(
        widget.roomId,
        tenKhach: _ten.text.trim(),
        sdt: _sdt.text.trim(),
        ngayBatDau: _ngayISO,
        soThang: _soThang,
        giaThue: double.tryParse(_gia.text.trim()),
        cocDaThu: double.tryParse(_coc.text.trim()),
        ngayThanhToan: _ngayThanhToan,
        ghiChu: _ghiChu.text.trim().isEmpty ? null : _ghiChu.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, kq);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangLuu = false;
        _loi = e is ApiException ? e.message : 'Không đánh dấu được. Thử lại sau.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
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
                const Icon(Icons.handshake_outlined, color: HD.accent),
                const SizedBox(width: HD.s8),
                Expanded(
                  child: Text(
                    'Đã cho thuê ngoài app · ${widget.maPhong}',
                    style: HD.bodyBold(size: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Text(
              'Phòng sẽ chuyển sang ĐANG THUÊ và mọi tin đang rao của phòng này '
              'đóng lại — kể cả tin do sale đăng. Khách thuê không cần cài app.',
              style: HD.body(size: 12, color: HD.inkSoft),
            ),
            const SizedBox(height: HD.s12),
            _o(_ten, 'Tên khách thuê', goiY: 'Bỏ trống = "Khách thuê ngoài app"'),
            const SizedBox(height: HD.s8),
            _o(_sdt, 'Số điện thoại', kieu: TextInputType.phone, goiY: 'Không bắt buộc'),
            const SizedBox(height: HD.s8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: const ValueKey('ctn-ngay'),
                    onTap: _chonNgay,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Bắt đầu thuê',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(
                        '${_hai(_batDau.day)}/${_hai(_batDau.month)}/${_batDau.year}',
                        style: HD.body(size: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: HD.s8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: const ValueKey('ctn-so-thang'),
                    initialValue: _soThang,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Thuê trong',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final t in const [3, 6, 12, 24, 36])
                        DropdownMenuItem(value: t, child: Text('$t tháng')),
                    ],
                    onChanged: (v) => setState(() => _soThang = v ?? 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: HD.s8),
            _o(
              _gia,
              'Tiền thuê (đ/tháng)',
              kieu: TextInputType.number,
              chiSo: true,
              goiY: (widget.giaPhong ?? 0) > 0
                  ? 'Giá đang rao ${PriceFormat.full(widget.giaPhong!)}'
                  : 'Bắt buộc — phòng chưa có giá',
            ),
            const SizedBox(height: HD.s8),
            Row(
              children: [
                Expanded(
                  child: _o(
                    _coc,
                    'Cọc đã thu (đ)',
                    kieu: TextInputType.number,
                    chiSo: true,
                    goiY: 'Không bắt buộc',
                  ),
                ),
                const SizedBox(width: HD.s8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: const ValueKey('ctn-ngay-thu'),
                    initialValue: _ngayThanhToan,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Thu tiền ngày',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final d in const [1, 5, 10, 15, 20, 25])
                        DropdownMenuItem(value: d, child: Text('Ngày $d')),
                    ],
                    onChanged: (v) => setState(() => _ngayThanhToan = v ?? 5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: HD.s8),
            _o(_ghiChu, 'Ghi chú', goiY: 'VD: thuê qua Facebook, chưa làm giấy tờ'),
            if (_loi != null) ...[
              const SizedBox(height: HD.s8),
              Text(_loi!, style: HD.body(size: 13, color: HD.negative)),
            ],
            const SizedBox(height: HD.s12),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                key: const ValueKey('ctn-luu'),
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
                label: Text(_dangLuu ? 'Đang lưu…' : 'Đánh dấu đã cho thuê'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

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
      hintStyle: HD.body(size: 12, color: HD.inkMuted),
      border: const OutlineInputBorder(),
      isDense: true,
    ),
  );
}
