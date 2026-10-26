import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/data/services/building_public_api.dart';
import 'package:house_booking/features/guest/sale/nhan_toa_tu_chu_nha_screen.dart';

/// Dải DỰ ÁN trên trang cá nhân sale — thanh trượt ngang.
///
/// Đọc từ `buildings` (dự án thật, có phòng và giá), không phải `album cũ`
/// nữa: album chỉ gom BÀI ĐĂNG, còn cho thuê thì một bài có thể ứng với nhiều
/// phòng giá khác nhau. Bấm vào mở `/du-an/:id` — bảng giá từng phòng.
///
/// Vì sao trượt ngang: lưới 2 cột ăn chiều dọc theo số dự án, sáu dự án là ba
/// hàng, đẩy toàn bộ feed bài đăng xuống dưới màn hình.
class ProjectStrip extends StatefulWidget {
  const ProjectStrip({required this.ownerId, super.key, this.api, this.onSua});

  final int ownerId;

  /// Chính chủ đang xem → mọc nút "Sửa" cạnh tiêu đề. null = khách xem.
  final VoidCallback? onSua;

  /// Chỉ để test bơm dữ liệu giả.
  final BuildingPublicApi? api;

  @override
  State<ProjectStrip> createState() => _ProjectStripState();
}

class _ProjectStripState extends State<ProjectStrip> {
  BuildingPublicApi get _api => widget.api ?? const BuildingPublicApi();

  static const _rongThe = 168.0;
  static const _caoAnh = 116.0;

