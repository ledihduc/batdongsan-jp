import 'package:flutter/material.dart';

import 'package:house_booking/core/theme/design_tokens.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/data/models/phong_xem_truoc.dart';

/// Bảng phòng trong bản xem trước, để ĐỐI CHIẾU với toà ngoài đời trước khi bấm
/// nhận.
///
/// Vì sao cần: hai màn nhập mã trước đây chỉ hiện tên toà, địa chỉ và **số**
/// phòng. Ba thứ đó không kiểm được gì — sale gõ nhầm diện tích, đánh thiếu một
/// tầng, hay dựng nhầm sang toà bên cạnh thì chủ nhà cũng chỉ phát hiện SAU khi
/// đã nhận, mà gỡ ra lại là chuyện khác hẳn.
class DanhSachPhongXemTruoc extends StatelessWidget {
  const DanhSachPhongXemTruoc({
    super.key,
    required this.phong,
    this.conLai = 0,
  });

  final List<PhongXemTruoc> phong;

  /// Số phòng bị cắt bớt ở phía máy chủ (toà lớn).
  final int conLai;

  @override
  Widget build(BuildContext context) {
    // Toà 0 phòng là trạng thái HỢP LỆ (dựng dự án trước, gắn tin sau) — nói
    // thẳng ra thay vì để một khoảng trống trông như đang tải hỏng.
    if (phong.isEmpty) {
      return Text(
        'Toà này chưa có phòng nào.',
        style: HD.body(size: 13, color: HD.inkMuted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Danh sách phòng', style: HD.eyebrow(color: HD.inkMuted)),
        const SizedBox(height: HD.s8),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: HD.hairline),
            borderRadius: BorderRadius.circular(HD.r8),
          ),
          child: Column(
            children: [
              for (var i = 0; i < phong.length; i++)
                _Hang(p: phong[i], dauTien: i == 0),
            ],
          ),
        ),
        if (conLai > 0) ...[
          const SizedBox(height: HD.s4),
          Text('và $conLai phòng nữa', style: HD.caption()),
        ],
      ],
    );
  }
}

class _Hang extends StatelessWidget {
  const _Hang({required this.p, required this.dauTien});

  final PhongXemTruoc p;
  final bool dauTien;

  @override
  Widget build(BuildContext context) {
    final mo = <String>[
      if (p.dienTich != null && p.dienTich! > 0)
        '${p.dienTich!.toStringAsFixed(0)}m²',
      if (p.sucChua > 0) '${p.sucChua} người',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HD.s12,
        vertical: HD.s8,
      ),
      decoration: BoxDecoration(
        border: dauTien
            ? null
            : const Border(top: BorderSide(color: HD.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.ma, style: HD.bodyBold(size: 13)),
                if (mo.isNotEmpty)
                  Text(mo, style: HD.body(size: 11, color: HD.inkMuted)),
              ],
            ),
          ),
          if (!p.conTrong)
            Padding(
              padding: const EdgeInsets.only(right: HD.s8),
              child: Text('Đã thuê', style: HD.caption()),
            ),
          if (p.gia > 0)
            Text(PriceFormat.compact(p.gia), style: HD.bodyBold(size: 13)),
        ],
      ),
    );
  }
}
