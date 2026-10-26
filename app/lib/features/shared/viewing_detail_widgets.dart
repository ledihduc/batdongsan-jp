import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:house_booking/core/config/api_config.dart';
import 'package:house_booking/core/utils/formatters.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/lich_xem_api.dart';

/// Các khối giao diện dùng chung cho ba vai trò trong luồng xem nhà dài hạn.
/// Giữ cùng một ngôn ngữ hình ảnh như bản thiết kế: đầu trang đỏ, nội dung
/// trắng, đường viền mảnh và CTA đỏ nổi bật.
class ViewingDetailAppBar extends AppBar {
  ViewingDetailAppBar({super.key, required String title, List<Widget>? actions})
    : super(
        backgroundColor: HD.accent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
        title: Text(title, style: HD.bodyBold(size: 17, color: Colors.white)),
        actions: actions,
      );
}

class ViewingPropertyCard extends StatelessWidget {
  const ViewingPropertyCard({
    super.key,
    required this.phieu,
    this.compact = false,
  });

  final PhieuHen phieu;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tin = phieu.tin;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(HD.r8),
          child: SizedBox(
            width: compact ? 76 : 94,
            height: compact ? 64 : 82,
            child: tin.anh == null || tin.anh!.isEmpty
                ? const ColoredBox(
                    color: HD.paperSunken,
                    child: Icon(Icons.apartment_rounded, color: HD.inkMuted),
                  )
                : CachedNetworkImage(
                    imageUrl: tin.anh!.startsWith('http')
                        ? tin.anh!
                        : '${ApiConfig.baseUrl}${tin.anh}',
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        const ColoredBox(color: HD.paperSunken),
                    errorWidget: (_, _, _) => const ColoredBox(
                      color: HD.paperSunken,
                      child: Icon(Icons.apartment_rounded, color: HD.inkMuted),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: HD.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tin.tieuDe.isEmpty ? 'Căn phòng đang xem' : tin.tieuDe,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: HD.bodyBold(size: compact ? 13.5 : 15),
              ),
              const SizedBox(height: 2),
              Text(phieu.ma, style: HD.body(size: 12.5, color: HD.inkMuted)),
              if (tin.diaChi.isNotEmpty)
                Text(
                  tin.diaChi,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HD.body(size: 12.5, color: HD.inkMuted),
                ),
              if ((tin.gia ?? 0) > 0) ...[
                const SizedBox(height: 3),
                Text(
                  '${PriceFormat.full(tin.gia!)}/${tin.donVi}',
                  style: HD.bodyBold(size: 14, color: HD.accent),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class ViewingStatusBox extends StatelessWidget {
  const ViewingStatusBox({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.color = HD.warning,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(HD.s12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(HD.r12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 29, color: color),
        const SizedBox(width: HD.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: HD.bodyBold(size: 14, color: color)),
              const SizedBox(height: 2),
              Text(message, style: HD.body(size: 12.5, color: HD.inkSoft)),
            ],
          ),
        ),
      ],
    ),
  );
}

class ViewingInfoRow extends StatelessWidget {
  const ViewingInfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.trailing,
  });

  final IconData icon;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 21, color: const Color(0xFF173B75)),
        const SizedBox(width: HD.s12),
        Expanded(
          child: Text(text, style: HD.body(size: 13.5, color: HD.ink)),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class ViewingSectionCard extends StatelessWidget {
  const ViewingSectionCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(HD.s12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(HD.r12),
      border: Border.all(color: HD.hairline),
    ),
    child: child,
  );
}

ButtonStyle viewingPrimaryButton() => FilledButton.styleFrom(
  backgroundColor: HD.accent,
  foregroundColor: Colors.white,
  minimumSize: const Size.fromHeight(50),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HD.r8)),
  textStyle: HD.bodyBold(size: 14.5),
);

ButtonStyle viewingOutlineButton({Color color = HD.accent}) =>
    OutlinedButton.styleFrom(
      foregroundColor: color,
      minimumSize: const Size.fromHeight(48),
      side: BorderSide(color: color),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HD.r8)),
      textStyle: HD.bodyBold(size: 13.5),
    );

String viewingPrettyDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final thu = d.weekday == DateTime.sunday
      ? 'Chủ nhật'
      : 'Thứ ${d.weekday + 1}';
  return '$thu, ${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class ViewingJourneyProgress extends StatelessWidget {
  const ViewingJourneyProgress({
    super.key,
    required this.labels,
    required this.current,
    this.icons = const [],
  });

  final List<String> labels;
  final List<IconData> icons;
  final int current;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < labels.length; i++) ...[
        Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i <= current ? HD.accent : HD.hairline,
                      ),
                    ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: i < current
                          ? HD.positive
                          : i == current
                          ? HD.accent
                          : HD.paperSunken,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      i < current
                          ? Icons.check
                          : i < icons.length
                          ? icons[i]
                          : Icons.circle,
                      size: 18,
                      color: i <= current ? Colors.white : HD.inkMuted,
                    ),
                  ),
                  if (i < labels.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i < current ? HD.accent : HD.hairline,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                labels[i],
                textAlign: TextAlign.center,
                maxLines: 2,
                style: i == current
                    ? HD.bodyBold(size: 10.5, color: HD.accent)
                    : HD.body(size: 10.5, color: HD.inkMuted),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}
