import 'package:flutter/material.dart';

import 'package:house_booking/core/theme/design_tokens.dart';

/// Nút "Sửa" nhỏ đặt CẠNH từng khối nội dung của chính chủ.
///
/// Vì sao là chip cạnh khối chứ không phải một màn "Sửa hồ sơ" gom hết: người
/// bán cần thấy ĐÚNG thứ khách thấy trong lúc sửa. Một danh sách ô nhập tách
/// rời buộc họ phải tự hình dung kết quả, và đó là lúc bio dài quá khổ hay ảnh
/// lệch khung lọt ra ngoài mà không ai biết.
///
/// Trang công khai của người khác thì KHÔNG bao giờ vẽ chip này — nơi gọi
/// truyền `null` cho callback là chip biến mất.
class DsEditChip extends StatelessWidget {
  const DsEditChip({required this.tooltip, required this.onTap, super.key});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HD.rPill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: HD.s8, vertical: 3),
          decoration: BoxDecoration(
            color: HD.accentTint,
            borderRadius: BorderRadius.circular(HD.rPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_outlined, size: 13, color: HD.accent),
              const SizedBox(width: 4),
              Text('Sửa', style: HD.bodyBold(size: 11.5, color: HD.accent)),
            ],
          ),
        ),
      ),
    );
  }
}
