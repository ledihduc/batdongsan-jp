import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/core/widgets/ds_app_bar.dart';
import 'package:house_booking/data/models/revenue_source_model.dart';
import 'package:house_booking/domain/repositories/i_analytics_repository.dart';
import 'package:house_booking/features/host/analytics/widgets/archive_confirm_dialog.dart';
import 'package:house_booking/features/host/analytics/widgets/delete_confirm_dialog.dart';
import 'package:house_booking/features/host/analytics/widgets/source_edit_dialog.dart';
import 'package:house_booking/features/host/analytics/widgets/source_list_tile.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/providers/report_provider.dart';

/// CRUD screen for managing revenue sources.
///
/// Sections:
///   - Active sources (where !isArchived)
///   - Archived sources (collapsed ExpansionTile)
///
/// Entry points:
///   - `/host/analytics/sources` (GoRoute, deferred)
///   - FilterBottomSheet "Quản lý nguồn" CTA
class SourceManagementScreen extends StatefulWidget {
  const SourceManagementScreen({super.key});

  @override
  State<SourceManagementScreen> createState() => _SourceManagementScreenState();
}

class _SourceManagementScreenState extends State<SourceManagementScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch all sources including archived on entry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context
          .read<ReportProvider>()
          .fetchSources(includeArchived: true, force: true);
    });
  }

  // ─── FAB: open create dialog ─────────────────────────────────────────────

  Future<void> _openCreateDialog() async {
    final provider = context.read<ReportProvider>();
    await showDialog<bool>(
      context: context,
      builder: (_) => SourceEditDialog(
        onSubmit: (name, colorHex) =>
            provider.createSource(name: name, colorHex: colorHex),
      ),
    );
    if (mounted) {
      provider.fetchSources(includeArchived: true, force: true);
    }
  }

  // ─── Edit ─────────────────────────────────────────────────────────────────

  Future<void> _openEditDialog(RevenueSourceModel source) async {
    final provider = context.read<ReportProvider>();
    await showDialog<bool>(
      context: context,
      builder: (_) => SourceEditDialog(
        initial: source,
        onSubmit: (name, colorHex) => provider.updateSource(
          id: source.id,
          name: name,
          colorHex: colorHex,
        ),
      ),
    );
    if (mounted) {
      provider.fetchSources(includeArchived: true, force: true);
    }
  }

  // ─── Archive (optimistic) ─────────────────────────────────────────────────

  Future<void> _confirmArchive(RevenueSourceModel source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const ArchiveConfirmDialog(),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<ReportProvider>();

    // Optimistic: mark archived in cache immediately.
    final snapshot = provider.sources ?? [];
    final optimistic = snapshot
        .map((s) => s.id == source.id ? _asArchived(s) : s)
        .toList();
    provider.patchSourcesOptimistic(optimistic);

    try {
      await provider.archiveSource(source.id);
    } catch (e) {
      // Revert on error.
      if (mounted) {
        provider.patchSourcesOptimistic(snapshot);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu trữ: $e')),
        );
      }
      return;
    }

    if (mounted) {
      provider.fetchSources(includeArchived: true, force: true);
    }
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(RevenueSourceModel source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const DeleteConfirmDialog(),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<ReportProvider>();

    try {
      await provider.deleteSource(source.id);
      if (mounted) {
        provider.fetchSources(includeArchived: true, force: true);
      }
    } on SourceInUseException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đang được sử dụng — chỉ có thể lưu trữ'),
            action: SnackBarAction(
              label: 'Lưu trữ',
              onPressed: () => _confirmArchive(source),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xoá: $e')),
        );
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: const DsAppBar(
        title: 'Quản lý nguồn doanh thu',
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_source_fab'),
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Thêm'),
        backgroundColor: HD.ink,
        foregroundColor: HD.paperRaised,
      ),
      body: Consumer<ReportProvider>(
        builder: (context, provider, _) {
          if (provider.sourcesLoading && (provider.sources == null)) {
            return const _LoadingSkeleton();
          }

          if (provider.sourcesError != null && provider.sources == null) {
            return _ErrorState(
              error: provider.sourcesError!,
              onRetry: () => provider.fetchSources(
                includeArchived: true,
                force: true,
              ),
            );
          }

          final all = provider.sources ?? [];
          final active =
              all.where((s) => !s.isArchived).toList();
          final archived =
              all.where((s) => s.isArchived).toList();

          return RefreshIndicator(
            onRefresh: () => provider.fetchSources(
              includeArchived: true,
              force: true,
            ),
            child: CustomScrollView(
              slivers: [
                // ── Active section ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        HD.s16, HD.s16, HD.s16, HD.s8),
                    child: Text(
                      'ĐANG HOẠT ĐỘNG (${active.length})',
                      style: HD.eyebrow(),
                    ),
                  ),
                ),
                if (active.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: HD.s16,
                        vertical: HD.s12,
                      ),
                      child: Text('Chưa có nguồn nào đang hoạt động'),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final s = active[i];
                        return Column(
                          children: [
                            SourceListTile(
                              source: s,
                              onEdit: () => _openEditDialog(s),
                              onArchive: () => _confirmArchive(s),
                              onDelete: () => _confirmDelete(s),
                            ),
                            const HDHairline(indent: HD.s16),
                          ],
                        );
                      },
                      childCount: active.length,
                    ),
                  ),
                // ── Archived section ────────────────────────────────────
                if (archived.isNotEmpty)
                  SliverToBoxAdapter(
                    child: ExpansionTile(
                      key: const Key('archived_section'),
                      title: Text(
                        'ĐÃ LƯU TRỮ (${archived.length})',
                        style: HD.eyebrow(),
                      ),
                      initiallyExpanded: false,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: HD.s16,
                        vertical: HD.s4,
                      ),
                      children: archived
                          .map(
                            (s) => SourceListTile(
                              source: s,
                              onEdit: () => _openEditDialog(s),
                              onArchive: () {}, // already archived — no-op
                              onDelete: () => _confirmDelete(s),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                // Bottom padding so FAB doesn't overlap last tile.
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Returns a copy of [s] with [isArchived] forced to true (for optimistic UI).
  RevenueSourceModel _asArchived(RevenueSourceModel s) {
    return RevenueSourceModel(
      id: s.id,
      hostId: s.hostId,
      name: s.name,
      displayName: s.displayName,
      colorHex: s.colorHex,
      isArchived: true,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
    );
  }
}

// ─── Loading skeleton ────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(HD.s16),
      itemCount: 5,
      separatorBuilder: (_, _) => const HDHairline(),
      itemBuilder: (_, _) => const _SkeletonTile(),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: HD.hairline,
          shape: BoxShape.circle,
        ),
      ),
      title: Container(
        height: 14,
        width: 120,
        color: HD.hairline,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: HD.s4),
        child: Container(height: 10, width: 60, color: HD.hairline),
      ),
    );
  }
}

// ─── Error state ─────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HD.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: HD.accent, size: 40),
            const SizedBox(height: HD.s12),
            Text(error, style: HD.body(), textAlign: TextAlign.center),
            const SizedBox(height: HD.s16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: HD.ink,
                foregroundColor: HD.paperRaised,
              ),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
