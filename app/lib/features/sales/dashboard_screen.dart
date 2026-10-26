/// JP Sales agent dashboard screen.
///
/// Shows KPI cards: 担当物件数, 内見リクエスト待ち数, 申込審査待ち数.
/// Links to [ViewingInboxScreen] and [ApplicationQueueScreen].
///
/// Route: /sales (GoRoute). Only accessible in Japan region builds.
/// Provider: none — loads data via JP repositories.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/repositories/jp/mock_jp_listing_repository.dart';
import 'package:house_booking/data/repositories/jp/mock_jp_viewing_repository.dart';
import 'package:house_booking/data/repositories/jp/mock_jp_application_repository.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_listing_repository.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_viewing_repository.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_application_repository.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class SalesDashboardScreen extends StatefulWidget {
  /// Route: /sales
  const SalesDashboardScreen({
    super.key,
    IJpListingRepository? listingRepo,
    IJpViewingRepository? viewingRepo,
    IJpApplicationRepository? applicationRepo,
  })  : _listingRepo = listingRepo,
        _viewingRepo = viewingRepo,
        _applicationRepo = applicationRepo;

  final IJpListingRepository? _listingRepo;
  final IJpViewingRepository? _viewingRepo;
  final IJpApplicationRepository? _applicationRepo;

  @override
  State<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends State<SalesDashboardScreen> {
  late final IJpListingRepository _listingRepo;
  late final IJpViewingRepository _viewingRepo;
  late final IJpApplicationRepository _applicationRepo;

  int _assignedListings = 0;
  int _pendingViewings = 0;
  int _pendingApplications = 0;
  bool _loading = true;

  // Stub agent ID — in production sourced from JWT claims.
  static const int _agentId = 501;

  @override
  void initState() {
    super.initState();
    _listingRepo = widget._listingRepo ?? const MockJpListingRepository();
    _viewingRepo = widget._viewingRepo ?? MockJpViewingRepository();
    _applicationRepo =
        widget._applicationRepo ?? MockJpApplicationRepository();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _listingRepo.search(const JpListingSearchParams(pageSize: 1)),
        _viewingRepo.listForAgent(_agentId),
        _applicationRepo.listForAgent(_agentId),
      ]);
      if (mounted) {
        setState(() {
          // Use actual count where possible; mock returns all fixtures.
          _assignedListings = (results[0] as List).length;
          _pendingViewings = (results[1] as List).length;
          _pendingApplications = (results[2] as List).length;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        eyebrow: '仲介',
        title: l.jp_sales_dashboard_title,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: HD.accent))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // KPI cards row
                  Row(
                    children: [
                      Expanded(
                        child: _KpiCard(
                          label: l.jp_assigned_listings,
                          value: _assignedListings,
                          icon: Icons.home_outlined,
                          onTap: () => context.push('/sales/listings'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _KpiCard(
                          label: l.jp_pending_viewings,
                          value: _pendingViewings,
                          icon: Icons.calendar_month_outlined,
                          onTap: () => context.push('/sales/viewings'),
                          badge: _pendingViewings > 0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _KpiCard(
                          label: l.jp_pending_applications,
                          value: _pendingApplications,
                          icon: Icons.assignment_outlined,
                          onTap: () => context.push('/sales/applications'),
                          badge: _pendingApplications > 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Quick nav tiles
                  _NavTile(
                    icon: Icons.inbox_outlined,
                    title: l.jp_viewing_inbox_title,
                    badge: _pendingViewings,
                    onTap: () => context.push('/sales/viewings'),
                  ),
                  const SizedBox(height: 8),
                  _NavTile(
                    icon: Icons.queue_outlined,
                    title: l.jp_application_queue_title,
                    badge: _pendingApplications,
                    onTap: () => context.push('/sales/applications'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.badge = false,
  });

  final String label;
  final int value;
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HD.paperRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: badge ? HD.accent : HD.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: badge ? HD.accent : HD.inkMuted, size: 20),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: badge ? HD.accent : HD.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: HD.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DsListTile(
      leading: Icon(icon, color: HD.accent),
      title: title,
      trailing: badge > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: HD.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : const Icon(Icons.chevron_right, color: HD.inkMuted),
      onTap: onTap,
    );
  }
}
