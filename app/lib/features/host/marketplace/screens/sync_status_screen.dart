import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/data/models/marketplace_sync_model.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/marketplace/providers/marketplace_provider.dart';
import 'package:house_booking/features/host/marketplace/screens/publish_room_screen.dart';
import 'package:house_booking/features/host/marketplace/widgets/sync_status_badge.dart';

/// Phase 08 — list per-room sync state with publish / unpublish actions.
class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketplaceProvider>().fetchSyncStatus();
    });
  }

  Future<void> _confirmUnpublish(SyncStatusItem item) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: HD.paperRaised,
        title: Text(l.hSyncHideListingTitle, style: HD.sectionTitle()),
        content: Text(
          l.hSyncHideConfirm(item.roomCode),
          style: HD.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: HD.negative),
            child: Text(l.hSyncHideAction),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final prov = context.read<MarketplaceProvider>();
    final done = await prov.unpublishRoom(item.roomId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(done ? l.hSyncHidden : (prov.error ?? l.hSyncError))),
    );
  }

  Future<void> _openPublish(SyncStatusItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublishRoomScreen(
          roomId: item.roomId,
          roomCode: item.roomCode,
          buildingName: item.buildingName,
        ),
      ),
    );
    if (!mounted) return;
    await context.read<MarketplaceProvider>().fetchSyncStatus();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: l.hSyncTitle,
      ),
      body: Consumer<MarketplaceProvider>(
        builder: (context, prov, _) {
          if (prov.isLoading && prov.items.isEmpty) {
            return const Center(child: DsRowSkeleton());
          }
          if (prov.error != null && prov.items.isEmpty) {
            return DsErrorState(
              message: prov.error!,
              onRetry: () => context.read<MarketplaceProvider>().fetchSyncStatus(),
            );
          }
          if (prov.items.isEmpty) {
            return DsEmptyState(
              icon: Icons.cloud_off_outlined,
              title: l.hSyncEmptyTitle,
              subtitle: l.hSyncEmptySubtitle,
            );
          }
          return RefreshIndicator(
            onRefresh: () => context.read<MarketplaceProvider>().fetchSyncStatus(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: HD.s8),
              itemCount: prov.items.length,
              separatorBuilder: (_, __) => const HDHairline(indent: HD.s20),
              itemBuilder: (context, i) => _tile(prov.items[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _tile(SyncStatusItem item) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HD.s20, vertical: HD.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.buildingName} • ${item.roomCode}',
                  style: HD.bodyBold(),
                ),
              ),
              SyncStatusBadge(badge: item.badge),
            ],
          ),
          if (item.houseStatus != null) ...[
            const SizedBox(height: 4),
            Text(
              l.hSyncMarketplaceStatus(item.houseStatus.toString()),
              style: HD.caption(),
            ),
          ],
          if (item.lastSyncedAt != null) ...[
            const SizedBox(height: 2),
            Text(
              l.hSyncLastSynced(item.lastSyncedAt!.toLocal().toIso8601String().substring(0, 16).replaceAll("T", " ")),
              style: HD.caption(),
            ),
          ],
          const SizedBox(height: HD.s8),
          Row(
            children: [
              if (!item.isListed)
                Expanded(
                  child: FilledButton(
                    onPressed: () => _openPublish(item),
                    style: FilledButton.styleFrom(backgroundColor: HD.ink),
                    child: Text(l.hSyncPublish),
                  ),
                ),
              if (item.isListed) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openPublish(item),
                    child: Text(l.hSyncResync),
                  ),
                ),
                const SizedBox(width: HD.s8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _confirmUnpublish(item),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HD.negative,
                      side: const BorderSide(color: HD.negative),
                    ),
                    child: Text(l.hSyncHide),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
