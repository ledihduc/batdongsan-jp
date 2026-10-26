import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/short_stay_api.dart';

/// Ba mức giá lưu trú ngắn hạn của một phòng: THEO GIỜ · QUA ĐÊM · THEO NGÀY.
///
/// Vì sao phải có màn này: `PUT /api/host/short-stays/rooms/{id}/rates` đã có
/// từ lúc dựng tính năng, nhưng **không nơi nào trong app gọi tới**. Hậu quả đo
/// được trên staging: 10 phòng đã bật kênh ngắn hạn mà `/api/short-stays/rooms`
/// trả về danh sách RỖNG — vì tìm kiếm ngắn hạn chỉ bày phòng đã khai ít nhất
/// một trong ba giá này, và chủ nhà không có cách nào khai.
///
/// Ba giá là ba SẢN PHẨM khác nhau, không phải ba cách viết một con số:
///
///     theo giờ   thuê 1–24 giờ nguyên, tính theo giờ
///     qua đêm    khung 21:00–09:00 hôm sau, một giá trọn gói
///     theo ngày  1–30 ngày, mỗi ngày 24 giờ
///
/// Bỏ trống một ô = KHÔNG bán hình thức đó. Cố ý cho bỏ trống: nhà nghỉ theo
/// giờ không nhận khách ở cả tuần, còn homestay thì ngược lại — ép khai đủ ba
/// là bắt người ta bịa ra một cái giá họ không định bán.
class HopThoaiGiaNganHan extends StatefulWidget {
  const HopThoaiGiaNganHan({
    super.key,
    required this.roomId,
    this.api = const ShortStayApi(),
    this.banDau = const {},
  });

  final int roomId;
  final ShortStayApi api;

  /// Giá đang có (từ `GET /api/host/short-stays/rooms`); rỗng = chưa khai.
  final Map<String, dynamic> banDau;

  @override
  State<HopThoaiGiaNganHan> createState() => _HopThoaiGiaNganHanState();
}

class _HopThoaiGiaNganHanState extends State<HopThoaiGiaNganHan> {
  late final _loai = TextEditingController(
    text: (widget.banDau['loai_phong'] as String?) ?? 'Phòng',
  );
  late final _gio = _o('gia_theo_gio');
  late final _dem = _o('gia_qua_dem');
  late final _ngay = _o('gia_theo_ngay');
  late final _huyGio = _o('huy_truoc_gio', mac: '1');
  late final _huyDem = _o('huy_truoc_dem', mac: '2');
  late final _huyNgay = _o('huy_truoc_ngay', mac: '12');

  bool _dangLuu = false;
  String? _loi;

  TextEditingController _o(String khoa, {String mac = ''}) {
    final v = widget.banDau[khoa];
    return TextEditingController(
      text: v == null ? mac : (v as num).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    for (final c in [_loai, _gio, _dem, _ngay, _huyGio, _huyDem, _huyNgay]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _so(TextEditingController c) => int.tryParse(c.text.trim());

  Future<void> _luu() async {
    final gio = _so(_gio);
    final dem = _so(_dem);
    final ngay = _so(_ngay);
    if (gio == null && dem == null && ngay == null) {
      // Server cũng chặn (`Rates.has_rate`), nhưng bắt ở đây thì người dùng
      // biết ngay thay vì bấm Lưu rồi mới nhận một câu lỗi chung chung.
      setState(() => _loi = 'Khai ít nhất một mức giá, nếu không phòng sẽ '
          'không hiện trong tìm kiếm ngắn hạn.');
      return;
    }
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    try {
      await widget.api.rates(widget.roomId, {
        'loai_phong': _loai.text.trim().isEmpty ? 'Phòng' : _loai.text.trim(),
        'gia_theo_gio': gio,
        'gia_qua_dem': dem,
        'gia_theo_ngay': ngay,
        'huy_truoc_gio': _so(_huyGio) ?? 1,
        'huy_truoc_dem': _so(_huyDem) ?? 2,
        'huy_truoc_ngay': _so(_huyNgay) ?? 12,
        'dang_bat': true,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _dangLuu = false;
          _loi = 'Không lưu được. $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Giá lưu trú ngắn hạn'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bỏ trống hình thức nào là không bán hình thức đó.',
              style: HD.body(size: 13, color: HD.inkSoft),
            ),
            const SizedBox(height: HD.s12),
            _hang(_loai, 'Tên loại phòng', so: false),
            const SizedBox(height: HD.s12),
            _muc(
              nhan: 'Theo giờ (đ/giờ)',
              mo: 'Thuê 1–24 giờ nguyên',
              gia: _gio,
              huy: _huyGio,
            ),
            _muc(
              nhan: 'Qua đêm (đ/đêm)',
              mo: '21:00 – 09:00 hôm sau',
              gia: _dem,
              huy: _huyDem,
            ),
            _muc(
              nhan: 'Theo ngày (đ/ngày)',
              mo: '1–30 ngày, mỗi ngày 24 giờ',
              gia: _ngay,
              huy: _huyNgay,
            ),
            if (_loi != null) ...[
              const SizedBox(height: HD.s8),
              Text(_loi!, style: HD.body(size: 13, color: HD.negative)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _dangLuu ? null : () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        TextButton(
          onPressed: _dangLuu ? null : _luu,
          child: Text(_dangLuu ? 'Đang lưu…' : 'Lưu'),
        ),
      ],
    );
  }

  Widget _muc({
    required String nhan,
    required String mo,
    required TextEditingController gia,
    required TextEditingController huy,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: HD.s12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nhan, style: HD.bodyBold(size: 13)),
        Text(mo, style: HD.body(size: 11, color: HD.inkMuted)),
        const SizedBox(height: HD.s4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _hang(gia, 'Giá')),
            const SizedBox(width: HD.s8),
            // Mốc huỷ miễn phí đi LIỀN với giá, không tách sang mục riêng:
            // hai thứ này luôn được quyết cùng lúc, giá càng rẻ thì cửa huỷ
            // càng hẹp.
            Expanded(flex: 2, child: _hang(huy, 'Huỷ trước (giờ)')),
          ],
        ),
      ],
    ),
  );

  Widget _hang(TextEditingController c, String nhan, {bool so = true}) =>
      TextField(
        controller: c,
        keyboardType: so ? TextInputType.number : TextInputType.text,
        inputFormatters: so ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(
          labelText: nhan,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      );
}
