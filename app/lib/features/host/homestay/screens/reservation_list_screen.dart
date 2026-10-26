import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:house_booking/l10n/app_localizations.dart';
import 'package:house_booking/data/models/reservation_model.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';
import 'package:house_booking/features/host/homestay/providers/reservation_provider.dart';
import 'package:house_booking/features/host/homestay/widgets/reservation_status_badge.dart';
import 'package:house_booking/features/host/homestay/screens/reservation_detail_screen.dart';

/// Phase 07 — host's reservation queue, filterable by status.
class ReservationListScreen extends StatefulWidget {
  const ReservationListScreen({super.key});

  @override
  State<ReservationListScreen> createState() => _ReservationListScreenState();
}

class _ReservationListScreenState extends State<ReservationListScreen> {
  static const _statuses = [
    'all',
    'pending',
    'approved',
    'checked_in',
    'checked_out',
    'cancelled',
  ];
  String _current = 'all';

  String _filterLabel(AppLocalizations l, String status) {
    switch (status) {
      case 'pending':
        return l.hResvListFilterPending;
      case 'approved':
        return l.hResvListFilterApproved;
      case 'checked_in':
        return l.hResvListFilterCheckedIn;
      case 'checked_out':
        return l.hResvListFilterCheckedOut;
      case 'cancelled':
        return l.hResvListFilterCancelled;
      default:
        return l.hResvListFilterAll;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReservationProvider>().fetchList();
    });
  }

  Future<void> _refetch() async {
    await context
        .read<ReservationProvider>()
        .fetchList(status: _current == 'all' ? null : _current);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        title: l.hResvListTitle,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: HD.s16),
              children: [
                for (final s in _statuses)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(_filterLabel(l, s)),
                      selected: _current == s,
                      onSelected: (_) async {
                        setState(() => _current = s);
                        await _refetch();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const HDHairline(),
          Expanded(
            child: Consumer<ReservationProvider>(
              builder: (context, prov, _) {
                if (prov.isLoading && prov.records.isEmpty) {
                  return const Center(child: DsRowSkeleton());
                }
                if (prov.error != null && prov.records.isEmpty) {
                  return DsErrorState(
                    message: prov.error!,
                    onRetry: _refetch,
                  );
                }
                if (prov.records.isEmpty) {
                  return DsEmptyState(
                    icon: Icons.event_busy_rounded,
                    title: l.hResvListEmptyTitle,
                    subtitle: l.hResvListEmptySubtitle,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: HD.s8),
                  itemCount: prov.records.length,
                  separatorBuilder: (_, __) => const HDHairline(indent: HD.s20),
                  itemBuilder: (context, i) =>
                      _reservationTile(prov.records[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _reservationTile(ReservationModel r) {
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReservationDetailScreen(reservationId: r.id),
          ),
        );
        await _refetch();
      },
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: HD.s20, vertical: HD.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(r.guestName, style: HD.bodyBold())),
                ReservationStatusBadge(status: r.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${r.checkInDate} → ${r.checkOutDate} • ${l.hResvListNights(r.nights)}',
              style: HD.caption(),
            ),
            const SizedBox(height: 2),
            Text(
              '${r.buildingName ?? '—'} • ${r.roomCode ?? '—'}',
              style: HD.caption(),
            ),
            const SizedBox(height: 4),
            Text(
              '${(r.totalAmount / 1000).toStringAsFixed(0)}K VND',
              style: HD.tabular(size: 13),
            ),
          ],
        ),
      ),
    );
  }
}
