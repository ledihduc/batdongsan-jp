import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/theme/design_tokens.dart';

/// Đầu trang hồ sơ kiểu Facebook: ảnh bìa rộng, avatar tròn viền trắng **đè
/// lên mép dưới ảnh bìa**, rồi tên — dòng phụ — hàng nút.
///
/// Chi tiết dễ làm sai: avatar phải TRÀN RA NGOÀI khung ảnh bìa (dùng
/// [Stack] + [Positioned] với `bottom` âm và `clipBehavior: Clip.none`).
/// Nếu để bên trong, bố cục trông như một cái card thường chứ không phải hồ sơ.
class FbProfileHeader extends StatelessWidget {
  const FbProfileHeader({
    super.key,
    required this.name,
    this.avatarUrl,
    this.coverUrl,
    this.coverChild,
    this.subtitle,
    this.bio,
    this.badge,
    this.actions = const [],
    this.overlayActions = const [],
    this.onTapAvatar,
    this.onTapCover,
  });

  final String name;
  final String? avatarUrl;

  /// Ảnh bìa. Không có → dải màu nhấn nhạt, KHÔNG để trống xám.
  final String? coverUrl;

  /// Widget dựng THAY cho ảnh bìa. Có giá trị thì [coverUrl] bị bỏ qua.
  ///
  /// Mở ra để hồ sơ chủ nhà đặt bản đồ nhiệt tin đăng vào chỗ ảnh bìa mà không
  /// phải nhân bản cả khối đầu trang (avatar tràn xuống, nút nổi, badge…) sang
  /// một widget thứ hai — app đã có sẵn ba kiểu đầu trang hồ sơ khác nhau rồi.
  final Widget? coverChild;

  /// Dòng dưới tên (email, vai trò, số tin đăng…).
  final String? subtitle;

  final String? bio;

  /// Nhãn cạnh tên (vai trò, tick xác minh).
  final Widget? badge;

  /// Hàng nút dưới cùng — FB đặt "Chỉnh sửa trang cá nhân" ở đây.
  final List<Widget> actions;

  /// Nút NỔI ở góc phải-trên ảnh bìa (cài đặt, đăng xuất…). Dùng khi màn không
  /// có app bar riêng — gộp thanh tiêu đề vào bìa để lấy lại ~78px chiều cao.
  /// Mỗi phần tử nên là [FbCoverIconButton] để có nền tương phản trên ảnh.
  final List<Widget> overlayActions;

  final VoidCallback? onTapAvatar;
  final VoidCallback? onTapCover;

  static const double _cao = 150;
  static const double _avatar = 88;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: HD.paperRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: onTapCover,
                child: SizedBox(
                  height: _cao,
                  width: double.infinity,
                  child:
                      coverChild ??
                      (coverUrl != null && coverUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: coverUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, _) =>
                                  Container(color: HD.accentSoft),
                              errorWidget: (_, _, _) => const _BiaMacDinh(),
                            )
                          : const _BiaMacDinh()),
                ),
              ),
              if (overlayActions.isNotEmpty)
                Positioned(
                  top: 0,
                  right: 4,
                  child: SafeArea(
                    bottom: false,
                    child: Row(children: overlayActions),
                  ),
                ),
              Positioned(
                left: 16,
                bottom: -_avatar / 2,
                child: GestureDetector(
                  onTap: onTapAvatar,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: HD.paperRaised,
                      shape: BoxShape.circle,
                    ),
                    child: _Avatar(
                      url: avatarUrl,
                      ten: name,
                      kichThuoc: _avatar,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: _avatar / 2 + 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: HD.ink,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (badge != null) ...[const SizedBox(width: 6), badge!],
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(fontSize: 15, color: HD.inkMuted),
                    ),
                  ),
                if (bio != null && bio!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      bio!,
                      style: const TextStyle(
                        fontSize: 15,
                        color: HD.inkSoft,
                        height: 1.35,
                      ),
                    ),
                  ),
                if (actions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Row(
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(child: actions[i]),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút icon đặt ĐÈ lên ảnh bìa. Ảnh bìa do người dùng tải lên nên sáng-tối
/// không đoán trước được → icon trắng trên đĩa tối mờ, đọc được ở cả hai nền.
class FbCoverIconButton extends StatelessWidget {
  const FbCoverIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.mauIcon,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// Mặc định trắng. Truyền [HD.negative] cho hành động phá huỷ (đăng xuất).
  final Color? mauIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: HD.ink.withOpacity(0.35),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Tooltip(
            message: tooltip,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, size: 20, color: mauIcon ?? HD.paperRaised),
            ),
          ),
        ),
      ),
    );
  }
}

class _BiaMacDinh extends StatelessWidget {
  const _BiaMacDinh();

  @override
  Widget build(BuildContext context) =>
      Container(decoration: const BoxDecoration(gradient: HD.accentGradient));
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url, required this.ten, required this.kichThuoc});

  final String? url;
  final String ten;
  final double kichThuoc;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          width: kichThuoc,
          height: kichThuoc,
          fit: BoxFit.cover,
          placeholder: (_, _) => _chuCai(),
          errorWidget: (_, _, _) => _chuCai(),
        ),
      );
    }
    return _chuCai();
  }

  Widget _chuCai() {
    final c = ten.trim().isEmpty
        ? '?'
        : ten.trim().characters.first.toUpperCase();
    return Container(
      width: kichThuoc,
      height: kichThuoc,
      decoration: const BoxDecoration(
        color: HD.accentSoft,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        c,
        style: TextStyle(
          fontSize: kichThuoc * 0.42,
          fontWeight: FontWeight.w700,
          color: HD.accentDeep,
        ),
      ),
    );
  }
}

/// Nút chính kiểu FB (nền xanh, chữ trắng) — "Chỉnh sửa trang cá nhân".
class FbPrimaryButton extends StatelessWidget {
  const FbPrimaryButton({super.key, required this.nhan, this.icon, this.onTap});

  final String nhan;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onTap,
    icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
    label: Text(nhan, maxLines: 1, overflow: TextOverflow.ellipsis),
    style: FilledButton.styleFrom(
      // accentDeep chứ không accent: chữ trắng trên #1877F2 chỉ đạt 3.6:1,
      // chưa đủ WCAG AA cho chữ nhỏ.
      backgroundColor: HD.accentDeep,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  );
}

/// Nút phụ kiểu FB (nền xám #E4E6EB, chữ đen).
class FbSecondaryButton extends StatelessWidget {
  const FbSecondaryButton({
    super.key,
    required this.nhan,
    this.icon,
    this.onTap,
  });

  final String nhan;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onTap,
    icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
    label: Text(nhan, maxLines: 1, overflow: TextOverflow.ellipsis),
    style: FilledButton.styleFrom(
      backgroundColor: HD.paperSunken,
      foregroundColor: HD.ink,
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  );
}
