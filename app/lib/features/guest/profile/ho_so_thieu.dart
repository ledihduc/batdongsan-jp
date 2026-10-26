import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/user_model.dart';

/// Hồ sơ người bán còn THIẾU những gì — và thẻ nhắc điền ở tab Cá nhân.
///
/// Vì sao cần: mọi tài khoản mới đều là `account_type='sale'`
/// (`auth_router.py` — register ghi thẳng `account_type="sale"`), tức là ai đăng
/// ký xong cũng có ngay một trang bán hàng. Nhưng form đăng ký chỉ lấy tên,
/// email, mật khẩu; SĐT thì để tuỳ chọn. Kết quả là trang mới lập trống trơn:
/// không ảnh, không giới thiệu, khách xem không biết người này mạnh khu nào —
/// mà chủ tài khoản thì không có gì nhắc họ điền.
///
/// Tính bằng dữ liệu ĐÃ CÓ trong `UserModel`, không gọi thêm API: thẻ nhắc nằm
/// ở đầu tab Cá nhân, thêm một vòng mạng ở đó là thêm một nhịp trang nhảy.
@immutable
class HoSoThieu {
  const HoSoThieu({
    required this.thieuAnh,
    required this.thieuGioiThieu,
    required this.thieuSoDienThoai,
  });

  /// Đọc từ tài khoản hiện tại. `null` (chưa đăng nhập) coi như không thiếu gì —
  /// khách vãng lai không có hồ sơ để mà hoàn thiện.
  factory HoSoThieu.tu(UserModel? u) {
    if (u == null) {
      return const HoSoThieu(
        thieuAnh: false,
        thieuGioiThieu: false,
        thieuSoDienThoai: false,
      );
    }
    return HoSoThieu(
      thieuAnh: u.avatarPath.trim().isEmpty,
      // Ngưỡng 20 ký tự chứ không phải "khác rỗng": một dòng "ok" hay "abc"
      // vẫn để khách xem trang mù tịt y như bỏ trống, nhưng lại làm thẻ nhắc
      // biến mất nên không ai sửa nữa.
      thieuGioiThieu: (u.bio ?? '').trim().length < _toiThieuGioiThieu,
      thieuSoDienThoai: u.phone.trim().isEmpty,
    );
  }

  /// Độ dài tối thiểu để coi phần giới thiệu là "đã viết".
  static const int _toiThieuGioiThieu = 20;

  final bool thieuAnh;
  final bool thieuGioiThieu;
  final bool thieuSoDienThoai;

  /// Tổng số mục hồ sơ được theo dõi.
  static const int tongSoMuc = 3;

  int get soMucThieu =>
      (thieuAnh ? 1 : 0) + (thieuGioiThieu ? 1 : 0) + (thieuSoDienThoai ? 1 : 0);

  int get soMucXong => tongSoMuc - soMucThieu;

  bool get daXong => soMucThieu == 0;

  /// 0..1 — để vẽ thanh tiến độ.
  double get tiLe => soMucXong / tongSoMuc;

  /// Tên các mục còn thiếu, theo thứ tự ưu tiên nhắc.
  List<String> get tenMucThieu => [
    if (thieuSoDienThoai) 'Số điện thoại',
    if (thieuGioiThieu) 'Giới thiệu',
    if (thieuAnh) 'Ảnh đại diện',
  ];

  @override
  bool operator ==(Object other) =>
      other is HoSoThieu &&
      other.thieuAnh == thieuAnh &&
      other.thieuGioiThieu == thieuGioiThieu &&
      other.thieuSoDienThoai == thieuSoDienThoai;

  @override
  int get hashCode => Object.hash(thieuAnh, thieuGioiThieu, thieuSoDienThoai);
}

/// Thẻ "Hoàn thiện hồ sơ" ở đầu tab Cá nhân. Tự ẩn khi không còn thiếu gì.
///
/// Nói THIẾU GÌ và THIẾU VÌ SAO, không chỉ một thanh phần trăm: "hồ sơ 33%"
/// không cho biết phải bấm vào đâu, còn "Số điện thoại · Giới thiệu"
/// thì có.
class TheHoanThienHoSo extends StatelessWidget {
  const TheHoanThienHoSo({super.key, required this.thieu, required this.onNhan});

  final HoSoThieu thieu;
  final VoidCallback onNhan;

  @override
  Widget build(BuildContext context) {
    if (thieu.daXong) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(HD.s16, HD.s12, HD.s16, 0),
      child: Material(
        color: HD.accentTint,
        borderRadius: BorderRadius.circular(HD.r12),
        child: InkWell(
          onTap: onNhan,
          borderRadius: BorderRadius.circular(HD.r12),
          child: Padding(
            padding: const EdgeInsets.all(HD.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 20,
                      color: HD.accent,
                    ),
                    const SizedBox(width: HD.s8),
                    Expanded(
                      child: Text(
                        'Hoàn thiện hồ sơ',
                        style: HD.bodyBold(size: 15, color: HD.accentDeep),
                      ),
                    ),
                    Text(
                      '${thieu.soMucXong}/${HoSoThieu.tongSoMuc}',
                      style: HD.bodyBold(size: 13, color: HD.accent),
                    ),
                    const SizedBox(width: HD.s4),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: HD.accent,
                    ),
                  ],
                ),
                const SizedBox(height: HD.s8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: thieu.tiLe,
                    minHeight: 5,
                    backgroundColor: Colors.white,
                    valueColor: const AlwaysStoppedAnimation(HD.accent),
                  ),
                ),
                const SizedBox(height: HD.s8),
                Text(
                  'Còn thiếu: ${thieu.tenMucThieu.join(' · ')}',
                  style: HD.body(size: 12.5, color: HD.inkSoft),
                ),
                const SizedBox(height: HD.s4),
                Text(
                  'Khách xem trang bạn sẽ thấy một hồ sơ trống và bỏ qua.',
                  style: HD.body(size: 12, color: HD.inkMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
