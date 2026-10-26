import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:house_booking/data/models/house_model.dart';
import '../host_dashboard_tokens.dart';
import 'hd_status_pill.dart';

/// A house-listing row, formatted as a newspaper classified-ad entry.
/// No card chrome — relies on hairline at the bottom for separation.
///
/// Layout: thumbnail (left), title + meta (centre), status + numeric index (right).
class HDListingRow extends StatelessWidget {
  const HDListingRow({
    super.key,
    required this.house,
    required this.index,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onCloseOneUnit,
    this.onSchedule,
  });

  final HouseModel house;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onCloseOneUnit;
  final VoidCallback? onSchedule;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      highlightColor: HD.paperRaised,
      splashColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: HD.s20, vertical: HD.s16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: HD.hairline)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumbnail(image: house.images.isEmpty ? null : house.images.first, label: house.title),
                const SizedBox(width: HD.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '№ ${index.toString().padLeft(2, '0')}',
                            style: HD.tabular(color: HD.inkMuted, size: 10),
                          ),
                          const SizedBox(width: HD.s8),
                          HDStatusPill.house(house.status),
                        ],
                      ),
                      const SizedBox(height: HD.s8),
                      Text(
                        house.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: HD.bodyBold(size: 15),
                      ),
                      const SizedBox(height: HD.s4),
                      Text(
                        '${house.district} · ${house.city}',
                        style: HD.body(size: 12, color: HD.inkMuted),
                      ),
                      if (house.status == 'rejected' &&
                          (house.rejectionReason?.isNotEmpty ?? false)) ...[
                        const SizedBox(height: HD.s8),
                        Container(
                          padding: const EdgeInsets.all(HD.s8),
                          decoration: BoxDecoration(
                            color: const Color(0x14D32F2F),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline,
                                  size: 14, color: Color(0xFFD32F2F)),
                              const SizedBox(width: HD.s4),
                              Expanded(
                                child: Text(
                                  'Lý do từ chối: ${house.rejectionReason}',
                                  style: HD.body(
                                      size: 12, color: const Color(0xFFD32F2F)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (house.isMultiUnit) ...[
                        const SizedBox(height: HD.s8),
                        _UnitInventory(house: house),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: HD.s12),
            _ActionRail(
              onEdit: onEdit,
              onDelete: onDelete,
              onSchedule: onSchedule,
              onCloseOneUnit: house.isMultiUnit && !house.isFull
                  ? onCloseOneUnit
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.image, this.label});
  final String? image;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: HD.paperRaised,
        border: Border.all(color: HD.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: image != null
          ? Semantics(
              label: label,
              child: CachedNetworkImage(
                imageUrl: image!,
                fit: BoxFit.cover,
                memCacheWidth: 200,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, __) => _placeholder(),
                errorWidget: (_, __, ___) => _placeholder(),
              ),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() => const Center(
        child: Icon(Icons.home_outlined, size: 24, color: HD.inkMuted),
      );
}

class _UnitInventory extends StatelessWidget {
  const _UnitInventory({required this.house});
  final HouseModel house;

  @override
  Widget build(BuildContext context) {
    final full = house.isFull;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 1, color: HD.hairline),
        const SizedBox(width: HD.s8),
        Text(
          full ? 'KÍN PHÒNG' : 'CÒN PHÒNG',
          style: HD.eyebrow(color: full ? HD.inkMuted : HD.accent).copyWith(fontSize: 9.5),
        ),
        const SizedBox(width: HD.s8),
        Text(
          '${house.availableUnits}/${house.totalUnits}',
          style: HD.tabular(color: HD.ink, size: 12),
        ),
      ],
    );
  }
}

class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.onEdit,
    required this.onDelete,
    this.onCloseOneUnit,
    this.onSchedule,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onCloseOneUnit;
  final VoidCallback? onSchedule;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HoverAction(
          icon: Icons.edit_outlined,
          label: 'Sửa',
          onTap: onEdit,
        ),
        if (onSchedule != null) ...[
          _div(),
          _HoverAction(
            icon: Icons.schedule_outlined,
            label: 'Khung giờ',
            onTap: onSchedule!,
          ),
        ],
        _div(),
        _HoverAction(
          icon: Icons.delete_outline,
          label: 'Xoá',
          tone: HD.negative,
          onTap: onDelete,
        ),
        if (onCloseOneUnit != null) ...[
          _div(),
          _HoverAction(
            icon: Icons.do_not_disturb_on_outlined,
            label: 'Đóng 1 phòng',
            tone: HD.warning,
            onTap: onCloseOneUnit!,
          ),
        ],
      ],
    );
  }

  Widget _div() => Container(
        width: 1,
        height: 14,
        color: HD.hairline,
        margin: const EdgeInsets.symmetric(horizontal: HD.s12),
      );
}

class _HoverAction extends StatelessWidget {
  const _HoverAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? HD.inkSoft;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: HD.s4),
            Text(
              label,
              style: HD.eyebrow(color: color).copyWith(fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}