  List<DuAnTomTat> _ds = const [];
  bool _dangTai = true;

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    final ds = await _api.cuaNguoi(widget.ownerId);
    if (mounted)
      setState(() {
        _ds = ds;
        _dangTai = false;
      });
  }

  /// Mở màn nhập mã mời của chủ nhà, nhận xong thì nạp lại dải dự án — toà
  /// vừa nhận phải hiện ra ngay, không bắt người ta thoát vào lại.
  Future<void> _nhanToa(BuildContext context) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NhanToaTuChuNhaScreen()),
    );
    if (ok == true && mounted) {
      setState(() => _dangTai = true);
      await _nap();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dangTai) return const SizedBox.shrink();
    // KHÁCH xem trang người khác mà chưa có dự án nào → ẩn hẳn, không để tiêu
    // đề treo trên khoảng trắng.
    //
    // CHỦ TRANG thì ngược lại: phải thấy lời mời tạo. Trước đây dải này ẩn luôn
    // với cả hai, nên người bán mới lập tài khoản mở trang mình ra KHÔNG HỀ
    // BIẾT là dựng được dự án — lối vào duy nhất nằm sau nút ⚙ rồi mới tới mục
    // "Dự án & phòng đang quản lý". Đúng cái bẫy trạng thái rỗng: chỗ trống
    // nhất của màn hình lại là chỗ duy nhất không nói gì.
    if (_ds.isEmpty) {
      if (widget.onSua == null) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_moiTaoDuAn(context), _moiNhapMa(context)],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: HD.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HD.s16),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.apartment_rounded,
                        size: 16,
                        color: HD.accent,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Dự án BĐS',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HD.bodyBold(size: 15),
                        ),
                      ),
                      const SizedBox(width: HD.s8),
                      Text('${_ds.length}', style: HD.caption()),
                    ],
                  ),
                ),
                if (widget.onSua != null) ...[
                  // Chủ nhà cũng tự dựng toà rồi gửi sale mã mời — chiều ngược
                  // của mã bàn giao. Không có lối vào ở đây thì sale cầm mã mà
                  // không biết gõ vào đâu.
                  IconButton(
                    tooltip: 'Nhận toà từ chủ nhà',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.vpn_key_outlined, size: 19),
                    color: HD.accent,
                    onPressed: () => _nhanToa(context),
                  ),
                  DsEditChip(tooltip: 'Quản lý dự án', onTap: widget.onSua!),
                ],
              ],
            ),
          ),
          const SizedBox(height: HD.s12),
          SizedBox(
            height: _caoAnh + 66,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              // Lề nằm TRONG danh sách để thẻ cuối trượt sát mép phải — thẻ bị
              // cắt ngang ở mép là tín hiệu "còn nữa, kéo tiếp".
              padding: const EdgeInsets.symmetric(horizontal: HD.s16),
              itemCount: _ds.length,
              separatorBuilder: (_, _) => const SizedBox(width: HD.s12),
              itemBuilder: (_, i) => _the(_ds[i]),
            ),
          ),
        ],
      ),
    );
  }

  /// Lời mời dựng dự án đầu tiên — CHỈ hiện trên trang của chính mình.
  ///
  /// Cố ý KHÔNG dùng khung nét đứt kiểu "ô trống chờ điền": dải này nằm giữa
  /// một trang hồ sơ đã có nội dung, một ô rỗng ở đó đọc thành "chỗ này hỏng".
  /// Dùng thẻ đặc, nói được VÌ SAO nên tạo, và nói rõ là KHÔNG cần tin đăng
  /// trước — vì thứ tự đó chính là chỗ người bán hay tưởng là bắt buộc.
  Widget _moiTaoDuAn(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(HD.s16, HD.s24, HD.s16, 0),
      child: Material(
        color: HD.paperRaised,
        borderRadius: BorderRadius.circular(HD.r12),
        child: InkWell(
          onTap: widget.onSua,
          borderRadius: BorderRadius.circular(HD.r12),
          child: Container(
            padding: const EdgeInsets.all(HD.s16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(HD.r12),
              border: Border.all(color: HD.hairline),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: HD.accentTint,
                    borderRadius: BorderRadius.circular(HD.r8),
                  ),
                  child: const Icon(
                    Icons.apartment_rounded,
                    size: 22,
                    color: HD.accent,
                  ),
                ),
                const SizedBox(width: HD.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dựng dự án BĐS', style: HD.bodyBold(size: 15)),
                      const SizedBox(height: 3),
                      Text(
                        'Gom phòng theo toà, mỗi phòng một giá — khách xem được '
                        'bảng giá cả toà thay vì từng tin rời.',
                        style: HD.body(size: 12.5, color: HD.inkSoft),
                      ),
                      const SizedBox(height: HD.s8),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 14,
                            color: HD.positive,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Chưa có tin đăng nào vẫn tạo được',
                              style: HD.body(size: 12, color: HD.inkMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: HD.s8),
                const Icon(Icons.chevron_right, color: HD.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Sale CHƯA có dự án nào nhưng đang cầm mã của chủ nhà.
  ///
  /// Lời mời "Dựng dự án" ở trên là đường duy nhất hiện ra lúc trang trống —
  /// nếu nó là đường duy nhất thì người cầm mã sẽ đi dựng một toà TRÙNG, còn
  /// toà thật của chủ nhà nằm lại đó không ai nhận.
  Widget _moiNhapMa(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(HD.s16, HD.s8, HD.s16, 0),
    child: Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _nhanToa(context),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        icon: const Icon(Icons.vpn_key_outlined, size: 17),
        label: const Text('Đã có mã mời từ chủ nhà?'),
      ),
    ),
  );

  /// Ảnh nền của thẻ. Ưu tiên danh sách `anh` (gom từ ảnh các TIN đã gắn);
  /// `anhBia` chỉ là đường lùi cho dữ liệu cũ chưa có trường mới.
  static List<String> _anhCua(DuAnTomTat d) {
    if (d.anh.isNotEmpty) return d.anh;
    final b = d.anhBia;
    return (b == null || b.isEmpty) ? const [] : [b];
  }

  Widget _the(DuAnTomTat d) {
    return SizedBox(
      width: _rongThe,
      child: InkWell(
        onTap: () => context.push('/du-an/${d.id}'),
        borderRadius: BorderRadius.circular(HD.r12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(HD.r12),
              child: SizedBox(
                width: _rongThe,
                height: _caoAnh,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BangChuyenAnh(anh: _anhCua(d), memCacheWidth: 420),
                    // "Còn N phòng" là lý do khách bấm vào. Đặt đè lên ảnh vì
                    // khi quét ngang thì con số mới phân biệt được các thẻ.
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          // 0 phòng KHÔNG phải "hết hàng" — là chưa nhập phòng
                          // nào. Dùng chung nhãn đen "Hết phòng" cho cả hai là
                          // báo cho khách một tin sai, và báo cho chính chủ vừa
                          // tạo dự án rằng dự án của họ đã bán sạch.
                          color: d.soPhong == 0
                              ? HD.inkMuted
                              : d.soPhongTrong > 0
                              ? HD.accent
                              : const Color(0xCC000000),
                          borderRadius: BorderRadius.circular(HD.rPill),
                        ),
                        child: Text(
                          d.soPhong == 0
                              ? 'Đang cập nhật'
                              : d.soPhongTrong > 0
                              ? 'Còn ${d.soPhongTrong} phòng'
                              : 'Hết phòng',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              d.ten,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: HD.bodyBold(size: 13),
            ),
            if (d.giaTu != null)
              Text(
                'từ ${PriceFormat.compact(d.giaTu!)}/tháng',
                style: HD.body(size: 12, color: HD.accent),
              ),
          ],
        ),
      ),
    );
  }
}
