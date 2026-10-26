import 'package:flutter/material.dart';

import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/core/widgets/ds_button.dart';
import 'package:house_booking/data/services/location_input_service.dart';

/// Chọn ĐỊA GIỚI HÀNH CHÍNH — dùng chung cho MỌI form có địa chỉ.
///
/// **Cơ cấu 2 CẤP (từ 01/07/2025): 34 Tỉnh/Thành → Phường/Xã.**
/// Không còn cấp quận/huyện. Widget này cố ý KHÔNG có ô "Quận/Huyện" — dựng lại
/// một cấp đã bị bãi bỏ chỉ đẻ ra dữ liệu không đối chiếu được với bất cứ danh
/// mục nhà nước nào.
///
/// **Vì sao phải CHỌN chứ không NHẬP TAY:** cùng một nơi, người này gõ "TP.HCM",
/// người kia "Tp Hồ Chí Minh", người nữa "Sài Gòn" — lọc theo khu vực lập tức
/// vỡ, và không cách nào gộp lại được về sau. Nguồn duy nhất là
/// `/api/master/provinces` + `/api/master/wards` (`vn_admin_2025.json`, 34 tỉnh
/// ~3321 phường/xã).
///
/// Chỉ ĐỊA CHỈ CHI TIẾT (số nhà, tên đường) mới để người dùng gõ tự do — phần
/// đó không có danh mục nào để đối chiếu.
///
/// Dùng khay tìm kiếm chứ không dùng `DropdownButtonFormField`: TP.HCM có hơn
/// 160 phường/xã, một danh sách xổ dài chừng đó buộc người dùng phải CUỘN TÌM
/// thay vì gõ hai chữ là ra.
class ChonDiaBan extends StatefulWidget {
  const ChonDiaBan({
    required this.onChanged,
    super.key,
    this.tinh,
    this.phuong,
    this.hienPhuongXa = true,
    this.nhanTinh = 'Tỉnh/Thành phố',
    this.nhanPhuong = 'Phường/Xã',
    this.service,
  });

  /// Báo ra ngoài mỗi khi đổi. [phuong] là null khi chưa chọn hoặc khi
  /// [hienPhuongXa] = false.
  final void Function(AdminUnit? tinh, AdminUnit? phuong) onChanged;

  /// Giá trị đang có (sửa bản ghi cũ, hoặc vừa reverse-geocode từ bản đồ).
  final AdminUnit? tinh;
  final AdminUnit? phuong;

  /// Tắt khi form chỉ cần cấp tỉnh (khảo sát quan tâm, lọc theo khu vực…).
  final bool hienPhuongXa;

  final String nhanTinh;
  final String nhanPhuong;

  /// Chỉ để test bơm dịch vụ giả.
  final LocationInputService? service;

  @override
  State<ChonDiaBan> createState() => _ChonDiaBanState();
}

class _ChonDiaBanState extends State<ChonDiaBan> {
  LocationInputService get _svc => widget.service ?? const LocationInputService();

  List<AdminUnit> _tinhDs = const [];
  List<AdminUnit> _phuongDs = const [];

  AdminUnit? _tinh;
  AdminUnit? _phuong;

