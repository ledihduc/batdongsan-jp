import 'package:flutter/material.dart';

import 'package:house_booking/core/config/brand.dart';
import 'package:house_booking/core/theme/design_tokens.dart';

/// Logo Vua Nhà dạng ẢNH.
///
/// Trước đây "logo" trong app hoàn toàn là CHỮ (`Brand.logoPart1/2` dựng bằng
/// [HD.masthead]), còn tệp logo thật thì nằm trong `assets/` mà không widget
/// nào đọc — mở app lên không thấy logo ở đâu cả. Widget này là chỗ duy nhất
/// nạp ảnh logo, để lần sau đổi nhận diện chỉ phải sửa một nơi.
///
/// Hai bản dẫn xuất, dùng vào hai việc khác nhau:
/// * [BrandLogo.full] — logo đầy đủ (thẻ + ghim + chữ "VUA NHÀ" + tagline).
///   Chỉ cho màn lớn có chỗ thở: splash, đăng nhập, đăng ký.
/// * [BrandLogo.mark] — CHỈ phần ghim. Dùng ở chỗ chật (AppBar, drawer) và
///   luôn đứng cạnh wordmark chữ sẵn có. Đặt bản đầy đủ vào đó thì vừa in tên
///   thương hiệu hai lần, vừa không đọc nổi vì cao chưa tới 24px.
///
/// Ảnh do `tools/gen_brand_icons.py` sinh từ `tools/icon_src/logo_master.png`
/// — đừng thay tay trong `assets/branding/`, chạy lại script.
class BrandLogo extends StatelessWidget {
  /// Logo đầy đủ. [size] là cạnh của khung vuông chứa ảnh.
  const BrandLogo.full({super.key, this.size = 96})
    : _asset = _assetFull,
      _onDark = false;

  /// Chỉ ghim. Bật [onDark] khi đặt trên nền màu đậm (header đỏ thương hiệu).
  const BrandLogo.mark({super.key, this.size = 24, bool onDark = false})
    : _asset = _assetMark,
      _onDark = onDark;

  static const String _assetFull = 'assets/branding/logo_full.png';
  static const String _assetMark = 'assets/branding/logo_mark.png';

  /// Màu nền thẻ trong logo gốc — dùng lót khi ghim nằm trên nền đậm.
  static const Color _cream = Color(0xFFFAF5F1);

  final double size;
  final String _asset;
  final bool _onDark;

  @override
  Widget build(BuildContext context) {
    // Ảnh ghim đã có sẵn ~10% lề trong. Ở bản onDark còn lồng thêm ô cream,
    // nên để hệ số 0.72 thì hai lớp lề cộng dồn và ghim co lại thành một chấm
    // ở cỡ 22-26px. 0.84 giữ ô cream vẫn thấy được mà ghim đủ to.
    final double imageSize = _onDark ? size * 0.84 : size;
    final Widget image = Image.asset(
      _asset,
      width: imageSize,
      height: imageSize,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: Brand.name,
      // Logo là trang trí: thiếu ảnh thì chừa chỗ trống, KHÔNG được ném lỗi
      // làm vỡ cả màn hình (splash và đăng nhập là hai màn không có đường lui).
      errorBuilder: (_, __, ___) =>
          SizedBox(width: imageSize, height: imageSize),
    );

    if (!_onDark) return image;

    // Ghim là đỏ mận + vàng; đặt thẳng lên nền đỏ thương hiệu thì chìm hẳn.
    // Lót một ô cream đúng màu thẻ trong logo gốc để tách nền.
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: image,
    );
  }
}
