import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/api_client.dart';
import 'package:house_booking/data/services/ho_so_ngan_han_api.dart';

/// MỞ CA THUÊ cho khách vãng lai — người đứng ngay ở quầy, không đặt trước.
///
/// Route: không — `showModalBottomSheet` từ màn Hồ sơ phòng ngắn hạn.
/// API: [HoSoNganHanApi.themCa] (`POST /api/host/rooms/{id}/ca-thue`).
///
/// Trước đây app chỉ tạo được đơn THEO NGÀY, nên phòng bán theo giờ không có
/// đường ghi khách vãng lai — phần lớn doanh thu của mô hình này đi qua đó.
class HopThoaiThemCa extends StatefulWidget {
  const HopThoaiThemCa({
    super.key,
    required this.roomId,
    required this.maPhong,
    this.giaGio,
    this.giaQuaDem,
    this.giaNgay,
    this.api = const HoSoNganHanApi(),
  });

  final int roomId;
  final String maPhong;
  final double? giaGio;
  final double? giaQuaDem;
  final double? giaNgay;
  final HoSoNganHanApi api;

  @override
  State<HopThoaiThemCa> createState() => _HopThoaiThemCaState();
}

class _HopThoaiThemCaState extends State<HopThoaiThemCa> {
  late final _ten = TextEditingController();
  late final _sdt = TextEditingController();
  late final _ghiChu = TextEditingController();

  late String _kieu = _kieuDauTien();
  int _soLuong = 2;
  bool _dangLuu = false;
  String? _loi;

  /// Chỉ mời những hình thức phòng ĐÃ khai giá — mở ca theo giờ cho phòng chưa
  /// có giá giờ thì server từ chối, và người dùng không hiểu vì sao.
  String _kieuDauTien() {
    if (widget.giaGio != null) return 'theo_gio';
    if (widget.giaQuaDem != null) return 'qua_dem';
    return 'theo_ngay';
  }

  List<({String ma, String nhan, double? gia, String donVi})> get _kieuCo => [
    if (widget.giaGio != null)
      (ma: 'theo_gio', nhan: 'Theo giờ', gia: widget.giaGio, donVi: 'giờ'),
    if (widget.giaQuaDem != null)
      (ma: 'qua_dem', nhan: 'Qua đêm', gia: widget.giaQuaDem, donVi: 'đêm'),
    if (widget.giaNgay != null)
      (ma: 'theo_ngay', nhan: 'Theo ngày', gia: widget.giaNgay, donVi: 'ngày'),
  ];

  double? get _donGia => _kieuCo.where((k) => k.ma == _kieu).firstOrNull?.gia;

  int get _soDonVi => _kieu == 'qua_dem' ? 1 : _soLuong;

  @override
  void dispose() {
    _ten.dispose();
    _sdt.dispose();
    _ghiChu.dispose();
    super.dispose();
  }

  Future<void> _luu() async {
    if (_ten.text.trim().isEmpty) {
      setState(() => _loi = 'Nhập tên khách để còn biết ai đang ở');
      return;
    }
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    try {
      final ca = await widget.api.themCa(
        widget.roomId,
        ten: _ten.text.trim(),
        sdt: _sdt.text.trim(),
        kieu: _kieu,
        soLuong: _soDonVi,
        ghiChu: _ghiChu.text.trim().isEmpty ? null : _ghiChu.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, ca);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dangLuu = false;
        _loi = e is ApiException ? e.message : 'Không mở được ca. Thử lại sau.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gia = _donGia;
    final tong = gia == null ? null : gia * _soDonVi;
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
                  const Icon(Icons.person_add_alt, color: HD.accent),
                  const SizedBox(width: HD.s8),
                  Expanded(
                    child: Text(
                      'Mở ca thuê · ${widget.maPhong}',
                      style: HD.bodyBold(size: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              if (_kieuCo.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: HD.s12),
                  child: Text(
                    'Phòng chưa khai giá giờ / đêm / ngày nào. Bấm "Sửa giá" ở '
                    'đầu màn để khai trước đã.',
                    style: HD.body(size: 13, color: HD.negative),
                  ),
                )
              else ...[
                Wrap(
                  spacing: HD.s8,
                  children: [
                    for (final k in _kieuCo)
                      ChoiceChip(
                        key: ValueKey('ca-${k.ma}'),
                        label: Text('${k.nhan} · ${PriceFormat.compact(k.gia!)}'),
                        selected: _kieu == k.ma,
                        onSelected: (_) => setState(() => _kieu = k.ma),
                      ),
                  ],
                ),
                const SizedBox(height: HD.s12),
                _o(_ten, 'Tên khách', goiY: 'Bắt buộc — để biết ai đang trong phòng'),
                const SizedBox(height: HD.s8),
                _o(_sdt, 'Số điện thoại', kieu: TextInputType.phone, goiY: 'Không bắt buộc'),
                const SizedBox(height: HD.s12),
                if (_kieu == 'qua_dem')
                  Container(
                    padding: const EdgeInsets.all(HD.s12),
                    decoration: BoxDecoration(
                      color: HD.paper,
                      borderRadius: BorderRadius.circular(HD.r12),
                    ),
                    child: Text(
                      'Ca qua đêm theo khung cố định 21:00 → 09:00 hôm sau.',
                      style: HD.body(size: 12, color: HD.inkSoft),
                    ),
                  )
                else
                  Row(
                    children: [
                      Text(
                        _kieu == 'theo_gio' ? 'Số giờ' : 'Số ngày',
                        style: HD.bodyBold(size: 13),
                      ),
                      const Spacer(),
                      IconButton(
                        key: const ValueKey('ca-giam'),
                        onPressed: _soLuong <= 1
                            ? null
                            : () => setState(() => _soLuong--),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$_soLuong', style: HD.bodyBold(size: 16)),
                      IconButton(
                        key: const ValueKey('ca-tang'),
                        onPressed: _soLuong >= (_kieu == 'theo_gio' ? 24 : 30)
                            ? null
                            : () => setState(() => _soLuong++),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                const SizedBox(height: HD.s8),
                _o(_ghiChu, 'Ghi chú', goiY: 'VD: khách quen, xin thêm khăn'),
                if (tong != null) ...[
                  const SizedBox(height: HD.s12),
                  Container(
                    padding: const EdgeInsets.all(HD.s12),
                    decoration: BoxDecoration(
                      color: HD.accentTint,
                      borderRadius: BorderRadius.circular(HD.r12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tạm tính ca này',
                            style: HD.body(size: 13, color: HD.inkSoft),
                          ),
                        ),
                        Text(
                          PriceFormat.full(tong),
                          key: const ValueKey('ca-tam-tinh'),
                          style: HD.bodyBold(size: 16, color: HD.accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              if (_loi != null) ...[
                const SizedBox(height: HD.s8),
                Text(_loi!, style: HD.body(size: 13, color: HD.negative)),
              ],
              const SizedBox(height: HD.s12),
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  key: const ValueKey('ca-luu'),
                  onPressed: _dangLuu || _kieuCo.isEmpty ? null : _luu,
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
                  label: Text(_dangLuu ? 'Đang mở ca…' : 'Mở ca thuê'),
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
    String? goiY,
  }) => TextField(
    controller: c,
    keyboardType: kieu,
    inputFormatters: kieu == TextInputType.phone
        ? [FilteringTextInputFormatter.digitsOnly]
        : null,
    decoration: InputDecoration(
      labelText: nhan,
      hintText: goiY,
      hintStyle: HD.body(size: 12, color: HD.inkMuted),
      border: const OutlineInputBorder(),
      isDense: true,
    ),
  );
}
