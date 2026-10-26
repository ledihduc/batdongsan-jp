import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Semantic status family — drives palette across pills, dots, banners.
enum DsStatusTone { positive, warning, negative, neutral, info, accent }

/// Status pill — small caps eyebrow label inside a tinted, hairline-bordered
/// pill. Use for invoice status, contract state, sync state, KPI deltas.
class DsStatusPill extends StatelessWidget {
  const DsStatusPill({
    super.key,
    required this.label,
    this.tone = DsStatusTone.neutral,
    this.icon,
    this.dense = false,
  });

  final String label;
  final DsStatusTone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(tone);
    final vPad = dense ? 2.0 : 4.0;
    final hPad = dense ? 6.0 : HD.s8;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(HD.r4),
        border: Border.all(color: palette.fg.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 10 : 12, color: palette.fg),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: HD.eyebrow(color: palette.fg).copyWith(
              fontSize: dense ? 9 : 10,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single dot — for inline status indicators (legend, list-row left edge).
class DsStatusDot extends StatelessWidget {
  const DsStatusDot({super.key, required this.tone, this.size = 8});
  final DsStatusTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.fg,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Filter chip — neutral background, hairline border, toggles to accentTint
/// when [selected]. Use for facet filters, segmented filters in a row.
class DsFilterChip extends StatelessWidget {
  const DsFilterChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HD.accentTint : HD.paperRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HD.r4),
        side: BorderSide(color: selected ? HD.accent : HD.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HD.r4),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HD.s12,
            vertical: HD.s8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: selected ? HD.accent : HD.inkSoft),
                const SizedBox(width: HD.s4),
              ],
              Text(
                label,
                style: HD.body(
                  size: 13,
                  color: selected ? HD.accentDeep : HD.ink,
                ).copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Palette {
  const _Palette(this.fg, this.bg);
  final Color fg;
  final Color bg;
}

_Palette _paletteFor(DsStatusTone tone) {
  switch (tone) {
    case DsStatusTone.positive:
      return const _Palette(HD.positive, HD.positiveTint);
    case DsStatusTone.warning:
      return const _Palette(HD.warning, HD.warningTint);
    case DsStatusTone.negative:
      return const _Palette(HD.negative, HD.negativeTint);
    case DsStatusTone.info:
      return const _Palette(HD.ink, HD.paperSunken);
    case DsStatusTone.accent:
      return const _Palette(HD.accentDeep, HD.accentSoft);
    case DsStatusTone.neutral:
      return const _Palette(HD.neutral, HD.neutralTint);
  }
}

/// Chip LỌC dùng chung cho mọi bộ lọc dạng hàng ngang trong app.
///
/// Có widget này vì trước đây mỗi màn tự vẽ chip một kiểu: chỗ là hộp vuông
/// viền xám chữ 11.5px, chỗ là pill nền hồng nhạt kèm icon và dấu tích. Cùng
/// một hành động "lọc" mà ba hình dạng khác nhau thì người dùng phải học lại ở
/// mỗi màn, và không màn nào trông thuộc về cùng một sản phẩm.
///
/// Quy ước:
///   • CHƯA chọn — nền trắng, viền mảnh, chữ đậm vừa. Trung tính, không hút mắt
///     khỏi nội dung phía dưới.
///   • ĐANG chọn — nền đặc màu [selectedColor], chữ trắng. MỘT tín hiệu duy
///     nhất; không kèm dấu tích, vì nền đặc đã nói đủ và dấu tích chỉ làm chip
///     dài thêm.
class DsChoiceChip extends StatelessWidget {
  const DsChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.selectedColor = HD.accent,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Chỉ nên dùng khi hàng có ÍT mục và các icon khác nhau rõ. Mười hai loại
  /// hình với mười hai icon na ná nhau thì icon không giúp phân biệt, chỉ làm
  /// mỗi chip dài thêm và người dùng phải cuộn nhiều hơn.
  final IconData? icon;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedColor : HD.paperRaised,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? selectedColor : HD.hairline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 16, color: selected ? Colors.white : HD.inkMuted),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : HD.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
