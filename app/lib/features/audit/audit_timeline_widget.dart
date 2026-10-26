/// Audit timeline widget — vertical timeline of delegation action entries.
///
/// Each entry shows: timestamp, operator avatar initials, action description,
/// entity link. Dual-identity display (who did it, on whose behalf).
library;

import 'package:flutter/material.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class AuditTimelineWidget extends StatelessWidget {
  const AuditTimelineWidget({
    super.key,
    required this.entries,
  });

  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: HD.s16,
        vertical: HD.s12,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isLast = index == entries.length - 1;
        return _TimelineRow(
          entry: entry,
          isLast: isLast,
        );
      },
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.entry,
    required this.isLast,
  });

  final Map<String, dynamic> entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final operatorName = entry['operator_name'] as String? ?? l.auditTlOperator;
    final ownerName = entry['owner_name'] as String? ?? l.auditTlOwner;
    final actionDesc = entry['action_description'] as String? ?? l.auditTlAction;
    final rawTs = entry['created_at'] as String?;
    final timestamp = rawTs != null ? DateTime.tryParse(rawTs) : null;
    final entityType = entry['entity_type'] as String?;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline spine
          SizedBox(
            width: 40,
            child: Column(
              children: [
                _Avatar(name: operatorName),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: HD.hairline,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: HD.s12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: HD.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        operatorName,
                        style: HD.bodyBold(color: HD.ink, size: 13),
                      ),
                      const SizedBox(width: HD.s4),
                      Text(
                        '→ $ownerName',
                        style: HD.caption(color: HD.inkMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    actionDesc,
                    style: HD.body(color: HD.inkSoft, size: 13),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (entityType != null) ...[
                        DsStatusPill(
                          label: entityType,
                          tone: DsStatusTone.neutral,
                          dense: true,
                        ),
                        const SizedBox(width: HD.s8),
                      ],
                      if (timestamp != null)
                        Text(
                          _formatTimestamp(timestamp, l),
                          style: HD.caption(color: HD.inkMuted),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt, AppLocalizations l) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return l.auditTlJustNow;
    if (diff.inHours < 1) return l.auditTlMinutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l.auditTlHoursAgo(diff.inHours);
    if (diff.inDays < 7) return l.auditTlDaysAgo(diff.inDays);

    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    return CircleAvatar(
      radius: 16,
      backgroundColor: HD.accentSoft,
      child: Text(
        initials,
        style: HD.caption(color: HD.accent).copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
