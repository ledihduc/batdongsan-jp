import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/services/management_read_model_api.dart';

/// Component library tối thiểu của Management V2.
///
/// Các widget chỉ trình bày read-model do server phát hành. Chúng không tự suy
/// đoán quyền, không biến [ManagementWorkItem.allowedActions] thành command và
/// không thay đổi bất kỳ màn nghiệp vụ legacy nào.
class ManagementBucketSelector extends StatelessWidget {
  const ManagementBucketSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ManagementBucket selected;
  final ValueChanged<ManagementBucket> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      scrollDirection: Axis.horizontal,
      itemCount: ManagementBucket.values.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, index) {
        final value = ManagementBucket.values[index];
        final active = value == selected;
        return Semantics(
          selected: active,
          button: true,
          label: 'Lọc theo ${managementBucketLabel(value)}',
          child: ChoiceChip(
            key: Key('management-v2-bucket-${value.value}'),
            label: Text(managementBucketLabel(value)),
            selected: active,
            onSelected: (_) => onSelected(value),
            selectedColor: HD.accent.withValues(alpha: .12),
            side: BorderSide(
              color: active ? HD.accent : const Color(0xffe6ebf2),
            ),
            labelStyle: active
                ? HD.bodyBold(size: 12.5, color: HD.accent)
                : HD.body(size: 12.5, color: HD.inkMuted),
          ),
        );
      },
    ),
  );
}

class ManagementWorkItemCard extends StatelessWidget {
  const ManagementWorkItemCard({super.key, required this.item, this.onOpen});

  final ManagementWorkItem item;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final accent = item.needsAction ? HD.accent : const Color(0xff246be8);
    final icon = switch (item.kind) {
      'VIEWING' => Icons.calendar_month_rounded,
      'RENTAL_JOURNEY' => Icons.description_rounded,
      'RESERVATION' => Icons.hotel_rounded,
      'CONTRACT' => Icons.article_rounded,
      'INVOICE' => Icons.receipt_long_rounded,
      _ => Icons.assignment_outlined,
    };
    return Semantics(
      container: true,
      button: onOpen != null,
      label: '${item.title}. ${item.subtitle}',
      hint: onOpen == null ? null : 'Mở màn chi tiết hiện có',
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xffe7edf3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: HD.bodyBold(size: 14, color: HD.ink),
                        ),
                      ),
                      if (item.needsAction) const _NeedsActionBadge(),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    style: HD.body(size: 12.5, color: HD.inkMuted),
                  ),
                  if (item.allowedActions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Có ${item.allowedActions.length} thao tác theo quyền của bạn',
                      style: HD.body(size: 11.5, color: HD.inkSoft),
                    ),
                  ],
                  if (onOpen != null && item.detailRoute.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: Key('management-v2-open-${item.id}'),
                        onPressed: onOpen,
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Mở chi tiết'),
                        style: TextButton.styleFrom(
                          foregroundColor: HD.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(48, 48),
                          tapTargetSize: MaterialTapTargetSize.padded,
                          textStyle: HD.bodyBold(size: 11.5),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NeedsActionBadge extends StatelessWidget {
  const _NeedsActionBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: HD.accent.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text('Cần xử lý', style: HD.bodyBold(size: 10.5, color: HD.accent)),
  );
}

String managementBucketLabel(ManagementBucket value) => switch (value) {
  ManagementBucket.actionRequired => 'Cần xử lý',
  ManagementBucket.waitingExternal => 'Chờ phản hồi',
  ManagementBucket.upcoming => 'Sắp tới',
  ManagementBucket.afterViewing => 'Sau khi xem',
  ManagementBucket.history => 'Lịch sử',
};
