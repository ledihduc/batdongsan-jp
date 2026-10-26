import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';

/// Hai đường vào khi chủ nhà bấm "+ THÊM TOÀ NHÀ".
///
/// Vì sao phải hỏi: hai đường dẫn tới hai trạng thái khác hẳn nhau.
///
///  * **Có mã của sale** — sale đã dựng sẵn toà, dựng phòng, có khi đã đăng
///    tin. Chủ nhà nhập mã là NHẬN LẠI công việc đó, không phải gõ lại từ đầu.
///  * **Tự tạo mới** — chưa ai làm gì. Chủ nhà nhập tên, địa chỉ, rồi (nếu
///    muốn) sinh mã mời sale vào phụ trách.
///
/// Trước đây nút này chỉ có đường thứ hai, nên chủ nhà nào được sale đưa mã
/// cũng phải tự tạo một toà TRÙNG — và toà thật của sale nằm lại đó, mồ côi.
enum CachThemToa { nhapMa, tuTao }

Future<CachThemToa?> chonCachThemToa(BuildContext context) {
  return showModalBottomSheet<CachThemToa>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Material(
      color: HD.paper,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(HD.r12)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(HD.s16, HD.s16, HD.s16, HD.s8),
              child: Text('THÊM TOÀ NHÀ', style: HD.eyebrow(color: HD.accent)),
            ),
            _muc(
              ctx,
              icon: Icons.vpn_key_outlined,
              tieuDe: 'Tôi có mã từ sale',
              mota: 'Sale đã dựng sẵn toà và phòng — nhập mã để nhận về.',
              gia: CachThemToa.nhapMa,
            ),
            const Divider(height: 1, color: HD.hairline),
            _muc(
              ctx,
              icon: Icons.add_home_work_outlined,
              tieuDe: 'Tự tạo toà mới',
              mota: 'Nhập tên và địa chỉ. Mời sale sau bằng mã bạn tự tạo.',
              gia: CachThemToa.tuTao,
            ),
            const SizedBox(height: HD.s8),
          ],
        ),
      ),
    ),
  );
}

Widget _muc(
  BuildContext ctx, {
  required IconData icon,
  required String tieuDe,
  required String mota,
  required CachThemToa gia,
}) => ListTile(
  leading: Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: HD.accentTint,
      borderRadius: BorderRadius.circular(HD.r8),
    ),
    child: Icon(icon, color: HD.accent, size: 20),
  ),
  title: Text(tieuDe, style: HD.bodyBold(size: 15)),
  subtitle: Text(mota, style: HD.body(size: 12.5, color: HD.inkSoft)),
  trailing: const Icon(Icons.chevron_right, color: HD.inkMuted),
  onTap: () => Navigator.pop(ctx, gia),
);
