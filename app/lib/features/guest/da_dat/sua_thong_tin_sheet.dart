import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_booking/core/theme/design_tokens.dart';

/// SỬA THÔNG TIN đơn đặt phòng / lịch hẹn — một tấm dùng chung (16/09/2026).
///
/// Chỉ trả những trường ĐÃ ĐỔI: server ghi lịch sử theo đúng các trường gửi
/// lên, gửi cả trường không đổi là lịch sử toàn dòng "A → A".
class ThongTinSua {
  const ThongTinSua({
    this.ten,
    this.sdt,
    this.so,
    this.ghiChu,
    this.hinhThuc,
  });

  final String? ten;
  final String? sdt;
  final int? so;
  final String? ghiChu;
  final String? hinhThuc;

  bool get trong =>
      ten == null && sdt == null && so == null && ghiChu == null && hinhThuc == null;
}

Future<ThongTinSua?> moSuaThongTin(
  BuildContext context, {
  required String ten,
  required String sdt,
  required int so,
  required int soToiDa,
  required String nhanSo,
  required String ghiChu,
  required String nhanGhiChu,
  String? hinhThuc,
}) => showModalBottomSheet<ThongTinSua>(
  context: context,
  isScrollControlled: true,
  // Màn gọi nằm trong Navigator của TAB — không lên gốc thì thanh dưới đè nút lưu.
  useRootNavigator: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => _SheetSua(
    ten: ten,
    sdt: sdt,
    so: so,
    soToiDa: soToiDa,
    nhanSo: nhanSo,
    ghiChu: ghiChu,
    nhanGhiChu: nhanGhiChu,
    hinhThuc: hinhThuc,
  ),
);

class _SheetSua extends StatefulWidget {
  const _SheetSua({
    required this.ten,
    required this.sdt,
    required this.so,
    required this.soToiDa,
    required this.nhanSo,
    required this.ghiChu,
    required this.nhanGhiChu,
    this.hinhThuc,
  });

  final String ten;
  final String sdt;
  final int so;
  final int soToiDa;
  final String nhanSo;
  final String ghiChu;
  final String nhanGhiChu;
  final String? hinhThuc;

  @override
  State<_SheetSua> createState() => _SheetSuaState();
}

class _SheetSuaState extends State<_SheetSua> {
  late final _ten = TextEditingController(text: widget.ten);
  late final _sdt = TextEditingController(text: widget.sdt);
  late final _ghiChu = TextEditingController(text: widget.ghiChu);
  late int _so = widget.so.clamp(1, widget.soToiDa);
  late String? _hinhThuc = widget.hinhThuc;
  String? _loi;

  @override
  void dispose() {
    _ten.dispose();
    _sdt.dispose();
    _ghiChu.dispose();
    super.dispose();
  }

  ThongTinSua get _doi {
    String? neu(String moi, String cu) => moi.trim() == cu.trim() ? null : moi.trim();
    return ThongTinSua(
      ten: neu(_ten.text, widget.ten),
      sdt: neu(_sdt.text, widget.sdt),
      so: _so == widget.so ? null : _so,
      ghiChu: neu(_ghiChu.text, widget.ghiChu),
      hinhThuc: _hinhThuc == widget.hinhThuc ? null : _hinhThuc,
    );
  }

  void _luu() {
    if (_ten.text.trim().length < 2) {
      setState(() => _loi = 'Họ tên quá ngắn');
      return;
    }
    final so = _sdt.text.replaceAll(RegExp(r'\D'), '');
    if (so.length < 9 || so.length > 11) {
      setState(() => _loi = 'Số điện thoại chưa đúng');
      return;
    }
    Navigator.of(context).pop(_doi);
  }

  @override
  Widget build(BuildContext context) {
    final coDoi = !_doi.trong;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Sửa thông tin', style: HD.bodyBold(size: 18)),
                  ),
                  IconButton(
                    key: const Key('sua-dong'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: HD.inkMuted),
                  ),
                ],
              ),
              Text(
                'Sale và chủ nhà được báo ngay; mọi thay đổi được ghi vào lịch sử.',
                style: HD.body(size: 12.5, color: HD.inkMuted),
              ),
              const SizedBox(height: 14),
              _nhan('Họ và tên'),
              _o(const Key('sua-ten'), _ten, Icons.badge_outlined),
              const SizedBox(height: 10),
              _nhan('Số điện thoại'),
              _o(
                const Key('sua-sdt'),
                _sdt,
                Icons.phone_iphone,
                kieu: TextInputType.phone,
                dinhDang: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +.]'))],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(widget.nhanSo, style: HD.bodyBold(size: 13)),
                  ),
                  _nutDem(const Key('sua-bot'), Icons.remove,
                      _so > 1 ? () => setState(() => _so--) : null),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '$_so',
                      key: const Key('sua-so'),
                      textAlign: TextAlign.center,
                      style: HD.bodyBold(size: 16),
                    ),
                  ),
                  _nutDem(const Key('sua-them'), Icons.add,
                      _so < widget.soToiDa ? () => setState(() => _so++) : null),
                ],
              ),
              if (widget.hinhThuc != null) ...[
                const SizedBox(height: 12),
                _nhan('Hình thức xem'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (ma, nhan) in const [
                      ('truc_tiep', 'Xem trực tiếp'),
                      ('video', 'Qua video call'),
                    ])
                      ChoiceChip(
                        key: Key('sua-hinh-thuc-$ma'),
                        label: Text(nhan),
                        selected: _hinhThuc == ma,
                        onSelected: (_) => setState(() => _hinhThuc = ma),
                        selectedColor: HD.accentTint,
                        showCheckmark: false,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _nhan(widget.nhanGhiChu),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  key: const Key('sua-ghi-chu'),
                  controller: _ghiChu,
                  maxLines: 2,
                  maxLength: 300,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    counterText: '',
                  ),
                ),
              ),
              if (_loi != null) ...[
                const SizedBox(height: 8),
                Text(_loi!, style: HD.body(size: 12.5, color: HD.negative)),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 50,
                child: FilledButton(
                  key: const Key('sua-luu'),
                  onPressed: coDoi ? _luu : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: HD.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: HD.bodyBold(size: 15),
                  ),
                  child: Text(coDoi ? 'Lưu thay đổi' : 'Chưa có thay đổi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nhan(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(s, style: HD.bodyBold(size: 12.5, color: HD.ink)),
  );

  Widget _o(
    Key khoa,
    TextEditingController c,
    IconData icon, {
    TextInputType? kieu,
    List<TextInputFormatter>? dinhDang,
  }) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F3FF),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: HD.inkMuted),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            key: khoa,
            controller: c,
            keyboardType: kieu,
            inputFormatters: dinhDang,
            onChanged: (_) => setState(() => _loi = null),
            style: HD.bodyBold(size: 14),
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _nutDem(Key khoa, IconData icon, VoidCallback? onTap) => InkWell(
    key: khoa,
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 16, color: onTap == null ? HD.hairlineStrong : HD.ink),
    ),
  );
}
