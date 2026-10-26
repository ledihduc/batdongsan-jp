import 'package:flutter/material.dart';
import 'package:house_booking/data/models/revenue_source_model.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// List tile for a single [RevenueSourceModel].
///
/// Displays:
/// - Leading: colour swatch CircleAvatar
/// - Title: [source.displayName] (NEVER raw name)
/// - Subtitle: archived chip OR active indicator
/// - Trailing: PopupMenuButton (Edit / Archive / Delete)
///
/// [linkedCount] is optional — show "—" when unknown (backend may not expose it
/// yet). When > 0, Delete is visually de-emphasised but still wired; the
/// provider will throw [SourceInUseException] and the screen handles the UX.
class SourceListTile extends StatelessWidget {
  const SourceListTile({
    super.key,
    required this.source,
    this.linkedCount,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  final RevenueSourceModel source;

  /// Number of records (invoices/contracts) using this source.
  /// Null = unknown; display "—".
  final int? linkedCount;

  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final swatchColor = _hexToColor(source.colorHex);

    return ListTile(
      key: Key('source_tile_${source.id}'),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: HD.s16,
        vertical: HD.s4,
      ),
      leading: CircleAvatar(
        backgroundColor: swatchColor,
        radius: 16,
      ),
      title: Text(
        source.displayName,
        style: HD.bodyBold(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: _buildSubtitle(),
      trailing: _PopupMenu(
        source: source,
        onEdit: onEdit,
        onArchive: onArchive,
        onDelete: onDelete,
      ),
    );
  }

  Widget _buildSubtitle() {
    if (source.isArchived) {
      return Padding(
        padding: const EdgeInsets.only(top: HD.s4),
        child: _StatusChip(
          label: 'Đã lưu trữ',
          color: HD.inkMuted,
        ),
      );
    }

    final countLabel = linkedCount == null ? '—' : '$linkedCount';
    return Padding(
      padding: const EdgeInsets.only(top: HD.s4),
      child: Row(
        children: [
          _StatusChip(label: 'Đang dùng', color: HD.positive),
          const SizedBox(width: HD.s8),
          Text(
            'Liên kết: $countLabel',
            style: HD.caption(color: HD.inkMuted),
          ),
        ],
      ),
    );
  }

  /// Parse a #RRGGBB hex string to a [Color] with full opacity.
  static Color _hexToColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16) ?? 0x9E9E9E;
    return Color(value | 0xFF000000);
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Private widgets
// ────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: HD.caption(color: color).copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PopupMenu extends StatelessWidget {
  const _PopupMenu({
    required this.source,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  final RevenueSourceModel source;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MenuAction>(
      key: Key('source_menu_${source.id}'),
      onSelected: (action) {
        switch (action) {
          case _MenuAction.edit:
            onEdit();
          case _MenuAction.archive:
            onArchive();
          case _MenuAction.delete:
            onDelete();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          key: Key('menu_edit_${source.id}'),
          value: _MenuAction.edit,
          child: const ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Sửa'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        // Archive option only shown for active sources
        if (!source.isArchived)
          PopupMenuItem(
            key: Key('menu_archive_${source.id}'),
            value: _MenuAction.archive,
            child: const ListTile(
              leading: Icon(Icons.archive_outlined),
              title: Text('Lưu trữ'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        PopupMenuItem(
          key: Key('menu_delete_${source.id}'),
          value: _MenuAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: HD.negative),
            title: Text('Xoá', style: TextStyle(color: HD.negative)),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
    );
  }
}

enum _MenuAction { edit, archive, delete }
