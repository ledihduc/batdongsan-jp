import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:house_booking/data/models/dashboard_action_items_model.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/providers/dashboard_provider.dart';

/// 'Cần action' aggregated section on host dashboard.
/// Shows 4 buckets — expiring contracts, overdue invoices, overdue khai báo,
/// rooms in maintenance — with quick taps and Zalo reminder shortcut.
class ActionItemsSection extends StatelessWidget {
  final ValueChanged<int>? onTapInvoice;
  final ValueChanged<int>? onTapContract;
  final ValueChanged<int>? onTapRoom;
  final VoidCallback? onTapKhaiBao;

  const ActionItemsSection({
    super.key,
    this.onTapInvoice,
    this.onTapContract,
    this.onTapRoom,
    this.onTapKhaiBao,
  });

  String _fmt(double v) => NumberFormat.decimalPattern('vi').format(v.round());

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prov = context.watch<DashboardProvider>();
    final data = prov.actionItems;

    if (!data.hasAny && !prov.isLoading) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: HD.paperRaised,
        border: Border.all(color: HD.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Text(l.hActionItemsHeader,
                    style: HD.eyebrow(color: HD.accent)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: HD.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text('${data.summary.total}',
                      style: HD.tabular(color: Colors.white, size: 11)),
                ),
                const Spacer(),
                if (prov.isLoading)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
              ],
            ),
          ),
          if (data.overdueInvoices.isNotEmpty) ...[
            const HDHairline(),
            _BucketHeader(
              label: l.hActionItemsOverdueInvoices,
              count: data.summary.overdueInvoiceCount,
            ),
            for (final inv in data.overdueInvoices.take(3))
              _OverdueInvoiceRow(
                row: inv,
                fmt: _fmt,
                onTap: () => onTapInvoice?.call(inv.invoiceId),
                onReminder: () => _sendZaloReminder(context, inv),
              ),
          ],
          if (data.expiringContracts.isNotEmpty) ...[
            const HDHairline(),
            _BucketHeader(
              label: l.hActionItemsExpiringContracts,
              count: data.summary.expiringCount,
            ),
            for (final c in data.expiringContracts.take(3))
              _ExpiringContractRow(
                row: c,
                fmt: _fmt,
                onTap: () => onTapContract?.call(c.contractId),
              ),
          ],
          if (data.overdueKhaiBao.isNotEmpty) ...[
            const HDHairline(),
            _BucketHeader(
              label: l.hActionItemsOverdueKhaiBao,
              count: data.summary.overdueKhaiBaoCount,
            ),
            for (final k in data.overdueKhaiBao.take(3))
              _KhaiBaoRow(row: k, onTap: onTapKhaiBao),
          ],
          if (data.maintenanceRooms.isNotEmpty) ...[
            const HDHairline(),
            _BucketHeader(
              label: l.hActionItemsMaintenanceRooms,
              count: data.summary.maintenanceCount,
            ),
            for (final r in data.maintenanceRooms.take(3))
              _MaintenanceRow(
                row: r,
                onTap: () => onTapRoom?.call(r.roomId),
              ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Future<void> _sendZaloReminder(
    BuildContext context,
    OverdueInvoiceRow inv,
  ) async {
    final result = await context
        .read<DashboardProvider>()
        .buildInvoiceZaloReminder(invoiceId: inv.invoiceId);
    if (!context.mounted) return;
    if (result == null || result.zaloLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context).hActionItemsZaloFailed)),
      );
      return;
    }
    final uri = Uri.tryParse(result.zaloLink);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _BucketHeader extends StatelessWidget {
  final String label;
  final int count;
  const _BucketHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: HD.bodyBold(size: 13))),
          Text('$count', style: HD.tabular(color: HD.inkMuted, size: 12)),
        ],
      ),
    );
  }
}

class _OverdueInvoiceRow extends StatelessWidget {
  final OverdueInvoiceRow row;
  final String Function(double) fmt;
  final VoidCallback? onTap;
  final VoidCallback? onReminder;

  const _OverdueInvoiceRow({
    required this.row,
    required this.fmt,
    required this.onTap,
    required this.onReminder,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.invoiceNumber, style: HD.bodyBold(size: 13)),
                  const SizedBox(height: 2),
                  Text(
                    l.hActionItemsInvoiceDue(row.dueDate, fmt(row.remaining)),
                    style: HD.caption(color: HD.negative),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              tooltip: l.hActionItemsRemindZalo,
              color: HD.accent,
              onPressed: onReminder,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiringContractRow extends StatelessWidget {
  final ExpiringContractRow row;
  final String Function(double) fmt;
  final VoidCallback? onTap;

  const _ExpiringContractRow({
    required this.row,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      l.hActionItemsContractRoom(row.contractId, row.roomId),
                      style: HD.bodyBold(size: 13)),
                  const SizedBox(height: 2),
                  Text(
                      l.hActionItemsContractExpiry(
                          row.endDate, fmt(row.monthlyRent)),
                      style: HD.caption(color: HD.warning)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: HD.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _KhaiBaoRow extends StatelessWidget {
  final OverdueKhaiBaoRow row;
  final VoidCallback? onTap;
  const _KhaiBaoRow({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.hActionItemsTenant(row.tenantId),
                      style: HD.bodyBold(size: 13)),
                  const SizedBox(height: 2),
                  Text(l.hActionItemsCheckIn(row.checkInAt),
                      style: HD.caption(color: HD.negative)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: HD.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceRow extends StatelessWidget {
  final MaintenanceRoomRow row;
  final VoidCallback? onTap;
  const _MaintenanceRow({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${row.roomCode} · ${row.buildingName}',
                      style: HD.bodyBold(size: 13)),
                  const SizedBox(height: 2),
                  Text(
                    row.maintenanceStart != null
                        ? l.hActionItemsMaintenanceSince(row.maintenanceStart!)
                        : l.hActionItemsMaintenanceActive,
                    style: HD.caption(color: HD.warning),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: HD.inkMuted),
          ],
        ),
      ),
    );
  }
}