  bool _dangTaiTinh = true;
  bool _dangTaiPhuong = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _tinh = widget.tinh;
    _phuong = widget.phuong;
    _napTinh();
  }

  @override
  void didUpdateWidget(ChonDiaBan cu) {
    super.didUpdateWidget(cu);
    // Bản đồ reverse-geocode xong đẩy tỉnh/phường vào từ ngoài — phải nhận,
    // nếu không người dùng ghim được điểm trên bản đồ mà ô vẫn trống.
    if (widget.tinh?.code != cu.tinh?.code) {
      _tinh = widget.tinh;
      _phuong = widget.phuong;
      if (_tinh != null) _napPhuong(_tinh!.code);
    } else if (widget.phuong?.code != cu.phuong?.code) {
      _phuong = widget.phuong;
    }
  }

  Future<void> _napTinh() async {
    setState(() {
      _dangTaiTinh = true;
      _loi = null;
    });
    try {
      final ds = await _svc.provinces();
      if (!mounted) return;
      setState(() {
        _tinhDs = ds;
        _dangTaiTinh = false;
      });
      if (_tinh != null) _napPhuong(_tinh!.code);
    } catch (_) {
      if (!mounted) return;
      // KHÔNG lặng lẽ rơi về ô nhập tay khi API hỏng: làm thế là mở lại đúng
      // cái cửa dữ liệu bẩn mà widget này sinh ra để đóng. Báo lỗi + cho thử
      // lại, người dùng biết mình đang chờ cái gì.
      setState(() {
        _dangTaiTinh = false;
        _loi = 'Không tải được danh mục tỉnh/thành';
      });
    }
  }

  Future<void> _napPhuong(String maTinh) async {
    if (!widget.hienPhuongXa) return;
    setState(() => _dangTaiPhuong = true);
    try {
      final ds = await _svc.wards(maTinh);
      if (!mounted) return;
      setState(() {
        _phuongDs = ds;
        _dangTaiPhuong = false;
      });
    } catch (_) {
      if (mounted) setState(() => _dangTaiPhuong = false);
    }
  }

  void _datTinh(AdminUnit t) {
    setState(() {
      _tinh = t;
      // Đổi tỉnh thì phường cũ chắc chắn sai — xoá luôn thay vì để nó nằm lại
      // trông như đã chọn đúng.
      _phuong = null;
      _phuongDs = const [];
    });
    widget.onChanged(_tinh, null);
    _napPhuong(t.code);
  }

  void _datPhuong(AdminUnit p) {
    setState(() => _phuong = p);
    widget.onChanged(_tinh, _phuong);
  }

  @override
  Widget build(BuildContext context) {
    if (_loi != null) {
      return Container(
        padding: const EdgeInsets.all(HD.s12),
        decoration: BoxDecoration(
          color: HD.accentTint,
          borderRadius: BorderRadius.circular(HD.r8),
          border: Border.all(color: HD.accentSoft),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_off_outlined, size: 18, color: HD.accent),
            const SizedBox(width: HD.s8),
            Expanded(child: Text(_loi!, style: HD.body(size: 13))),
            DsButton(
              label: 'Thử lại',
              size: DsButtonSize.compact,
              variant: DsButtonVariant.secondary,
              onPressed: _napTinh,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _o(
          nhan: widget.nhanTinh,
          giaTri: _tinh?.name,
          dangTai: _dangTaiTinh,
          onTap: _dangTaiTinh
              ? null
              : () => _moKhay(
                  tieuDe: 'Chọn tỉnh/thành phố',
                  ds: _tinhDs,
                  dangChon: _tinh,
                  onChon: _datTinh,
                ),
        ),
        if (widget.hienPhuongXa) ...[
          const SizedBox(height: HD.s12),
          _o(
            nhan: widget.nhanPhuong,
            giaTri: _phuong?.name,
            dangTai: _dangTaiPhuong,
            // Khoá cho tới khi có tỉnh: danh sách phường/xã CHỈ tồn tại trong
            // phạm vi một tỉnh, mở ra khi chưa chọn tỉnh thì nó rỗng và người
            // dùng tưởng hỏng.
            goiY: _tinh == null ? 'Chọn tỉnh/thành trước' : null,
            onTap: _tinh == null || _dangTaiPhuong
                ? null
                : () => _moKhay(
                    tieuDe: 'Chọn phường/xã',
                    ds: _phuongDs,
                    dangChon: _phuong,
                    onChon: _datPhuong,
                  ),
          ),
        ],
      ],
    );
  }

  Widget _o({
    required String nhan,
    required String? giaTri,
    required bool dangTai,
    VoidCallback? onTap,
    String? goiY,
  }) {
    final coGiaTri = giaTri != null && giaTri.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HD.r8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: nhan,
          isDense: true,
          border: const OutlineInputBorder(),
          enabled: onTap != null,
          suffixIcon: dangTai
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          coGiaTri ? giaTri : (goiY ?? 'Chọn'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: HD.body(color: coGiaTri ? HD.ink : HD.inkMuted),
        ),
      ),
    );
  }

  Future<void> _moKhay({
    required String tieuDe,
    required List<AdminUnit> ds,
    required AdminUnit? dangChon,
    required void Function(AdminUnit) onChon,
  }) async {
    final chon = await showModalBottomSheet<AdminUnit>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _KhayChon(tieuDe: tieuDe, ds: ds, dangChon: dangChon),
    );
    if (chon != null) onChon(chon);
  }
}

/// Khay chọn có ô tìm — bỏ dấu khi so khớp để gõ "ho chi minh" vẫn ra
/// "Tp Hồ Chí Minh"; trên bàn phím điện thoại gõ có dấu tốn gấp đôi thao tác.
class _KhayChon extends StatefulWidget {
  const _KhayChon({required this.tieuDe, required this.ds, this.dangChon});

  final String tieuDe;
  final List<AdminUnit> ds;
  final AdminUnit? dangChon;

  @override
  State<_KhayChon> createState() => _KhayChonState();
}

class _KhayChonState extends State<_KhayChon> {
  String _tim = '';

  static const _dau = 'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệ'
      'ìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ';
  static const _khongDau = 'aaaaaaaaaaaaaaaaaeeeeeeeeeee'
      'iiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

  static String _bo(String s) {
    final b = StringBuffer();
    for (final c in s.toLowerCase().runes) {
      final ch = String.fromCharCode(c);
      final i = _dau.indexOf(ch);
      b.write(i >= 0 ? _khongDau[i] : ch);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final tim = _bo(_tim.trim());
    final loc = tim.isEmpty
        ? widget.ds
        : widget.ds.where((e) => _bo(e.name).contains(tim)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      expand: false,
      // Material chứ không phải Container-có-màu: ListTile bên trong cần một
      // Material tổ tiên để vẽ hiệu ứng chạm. Nền tô bằng DecoratedBox thì
      // splash bị vẽ ĐÈ lên trên nền, nhìn như lỗi hiển thị.
      builder: (_, scroll) => Material(
        color: HD.paperRaised,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(HD.r12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: HD.s8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: HD.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: HD.s12),
            Text(widget.tieuDe, style: HD.bodyBold(size: 17)),
            Padding(
              padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s16, HD.s8),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _tim = v),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Tìm nhanh…',
                  prefixIcon: Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: loc.isEmpty
                  ? Center(
                      child: Text(
                        'Không có kết quả cho "$_tim"',
                        style: HD.body(color: HD.inkMuted),
                      ),
                    )
                  : ListView.separated(
                      controller: scroll,
                      itemCount: loc.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: HD.hairline),
                      itemBuilder: (_, i) {
                        final e = loc[i];
                        final chon = e.code == widget.dangChon?.code;
                        return ListTile(
                          dense: true,
                          title: Text(
                            e.name,
                            style: chon
                                ? HD.bodyBold(color: HD.accent)
                                : HD.body(),
                          ),
                          trailing: chon
                              ? const Icon(Icons.check, color: HD.accent, size: 20)
                              : null,
                          onTap: () => Navigator.pop(context, e),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
