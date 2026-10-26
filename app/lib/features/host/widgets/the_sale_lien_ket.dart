import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/sale_link_api.dart';
import 'package:house_booking/features/guest/sale/link_sale_screen.dart';

/// SALE ĐANG LIÊN KẾT — hiện ngay trên màn quản lý của chủ nhà.
///
/// Vì sao đặt ở đây chứ không chôn trong cài đặt: chủ nhà thường không tự tìm
/// khách. Người đưa họ vào hệ thống là sale — cũng chính là người họ gọi khi
/// phòng trống, khi cần đăng lại tin, khi khách hỏi khó. Số điện thoại đó phải
/// nằm ở màn họ mở hằng ngày, không phải sau ba lớp menu.
///
/// Chưa liên kết ai thì hiện lời mời nhập mã. Không vẽ thẻ rỗng: một ô trống
/// không giải thích được nó dùng để làm gì.
class TheSaleLienKet extends StatefulWidget {
  const TheSaleLienKet({super.key, this.api});

  /// Chỉ để test bơm API giả.
  final SaleLinkApi? api;

  @override
  State<TheSaleLienKet> createState() => _TheSaleLienKetState();
}

class _TheSaleLienKetState extends State<TheSaleLienKet> {
  SaleLinkApi get _api => widget.api ?? const SaleLinkApi();

  List<LienKet> _ds = const [];
  bool _dangTai = true;
  bool _loi = false;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    try {
      final ds = await _api.cuaToiBenChu();
      if (mounted) {
        setState(() {
          // Chỉ liên kết CÒN HIỆU LỰC. Liên kết đã ngắt giữ lại để tra lịch
          // sử, không phải để hiện như người đang phụ trách.
          _ds = ds.where((e) => e.trangThai == 'active').toList();
          _dangTai = false;
        });
      }
    } catch (_) {
      // Hỏng thì ẩn HẲN — đây là thẻ phụ, không được làm vỡ màn quản lý.
      //
      // Phải phân biệt "tải xong, rỗng" với "tải hỏng". Gộp hai cái làm một thì
      // lúc mất mạng, chủ nhà ĐANG CÓ sale lại thấy lời mời "Liên kết với sale"
      // — một câu sai, và mời họ làm lại việc đã làm rồi.
      if (mounted) {
        setState(() {
          _dangTai = false;
          _loi = true;
        });
      }
    }
  }

  Future<void> _moLienKet() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LinkSaleScreen()));
    if (mounted) _nap();
  }

  @override
  Widget build(BuildContext context) {
    if (_dangTai || _loi) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(HD.s16, 0, HD.s16, HD.s12),
      child: _ds.isEmpty ? _moiLienKet() : _dangCo(_ds),
    );
  }

  Widget _khung({required Widget con, VoidCallback? onTap}) => Material(
    color: HD.paperRaised,
    borderRadius: BorderRadius.circular(HD.r12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HD.r12),
      child: Container(
        padding: const EdgeInsets.all(HD.s12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HD.r12),
          border: Border.all(color: HD.hairline),
        ),
        child: con,
      ),
    ),
  );

  Widget _dangCo(List<LienKet> ds) => _khung(
    onTap: _moLienKet,
    con: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sale đang phối hợp',
          style: HD.body(size: 11.5, color: HD.inkMuted),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < ds.length; i++) ...[
          if (i > 0) const Divider(height: 16, color: HD.hairline),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: HD.accentTint,
                child: Text(
                  ds[i].tenDoiPhuong.isEmpty
                      ? '?'
                      : ds[i].tenDoiPhuong[0].toUpperCase(),
                  style: HD.bodyBold(color: HD.accent, size: 15),
                ),
              ),
              const SizedBox(width: HD.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ds[i].tenDoiPhuong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HD.bodyBold(size: 14.5),
                    ),
                    Text(
                      ds[i].buildingName ?? 'Chưa xác định toà nhà',
                      style: HD.caption(),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: HD.inkMuted),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Mỗi toà nhà có một sale phụ trách tất cả phòng.',
          style: HD.body(size: 12, color: HD.inkSoft),
        ),
      ],
    ),
  );

  Widget _moiLienKet() => _khung(
    onTap: _moLienKet,
    con: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: HD.accentTint,
            borderRadius: BorderRadius.circular(HD.r8),
          ),
          child: const Icon(Icons.link, size: 20, color: HD.accent),
        ),
        const SizedBox(width: HD.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Liên kết với sale', style: HD.bodyBold(size: 14.5)),
              const SizedBox(height: 2),
              Text(
                'Nhập mã của sale để họ giúp bạn đăng tin và tìm khách.',
                style: HD.body(size: 12, color: HD.inkSoft),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: HD.accent),
      ],
    ),
  );
}
