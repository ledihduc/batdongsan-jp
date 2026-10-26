import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/moi_sale_api.dart';
import 'package:house_booking/features/host/property/widgets/danh_sach_phong_xem_truoc.dart';

/// SALE nhập mã mời của CHỦ NHÀ để nhận phụ trách một toà.
///
/// Chiều ngược của `SaleCodeScreen` — nơi sale ĐƯA mã cho chủ nhà. Hai luồng
/// tồn tại song song vì ai chủ động cũng được:
///
///   sale dựng toà trước  → sale đưa mã bàn giao  → chủ nhà nhận quyền SỞ HỮU
///   chủ nhà dựng trước   → chủ nhà đưa mã mời    → sale nhận quyền PHỤ TRÁCH
///
/// Xem trước TRƯỚC khi nhận là bắt buộc: nhập tám ký tự rồi bấm mà không biết
/// mình sắp nhận toà nào, của ai, bao nhiêu phòng — đó là lúc người ta bỏ dở.
class NhanToaTuChuNhaScreen extends StatefulWidget {
  const NhanToaTuChuNhaScreen({super.key, this.api});

  final MoiSaleApi? api;

  @override
  State<NhanToaTuChuNhaScreen> createState() => _NhanToaTuChuNhaScreenState();
}

class _NhanToaTuChuNhaScreenState extends State<NhanToaTuChuNhaScreen> {
  MoiSaleApi get _api => widget.api ?? const MoiSaleApi();

  final _ma = TextEditingController();
  LoiMoiToa? _xemTruoc;
  String? _loi;
  bool _dangTai = false;
  bool _dangNhan = false;

  @override
  void dispose() {
    _ma.dispose();
    super.dispose();
  }

  String get _maSach => _ma.text.trim().toUpperCase();

  Future<void> _tra() async {
    if (_maSach.isEmpty) {
      setState(() => _loi = 'Nhập mã chủ nhà gửi cho bạn');
      return;
    }
    setState(() {
      _dangTai = true;
      _loi = null;
      _xemTruoc = null;
    });
    try {
      final d = await _api.xemTruoc(_maSach);
      if (mounted) setState(() => _xemTruoc = d);
    } catch (_) {
      // Một câu duy nhất cho MỌI lý do: mã sai, mã đã dùng, mã của người khác.
      // Nói rõ vế nào sai là biến ô này thành máy dò mã.
      //
      // Nhưng có kèm đường đi tiếp. Lý do trượt hay gặp nhất không phải gõ sai:
      // chủ nhà gửi nhầm mã BÀN GIAO (chiều ngược lại) vì hai mã trông giống
      // hệt nhau — tám ký tự, cùng bảng chữ. Câu này chỉ vào đúng chỗ lấy mã
      // đúng mà không tiết lộ mã họ vừa gõ là loại gì.
      if (mounted) {
        setState(
          () => _loi = 'Mã không đúng hoặc đã được dùng. Nhờ chủ nhà mở toà '
              'trong "Sổ toà nhà" rồi bấm "Mời sale phụ trách" để lấy mã.',
        );
      }
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  Future<void> _nhan() async {
    setState(() {
      _dangNhan = true;
      _loi = null;
    });
    try {
      final d = await _api.nhan(_maSach);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            d.soPhongNhan > 0
                ? 'Đã nhận "${d.ten}" — bạn phụ trách ${d.soPhongNhan} phòng.'
                : 'Đã nhận "${d.ten}".',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _loi = 'Không nhận được. Mã có thể vừa hết hiệu lực.');
    } finally {
      if (mounted) setState(() => _dangNhan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _xemTruoc;
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: const DsAppBar(
        eyebrow: 'Dự án',
        title: 'Nhận toà từ chủ nhà',
      ),
      body: ListView(
        padding: const EdgeInsets.all(HD.s16),
        children: [
          Text(
            'Chủ nhà tự dựng toà trên app rồi gửi bạn mã mời. Nhập mã để nhận '
            'phụ trách toà đó.',
            style: HD.body(size: 13.5, color: HD.inkSoft),
          ),
          const SizedBox(height: HD.s16),
          TextField(
            controller: _ma,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              // Mã chỉ có chữ HOA và số. Tự chuẩn hoá để người dùng gõ kiểu gì
              // cũng vào đúng, thay vì bị báo "mã sai" vì một chữ thường.
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
              LengthLimitingTextInputFormatter(8),
            ],
            style: HD.bodyBold(size: 20).copyWith(letterSpacing: 3),
            decoration: InputDecoration(
              labelText: 'Mã mời (8 ký tự)',
              errorText: _loi,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _tra(),
          ),
          const SizedBox(height: HD.s12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _dangTai ? null : _tra,
              child: Text(_dangTai ? 'Đang tra…' : 'Tra mã'),
            ),
          ),
          if (d != null) ...[
            const SizedBox(height: HD.s20),
            Container(
              padding: const EdgeInsets.all(HD.s16),
              decoration: BoxDecoration(
                color: HD.paperRaised,
                borderRadius: BorderRadius.circular(HD.r12),
                border: Border.all(color: HD.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BẠN SẮP NHẬN', style: HD.eyebrow(color: HD.accent)),
                  const SizedBox(height: HD.s8),
                  Text(d.ten, style: HD.bodyBold(size: 17)),
                  if (d.diaChi.isNotEmpty)
                    Text(
                      d.diaChi,
                      style: HD.body(size: 13, color: HD.inkMuted),
                    ),
                  const SizedBox(height: HD.s8),
                  Text(
                    '${d.soPhong} phòng · chủ nhà: ${d.chuTen}',
                    style: HD.body(size: 13, color: HD.inkSoft),
                  ),
                  // Toà đã có người phụ trách thì nói TRƯỚC: bạn vào ở cấp
                  // phòng, không thay được mặt tiền của người đang giữ.
                  if (d.daCoSale) ...[
                    const SizedBox(height: HD.s8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 15,
                          color: HD.warning,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Toà này đã có sale phụ trách. Bạn sẽ nhận các '
                            'phòng chưa ai quản lý.',
                            style: HD.body(size: 12.5, color: HD.inkSoft),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: HD.s12),
                  // Con số "N phòng" không đủ để quyết. Sale phải thấy mình sắp
                  // nhận HÀNG GÌ: bao nhiêu phòng còn trống, diện tích, giá chủ
                  // nhà đang để.
                  DanhSachPhongXemTruoc(phong: d.phong, conLai: d.conLai),
                ],
              ),
            ),
            const SizedBox(height: HD.s12),
            SizedBox(
              width: double.infinity,
              child: DsButton(
                label: _dangNhan ? 'Đang nhận…' : 'Nhận toà này',
                expand: true,
                onPressed: _dangNhan ? null : _nhan,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
