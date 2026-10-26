import 'package:flutter/material.dart';
import 'dashboard/host_dashboard_tokens.dart';

/// Khai báo tạm trú urgency banner — shown in Nhà trọ tab (Phase 05).
class HostHomeKhaiBaoBanner extends StatelessWidget {
  const HostHomeKhaiBaoBanner({
    super.key,
    required this.overdueCount,
    required this.pendingCount,
    required this.onTap,
  });

  final int overdueCount;
  final int pendingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUrgent = overdueCount > 0;
    final bg = isUrgent ? HD.negative : HD.warning;
    final headline = isUrgent
        ? '$overdueCount khách quá hạn khai báo tạm trú'
        : '$pendingCount khách chờ khai báo tạm trú';
    final hint = isUrgent
        ? 'Bấm để xử lý gấp (Nghị định 144/2021 — 12h)'
        : 'Gửi link khai báo cho khách trước hạn 12h';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(
              isUrgent ? Icons.warning_amber_rounded : Icons.assignment_outlined,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: HD.bodyBold(color: Colors.white, size: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: HD.caption(color: Colors.white).copyWith(
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}
